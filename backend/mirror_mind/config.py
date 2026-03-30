"""Environment configuration and constants for MirrorMind."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# ---------------------------------------------------------------------------
# Load .env from the backend root (one level above mirror_mind/)
# ---------------------------------------------------------------------------
_BACKEND_DIR = Path(__file__).resolve().parent.parent
load_dotenv(_BACKEND_DIR / ".env")

# ---------------------------------------------------------------------------
# Test mode (must be defined early since other settings depend on it)
# ---------------------------------------------------------------------------
TEST_MODE: bool = os.getenv("TEST_MODE", "").lower() in ("1", "true", "yes")

# ---------------------------------------------------------------------------
# Google AI
# ---------------------------------------------------------------------------
GOOGLE_API_KEY: str = os.getenv("GOOGLE_API_KEY", "")

# Live API voice model (native audio with affective dialog support)
LIVE_MODEL: str = "gemini-2.5-flash-native-audio-preview-12-2025"

# Image generation model
IMAGE_MODEL: str = "gemini-2.5-flash-image"

# ---------------------------------------------------------------------------
# Firebase (disabled in test mode to use in-memory storage)
# ---------------------------------------------------------------------------
FIREBASE_PROJECT_ID: str = "" if TEST_MODE else os.getenv("FIREBASE_PROJECT_ID", "")

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
HOST: str = os.getenv("HOST", "0.0.0.0")
PORT: int = int(os.getenv("PORT", "8080"))
CORS_ORIGINS: list[str] = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ORIGINS", "http://localhost:5173,http://localhost:3000,http://localhost:8080"
    ).split(",")
    if origin.strip()
]
# Default to WARNING in production (non-localhost), INFO for local development
_is_local = HOST in ("localhost", "127.0.0.1", "0.0.0.0")
_default_log_level = "INFO" if _is_local else "WARNING"
LOG_LEVEL: str = os.getenv("LOG_LEVEL", _default_log_level)

# ---------------------------------------------------------------------------
# Audio settings
# ---------------------------------------------------------------------------
INPUT_SAMPLE_RATE: int = 16_000   # 16 kHz mono PCM Int16 from browser mic
OUTPUT_SAMPLE_RATE: int = 24_000  # 24 kHz mono PCM Int16 from Gemini

# ---------------------------------------------------------------------------
# ADK app name (used across session service and runner)
# ---------------------------------------------------------------------------
APP_NAME: str = "mirror_mind"

# ---------------------------------------------------------------------------
# Voice for the agent (gentle, calm - ideal for therapeutic use)
# ---------------------------------------------------------------------------
VOICE_NAME: str = "Leda"

# ---------------------------------------------------------------------------
# Image generation defaults
# ---------------------------------------------------------------------------
IMAGE_ASPECT_RATIO: str = "16:9"
IMAGE_SIZE: str = "1K"

# ---------------------------------------------------------------------------
# Clerk authentication
# ---------------------------------------------------------------------------
CLERK_JWKS_URL: str = os.getenv("CLERK_JWKS_URL", "")
CLERK_SECRET_KEY: str = os.getenv("CLERK_SECRET_KEY", "")
CLERK_WEBHOOK_SECRET: str = os.getenv("CLERK_WEBHOOK_SECRET", "")
