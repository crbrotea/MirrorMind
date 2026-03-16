# MirrorMind

## Project Overview

MirrorMind is an emotional mirror web app that generates real-time art reflecting the user's emotional state through voice interaction. The user speaks, the app listens (tone, words, rhythm), and generates evolving artistic landscapes. After the session, it guides the user toward their desired emotional state through breathing exercises, reflective questions, and visual art transformation.

## Architecture

- **Monorepo**: `frontend/` (Next.js) + `backend/` (Python)
- **Single Agent with Function Tools**: One ADK agent with system prompt encoding 3 roles (Emotional Interpreter, Art Director, Transformation Guide)
- **WebSocket Protocol**: Single WS connection per session. Binary frames = PCM audio. JSON text frames = images, emotions, transcripts, breathing patterns.
- **Art Strategy**: Gemini-generated images with 3s CSS crossfade (no Canvas/WebGL needed for MVP)

## Tech Stack

### Frontend
- **Framework**: Next.js 15 (App Router) + React + TypeScript
- **Styling**: Tailwind CSS
- **Voice**: Web Audio API + AudioWorkletNode → WebSocket streaming
- **Art Display**: CSS crossfade between generated images
- **PWA**: Installable via manifest.json + service worker
- **Deploy**: Vercel

### Backend
- **Runtime**: Python 3.12
- **API**: FastAPI + WebSocket
- **AI Agents**: Google ADK (single agent + function tools)
- **Voice/Emotion**: Gemini Live API with `enable_affective_dialog`
- **Image Gen**: Gemini Image Generation (multi-turn chat for coherence)
- **DB**: Firebase/Firestore
- **Deploy**: Cloud Run

## Key Commands

```bash
# Frontend
cd frontend && npm run dev          # Dev server on :3000

# Backend
cd backend && pip install -e .      # Install deps
cd backend && uvicorn main:app --reload --port 8080  # Dev server on :8080
```

## WebSocket Protocol

### Binary: PCM Audio
- Client → Server: Int16, 16kHz mono
- Server → Client: Int16, 24kHz mono

### JSON Messages (Server → Client)
- `image`: base64 PNG + emotion + stage
- `transcript`: text + author (user|agent)
- `emotion_update`: emotion + valence + arousal
- `breathing_pattern`: technique + phases
- `stage_change`: welcome|mirror|shift|arrive|complete
- `session_complete`: gallery_id

## Language

- Code, comments, documentation: **English**
- User-facing content (UI, prompts, agent speech): **English**

## NO ACCEDER A SERVICIOS DE OWQLO
- PREGUNTAR SIEMPRE ante la duda