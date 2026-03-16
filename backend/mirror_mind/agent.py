"""MirrorMind ADK agent with function tools for emotion analysis and art generation.

The agent uses the Gemini Live API with affective dialog to detect emotions from
voice tone, rhythm, and words. It bridges to image generation via function tools
(since Live API cannot produce images directly in audio mode).
"""

from __future__ import annotations

import asyncio
import logging
from typing import Any

from google.adk.agents import Agent
from google.adk.tools import ToolContext

from mirror_mind import breathing as breathing_module
from mirror_mind import image_service
from mirror_mind.config import LIVE_MODEL
from mirror_mind.emotion_mapping import get_visual_prompt
from mirror_mind.prompts import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Tool: Analyze emotions and generate art
# ---------------------------------------------------------------------------

def analyze_and_generate_art(
    emotional_state: str,
    visual_description: str,
    stage: str,
    tool_context: ToolContext,
) -> dict[str, Any]:
    """Generates an artistic landscape reflecting the user's emotional state.

    Call this whenever you detect a shift in the user's emotions or when guiding
    them through a transformation exercise. The generated image will appear on
    the user's screen automatically.

    Args:
        emotional_state: The detected emotion (e.g., "ansiedad", "tristeza",
            "calma", "esperanza", "alegria", "miedo", "frustracion", "amor",
            "enojo"). Include perceived intensity as a qualifier if possible
            (e.g., "ansiedad intensa", "tristeza suave").
        visual_description: A rich, detailed description of a landscape that
            metaphorically represents this emotional state. Include colors,
            lighting, weather, terrain features, atmosphere, and art style.
            Be specific and evocative. This drives the image generation.
        stage: One of "mirror" (reflecting current emotional state faithfully),
            "shift" (beginning transformation - subtle hope elements appear),
            or "arrive" (destination reached - peaceful, warm, open landscape).

    Returns:
        dict with generation status and metadata. The image is delivered to
        the user's screen via WebSocket automatically.
    """
    session_id = tool_context.state.get("session_id", "default")

    # Track the emotional journey in session state
    emotional_journey: list[dict] = tool_context.state.get("emotional_journey", [])
    emotional_journey.append({
        "emotion": emotional_state,
        "stage": stage,
    })
    tool_context.state["emotional_journey"] = emotional_journey
    tool_context.state["current_emotion"] = emotional_state
    tool_context.state["current_stage"] = stage

    # Enrich the visual description with emotion mapping data if a known emotion
    # is detected. The agent's own description takes priority, but we append
    # circumplex-derived visual cues for consistency.
    base_emotion = _normalize_emotion(emotional_state)
    enrichment = get_visual_prompt(base_emotion, intensity=0.7, stage=stage)

    full_prompt = (
        f"{visual_description}\n\n"
        f"Additional visual guidance based on emotion profile:\n{enrichment}"
    )

    # Run image generation synchronously from the tool (ADK tools are sync)
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            # We are inside an async context; schedule and wait via a future
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                image_b64 = pool.submit(
                    asyncio.run, image_service.generate_landscape(session_id, full_prompt)
                ).result(timeout=30)
        else:
            image_b64 = asyncio.run(
                image_service.generate_landscape(session_id, full_prompt)
            )
    except Exception as e:
        logger.error("Image generation failed: %s", e)
        image_b64 = None

    if image_b64:
        # Store in session state so the WebSocket send loop can pick it up
        tool_context.state["latest_image"] = image_b64
        tool_context.state["image_updated"] = True
        tool_context.state["latest_image_emotion"] = emotional_state
        tool_context.state["latest_image_stage"] = stage

        return {
            "status": "success",
            "emotion": emotional_state,
            "stage": stage,
            "message": (
                "Nueva obra de arte generada y enviada a la pantalla del usuario. "
                "El paisaje refleja su estado emocional actual. "
                "Continua la conversacion con empatia."
            ),
        }

    return {
        "status": "error",
        "emotion": emotional_state,
        "stage": stage,
        "message": (
            "No se pudo generar la imagen en este momento. "
            "Continua la conversacion normalmente sin mencionar el error."
        ),
    }


# ---------------------------------------------------------------------------
# Tool: Get breathing pattern
# ---------------------------------------------------------------------------

def get_breathing_pattern(technique: str, tool_context: ToolContext) -> dict[str, Any]:
    """Returns timing for a breathing exercise to guide the user and synchronize
    with visual landscape changes.

    Call this when transitioning to the transformation stage. Guide the user
    through each phase by counting aloud with a calm, rhythmic voice.

    Args:
        technique: One of:
            - "box" (4-4-4-4): Good for frustration, anger, general regulation.
            - "calm" (4-7-8): Good for sadness, exhaustion, grief.
            - "physiological_sigh": Best evidence-based technique. Good for
              anxiety, stress, panic. Double inhale + long exhale.

    Returns:
        dict with phase timings in seconds, visual cues for each phase,
        Spanish instructions for the agent to speak, and the recommended
        number of cycles.
    """
    pattern = breathing_module.get_breathing_pattern(technique)
    tool_context.state["active_breathing"] = technique
    tool_context.state["current_stage"] = "shift"

    return {
        **pattern,
        "message": (
            "Patron de respiracion cargado. Guia al usuario fase por fase, "
            "contando suavemente. Usa las instrucciones en espanol proporcionadas. "
            "Despues de cada ciclo completo, genera una nueva imagen con stage='shift' "
            "que muestre la transformacion gradual del paisaje."
        ),
    }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _normalize_emotion(emotional_state: str) -> str:
    """Normalize a Spanish or English emotion string to an English key.

    The agent speaks in Spanish, so emotions may come in as Spanish words.
    This maps them to the English keys used in emotion_mapping.py.
    """
    mapping = {
        # Spanish -> English
        "ansiedad": "anxiety",
        "ansioso": "anxiety",
        "ansiosa": "anxiety",
        "tristeza": "sadness",
        "triste": "sadness",
        "enojo": "anger",
        "enojado": "anger",
        "enojada": "anger",
        "ira": "anger",
        "rabia": "anger",
        "alegria": "joy",
        "feliz": "joy",
        "felicidad": "joy",
        "calma": "calm",
        "tranquilidad": "calm",
        "tranquilo": "calm",
        "tranquila": "calm",
        "paz": "calm",
        "miedo": "fear",
        "temor": "fear",
        "esperanza": "hope",
        "amor": "love",
        "carino": "love",
        "frustracion": "frustration",
        "frustrado": "frustration",
        "frustrada": "frustration",
        "estres": "anxiety",
        "agotamiento": "sadness",
        "soledad": "sadness",
        "nostalgia": "sadness",
        "gratitud": "joy",
        "emocion": "joy",
        "preocupacion": "anxiety",
        "nervios": "anxiety",
        "confusion": "anxiety",
        # English passthrough
        "anxiety": "anxiety",
        "sadness": "sadness",
        "anger": "anger",
        "joy": "joy",
        "calm": "calm",
        "fear": "fear",
        "hope": "hope",
        "love": "love",
        "frustration": "frustration",
    }

    # Try exact match first
    normalized = emotional_state.lower().strip()
    if normalized in mapping:
        return mapping[normalized]

    # Try matching the first word (handles "ansiedad intensa" etc.)
    first_word = normalized.split()[0] if normalized else ""
    if first_word in mapping:
        return mapping[first_word]

    # Default to calm for unknown emotions
    return "calm"


# ---------------------------------------------------------------------------
# Root agent definition
# ---------------------------------------------------------------------------

root_agent = Agent(
    name="mirror_mind",
    model=LIVE_MODEL,
    instruction=SYSTEM_INSTRUCTION,
    tools=[analyze_and_generate_art, get_breathing_pattern],
)
