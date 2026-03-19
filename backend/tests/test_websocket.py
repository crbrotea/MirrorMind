"""Test WebSocket protocol with the mock session."""

from __future__ import annotations

import asyncio
import json

import pytest
import websockets


@pytest.mark.asyncio
async def test_ws_connects_and_receives_welcome(ws_url: str) -> None:
    """WebSocket should connect and receive a welcome stage_change."""
    async with websockets.connect(f"{ws_url}/ws/test-user-ws-1") as ws:
        # First message should be stage_change to welcome
        raw = await asyncio.wait_for(ws.recv(), timeout=5)
        msg = json.loads(raw)
        assert msg["type"] == "stage_change"
        assert msg["stage"] == "welcome"


@pytest.mark.asyncio
async def test_ws_receives_transcript(ws_url: str) -> None:
    """WebSocket should receive an agent transcript after welcome."""
    async with websockets.connect(f"{ws_url}/ws/test-user-ws-2") as ws:
        messages = []
        # Collect first few messages (welcome stage + transcript)
        for _ in range(3):
            try:
                raw = await asyncio.wait_for(ws.recv(), timeout=5)
                if isinstance(raw, str):
                    messages.append(json.loads(raw))
            except asyncio.TimeoutError:
                break

        transcripts = [m for m in messages if m.get("type") == "transcript"]
        assert len(transcripts) >= 1
        assert transcripts[0]["author"] == "agent"
        assert len(transcripts[0]["text"]) > 0


@pytest.mark.asyncio
async def test_ws_binary_audio_accepted(ws_url: str) -> None:
    """WebSocket should accept binary PCM audio without disconnecting."""
    async with websockets.connect(f"{ws_url}/ws/test-user-ws-3") as ws:
        # Consume the welcome message first
        await asyncio.wait_for(ws.recv(), timeout=5)

        # Send synthetic silence (4096 Int16 samples)
        silence = b"\x00\x00" * 4096
        await ws.send(silence)

        # Connection should stay alive — we should receive more messages
        raw = await asyncio.wait_for(ws.recv(), timeout=5)
        assert raw is not None


@pytest.mark.asyncio
async def test_ws_full_session_flow(ws_url: str) -> None:
    """Full mock session should walk through all stages and deliver images."""
    async with websockets.connect(f"{ws_url}/ws/test-user-ws-4") as ws:
        stages_seen: list[str] = []
        images_received = 0
        breathing_received = False
        emotions_seen: list[str] = []

        # Collect all messages until session ends or timeout
        try:
            while True:
                raw = await asyncio.wait_for(ws.recv(), timeout=20)
                if isinstance(raw, bytes):
                    continue  # Audio data — skip
                msg = json.loads(raw)

                if msg["type"] == "stage_change":
                    stages_seen.append(msg["stage"])
                elif msg["type"] == "image":
                    images_received += 1
                    assert "data" in msg  # base64 image
                    assert "emotion" in msg
                elif msg["type"] == "breathing_pattern":
                    breathing_received = True
                    assert "pattern" in msg
                elif msg["type"] == "emotion_update":
                    emotions_seen.append(msg["emotion"])
                elif msg["type"] == "session_complete":
                    assert "gallery_id" in msg
                    break

        except (asyncio.TimeoutError, websockets.exceptions.ConnectionClosed):
            pass

        # Verify full flow
        assert "welcome" in stages_seen
        assert "mirror" in stages_seen
        assert "shift" in stages_seen
        assert "arrive" in stages_seen
        assert images_received >= 2
        assert breathing_received
        assert len(emotions_seen) >= 1


@pytest.mark.asyncio
async def test_ws_end_session_message(ws_url: str) -> None:
    """Client sending end_session should trigger cleanup."""
    async with websockets.connect(f"{ws_url}/ws/test-user-ws-5") as ws:
        # Consume welcome
        await asyncio.wait_for(ws.recv(), timeout=5)

        # Send end_session
        await ws.send(json.dumps({"type": "end_session"}))

        # Connection should close gracefully (may receive session_complete first)
        try:
            while True:
                raw = await asyncio.wait_for(ws.recv(), timeout=5)
                if isinstance(raw, str):
                    msg = json.loads(raw)
                    if msg.get("type") == "session_complete":
                        break
        except (asyncio.TimeoutError, websockets.exceptions.ConnectionClosed):
            pass  # Connection closed — that's expected


@pytest.mark.asyncio
async def test_ws_gallery_populated_after_session(ws_url: str, backend_url: str) -> None:
    """After a full session, the gallery should have an entry for the user."""
    user_id = "test-user-gallery-check"

    # Run a full session
    async with websockets.connect(f"{ws_url}/ws/{user_id}") as ws:
        try:
            while True:
                raw = await asyncio.wait_for(ws.recv(), timeout=20)
                if isinstance(raw, str):
                    msg = json.loads(raw)
                    if msg.get("type") == "session_complete":
                        break
        except (asyncio.TimeoutError, websockets.exceptions.ConnectionClosed):
            pass

    # Check gallery via REST
    import httpx
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{backend_url}/api/gallery/{user_id}")
    assert resp.status_code == 200
    gallery = resp.json()["gallery"]
    assert len(gallery) >= 1
    assert gallery[0]["final_emotion"] == "joy"
