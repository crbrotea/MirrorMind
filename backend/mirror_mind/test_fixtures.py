"""Test fixtures: mock agent and image service for E2E testing without Gemini APIs.

When TEST_MODE=true, the backend uses these mocks instead of real ADK/Gemini services.
The mock agent sends scripted WebSocket responses that walk through all 5 stages.
"""

from __future__ import annotations

import asyncio
import base64
import json
import logging
import struct
import time
from typing import Any

from fastapi import WebSocket
from starlette.websockets import WebSocketState

from mirror_mind.breathing import get_breathing_pattern
from mirror_mind.config import OUTPUT_SAMPLE_RATE
from mirror_mind.gallery_service import save_session as save_gallery_session
from mirror_mind.image_service import get_image_queue, remove_image_queue

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# 1x1 transparent PNG (smallest valid PNG) used as test image
# ---------------------------------------------------------------------------
_TEST_PNG_BYTES = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4"
    "nGNgYPgPAAEDAQAIicLsAAAABElFTkSuQmCC"
)
TEST_IMAGE_B64 = base64.b64encode(_TEST_PNG_BYTES).decode("utf-8")

# ---------------------------------------------------------------------------
# Scripted session flow
# ---------------------------------------------------------------------------
# Each step is a list of messages to send, with a delay before moving to next step.
# This simulates a full emotional mirror session in ~12 seconds.

SCRIPTED_FLOW: list[dict[str, Any]] = [
    # Step 0: Welcome stage (immediate)
    {
        "delay": 0.5,
        "messages": [
            {"type": "stage_change", "stage": "welcome"},
            {
                "type": "transcript",
                "text": "Hola, bienvenido a MirrorMind. Estoy aquí para acompañarte.",
                "author": "agent",
            },
        ],
    },
    # Step 1: Mirror stage — detect emotion, send first image
    {
        "delay": 3.0,
        "messages": [
            {"type": "stage_change", "stage": "mirror"},
            {
                "type": "emotion_update",
                "emotion": "calm",
                "valence": 0.3,
                "arousal": -0.2,
            },
            {
                "type": "image",
                "data": TEST_IMAGE_B64,
                "emotion": "calm",
                "stage": "mirror",
            },
            {
                "type": "transcript",
                "text": "Percibo una calma en tu voz. Observa el paisaje que refleja tu estado.",
                "author": "agent",
            },
        ],
    },
    # Step 2: Shift stage — breathing exercise
    {
        "delay": 3.0,
        "messages": [
            {"type": "stage_change", "stage": "shift"},
            {
                "type": "breathing_pattern",
                "pattern": get_breathing_pattern("box"),
            },
            {
                "type": "transcript",
                "text": "Vamos a hacer un ejercicio de respiración juntos.",
                "author": "agent",
            },
            {
                "type": "image",
                "data": TEST_IMAGE_B64,
                "emotion": "hope",
                "stage": "shift",
            },
        ],
    },
    # Step 3: Arrive stage — transformation complete
    {
        "delay": 3.0,
        "messages": [
            {"type": "stage_change", "stage": "arrive"},
            {
                "type": "emotion_update",
                "emotion": "joy",
                "valence": 0.8,
                "arousal": 0.3,
            },
            {
                "type": "image",
                "data": TEST_IMAGE_B64,
                "emotion": "joy",
                "stage": "arrive",
            },
            {
                "type": "transcript",
                "text": "Has llegado a un lugar de paz. Observa tu nuevo paisaje.",
                "author": "agent",
            },
        ],
    },
    # Step 4: Complete
    {
        "delay": 2.0,
        "messages": [
            {"type": "stage_change", "stage": "complete"},
        ],
    },
]


async def _send_json(ws: WebSocket, data: dict) -> None:
    """Send JSON over WebSocket with error handling."""
    try:
        if ws.client_state == WebSocketState.CONNECTED:
            await ws.send_json(data)
    except Exception as e:
        logger.warning("Mock: failed to send JSON: %s", e)


def _generate_silence(duration_ms: int = 100) -> bytes:
    """Generate silent PCM audio (Int16, 24kHz mono)."""
    num_samples = int(OUTPUT_SAMPLE_RATE * duration_ms / 1000)
    return struct.pack(f"<{num_samples}h", *([0] * num_samples))


async def run_mock_session(ws: WebSocket, user_id: str) -> None:
    """Run a fully scripted mock session over an existing WebSocket connection.

    This replaces the real ADK runner + Gemini Live API for E2E testing.
    It walks through all 5 stages with deterministic timing.
    """
    await ws.accept()
    logger.info("Mock session started for user %s", user_id)

    session_start = time.time()
    cancelled = False
    session_images: list[dict] = []

    # ------------------------------------------------------------------
    # Receive loop: consume client messages but mostly ignore them
    # ------------------------------------------------------------------
    async def receive_from_client() -> None:
        nonlocal cancelled
        try:
            while True:
                message = await ws.receive()
                if message.get("type") == "websocket.disconnect":
                    break

                # Handle text messages
                if "text" in message and message["text"]:
                    try:
                        data = json.loads(message["text"])
                        if data.get("type") == "end_session":
                            cancelled = True
                            break
                        # Echo user text as transcript
                        if data.get("type") == "text" and data.get("text"):
                            await _send_json(ws, {
                                "type": "transcript",
                                "text": data["text"],
                                "author": "user",
                            })
                    except json.JSONDecodeError:
                        pass

                # Silently consume binary audio frames
        except Exception:
            cancelled = True

    # ------------------------------------------------------------------
    # Send loop: play the scripted flow
    # ------------------------------------------------------------------
    async def send_scripted_flow() -> None:
        nonlocal cancelled
        for step in SCRIPTED_FLOW:
            if cancelled:
                break

            await asyncio.sleep(step["delay"])

            if cancelled or ws.client_state != WebSocketState.CONNECTED:
                break

            for msg in step["messages"]:
                if ws.client_state != WebSocketState.CONNECTED:
                    break
                await _send_json(ws, msg)

                # Track images for gallery
                if msg.get("type") == "image":
                    session_images.append({
                        "data": msg["data"],
                        "emotion": msg.get("emotion", ""),
                        "stage": msg.get("stage", ""),
                        "timestamp": time.time(),
                    })

            # Send a small silence chunk so the client knows audio is "flowing"
            if ws.client_state == WebSocketState.CONNECTED:
                try:
                    await ws.send_bytes(_generate_silence(50))
                except Exception:
                    pass

    # ------------------------------------------------------------------
    # Run both loops
    # ------------------------------------------------------------------
    try:
        await asyncio.gather(
            receive_from_client(),
            send_scripted_flow(),
            return_exceptions=True,
        )
    finally:
        # Save to gallery
        duration = time.time() - session_start
        try:
            gallery_id = await save_gallery_session(
                user_id=user_id,
                session_id=f"{user_id}_mock",
                emotional_journey=[
                    {"emotion": "calm", "stage": "mirror"},
                    {"emotion": "hope", "stage": "shift"},
                    {"emotion": "joy", "stage": "arrive"},
                ],
                images=session_images,
                duration_seconds=duration,
                final_emotion="joy",
                final_stage="complete",
            )

            if ws.client_state == WebSocketState.CONNECTED:
                await _send_json(ws, {
                    "type": "session_complete",
                    "gallery_id": gallery_id,
                })
        except Exception as e:
            logger.error("Mock: failed to save gallery: %s", e)

        remove_image_queue(user_id)

        if ws.client_state == WebSocketState.CONNECTED:
            try:
                await ws.close()
            except Exception:
                pass

        logger.info("Mock session ended for user %s (%.1fs)", user_id, duration)
