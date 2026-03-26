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
import base64
import json
import logging
import time
from collections import defaultdict
from typing import Literal

import uvicorn
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from starlette.websockets import WebSocketState
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, ValidationError
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
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
# Security constants
# ---------------------------------------------------------------------------
MAX_WS_BINARY_SIZE = 64 * 1024  # 64 KB max for audio frames
IDLE_TIMEOUT_SECONDS = 10 * 60  # 10 minutes without audio
MAX_SESSION_DURATION_SECONDS = 60 * 60  # 60 minutes absolute max

# Per-IP WebSocket connection tracking
_ws_connections_per_ip: dict[str, int] = defaultdict(int)
MAX_WS_CONNECTIONS_PER_IP = 3


# ---------------------------------------------------------------------------
# Pydantic models for incoming WebSocket JSON messages (SEC-06, SEC-07)
# ---------------------------------------------------------------------------
class WsTextMessage(BaseModel):
    type: Literal["text"]
    text: str = Field(..., min_length=1, max_length=5000)


class WsBargeInMessage(BaseModel):
    type: Literal["barge_in"]


class WsEndSessionMessage(BaseModel):
    type: Literal["end_session"]


# ---------------------------------------------------------------------------
# Base64 PNG validation helper (SEC-10)
# ---------------------------------------------------------------------------
PNG_HEADER = b"\x89PNG\r\n\x1a\n"


def validate_base64_png(data: str) -> bool:
    """Return True if *data* is valid base64 that decodes to a PNG image."""
    try:
        raw = base64.b64decode(data, validate=True)
        return raw[:8] == PNG_HEADER
    except Exception:
        return False


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
# ---------------------------------------------------------------------------
# Rate limiter (SEC-05)
# ---------------------------------------------------------------------------
limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title="MirrorMind API",
    description="Emotional mirror backend - real-time voice analysis and art generation",
    version="0.1.0",
)

app.state.limiter = limiter


@app.exception_handler(RateLimitExceeded)
async def _rate_limit_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    return JSONResponse(status_code=429, content={"error": "Rate limit exceeded"})


app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "Accept"],
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
@limiter.limit("30/minute")
async def health_check(request: Request) -> JSONResponse:
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

    # Per-IP connection limit (SEC-05)
    client_ip = ws.client.host if ws.client else "unknown"
    if _ws_connections_per_ip[client_ip] >= MAX_WS_CONNECTIONS_PER_IP:
        await ws.accept()
        await ws.close(code=1008, reason="Too many connections from this IP")
        return
    _ws_connections_per_ip[client_ip] += 1

    await ws.accept()
    logger.info("WebSocket connected for user %s", user_id)

    # Session timing (SEC-15)
    session_start_time = time.monotonic()
    last_audio_time = time.monotonic()

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
        nonlocal last_audio_time
        try:
            while True:
                # Session timeout checks (SEC-15)
                now = time.monotonic()
                if now - last_audio_time > IDLE_TIMEOUT_SECONDS:
                    logger.info("Idle timeout for user %s", user_id)
                    await _send_json(ws, {
                        "type": "error",
                        "code": "idle_timeout",
                        "message": "Session closed due to inactivity",
                    })
                    break
                if now - session_start_time > MAX_SESSION_DURATION_SECONDS:
                    logger.info("Max session duration reached for user %s", user_id)
                    await _send_json(ws, {
                        "type": "error",
                        "code": "max_duration",
                        "message": "Maximum session duration reached",
                    })
                    break

                message = await ws.receive()

                if message.get("type") == "websocket.disconnect":
                    break

                if "bytes" in message and message["bytes"]:
                    raw_bytes = message["bytes"]
                    # Enforce binary frame size limit (SEC-06)
                    if len(raw_bytes) > MAX_WS_BINARY_SIZE:
                        logger.warning(
                            "Oversized binary frame (%d bytes) from user %s, dropping",
                            len(raw_bytes),
                            user_id,
                        )
                        continue

                    # PCM audio chunk from browser mic (Int16, 16kHz mono)
                    audio_blob = types.Blob(
                        mime_type="audio/pcm",
                        data=raw_bytes,
                    )
                    live_queue.send_realtime(audio_blob)
                    last_audio_time = time.monotonic()
                    await update_activity(user_id)

                elif "text" in message and message["text"]:
                    raw_text = message["text"]
                    # Limit raw JSON text size to 16 KB
                    if len(raw_text) > 16 * 1024:
                        logger.warning("Oversized text frame from user %s, dropping", user_id)
                        continue

                    try:
                        data = json.loads(raw_text)
                    except json.JSONDecodeError:
                        continue

                    msg_type = data.get("type", "")

                    # Validate against Pydantic schemas (SEC-07)
                    if msg_type == "text":
                        try:
                            validated = WsTextMessage(**data)
                        except ValidationError:
                            logger.warning("Invalid text message from user %s", user_id)
                            continue
                        content = types.Content(
                            parts=[types.Part(text=validated.text)]
                        )
                        live_queue.send_content(content)

                    elif msg_type == "barge_in":
                        try:
                            WsBargeInMessage(**data)
                        except ValidationError:
                            continue
                        # User interrupted the agent — frontend already
                        # stopped playback; Gemini will handle the new
                        # audio input natively.
                        logger.info("Barge-in from user %s", user_id)

                    elif msg_type == "end_session":
                        try:
                            WsEndSessionMessage(**data)
                        except ValidationError:
                            continue
                        # Client requests to end the session
                        break
                    else:
                        logger.warning("Unknown message type '%s' from user %s", msg_type, user_id)

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
                    # Validate base64 PNG before sending to client (SEC-10)
                    img_data = image_msg.get("data", "")
                    if img_data and not validate_base64_png(img_data):
                        logger.warning("Invalid PNG data for user %s, skipping", user_id)
                        continue
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
        # Decrement per-IP connection counter
        _ws_connections_per_ip[client_ip] = max(0, _ws_connections_per_ip[client_ip] - 1)
        if _ws_connections_per_ip[client_ip] == 0:
            _ws_connections_per_ip.pop(client_ip, None)

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
@limiter.limit("20/minute")
async def get_user_gallery(request: Request, user_id: str) -> JSONResponse:
    """Get all gallery entries for a user."""
    from mirror_mind.gallery_service import get_gallery
    entries = await get_gallery(user_id)
    return JSONResponse(content={"gallery": entries})


@app.get("/api/gallery/{user_id}/{gallery_id}")
@limiter.limit("20/minute")
async def get_gallery_detail(request: Request, user_id: str, gallery_id: str) -> JSONResponse:
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
