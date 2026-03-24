"""MirrorMind backend - FastAPI server with WebSocket endpoint for real-time
voice-driven emotional art generation.

Data flow:
  Browser mic -> PCM audio over WebSocket -> ADK LiveRequestQueue -> Gemini Live API
  -> model detects emotion from voice -> calls analyze_and_generate_art tool
  -> tool calls Gemini Image API -> base64 image stored in session state
  -> WebSocket pushes image JSON to browser -> browser renders new landscape

Protocol:
  - Binary frames: PCM audio (Int16 16kHz mono from client, 24kHz from server)
  - JSON text frames from server (see WebSocket message types below)
"""

from __future__ import annotations

import asyncio
import json
import logging
import time

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from starlette.websockets import WebSocketState
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from google.adk.agents import LiveRequestQueue
from google.adk.runners import InMemoryRunner
from google.adk.agents.run_config import RunConfig
from google.genai import types

from mirror_mind.config import (
    APP_NAME,
    CORS_ORIGINS,
    HOST,
    LOG_LEVEL,
    PORT,
    TEST_MODE,
    VOICE_NAME,
)

if not TEST_MODE:
    from mirror_mind.agent import root_agent
    from mirror_mind.session_manager import (
        close_session,
        create_session,
        get_session_metadata,
        record_emotion,
        record_image_generated,
        set_session_service,
        update_activity,
    )
    from mirror_mind.gallery_service import save_session as save_gallery_session
    from mirror_mind.image_service import get_image_queue, remove_image_queue

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL.upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("mirrormind")

# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(
    title="MirrorMind API",
    description="Emotional mirror backend - real-time voice analysis and art generation",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# ADK runner (shared across all connections) — skipped in test mode
# ---------------------------------------------------------------------------
runner = None
if not TEST_MODE:
    runner = InMemoryRunner(app_name=APP_NAME, agent=root_agent)
    set_session_service(runner.session_service)
else:
    logger.warning("🧪 TEST_MODE active — using mock agent (no Gemini API calls)")


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------
@app.get("/health")
async def health_check() -> JSONResponse:
    """Health check endpoint for load balancers and Cloud Run."""
    return JSONResponse(
        content={
            "status": "healthy",
            "service": "mirrormind",
            "timestamp": time.time(),
        }
    )


# ---------------------------------------------------------------------------
# WebSocket endpoint
# ---------------------------------------------------------------------------
@app.websocket("/ws/{user_id}")
async def websocket_endpoint(ws: WebSocket, user_id: str) -> None:
    """Main WebSocket endpoint for a MirrorMind session.

    Accepts PCM audio from the browser microphone, forwards it to the ADK
    live runner (Gemini Live API), and sends back audio, transcripts, images,
    breathing patterns, and stage changes.
    """
    # In test mode, use the scripted mock session instead of real ADK
    if TEST_MODE:
        from mirror_mind.test_fixtures import run_mock_session
        await run_mock_session(ws, user_id)
        return

    await ws.accept()
    logger.info("WebSocket connected for user %s", user_id)

    # Create a fresh session
    session = await create_session(user_id)

    # Set up the live request queue and run config
    live_queue = LiveRequestQueue()

    run_config = RunConfig(
        response_modalities=["AUDIO"],
        speech_config=types.SpeechConfig(
            voice_config=types.VoiceConfig(
                prebuilt_voice_config=types.PrebuiltVoiceConfig(
                    voice_name=VOICE_NAME,
                )
            )
        ),
        output_audio_transcription=types.AudioTranscriptionConfig(),
        input_audio_transcription=types.AudioTranscriptionConfig(),
    )

    # Start the live agent stream
    events = runner.run_live(
        session=session,
        live_request_queue=live_queue,
        run_config=run_config,
    )

    last_stage: str | None = "welcome"
    last_emotion: str | None = "neutral"
    session_images: list[dict] = []  # Accumulate images for gallery

    # ------------------------------------------------------------------
    # Receive loop: browser -> ADK
    # ------------------------------------------------------------------
    async def receive_from_client() -> None:
        """Forward microphone audio and text from the browser to the Live API."""
        try:
            while True:
                message = await ws.receive()

                if message.get("type") == "websocket.disconnect":
                    break

                if "bytes" in message and message["bytes"]:
                    # PCM audio chunk from browser mic (Int16, 16kHz mono)
                    audio_blob = types.Blob(
                        mime_type="audio/pcm",
                        data=message["bytes"],
                    )
                    live_queue.send_realtime(audio_blob)
                    await update_activity(user_id)

                elif "text" in message and message["text"]:
                    try:
                        data = json.loads(message["text"])
                    except json.JSONDecodeError:
                        continue

                    msg_type = data.get("type", "")

                    if msg_type == "text":
                        # Text message from the user (typed input)
                        content = types.Content(
                            parts=[types.Part(text=data.get("text", ""))]
                        )
                        live_queue.send_content(content)

                    elif msg_type == "barge_in":
                        # User interrupted the agent — frontend already
                        # stopped playback; Gemini will handle the new
                        # audio input natively.
                        logger.info("Barge-in from user %s", user_id)

                    elif msg_type == "end_session":
                        # Client requests to end the session
                        break

        except WebSocketDisconnect:
            logger.info("Client disconnected (receive loop): %s", user_id)
        except Exception as e:
            logger.error("Error in receive loop for %s: %s", user_id, e)
        finally:
            live_queue.close()

    # ------------------------------------------------------------------
    # Send loop: ADK -> browser
    # ------------------------------------------------------------------
    async def send_to_client() -> None:
        """Forward agent audio, transcripts, and state updates to the browser."""
        nonlocal last_stage, last_emotion
        sending_audio = False

        try:
            async for event in events:
                # Check WebSocket is still open
                if ws.client_state != WebSocketState.CONNECTED:
                    break

                # Process event content parts
                if event.content and event.content.parts:
                    has_audio_in_event = False

                    for part in event.content.parts:
                        # Audio data from Live API
                        if part.inline_data and part.inline_data.data:
                            mime = getattr(part.inline_data, "mime_type", "")
                            if "audio" in mime or not part.text:
                                # Signal turn start on first audio chunk
                                if not sending_audio:
                                    sending_audio = True
                                    await _send_json(ws, {
                                        "type": "turn_state",
                                        "speaking": True,
                                    })
                                await ws.send_bytes(part.inline_data.data)
                                has_audio_in_event = True

                        # Transcript text
                        if part.text:
                            author = getattr(event, "author", "agent") or "agent"
                            await _send_json(ws, {
                                "type": "transcript",
                                "text": part.text,
                                "author": author,
                            })

                    # If we were sending audio but this event had none, turn ended
                    if sending_audio and not has_audio_in_event:
                        sending_audio = False
                        await _send_json(ws, {
                            "type": "turn_state",
                            "speaking": False,
                        })
                else:
                    # Non-content event while sending audio means turn ended
                    if sending_audio:
                        sending_audio = False
                        await _send_json(ws, {
                            "type": "turn_state",
                            "speaking": False,
                        })

                # Note: images are delivered via the dedicated deliver_images loop

        except WebSocketDisconnect:
            logger.info("Client disconnected (send loop): %s", user_id)
        except Exception as e:
            logger.error("Error in send loop for %s: %s", user_id, e)
        finally:
            # Ensure we send end signal if loop exits while speaking
            if sending_audio and ws.client_state == WebSocketState.CONNECTED:
                await _send_json(ws, {"type": "turn_state", "speaking": False})

    # ------------------------------------------------------------------
    # Image delivery loop: reads from the image queue and sends to client
    # ------------------------------------------------------------------
    async def deliver_images() -> None:
        """Read images from the queue and send them to the browser."""
        queue = get_image_queue(user_id)
        try:
            while True:
                if ws.client_state != WebSocketState.CONNECTED:
                    break
                try:
                    image_msg = await asyncio.wait_for(queue.get(), timeout=1.0)
                    await _send_json(ws, image_msg)
                    await record_image_generated(user_id)
                    # Store for gallery persistence
                    session_images.append({
                        "data": image_msg["data"],
                        "emotion": image_msg.get("emotion", ""),
                        "stage": image_msg.get("stage", ""),
                        "timestamp": time.time(),
                    })
                    logger.info("Delivered image to user %s", user_id)
                except asyncio.TimeoutError:
                    continue
        except Exception as e:
            logger.error("Error in image delivery for %s: %s", user_id, e)

    # ------------------------------------------------------------------
    # Run all loops concurrently
    # ------------------------------------------------------------------
    try:
        await asyncio.gather(
            receive_from_client(),
            send_to_client(),
            deliver_images(),
            return_exceptions=True,
        )
    finally:
        # Session cleanup
        logger.info("Cleaning up session for user %s", user_id)

        # Save to gallery before closing
        meta = get_session_metadata(user_id)
        if meta is not None:
            try:
                # Collect images from the session journey for gallery
                session_data = await runner.session_service.get_session(
                    app_name=APP_NAME,
                    user_id=user_id,
                    session_id=session.id,
                )
                journey = (
                    session_data.state.get("emotional_journey", [])
                    if session_data
                    else []
                )
                gallery_id = await save_gallery_session(
                    user_id=user_id,
                    session_id=meta.session_id,
                    emotional_journey=journey,
                    images=session_images,
                    duration_seconds=time.time() - meta.created_at,
                    final_emotion=last_emotion or "neutral",
                    final_stage=last_stage or "welcome",
                )

                # Notify client if still connected
                if ws.client_state == WebSocketState.CONNECTED:
                    await _send_json(ws, {
                        "type": "session_complete",
                        "gallery_id": gallery_id,
                    })

            except Exception as e:
                logger.error("Failed to save gallery for %s: %s", user_id, e)

        await close_session(user_id)
        remove_image_queue(user_id)

        # Close the WebSocket if still open
        if ws.client_state == WebSocketState.CONNECTED:
            try:
                await ws.close()
            except Exception:
                pass

        logger.info("Session fully cleaned up for user %s", user_id)


async def _send_json(ws: WebSocket, data: dict) -> None:
    """Send a JSON message over WebSocket with error handling."""
    try:
        if ws.client_state == WebSocketState.CONNECTED:
            await ws.send_json(data)
    except Exception as e:
        logger.warning("Failed to send JSON to client: %s", e)


# ---------------------------------------------------------------------------
# Gallery REST endpoints (for frontend to fetch past sessions)
# ---------------------------------------------------------------------------
@app.get("/api/gallery/{user_id}")
async def get_user_gallery(user_id: str) -> JSONResponse:
    """Get all gallery entries for a user."""
    from mirror_mind.gallery_service import get_gallery
    entries = await get_gallery(user_id)
    return JSONResponse(content={"gallery": entries})


@app.get("/api/gallery/{user_id}/{gallery_id}")
async def get_gallery_detail(user_id: str, gallery_id: str) -> JSONResponse:
    """Get full detail for a specific gallery entry."""
    from mirror_mind.gallery_service import get_session_detail
    detail = await get_session_detail(gallery_id)
    if detail is None:
        return JSONResponse(status_code=404, content={"error": "Session not found"})
    return JSONResponse(content=detail)


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=HOST,
        port=PORT,
        reload=False,
        log_level=LOG_LEVEL.lower(),
    )
