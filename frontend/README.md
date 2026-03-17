# MirrorMind Frontend

Next.js 15 web app for MirrorMind — captures voice via microphone, streams PCM audio to the backend over WebSocket, and displays AI-generated emotional landscapes in real time.

## Setup

```bash
npm install
cp env.example .env.local   # Then edit with your backend URL
npm run dev                  # http://localhost:3000
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NEXT_PUBLIC_WS_URL` | Backend WebSocket URL | `ws://localhost:8080/ws` |

For production, set this in Vercel:
```bash
vercel env add NEXT_PUBLIC_WS_URL production
# Enter: wss://mirrormind-backend-XXXXX.us-central1.run.app/ws
```

## Project Structure

```
src/
├── app/                        # Next.js App Router pages
│   ├── layout.tsx              # Root layout (PWA meta, dark theme, lang=es)
│   ├── page.tsx                # Landing page — "Comenzar" CTA
│   ├── session/page.tsx        # Main experience — voice + canvas + controls
│   ├── gallery/page.tsx        # Gallery — past sessions from API
│   └── globals.css             # Tailwind + custom keyframes
│
├── components/
│   ├── EmotionalCanvas.tsx     # Full-screen dual-layer image crossfade (3s)
│   ├── VoiceControls.tsx       # Mic button with pulse animation + waveform
│   ├── TranscriptOverlay.tsx   # Agent/user speech subtitles (auto-fade)
│   ├── BreathingGuide.tsx      # Animated breathing circle (inhale/hold/exhale)
│   ├── EmotionIndicator.tsx    # Top-left emotion badge + stage label
│   ├── SessionHeader.tsx       # Timer, stage progress bar, end button
│   ├── GalleryGrid.tsx         # Responsive grid + full-screen viewer modal
│   └── GalleryCard.tsx         # Session card with emotion dots + date
│
├── hooks/
│   ├── useMirrorMind.ts        # Core state machine — WebSocket, audio I/O, state
│   ├── useAudioCapture.ts      # Mic → AudioWorklet → PCM Int16 16kHz chunks
│   ├── useAudioPlayback.ts     # PCM chunks → AudioContext 24kHz playback
│   └── useBreathingSync.ts     # Breathing phase cycling with rAF progress
│
├── lib/
│   ├── websocket.ts            # WebSocket client with auto-reconnect
│   ├── audio-utils.ts          # Float32↔Int16 conversion, base64 helpers
│   ├── constants.ts            # Emotion colors, stage labels (Spanish), WS URL
│   └── firebase.ts             # Firebase init stub
│
└── types/
    └── index.ts                # MirrorState, WSMessage types, BreathingPattern
```

## Key Concepts

### Audio Pipeline

```
Microphone
  → getUserMedia (16kHz mono)
  → AudioWorkletNode (PCMCaptureProcessor)
  → Float32 → Int16 conversion
  → WebSocket binary frames → Backend
```

```
Backend
  → WebSocket binary frames (24kHz PCM)
  → AudioContext buffer queue
  → Gapless sequential playback → Speaker
```

The AudioWorklet processor lives in `public/audio-worklet-processor.js`.

### Image Display

`EmotionalCanvas` uses a dual-layer crossfade technique:
- Two absolutely positioned `<img>` elements (Layer A and Layer B)
- On each new image, the inactive layer loads the new image and fades to opacity 1
- 3-second CSS transition creates smooth crossfade

### State Machine

`useMirrorMind` manages the full session lifecycle:
1. Connect WebSocket with persistent `user_id` (stored in localStorage)
2. Route binary messages to `useAudioPlayback`
3. Route JSON messages to state updates (image, emotion, stage, transcript, breathing)
4. Expose controls: `connect`, `startListening`, `stopListening`, `endSession`

### WebSocket Protocol

**Sending** (to backend):
- Binary: PCM Int16 audio chunks from microphone
- JSON: `{ type: "end_session" }`

**Receiving** (from backend):
- Binary: PCM audio from Gemini voice agent
- JSON: `image`, `transcript`, `emotion_update`, `stage_change`, `breathing_pattern`, `session_complete`

## Deploy

```bash
vercel --yes --prod
```

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start dev server (Turbopack) |
| `npm run build` | Production build |
| `npm run start` | Serve production build |
| `npm run lint` | Run ESLint |
