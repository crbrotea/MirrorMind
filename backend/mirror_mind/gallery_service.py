"""Gallery persistence service for MirrorMind sessions.

MVP implementation using in-memory storage with Firestore-ready interface.
When FIREBASE_PROJECT_ID is configured, operations persist to Firestore.
Otherwise, data is stored in memory for the lifetime of the server process.
"""

from __future__ import annotations

import logging
import time
import uuid
from typing import Any

from mirror_mind.config import FIREBASE_PROJECT_ID

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# In-memory store (used when Firestore is not configured)
# ---------------------------------------------------------------------------
_gallery_store: dict[str, dict[str, Any]] = {}  # gallery_id -> gallery data
_user_galleries: dict[str, list[str]] = {}       # user_id -> [gallery_ids]

# ---------------------------------------------------------------------------
# Firestore client (lazily initialized)
# ---------------------------------------------------------------------------
_firestore_db: Any | None = None
_firestore_initialized: bool = False


def _get_firestore_db() -> Any | None:
    """Lazily initialize Firestore if configured."""
    global _firestore_db, _firestore_initialized

    if _firestore_initialized:
        return _firestore_db

    _firestore_initialized = True

    if not FIREBASE_PROJECT_ID:
        logger.info("FIREBASE_PROJECT_ID not set - using in-memory gallery storage")
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials, firestore

        # Initialize Firebase app if not already done
        if not firebase_admin._apps:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred, {"projectId": FIREBASE_PROJECT_ID})

        _firestore_db = firestore.client()
        logger.info("Firestore initialized for project %s", FIREBASE_PROJECT_ID)
        return _firestore_db

    except Exception as e:
        logger.warning(
            "Failed to initialize Firestore (falling back to in-memory): %s", e
        )
        return None


async def save_session(
    user_id: str,
    session_id: str,
    emotional_journey: list[dict[str, Any]],
    images: list[dict[str, Any]],
    duration_seconds: float,
    final_emotion: str,
    final_stage: str,
) -> str:
    """Save a completed session to the gallery.

    Args:
        user_id: The user who completed the session.
        session_id: The original session identifier.
        emotional_journey: List of emotion records from the session.
        images: List of image records (each with base64 data, emotion, stage).
        duration_seconds: Total session duration.
        final_emotion: The emotion at session end.
        final_stage: The stage at session end.

    Returns:
        The gallery_id for the saved session.
    """
    gallery_id = f"gallery_{uuid.uuid4().hex[:12]}"
    now = time.time()

    gallery_data = {
        "gallery_id": gallery_id,
        "user_id": user_id,
        "session_id": session_id,
        "created_at": now,
        "duration_seconds": duration_seconds,
        "emotional_journey": emotional_journey,
        "images": images,
        "final_emotion": final_emotion,
        "final_stage": final_stage,
        "image_count": len(images),
        "emotion_count": len(emotional_journey),
    }

    db = _get_firestore_db()

    if db is not None:
        try:
            doc_ref = db.collection("galleries").document(gallery_id)
            doc_ref.set(gallery_data)

            # Also add to user's gallery index
            user_ref = db.collection("users").document(user_id)
            user_doc = user_ref.get()
            if user_doc.exists:
                existing = user_doc.to_dict().get("gallery_ids", [])
                existing.append(gallery_id)
                user_ref.update({"gallery_ids": existing})
            else:
                user_ref.set({"gallery_ids": [gallery_id]})

            logger.info("Saved session to Firestore gallery %s", gallery_id)
        except Exception as e:
            logger.error("Firestore save failed, using in-memory fallback: %s", e)
            _save_to_memory(user_id, gallery_id, gallery_data)
    else:
        _save_to_memory(user_id, gallery_id, gallery_data)

    return gallery_id


def _save_to_memory(
    user_id: str, gallery_id: str, gallery_data: dict[str, Any]
) -> None:
    """Save gallery data to in-memory store."""
    _gallery_store[gallery_id] = gallery_data
    if user_id not in _user_galleries:
        _user_galleries[user_id] = []
    _user_galleries[user_id].append(gallery_id)
    logger.info("Saved session to in-memory gallery %s", gallery_id)


async def get_gallery(user_id: str) -> list[dict[str, Any]]:
    """Get all gallery entries for a user.

    Args:
        user_id: The user whose gallery to retrieve.

    Returns:
        List of gallery session summaries (without full image data for efficiency).
    """
    db = _get_firestore_db()

    if db is not None:
        try:
            user_ref = db.collection("users").document(user_id)
            user_doc = user_ref.get()
            if not user_doc.exists:
                return []

            gallery_ids = user_doc.to_dict().get("gallery_ids", [])
            results = []
            for gid in gallery_ids:
                doc = db.collection("galleries").document(gid).get()
                if doc.exists:
                    data = doc.to_dict()
                    # Return summary without full base64 image data
                    results.append(_summarize_gallery_entry(data))
            return results

        except Exception as e:
            logger.error("Firestore gallery fetch failed: %s", e)

    # In-memory fallback
    gallery_ids = _user_galleries.get(user_id, [])
    results = []
    for gid in gallery_ids:
        data = _gallery_store.get(gid)
        if data is not None:
            results.append(_summarize_gallery_entry(data))
    return results


async def get_session_detail(gallery_id: str) -> dict[str, Any] | None:
    """Get full session detail including images.

    Args:
        gallery_id: The gallery entry identifier.

    Returns:
        Full gallery data including images, or None if not found.
    """
    db = _get_firestore_db()

    if db is not None:
        try:
            doc = db.collection("galleries").document(gallery_id).get()
            if doc.exists:
                return doc.to_dict()
        except Exception as e:
            logger.error("Firestore session detail fetch failed: %s", e)

    # In-memory fallback
    return _gallery_store.get(gallery_id)


def _summarize_gallery_entry(data: dict[str, Any]) -> dict[str, Any]:
    """Create a summary of a gallery entry without heavy image data."""
    return {
        "gallery_id": data.get("gallery_id"),
        "created_at": data.get("created_at"),
        "duration_seconds": data.get("duration_seconds"),
        "final_emotion": data.get("final_emotion"),
        "final_stage": data.get("final_stage"),
        "image_count": data.get("image_count", 0),
        "emotion_count": data.get("emotion_count", 0),
        "emotional_journey": data.get("emotional_journey", []),
    }
