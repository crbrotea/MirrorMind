"""Breathing pattern definitions for guided emotional transformation.

Three evidence-based techniques:
- Box breathing (4-4-4-4): General regulation, military/first-responder standard.
- 4-7-8 calm breathing: Parasympathetic activation, best for sadness/exhaustion.
- Physiological sigh: Highest evidence (Balban et al., 2023, Cell Reports Medicine).
  5 min daily cyclic sighing improved mood more than mindfulness meditation.
"""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class BreathingPhase:
    """A single phase in a breathing cycle."""

    action: str          # e.g. "inhale", "hold", "exhale", "deep_inhale"
    duration: float      # seconds
    visual_cue: str      # description of landscape change during this phase
    instruction: str     # Voice instruction for the agent to speak


@dataclass(frozen=True)
class BreathingPattern:
    """Complete breathing pattern with phases, cycles, and metadata."""

    technique: str
    display_name: str
    description: str
    phases: list[BreathingPhase]
    cycles: int
    total_seconds: float
    best_for: list[str]
    visual_arc: str      # overall visual transformation description


# ---------------------------------------------------------------------------
# Pattern definitions
# ---------------------------------------------------------------------------

BOX_BREATHING = BreathingPattern(
    technique="box",
    display_name="Box Breathing",
    description="Four equal phases of 4 seconds. Balances the nervous system.",
    phases=[
        BreathingPhase(
            action="inhale",
            duration=4.0,
            visual_cue="Scene expands outward, colors brighten gradually, light increases",
            instruction="Inhale... two... three... four...",
        ),
        BreathingPhase(
            action="hold",
            duration=4.0,
            visual_cue="Scene shimmers at peak brightness, particles of light suspended",
            instruction="Hold... two... three... four...",
        ),
        BreathingPhase(
            action="exhale",
            duration=4.0,
            visual_cue="Scene settles and softens, colors warm, gentle descent",
            instruction="Exhale... two... three... four...",
        ),
        BreathingPhase(
            action="hold",
            duration=4.0,
            visual_cue="Deep stillness, perfect calm, mirror-like water surface",
            instruction="Hold... two... three... four...",
        ),
    ],
    cycles=4,
    total_seconds=64.0,
    best_for=["frustration", "general_regulation", "focus"],
    visual_arc=(
        "Landscape shifts from current emotional state through rhythmic pulses of "
        "expansion and settling, each cycle bringing slightly more warmth and openness "
        "until the scene reaches balanced equilibrium."
    ),
)

CALM_BREATHING = BreathingPattern(
    technique="calm",
    display_name="4-7-8 Breathing",
    description="Inhale 4, hold 7, exhale 8. Activates the parasympathetic system.",
    phases=[
        BreathingPhase(
            action="inhale",
            duration=4.0,
            visual_cue="Warm light slowly enters the scene from the horizon, gentle glow",
            instruction="Inhale gently... two... three... four...",
        ),
        BreathingPhase(
            action="hold",
            duration=7.0,
            visual_cue="Golden glow spreads through the landscape, warmth permeates everything",
            instruction="Hold the air... let the calm expand... three... four... five... six... seven...",
        ),
        BreathingPhase(
            action="exhale",
            duration=8.0,
            visual_cue="Gentle settling like leaves falling, colors deepen into warmth, peace descends",
            instruction="Exhale slowly... let it all go... three... four... five... six... seven... eight...",
        ),
    ],
    cycles=3,
    total_seconds=57.0,
    best_for=["sadness", "exhaustion", "insomnia", "grief"],
    visual_arc=(
        "Landscape slowly fills with warmth over three long cycles. The extended exhale "
        "phases create a sense of gentle release, like watching a sunset gradually paint "
        "the sky in deeper, warmer colors."
    ),
)

PHYSIOLOGICAL_SIGH = BreathingPattern(
    technique="physiological_sigh",
    display_name="Physiological Sigh",
    description=(
        "Deep inhale + short extra inhale + long exhale. "
        "The breathing technique with the strongest scientific evidence (Balban et al., 2023)."
    ),
    phases=[
        BreathingPhase(
            action="deep_inhale",
            duration=3.0,
            visual_cue="Scene brightens significantly, expansion in all directions",
            instruction="Inhale deeply through your nose... two... three...",
        ),
        BreathingPhase(
            action="sharp_inhale",
            duration=1.0,
            visual_cue="Quick additional brightening, slight upward lift effect",
            instruction="...and a little more air...",
        ),
        BreathingPhase(
            action="long_exhale",
            duration=6.0,
            visual_cue="Slow gentle descent, colors warm maximally, deep calm settles in",
            instruction="Exhale long through your mouth... let it all out... three... four... five... six...",
        ),
    ],
    cycles=5,
    total_seconds=50.0,
    best_for=["anxiety", "stress", "panic", "acute_distress"],
    visual_arc=(
        "Each sigh cycle is a dramatic release. The double-inhale creates a peak of "
        "brightness and expansion, and the long exhale carries the scene into progressively "
        "deeper calm. By the fifth cycle the landscape has fully transformed."
    ),
)


# ---------------------------------------------------------------------------
# Registry and lookup
# ---------------------------------------------------------------------------

PATTERNS: dict[str, BreathingPattern] = {
    "box": BOX_BREATHING,
    "calm": CALM_BREATHING,
    "physiological_sigh": PHYSIOLOGICAL_SIGH,
}


def get_breathing_pattern(technique: str) -> dict:
    """Return a breathing pattern as a serializable dictionary.

    Args:
        technique: One of "box", "calm", or "physiological_sigh".

    Returns:
        Dictionary with all pattern data, suitable for JSON serialization
        and WebSocket delivery to the frontend.
    """
    pattern = PATTERNS.get(technique)
    if pattern is None:
        # Default to physiological sigh (highest evidence)
        pattern = PHYSIOLOGICAL_SIGH

    return {
        "technique": pattern.technique,
        "display_name": pattern.display_name,
        "description": pattern.description,
        "phases": [
            {
                "action": phase.action,
                "duration": phase.duration,
                "visual_cue": phase.visual_cue,
                "instruction": phase.instruction,
            }
            for phase in pattern.phases
        ],
        "cycles": pattern.cycles,
        "total_seconds": pattern.total_seconds,
        "best_for": pattern.best_for,
        "visual_arc": pattern.visual_arc,
    }


def suggest_technique(emotion: str) -> str:
    """Suggest the best breathing technique for a given emotion.

    Args:
        emotion: The current emotional state.

    Returns:
        The technique key string.
    """
    emotion_lower = emotion.lower()

    # Physiological sigh for high-arousal negative states
    if emotion_lower in ("anxiety", "fear", "panic", "stress", "overwhelm"):
        return "physiological_sigh"

    # 4-7-8 for low-arousal negative states
    if emotion_lower in ("sadness", "grief", "exhaustion", "loneliness", "emptiness"):
        return "calm"

    # Box breathing for moderate arousal or mixed states
    if emotion_lower in ("frustration", "anger", "irritation", "restlessness"):
        return "box"

    # Default to physiological sigh
    return "physiological_sigh"
