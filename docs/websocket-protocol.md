# WebSocket Protocol

MirrorMind uses a single WebSocket connection per session at `/ws/{user_id}` for all real-time communication.

## Connection

```
ws://localhost:8080/ws/{user_id}     # Local development
wss://your-domain.run.app/ws/{user_id}  # Production
```

The `user_id` is generated client-side and persisted in `localStorage` for gallery continuity.

## Binary Messages: PCM Audio

| Direction | Format | Sample Rate | Channels |
|-----------|--------|-------------|----------|
| Client → Server | Int16 PCM | 16 kHz | Mono |
| Server → Client | Int16 PCM | 24 kHz | Mono |

Audio is streamed as raw binary WebSocket frames. The frontend uses AudioWorkletNode for capture and Web Audio API for playback.

## JSON Messages: Server → Client

### `image` - Generated Landscape

```json
{
  "type": "image",
  "data": "<base64-encoded PNG>",
  "emotion": "anxiety",
  "stage": "mirror"
}
```

### `transcript` - Speech Transcription

```json
{
  "type": "transcript",
  "text": "I've been feeling overwhelmed lately...",
  "author": "user"
}
```

```json
{
  "type": "transcript",
  "text": "I can hear that in your voice. Let me reflect that...",
  "author": "agent"
}
```

### `emotion_update` - Detected Emotion

```json
{
  "type": "emotion_update",
  "emotion": "anxiety",
  "valence": -0.6,
  "arousal": 0.7
}
```

### `breathing_pattern` - Breathing Exercise

```json
{
  "type": "breathing_pattern",
  "pattern": {
    "technique": "box",
    "phases": [
      { "name": "inhale", "duration": 4 },
      { "name": "hold", "duration": 4 },
      { "name": "exhale", "duration": 4 },
      { "name": "rest", "duration": 4 }
    ],
    "cycles": 4,
    "totalSeconds": 64
  }
}
```

### `stage_change` - Session Phase Transition

```json
{
  "type": "stage_change",
  "stage": "shift"
}
```

Stages: `welcome` → `mirror` → `shift` → `arrive` → `complete`

### `audio` - Agent Voice

```json
{
  "type": "audio",
  "data": "<base64-encoded PCM>"
}
```

### `session_complete` - Session Finished

```json
{
  "type": "session_complete",
  "gallery_id": "uuid-string"
}
```

## JSON Messages: Client → Server

### `text` - User Text Input

```json
{
  "type": "text",
  "text": "I feel anxious today"
}
```

### `end_session` - Terminate Session

```json
{
  "type": "end_session"
}
```
