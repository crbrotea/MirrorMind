"""Emotion to visual landscape mapping based on the valence-arousal circumplex model.

Maps detected emotions to visual parameters (palette, landscape type, lighting,
weather, style) using Russell's circumplex model. Valence controls brightness and
warmth; arousal controls saturation and dynamism.

References:
- Russell, J.A. (1980). A circumplex model of affect.
- Wilms & Oberfeld (2018). Color and emotion: brightness = pleasure (r=.69),
  saturation = arousal (r=.60).
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class EmotionVisualProfile:
    """Complete visual profile for an emotion."""

    emotion: str
    valence: float        # -1.0 (unpleasant) to 1.0 (pleasant)
    arousal: float        # -1.0 (low energy) to 1.0 (high energy)
    palette: list[str]
    landscape: str
    lighting: str
    weather: str
    style: str
    texture: str
    composition: str


# ---------------------------------------------------------------------------
# Circumplex emotion profiles
# ---------------------------------------------------------------------------
EMOTION_PROFILES: dict[str, EmotionVisualProfile] = {
    "anxiety": EmotionVisualProfile(
        emotion="anxiety",
        valence=-0.6,
        arousal=0.7,
        palette=["grey-green", "sickly yellow", "muted olive", "dull amber"],
        landscape="Dense tangled forest with narrow winding paths disappearing into fog",
        lighting="Overcast, oppressive, diffused through heavy clouds",
        weather="Thick low fog drifting between trees, humid and still",
        style="Atmospheric oil painting, Caspar David Friedrich influence",
        texture="Sharp angular branches, gnarled bark, chaotic undergrowth",
        composition="Constricted, paths narrowing, uncertain depth",
    ),
    "sadness": EmotionVisualProfile(
        emotion="sadness",
        valence=-0.5,
        arousal=-0.6,
        palette=["muted blue-grey", "deep indigo", "pale silver", "dusty violet"],
        landscape="Vast empty plain stretching to distant horizon with solitary bare tree",
        lighting="Twilight, soft diffused light, no direct source",
        weather="Gentle persistent rain, soft ripples in shallow water",
        style="Tonalist painting, Whistler-inspired soft focus",
        texture="Blurred edges, soft gradients, watercolor bleed",
        composition="Open and empty, single focal point far away, low horizon",
    ),
    "anger": EmotionVisualProfile(
        emotion="anger",
        valence=-0.7,
        arousal=0.9,
        palette=["deep crimson", "intense orange", "stark black", "molten gold"],
        landscape="Volcanic terrain with cracked glowing earth and jagged obsidian formations",
        lighting="Lightning strikes, harsh directional contrast, no soft light",
        weather="Dark thunderclouds, electrical storm, intense atmospheric pressure",
        style="Dramatic Expressionism, bold impasto, aggressive brushwork",
        texture="Cracked surfaces, sharp edges, rough volcanic rock",
        composition="Extreme contrast, upward-thrusting forms, confrontational",
    ),
    "joy": EmotionVisualProfile(
        emotion="joy",
        valence=0.8,
        arousal=0.6,
        palette=["vibrant yellow", "fresh green", "sky blue", "coral", "warm gold"],
        landscape="Sunlit meadow of wildflowers stretching toward rolling green hills",
        lighting="Brilliant golden light from high sun, warm and enveloping",
        weather="Clear cerulean sky with soft cumulus clouds, gentle breeze",
        style="Luminous Impressionism, Monet-inspired, light particles",
        texture="Soft petals, flowing grass, dappled light on surfaces",
        composition="Open, expansive, inviting depth, high brightness throughout",
    ),
    "calm": EmotionVisualProfile(
        emotion="calm",
        valence=0.7,
        arousal=-0.7,
        palette=["soft pink-gold", "cool lavender", "sage green", "warm peach"],
        landscape="Perfectly still mountain lake at dawn reflecting snow-capped peaks",
        lighting="Gentle gradient sunrise, soft ambient glow, no harsh shadows",
        weather="Perfectly clear, still air, faint warmth on the horizon",
        style="Serene luminism, Hudson River School, photographic clarity",
        texture="Glass-smooth water, rounded stones, soft moss",
        composition="Perfect symmetry via reflection, low contrast, harmonious balance",
    ),
    "fear": EmotionVisualProfile(
        emotion="fear",
        valence=-0.7,
        arousal=0.8,
        palette=["near-black", "icy blue-white", "deep shadow", "cold steel"],
        landscape="Dark narrow cavern with walls closing in, single distant light",
        lighting="Single cold blue point light far away, deep surrounding shadows",
        weather="Underground, no sky, damp oppressive air",
        style="Sublime horror, Goya influence, dramatic chiaroscuro",
        texture="Rough stone, dripping water, barely visible shapes in shadow",
        composition="Constricted, claustrophobic, vanishing point pulling inward",
    ),
    "hope": EmotionVisualProfile(
        emotion="hope",
        valence=0.5,
        arousal=0.3,
        palette=["amber", "soft peach", "tender green", "warm white", "sky blue"],
        landscape="Forest clearing where morning light filters through canopy, new growth visible",
        lighting="Morning light breaking through clouds, crepuscular rays",
        weather="Mist dissipating, first blue patches appearing in overcast sky",
        style="Barbizon School luminism, emerging light, natural realism",
        texture="Young leaves, soft bark, dew on surfaces, gentle stream",
        composition="Transitional - dark edges giving way to bright center, forward motion",
    ),
    "love": EmotionVisualProfile(
        emotion="love",
        valence=0.9,
        arousal=0.4,
        palette=["deep rose", "warm gold", "soft cream", "blush pink", "sage"],
        landscape="Secret garden at sunset with roses in bloom, wisteria cascading over stone arch",
        lighting="Golden-pink warm light bathing everything, backlit petals",
        weather="Perfectly still warm evening, petals floating in the air",
        style="Pre-Raphaelite Romanticism, rich detail, jewel-like color",
        texture="Velvet petals, warm stone, soft fabric, organic curves",
        composition="Intimate, enclosed and protected, rich layered depth",
    ),
    "frustration": EmotionVisualProfile(
        emotion="frustration",
        valence=-0.4,
        arousal=0.5,
        palette=["blue-grey", "rust orange", "slate", "dull white foam"],
        landscape="Choppy sea with waves crashing against irregular rocks, distant horizon",
        lighting="Flat grey light with occasional breaks, no warmth",
        weather="Strong wind, salt spray, restless churning water",
        style="Maritime realism, Winslow Homer influence, contained energy",
        texture="Rough sea surface, jagged rock edges, wind-blown spray",
        composition="Horizontal tension, blocked forward motion, visible but unreachable horizon",
    ),
}


def get_visual_prompt(emotion: str, intensity: float = 0.7, stage: str = "mirror") -> str:
    """Generate a rich visual prompt from an emotion, intensity, and session stage.

    Args:
        emotion: The detected emotion key (e.g., "anxiety", "joy", "calm").
        intensity: Emotion intensity from 0.0 to 1.0. Higher intensity amplifies
            the visual characteristics (saturation, contrast, dynamism).
        stage: Session stage - "mirror" (reflect current state), "shift" (beginning
            transformation toward calm), or "arrive" (destination of peace).

    Returns:
        A detailed landscape prompt string ready for image generation.
    """
    profile = EMOTION_PROFILES.get(emotion.lower())
    if profile is None:
        # Fallback: blend toward a neutral-calm landscape
        profile = EMOTION_PROFILES["calm"]

    # Intensity modifiers
    if intensity >= 0.8:
        intensity_mod = "extremely vivid and intense"
    elif intensity >= 0.6:
        intensity_mod = "clearly present and distinct"
    elif intensity >= 0.4:
        intensity_mod = "subtle but noticeable"
    else:
        intensity_mod = "faint and gentle"

    # Stage-specific transformations
    if stage == "mirror":
        stage_directive = (
            "Render this emotional state faithfully and fully. The user needs to feel "
            "seen. Do not soften or beautify the emotion — honor its truth."
        )
    elif stage == "shift":
        stage_directive = (
            "The scene is beginning to transform. Keep the original landscape recognizable "
            "but introduce subtle elements of hope: a break in the clouds, a distant warm "
            "light, a single green shoot. The transformation should feel gradual and natural, "
            "not forced. Colors begin to shift warmer at the edges."
        )
    elif stage == "arrive":
        stage_directive = (
            "The transformation is complete. The landscape has evolved into a place of deep "
            "peace and serenity. Warm golden light. Open space. Gentle natural beauty. The "
            "original terrain is still faintly recognizable but fundamentally changed — like "
            "a storm that has passed revealing a clear sky."
        )
    else:
        stage_directive = ""

    palette_str = ", ".join(profile.palette)

    prompt = (
        f"{profile.landscape}. "
        f"Color palette: {palette_str}. "
        f"Lighting: {profile.lighting}. "
        f"Weather: {profile.weather}. "
        f"Texture: {profile.texture}. "
        f"Composition: {profile.composition}. "
        f"Emotional intensity: {intensity_mod}. "
        f"Art style: {profile.style}. "
        f"Aspect ratio 16:9, atmospheric, painterly. "
        f"{stage_directive}"
    )

    return prompt


def get_emotion_profile(emotion: str) -> EmotionVisualProfile | None:
    """Return the full visual profile for an emotion, or None if unknown."""
    return EMOTION_PROFILES.get(emotion.lower())


def list_supported_emotions() -> list[str]:
    """Return all supported emotion keys."""
    return list(EMOTION_PROFILES.keys())
