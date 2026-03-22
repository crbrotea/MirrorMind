# API Reference

## REST Endpoints

### Health Check

```
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "mirrormind",
  "timestamp": "2026-03-21T10:00:00Z"
}
```

### List User Sessions

```
GET /api/gallery/{user_id}
```

**Response:**
```json
{
  "gallery": [
    {
      "session_id": "uuid",
      "gallery_id": "uuid",
      "date": "2026-03-21T10:00:00Z",
      "emotions": ["anxiety", "hope", "calm"],
      "final_emotion": "calm",
      "images": ["base64..."],
      "duration": 420,
      "image_count": 5
    }
  ]
}
```

### Get Session Detail

```
GET /api/gallery/{user_id}/{gallery_id}
```

**Response:** Full session object with all images, emotional journey data, timestamps, and metadata.

## WebSocket

```
WS /ws/{user_id}
```

See [WebSocket Protocol](./websocket-protocol.md) for full message format documentation.

## Agent Tools (Internal)

These are ADK function tools called by the agent during a session:

### `analyze_and_generate_art`

Generates an artistic landscape image based on the current emotional state.

| Parameter | Type | Description |
|-----------|------|-------------|
| `emotional_state` | string | Current detected emotion |
| `visual_description` | string | Rich description of the landscape to generate |
| `stage` | string | Current session stage (`mirror`, `shift`, `arrive`) |

The description is enriched with circumplex model data (palette, lighting, weather) before calling Gemini Image API. Returns a base64 PNG sent to the client via WebSocket.

### `get_breathing_pattern`

Returns a breathing exercise pattern.

| Parameter | Type | Description |
|-----------|------|-------------|
| `technique` | string | One of: `physiological_sigh`, `calm`, `box` |

Returns phase definitions, cycle count, and total duration. Sent to the client as a `breathing_pattern` WebSocket message.
