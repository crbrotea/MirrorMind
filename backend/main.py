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

from mirror_mind.agent import root_agent
from mirror_mind.config import (
    APP_NAME,
    CORS_ORIGINS,
    HOST,
    LOG_LEVEL,
    PORT,
    VOICE_NAME,
)
from mirror_mind.session_manager import (
    close_session,
    create_session,
    get_session_metadata,
    record_emotion,
    record_image_generated,
    update_activity,
)
from mirror_mind.gallery_service import save_session as save_gallery_session

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
# ADK runner (shared across all connections)
# ---------------------------------------------------------------------------
runner = InMemoryRunner(app_name=APP_NAME, agent=root_agent)


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

    # Track the previous state to detect changes
    last_image_check: str | None = None
    last_stage: str | None = "welcome"
    last_emotion: str | None = "neutral"

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
        nonlocal last_image_check, last_stage, last_emotion

        try:
            async for event in events:
                # Check WebSocket is still open
                if ws.client_state != WebSocketState.CONNECTED:
                    break

                # Process event content parts
                if event.content and event.content.parts:
                    for part in event.content.parts:
                        # Audio data from Live API
                        if part.inline_data and part.inline_data.data:
                            mime = getattr(part.inline_data, "mime_type", "")
                            if "audio" in mime or not part.text:
                                await ws.send_bytes(part.inline_data.data)

                        # Transcript text
                        if part.text:
                            author = getattr(event, "author", "agent") or "agent"
                            await _send_json(ws, {
                                "type": "transcript",
                                "text": part.text,
                                "author": author,
                            })

                # Check session state for updates pushed by tools
                try:
                    updated_session = await runner.session_service.get_session(
                        app_name=APP_NAME,
                        user_id=user_id,
                        session_id=session.id,
                    )
                except Exception:
                    continue

                if updated_session is None:
                    continue

                state = updated_session.state

                # Image update
                if state.get("image_updated"):
                    image_b64 = state.get("latest_image")
                    if image_b64 and image_b64 != last_image_check:
                        last_image_check = image_b64
                        await _send_json(ws, {
                            "type": "image",
                            "data": image_b64,
                            "emotion": state.get("latest_image_emotion", ""),
                            "stage": state.get("latest_image_stage", ""),
                        })
                        await record_image_generated(user_id)
                    state["image_updated"] = False

                # Stage change
                current_stage = state.get("current_stage", "welcome")
                if current_stage != last_stage:
                    last_stage = current_stage
                    await _send_json(ws, {
                        "type": "stage_change",
                        "stage": current_stage,
                    })

                # Emotion update
                current_emotion = state.get("current_emotion", "neutral")
                if current_emotion != last_emotion:
                    last_emotion = current_emotion
                    await record_emotion(user_id, current_emotion, current_stage)
                    await _send_json(ws, {
                        "type": "emotion_update",
                        "emotion": current_emotion,
                        "stage": current_stage,
                    })

                # Breathing pattern activation
                active_breathing = state.get("active_breathing")
                if active_breathing:
                    from mirror_mind.breathing import get_breathing_pattern
                    pattern = get_breathing_pattern(active_breathing)
                    await _send_json(ws, {
                        "type": "breathing_pattern",
                        "pattern": pattern,
                    })
                    state["active_breathing"] = None

        except WebSocketDisconnect:
            logger.info("Client disconnected (send loop): %s", user_id)
        except Exception as e:
            logger.error("Error in send loop for %s: %s", user_id, e)

    # ------------------------------------------------------------------
    # Run both loops concurrently
    # ------------------------------------------------------------------
    try:
        await asyncio.gather(
            receive_from_client(),
            send_to_client(),
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
                    images=[],  # Full image persistence handled separately
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
