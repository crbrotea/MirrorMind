# Architecture

## Overview

MirrorMind is a monorepo with two main components:

```
mirrormind_workspace/
├── frontend/          # Next.js 15 (App Router) + React + TypeScript
├── backend/           # Python 3.12 + FastAPI + Google ADK
├── config/            # Shared configuration
└── docs/              # Documentation
```

## Frontend

- **Framework**: Next.js 15 with App Router, React 19, TypeScript
- **Styling**: Tailwind CSS
- **Voice Capture**: Web Audio API + AudioWorkletNode for real-time PCM streaming
- **Art Display**: CSS crossfade between generated images (3s transitions, no Canvas/WebGL)
- **State Management**: Custom React hooks (`useMirrorMind`, `useAudioCapture`, `useAudioPlayback`, `useBreathingSync`)
- **PWA**: Installable via manifest.json + service worker

### Key Directories

```
frontend/src/
├── app/               # Pages: landing (/), session (/session), gallery (/gallery)
├── components/        # UI: EmotionalCanvas, VoiceControls, BreathingGuide, SessionHeader, etc.
├── hooks/             # State: useMirrorMind (orchestrator), useAudioCapture, useAudioPlayback
├── lib/               # Utilities: WebSocket client, audio encoding, constants
└── types/             # TypeScript interfaces
```

### Core Hook: `useMirrorMind`

Central state orchestrator that manages:
- WebSocket connection lifecycle
- Audio capture/playback coordination
- Session state (stage, emotion, images, transcripts)
- Breathing pattern synchronization

## Backend

- **Runtime**: Python 3.12
- **API**: FastAPI with WebSocket support
- **AI Agent**: Google ADK (single agent with function tools)
- **Voice/Emotion**: Gemini Live API with `enable_affective_dialog`
- **Image Generation**: Gemini 2.5 Flash for image generation
- **Database**: Firebase/Firestore (optional, in-memory fallback)

### Key Files

```
backend/
├── main.py                        # FastAPI app, WebSocket handler, REST endpoints
└── mirror_mind/
    ├── agent.py                   # ADK agent with analyze_and_generate_art tool
    ├── breathing.py               # Breathing pattern definitions
    ├── emotion_mapping.py         # Russell's circumplex model mapping
    ├── prompts.py                 # Agent system instructions
    ├── gallery_service.py         # Session persistence
    └── config.py                  # Environment settings
```

### Single Agent, Three Roles

The ADK agent's system prompt encodes three personas:

1. **Emotional Interpreter** - Analyzes voice tone, rhythm, pauses, and words to detect emotion
2. **Art Director** - Translates emotions into rich visual landscape descriptions using the circumplex model
3. **Transformation Guide** - Offers breathing exercises and gradually transforms visuals toward calm

### Agent Tools

- **`analyze_and_generate_art(emotional_state, visual_description, stage)`** - Enriches descriptions with circumplex data, calls Gemini Image API, queues image delivery
- **`get_breathing_pattern(technique)`** - Returns breathing exercise parameters based on detected emotion

## Communication

A single WebSocket connection per session handles all real-time communication:

- **Binary frames**: PCM audio (16kHz mono upstream, 24kHz mono downstream)
- **JSON text frames**: Images, transcripts, emotions, breathing patterns, stage changes

See [WebSocket Protocol](./websocket-protocol.md) for full details.

## Emotion Model

Uses Russell's valence-arousal circumplex to map emotions to visual parameters:

- **Valence** (-1.0 to 1.0): Negative to positive emotional tone
- **Arousal** (-1.0 to 1.0): Low energy to high energy

Each emotion maps to specific palette, landscape, lighting, and weather attributes that drive art generation.
