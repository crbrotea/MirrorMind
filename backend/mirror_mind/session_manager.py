"""Session lifecycle management for MirrorMind.

Manages ADK InMemorySessionService sessions, tracks emotional journeys,
and coordinates cleanup across image service and gallery.
"""

from __future__ import annotations

import logging
import time
import uuid
from dataclasses import dataclass, field
from typing import Any

from google.adk.sessions import InMemorySessionService, Session

from mirror_mind.config import APP_NAME
from mirror_mind.image_service import close_session as close_image_session

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Module-level session service — set by main.py from the runner's own service
# so that sessions created here are visible to the ADK runner.
# ---------------------------------------------------------------------------
session_service: InMemorySessionService | None = None


def set_session_service(svc: InMemorySessionService) -> None:
    """Inject the runner's session service so we share a single instance."""
    global session_service
    session_service = svc


@dataclass
class SessionMetadata:
    """Tracks metadata about an active MirrorMind session."""

    session_id: str
    user_id: str
    created_at: float
    last_activity: float
    stage: str = "welcome"
    emotions_detected: list[dict] = field(default_factory=list)
    images_generated: int = 0
    is_active: bool = True


# Active session metadata (keyed by user_id)
_active_sessions: dict[str, SessionMetadata] = {}


def _default_state(user_id: str, session_id: str) -> dict[str, Any]:
    """Return the default session state for a new MirrorMind session."""
    return {
        "session_id": session_id,
        "current_emotion": "neutral",
        "current_stage": "welcome",
        "emotional_journey": [],
        "latest_image": None,
        "image_updated": False,
        "active_breathing": None,
    }


async def create_session(user_id: str) -> Session:
    """Create a new MirrorMind session for a user.

    If the user already has an active session, it will be closed first.

    Args:
        user_id: The unique user identifier.

    Returns:
        A new ADK Session ready for the live runner.
    """
    # Close any existing session for this user
    if user_id in _active_sessions:
        await close_session(user_id)

    session_id = f"{user_id}_{uuid.uuid4().hex[:8]}"
    now = time.time()

    session = await session_service.create_session(
        app_name=APP_NAME,
        user_id=user_id,
        state=_default_state(user_id, session_id),
    )

    _active_sessions[user_id] = SessionMetadata(
        session_id=session.id,
        user_id=user_id,
        created_at=now,
        last_activity=now,
    )

    logger.info("Created session %s for user %s", session.id, user_id)
    return session


async def get_session(user_id: str) -> Session | None:
    """Retrieve the current ADK session for a user.

    Args:
        user_id: The unique user identifier.

    Returns:
        The active Session, or None if no session exists.
    """
    meta = _active_sessions.get(user_id)
    if meta is None or not meta.is_active:
        return None

    session = await session_service.get_session(
        app_name=APP_NAME,
        user_id=user_id,
        session_id=meta.session_id,
    )
    return session


async def update_activity(user_id: str) -> None:
    """Update the last activity timestamp for a user's session."""
    meta = _active_sessions.get(user_id)
    if meta is not None:
        meta.last_activity = time.time()


async def record_emotion(user_id: str, emotion: str, stage: str) -> None:
    """Record a detected emotion in the session metadata.

    Args:
        user_id: The unique user identifier.
        emotion: The detected emotion label.
        stage: The current session stage.
    """
    meta = _active_sessions.get(user_id)
    if meta is not None:
        meta.emotions_detected.append({
            "emotion": emotion,
            "stage": stage,
            "timestamp": time.time(),
        })
        meta.stage = stage
        meta.last_activity = time.time()


async def record_image_generated(user_id: str) -> None:
    """Increment the image generation counter for a session."""
    meta = _active_sessions.get(user_id)
    if meta is not None:
        meta.images_generated += 1


async def close_session(user_id: str) -> SessionMetadata | None:
    """Close and clean up a user's session.

    Closes the image chat, marks metadata as inactive, and returns
    the final session metadata for gallery persistence.

    Args:
        user_id: The unique user identifier.

    Returns:
        The final SessionMetadata, or None if no session was active.
    """
    meta = _active_sessions.pop(user_id, None)
    if meta is None:
        return None

    meta.is_active = False

    # Clean up the image generation chat
    close_image_session(meta.session_id)

    logger.info(
        "Closed session %s for user %s (emotions: %d, images: %d, duration: %.0fs)",
        meta.session_id,
        user_id,
        len(meta.emotions_detected),
        meta.images_generated,
        time.time() - meta.created_at,
    )

    return meta


def get_session_metadata(user_id: str) -> SessionMetadata | None:
    """Get metadata for an active session without touching ADK."""
    return _active_sessions.get(user_id)


def get_all_active_sessions() -> list[SessionMetadata]:
    """Return metadata for all active sessions."""
    return [m for m in _active_sessions.values() if m.is_active]
