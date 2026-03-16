"""Gemini image generation service with multi-turn chat for coherent landscape evolution.

Uses a per-session chat to maintain visual context across turns, so the landscape
evolves consistently as the user's emotions shift. Falls back to single-shot
generation if the chat context is lost.
"""

from __future__ import annotations

import asyncio
import base64
import logging
from typing import Any

from google import genai
from google.genai import types

from mirror_mind.config import GOOGLE_API_KEY, IMAGE_MODEL, IMAGE_ASPECT_RATIO, IMAGE_SIZE

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Module-level image client (separate from the ADK/Live API client)
# ---------------------------------------------------------------------------
_image_client: genai.Client | None = None


def _get_client() -> genai.Client:
    """Lazily initialize the genai client for image generation."""
    global _image_client
    if _image_client is None:
        _image_client = genai.Client(api_key=GOOGLE_API_KEY)
    return _image_client


# ---------------------------------------------------------------------------
# Per-session multi-turn chat sessions for coherent image evolution
# ---------------------------------------------------------------------------
_image_chats: dict[str, Any] = {}


def _get_image_config() -> types.GenerateContentConfig:
    """Return the standard image generation config."""
    return types.GenerateContentConfig(
        response_modalities=["TEXT", "IMAGE"],
        image_config=types.ImageConfig(
            aspect_ratio=IMAGE_ASPECT_RATIO,
            image_size=IMAGE_SIZE,
        ),
    )


def _create_chat(session_id: str) -> Any:
    """Create a new multi-turn image chat for a session."""
    client = _get_client()
    chat = client.chats.create(
        model=IMAGE_MODEL,
        config=_get_image_config(),
    )
    _image_chats[session_id] = chat
    logger.info("Created new image chat for session %s", session_id)
    return chat


def _get_or_create_chat(session_id: str) -> Any:
    """Get existing chat or create a new one for the session."""
    chat = _image_chats.get(session_id)
    if chat is None:
        chat = _create_chat(session_id)
    return chat


async def generate_landscape(session_id: str, prompt: str) -> str | None:
    """Generate a landscape image using multi-turn chat for visual coherence.

    The chat session maintains context across turns so the landscape evolves
    naturally. Each call builds on the previous image in the conversation.

    Args:
        session_id: Unique session identifier for tracking the chat.
        prompt: Rich visual description of the landscape to generate.

    Returns:
        Base64-encoded PNG string, or None if generation failed.
    """
    chat = _get_or_create_chat(session_id)

    # Style anchors appended to every prompt for consistency
    style_anchor = (
        " Maintain consistent artistic style across the series. "
        "Oil painting style, 16:9 aspect ratio, atmospheric, painterly. "
        "No text, no watermarks, no borders."
    )
    full_prompt = prompt + style_anchor

    try:
        # Run the synchronous chat.send_message in a thread to avoid blocking
        response = await asyncio.to_thread(chat.send_message, full_prompt)
        return _extract_image_base64(response)

    except Exception as e:
        logger.warning(
            "Multi-turn image generation failed for session %s: %s. "
            "Attempting single-shot fallback.",
            session_id,
            e,
        )
        return await _single_shot_fallback(session_id, full_prompt)


async def _single_shot_fallback(session_id: str, prompt: str) -> str | None:
    """Fallback: create a fresh chat and generate a single image.

    Used when the existing chat context is corrupted or lost.
    """
    try:
        # Reset the chat for this session
        chat = _create_chat(session_id)
        response = await asyncio.to_thread(chat.send_message, prompt)
        return _extract_image_base64(response)
    except Exception as e:
        logger.error(
            "Single-shot image generation also failed for session %s: %s",
            session_id,
            e,
        )
        return None


def _extract_image_base64(response: Any) -> str | None:
    """Extract base64-encoded image data from a Gemini response."""
    if response.parts is None:
        return None

    for part in response.parts:
        if part.inline_data and part.inline_data.data:
            image_bytes = part.inline_data.data
            # inline_data.data may already be bytes
            if isinstance(image_bytes, str):
                return image_bytes
            return base64.b64encode(image_bytes).decode("utf-8")

    logger.warning("Response contained no image parts")
    return None


def close_session(session_id: str) -> None:
    """Clean up the image chat for a session."""
    chat = _image_chats.pop(session_id, None)
    if chat is not None:
        logger.info("Closed image chat for session %s", session_id)


def get_active_sessions() -> list[str]:
    """Return list of session IDs with active image chats."""
    return list(_image_chats.keys())
