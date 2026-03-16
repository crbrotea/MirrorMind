# MirrorMind: complete technical blueprint for the Gemini Live Agent Challenge

**MirrorMind is architecturally feasible today using Gemini's Live API for real-time voice emotion detection and Nano Banana 2 for iterative image generation — the key constraint is that audio streaming and image generation cannot happen in the same API call, requiring a function-calling bridge pattern.** This report provides every API call, configuration object, architecture decision, and line of code needed to build and ship MirrorMind in 12 days. The Gemini Live Agent Challenge deadline is March 16, 2026, with $80K+ in prizes across categories including Best Live Agent ($10K) and Best Multimodal Integration ($5K) — both tailor-made for this project. No existing hackathon submission or commercial app combines real-time voice emotion detection, generative art creation, and guided therapeutic transformation in a single live-streaming pipeline. MirrorMind's core innovation — a closed emotional feedback loop where you speak, see your emotions as art, and watch the art transform as you heal — is uniquely enabled by Gemini's affective dialog + native image generation in one model family.

---

## 1. Gemini Live API: the voice engine

The Live API provides persistent WebSocket connections for bidirectional audio streaming. The critical model for MirrorMind is **`gemini-2.5-flash-native-audio-preview-12-2025`** (Developer API) or `gemini-live-2.5-flash-native-audio` (Vertex AI). Native audio models process raw waveforms directly — they don't convert speech to text first — which means they capture **tone, pace, pitch, and emotional texture** that text-based pipelines lose entirely.

### Connection and configuration

The WebSocket endpoint for the Developer API is `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent`. Audio input is **16-bit PCM at 16kHz mono**; output is **24kHz mono**. The context window is **128K tokens** for native audio models, and sessions can run indefinitely with context window compression enabled.

Here is the complete session configuration for MirrorMind's voice agent:

```python
from google import genai
from google.genai import types

# v1alpha required for affective dialog + proactive audio
client = genai.Client(http_options={"api_version": "v1alpha"})

MODEL = "gemini-2.5-flash-native-audio-preview-12-2025"

config = types.LiveConnectConfig(
    response_modalities=["AUDIO"],
    
    speech_config=types.SpeechConfig(
        voice_config=types.VoiceConfig(
            prebuilt_voice_config=types.PrebuiltVoiceConfig(
                voice_name="Leda"  # Gentle, calm — best for therapeutic use
            )
        )
    ),
    
    system_instruction=types.Content(parts=[types.Part(text="""
You are MirrorMind, a warm and empathetic emotional companion. Your role is to:
1. Listen deeply to the user as they share their feelings about their day
2. Reflect back what you hear with genuine empathy — validate before suggesting change
3. Periodically call the analyze_and_generate_art tool with a description of the 
   user's current emotional state and key themes from their words
4. When the user seems ready, guide them through a calming transformation exercise 
   using breathing techniques, and call the tool again with evolving emotional targets
5. Never diagnose or claim to be a therapist. You are an emotional mirror and guide.

Voice style: Speak slowly, with warmth. Use pauses. Match the user's energy level 
initially, then gradually shift toward calm. If the user expresses crisis or suicidal 
thoughts, immediately provide the 988 Suicide & Crisis Lifeline number and encourage 
them to call. Do not continue the exercise.
""")]),
    
    # CRITICAL: enables emotion detection from voice tone/pace/pitch
    enable_affective_dialog=True,
    
    # Model speaks only when relevant (ignores background noise)
    proactivity=types.ProactivityConfig(proactive_audio=True),
    
    # Get text transcription of both user speech and model responses
    input_audio_transcription=types.AudioTranscriptionConfig(),
    output_audio_transcription=types.AudioTranscriptionConfig(),
    
    # VAD tuned for therapeutic conversation (tolerate pauses)
    realtime_input_config=types.RealtimeInputConfig(
        automatic_activity_detection=types.AutomaticActivityDetection(
            start_of_speech_sensitivity=types.StartSensitivity.START_SENSITIVITY_HIGH,
            end_of_speech_sensitivity=types.EndSensitivity.END_SENSITIVITY_LOW,
            silence_duration_ms=800,  # Longer pause tolerance for emotional sharing
        )
    ),
    
    # Unlimited session length via compression
    context_window_compression=types.ContextWindowCompressionConfig(
        sliding_window=types.SlidingWindow(target_tokens=16000),
        trigger_tokens=100000,
    ),
    session_resumption=types.SessionResumptionConfig(),
)
```

### Affective dialog: what it actually detects

`enable_affective_dialog=True` requires the `v1alpha` API version and a native audio model. Technically, the model processes raw audio and interprets **tone, pitch contour, speaking rate, emphasis patterns, pauses, and non-speech vocalizations** (sighs, laughter, shaky voice). It does not return explicit emotion labels — instead, it adjusts its response style and tone to match the user's emotional expression. For MirrorMind, you extract the emotional state by **instructing the model via system prompt to articulate what it detects** when calling the image generation tool. The model's native understanding of voice emotion becomes the input to your art pipeline.

### The critical constraint: audio and images cannot coexist

**The Live API supports only ONE response modality per session** — either `AUDIO` or `TEXT`. You cannot set `response_modalities=["AUDIO", "IMAGE"]`. This means the voice agent cannot directly generate images. The solution is **function calling as a bridge**: register an image generation tool in the Live API session, and when the model calls it, your backend invokes the Gemini Image API separately and pushes the result to the frontend through a parallel WebSocket channel.

### Voice options for therapeutic use

Native audio models support **30 HD voices**. For calm, therapeutic interaction:

- **Leda** — Gentle and calm. Best primary choice for MirrorMind.
- **Fenrir** — Warm and approachable. Good alternative.
- **Kore** — Neutral and professional. Works for a more clinical feel.
- **Zephyr** — Light and airy. Works for breathing exercises.

---

## 2. Nano Banana 2: the art engine

The current best model for image generation is **`gemini-3.1-flash-image-preview`** (codenamed Nano Banana 2), which combines Pro-level quality with Flash speed. Note: `gemini-3-pro-image-preview` is **deprecated and shuts down March 9, 2026** — do not use it. The fallback stable model is `gemini-2.5-flash-image`.

### Basic image generation

```python
from google import genai
from google.genai import types

client = genai.Client()

response = client.models.generate_content(
    model="gemini-3.1-flash-image-preview",
    contents=["A vast stormy ocean under dark violet clouds, churning waves, "
              "muted blues and grays, oil painting style, 16:9 aspect ratio"],
    config=types.GenerateContentConfig(
        response_modalities=["TEXT", "IMAGE"],
        image_config=types.ImageConfig(
            aspect_ratio="16:9",
            image_size="2K",
        ),
    ),
)

for part in response.parts:
    if part.text:
        print(part.text)
    elif part.inline_data:
        image = part.as_image()  # PIL Image object
        image.save("emotional_landscape.png")
```

Images return as **base64-encoded PNG** in `part.inline_data.data`. A 1K image consumes ~**1,290 output tokens** (~$0.039 at standard pricing). Generation takes approximately **2–5 seconds** for 1K resolution, scaling proportionally for 2K and 4K.

### Conversational image editing — the transformation engine

This is MirrorMind's secret weapon. Gemini's chat sessions maintain visual context across turns via **thought signatures** — encrypted state that preserves the model's reasoning about what it generated. The SDK's `client.chats.create()` handles these automatically.

```python
chat = client.chats.create(
    model="gemini-3.1-flash-image-preview",
    config=types.GenerateContentConfig(
        response_modalities=["TEXT", "IMAGE"],
        image_config=types.ImageConfig(aspect_ratio="16:9", image_size="1K"),
    ),
)

# Stage 1: Mirror the current emotion (anxiety)
resp = chat.send_message(
    "A dense tangled forest under heavy overcast sky, muted grey-green palette, "
    "thin fog drifting between gnarled trees, narrow winding path disappearing "
    "into uncertainty. Atmospheric, slightly unsettling. Oil painting style."
)
save_image(resp, "stage1_anxiety.png")

# Stage 2: First signs of shift
resp = chat.send_message(
    "The forest begins to thin slightly. A single ray of warm golden light "
    "breaks through the canopy on the right side. Keep the overall mood but "
    "add a subtle sense of hope at the edges."
)
save_image(resp, "stage2_shift.png")

# Stage 3: Transformation deepens
resp = chat.send_message(
    "More light filters through. The gnarled branches now have small green buds. "
    "The fog is lifting. A gentle stream appears along the path. Colors shift "
    "warmer — soft greens and amber replace the grey."
)
save_image(resp, "stage3_opening.png")

# Stage 4: Arrival at calm
resp = chat.send_message(
    "The path opens into a sunlit clearing with a calm reflecting pool. "
    "Wildflowers dot the meadow. Soft golden light. The trees around the "
    "clearing are tall and protective, not threatening. Deep peace. "
    "Luminous Impressionism style."
)
save_image(resp, "stage4_calm.png")
```

The model maintains **character/subject consistency for up to 5 characters and 14 objects** across turns. For landscape evolution, this means terrain features, color palette direction, and compositional elements persist naturally. There is **no seed parameter** for deterministic output — save successful generations and use them as reference images if exact reproducibility matters.

### Style consistency techniques

- Use the multi-turn chat session (mandatory — don't make independent calls)
- Include consistent style anchors in every prompt: "oil painting style, 16:9, atmospheric"
- Reference specific art movements: "Hudson River School luminism" or "Monet-inspired Impressionism"
- Up to **14 reference images** can be provided as input to guide style

---

## 3. ADK architecture: the orchestration layer

Google's Agent Development Kit (ADK, `pip install google-adk`) provides the multi-agent framework. MirrorMind uses a single root `LlmAgent` connected to the Live API with function tools that bridge to image generation.

### The MirrorMind agent with tools

```python
# mirror_mind/agent.py
import asyncio
import base64
import json
from google.adk.agents import Agent
from google.adk.tools import ToolContext
from google import genai
from google.genai import types

image_client = genai.Client()  # Separate client for image generation

# Track the image chat session per user in memory (production: use session state)
image_sessions = {}

def analyze_and_generate_art(
    emotional_state: str,
    visual_description: str,
    transformation_stage: str,
    tool_context: ToolContext,
) -> dict:
    """Generates an artistic landscape reflecting the user's emotional state.
    
    Call this whenever you detect a shift in the user's emotions or when guiding 
    them through a transformation exercise.
    
    Args:
        emotional_state: The detected emotion (e.g., "anxious", "sad", "calm", 
            "hopeful"). Include intensity from 0-1.
        visual_description: A rich, detailed description of a landscape that 
            metaphorically represents this emotional state. Include colors, 
            lighting, weather, terrain, atmosphere, and art style.
        transformation_stage: One of "mirror" (reflecting current state), 
            "shift" (beginning transformation), or "arrive" (calm destination).
    
    Returns:
        dict with status and image_id for the frontend to fetch.
    """
    session_id = tool_context.state.get("session_id", "default")
    
    # Save emotional state to session for tracking
    emotional_journey = tool_context.state.get("emotional_journey", [])
    emotional_journey.append({
        "emotion": emotional_state,
        "stage": transformation_stage,
    })
    tool_context.state["emotional_journey"] = emotional_journey
    tool_context.state["current_emotion"] = emotional_state
    tool_context.state["current_stage"] = transformation_stage
    
    # Get or create image chat session for multi-turn editing
    if session_id not in image_sessions:
        image_sessions[session_id] = image_client.chats.create(
            model="gemini-3.1-flash-image-preview",
            config=types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
                image_config=types.ImageConfig(
                    aspect_ratio="16:9",
                    image_size="1K",
                ),
            ),
        )
    
    chat = image_sessions[session_id]
    
    try:
        resp = chat.send_message(visual_description)
        for part in resp.parts:
            if part.inline_data:
                image_b64 = base64.b64encode(part.inline_data.data).decode()
                # Store in session state for WebSocket delivery to frontend
                tool_context.state["latest_image"] = image_b64
                tool_context.state["image_updated"] = True
                return {
                    "status": "success",
                    "emotion": emotional_state,
                    "stage": transformation_stage,
                    "message": "New artwork generated and sent to the user's screen."
                }
        return {"status": "no_image", "message": "Art generation returned text only."}
    except Exception as e:
        return {"status": "error", "message": str(e)}


def get_breathing_pattern(technique: str, tool_context: ToolContext) -> dict:
    """Returns timing for a breathing exercise to synchronize with visual changes.
    
    Args:
        technique: One of "box" (4-4-4-4), "calm" (4-7-8), or "sigh" (physiological sigh).
    
    Returns:
        dict with phase timings in seconds and visual cues.
    """
    patterns = {
        "box": {
            "phases": [
                {"action": "inhale", "duration": 4, "visual": "expand, brighten"},
                {"action": "hold", "duration": 4, "visual": "shimmer at peak"},
                {"action": "exhale", "duration": 4, "visual": "settle, soften"},
                {"action": "hold", "duration": 4, "visual": "deep stillness"},
            ],
            "cycles": 4,
            "total_seconds": 64,
        },
        "calm": {
            "phases": [
                {"action": "inhale", "duration": 4, "visual": "warm light enters"},
                {"action": "hold", "duration": 7, "visual": "golden glow spreads"},
                {"action": "exhale", "duration": 8, "visual": "gentle settling"},
            ],
            "cycles": 3,
            "total_seconds": 57,
        },
        "sigh": {
            "phases": [
                {"action": "deep_inhale", "duration": 3, "visual": "scene brightens"},
                {"action": "sharp_inhale", "duration": 1, "visual": "quick lift"},
                {"action": "long_exhale", "duration": 6, "visual": "slow settling"},
            ],
            "cycles": 5,
            "total_seconds": 50,
        },
    }
    pattern = patterns.get(technique, patterns["sigh"])
    tool_context.state["active_breathing"] = technique
    return pattern


# Root agent definition
root_agent = Agent(
    name="mirror_mind",
    model="gemini-2.5-flash-native-audio-preview-12-2025",
    instruction="""You are MirrorMind, a warm and empathetic emotional companion.

FLOW:
1. WELCOME: Greet the user warmly. "Welcome to MirrorMind. I'm here to listen. 
   Tell me about your day — whatever comes to mind."
2. LISTEN & MIRROR: As the user shares, listen deeply. When you sense their 
   emotional state, call analyze_and_generate_art with stage="mirror" and a rich 
   visual description that metaphorically represents their emotion.
3. VALIDATE: "I can hear [emotion] in your voice. That makes complete sense 
   given what you're describing." Never rush past this stage.
4. OFFER TRANSFORMATION: When appropriate, "Would you like to try a short 
   breathing exercise together? We'll watch your landscape transform as we go."
5. GUIDE: Call get_breathing_pattern, then guide the user through it. After 
   each cycle, call analyze_and_generate_art with stage="shift", gradually 
   moving the visual description toward calm.
6. ARRIVE: Final image with stage="arrive". Reflect on the journey.

VOICE: Speak slowly and gently. Use pauses. Match the user's energy first, 
then gradually lower your pace. You detect emotion from voice tone natively.

SAFETY: If the user expresses suicidal thoughts or self-harm, immediately say: 
"I hear you, and what you're feeling matters. Please reach out to the 988 
Suicide and Crisis Lifeline — you can call or text 988 right now." 
Stop the exercise. Stay present and warm.

Current emotion: {current_emotion}
Current stage: {current_stage}""",
    tools=[analyze_and_generate_art, get_breathing_pattern],
)
```

### Session state flows automatically

ADK session state (`tool_context.state`) is shared across all tools and the agent instruction (via `{current_emotion}` template variables). When the `analyze_and_generate_art` tool sets `state["latest_image"]`, your WebSocket server can read this and push the image to the frontend.

### LiveRequestQueue for streaming

```python
from google.adk.agents import LiveRequestQueue
from google.adk.runners import InMemoryRunner
from google.adk.agents.run_config import RunConfig
from google.genai import types

runner = InMemoryRunner(app_name="mirror_mind", agent=root_agent)

async def create_session(user_id: str):
    session = await runner.session_service.create_session(
        app_name="mirror_mind",
        user_id=user_id,
        state={"current_emotion": "neutral", "current_stage": "welcome",
               "emotional_journey": [], "session_id": user_id},
    )
    
    live_queue = LiveRequestQueue()
    run_config = RunConfig(
        response_modalities=["AUDIO"],
        speech_config=types.SpeechConfig(
            voice_config=types.VoiceConfig(
                prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name="Leda")
            )
        ),
    )
    
    events = runner.run_live(
        session=session,
        live_request_queue=live_queue,
        run_config=run_config,
    )
    return events, live_queue, session
```

---

## 4. The synchronization architecture that makes it all work

Since the Live API (audio) and Image Generation (visual) are separate API calls, the backend must bridge them. Here is the complete FastAPI server:

```python
# main.py
import asyncio
import base64
import json
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from google.adk.agents import LiveRequestQueue
from google.adk.runners import InMemoryRunner
from google.adk.agents.run_config import RunConfig
from google.genai import types

from mirror_mind.agent import root_agent

app = FastAPI()
runner = InMemoryRunner(app_name="mirror_mind", agent=root_agent)

@app.websocket("/ws/{user_id}")
async def websocket_endpoint(ws: WebSocket, user_id: str):
    await ws.accept()
    
    session = await runner.session_service.create_session(
        app_name="mirror_mind", user_id=user_id,
        state={"current_emotion": "neutral", "current_stage": "welcome",
               "emotional_journey": [], "session_id": user_id},
    )
    
    live_queue = LiveRequestQueue()
    run_config = RunConfig(response_modalities=["AUDIO"])
    events = runner.run_live(
        session=session,
        live_request_queue=live_queue,
        run_config=run_config,
    )
    
    async def receive_from_client():
        """Forward mic audio from browser → Live API."""
        try:
            while True:
                msg = await ws.receive()
                if "bytes" in msg:
                    blob = types.Blob(mime_type="audio/pcm", data=msg["bytes"])
                    live_queue.send_realtime(blob)
                elif "text" in msg:
                    data = json.loads(msg["text"])
                    if data.get("type") == "text":
                        content = types.Content(
                            parts=[types.Part(text=data["text"])]
                        )
                        live_queue.send_content(content)
        except WebSocketDisconnect:
            live_queue.close()
    
    async def send_to_client():
        """Forward agent audio + image updates → browser."""
        try:
            async for event in events:
                if event.content and event.content.parts:
                    for part in event.content.parts:
                        if part.inline_data:
                            # Audio chunk from Live API
                            await ws.send_bytes(part.inline_data.data)
                        if part.text:
                            await ws.send_json({
                                "type": "transcript",
                                "text": part.text,
                                "author": event.author,
                            })
                
                # Check if image was updated by tool
                updated_session = await runner.session_service.get_session(
                    app_name="mirror_mind", user_id=user_id,
                    session_id=session.id,
                )
                if updated_session.state.get("image_updated"):
                    img_b64 = updated_session.state.get("latest_image")
                    if img_b64:
                        await ws.send_json({
                            "type": "image",
                            "data": img_b64,
                            "emotion": updated_session.state.get("current_emotion"),
                            "stage": updated_session.state.get("current_stage"),
                        })
                        # Reset flag
                        updated_session.state["image_updated"] = False
        except WebSocketDisconnect:
            pass
    
    await asyncio.gather(receive_from_client(), send_to_client())

app.mount("/", StaticFiles(directory="frontend/dist", html=True), name="static")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
```

**Data flow**: Browser mic → PCM chunks over WebSocket → `LiveRequestQueue` → Gemini Live API → model detects emotion from voice → calls `analyze_and_generate_art` tool → tool calls Gemini Image API → base64 image stored in session state → WebSocket pushes image JSON to browser → browser renders new landscape with CSS crossfade.

---

## 5. Emotion-to-visual mapping: the prompt engineering system

The mapping system translates Russell's circumplex model (valence × arousal) into landscape prompts.

### The two-axis framework

**Valence** (pleasant ↔ unpleasant) controls **brightness, color warmth, and landscape openness**. **Arousal** (high ↔ low) controls **saturation, movement/dynamism, and compositional complexity**. Research by Wilms & Oberfeld (2018) confirmed brightness correlates with pleasure at **r = .69** and saturation correlates with arousal at **r = .60** — these are the strongest cross-cultural relationships in color psychology.

| Emotion | Valence | Arousal | Color Palette | Landscape | Lighting |
|---------|---------|---------|---------------|-----------|----------|
| Anxiety | Low | High | Grey-green, sickly yellow | Tangled forest, narrow paths | Overcast, oppressive |
| Anger | Low | Very High | Deep red, orange, black | Volcanic, cracked earth | Lightning, harsh contrast |
| Sadness | Low | Low | Muted blue-grey, indigo | Empty plain, bare tree, rain | Twilight, diffused |
| Fear | Low | High | Near-black, icy blue | Dark cavern, closing walls | Single cold light source |
| Joy | High | High | Vibrant yellow, green, coral | Sunlit meadow, wildflowers | Brilliant golden light |
| Calm | High | Low | Soft pastels, pink-gold | Still mountain lake, dawn | Gentle gradient sunrise |
| Hope | Medium-High | Medium | Amber, soft peach, green | Forest clearing, new growth | Morning light breaking through |

### Complete prompt templates

```python
EMOTION_PROMPTS = {
    "anxiety": (
        "A dense, tangled forest under a heavy overcast sky. Muted grey-green "
        "palette with patches of sickly yellow light. Thin fog drifts between "
        "gnarled trees. Sharp angular branches create chaotic patterns. A narrow "
        "winding path disappears into uncertainty. Low saturation, medium-dark. "
        "Atmospheric oil painting, reminiscent of Caspar David Friedrich."
    ),
    "sadness": (
        "A vast, empty plain stretching to a distant horizon under a twilight "
        "sky of deep indigo and muted violet. A solitary bare tree in the middle "
        "distance. Gentle rain falls, creating soft ripples in shallow water. "
        "Desaturated blue-grey palette with pale silver light. Soft focus, "
        "blurred edges. Tonalist style, Whistler-inspired."
    ),
    "anger": (
        "A volcanic landscape with cracked, glowing crimson earth and dark "
        "thunderclouds. Jagged obsidian rock formations pierce upward. Deep "
        "reds, intense oranges, stark blacks. Lightning illuminates turbulent "
        "sky. Extreme contrast. Dramatic Expressionism, bold impasto."
    ),
    "joy": (
        "A sunlit meadow of wildflowers stretching toward rolling green hills "
        "under brilliant cerulean sky with soft cumulus clouds. Warm golden "
        "light. Vibrant yellows, fresh greens, sky blues, pops of coral. "
        "Butterflies and light particles float. High brightness, high "
        "saturation. Luminous Impressionism, Monet-inspired."
    ),
    "calm": (
        "A perfectly still mountain lake at dawn reflecting snow-capped peaks "
        "and a soft pink-gold sky. Smooth water like glass. Gentle gradient "
        "from warm peach at horizon to cool lavender above. Soft sage green "
        "shore with round stones. Low contrast, medium-high brightness. "
        "Serene luminism, Hudson River School."
    ),
    "fear": (
        "A dark, narrow cavern with walls closing in, illuminated by a single "
        "distant cold blue light. Deep shadows with barely visible shapes. Very "
        "dark palette with icy blue-white highlights. Rough stone textures. "
        "Constricted, claustrophobic composition. Sublime horror, Goya-influenced."
    ),
}
```

The system prompt instructs the Live API agent to compose its own visual descriptions using these patterns as a foundation, adapting to the specific content the user shares. This produces more personalized art than rigid template selection.

---

## 6. The transformation experience: four stages backed by evidence

### Therapeutic framework

The transformation follows four stages grounded in DBT and MBSR research:

**Stage 1 — ACKNOWLEDGE (20% of session):** Fully render the current emotional landscape. The user must feel "seen" before any change begins. Art therapy research (Malchiodi, 2015) shows that **externalizing emotions visually reduces their intensity** — the act of seeing your anxiety as a storm is itself therapeutic. Call `analyze_and_generate_art` with `stage="mirror"`.

**Stage 2 — EXPLORE (20%):** Subtle elements of change appear at edges — a distant light, a single bloom, a break in clouds. The overall scene remains largely unchanged. This maps to DBT's "observe without judgment."

**Stage 3 — SHIFT (40%):** Active transformation synchronized with breathing. The Stanford cyclic sighing study (Balban et al., 2023, *Cell Reports Medicine*) demonstrated that **5 minutes of daily cyclic sighing improved mood more than mindfulness meditation** (positive affect +1.91 vs +1.22, p<0.05). This is MirrorMind's primary breathing technique:

```python
# Physiological sigh — highest evidence breathing technique
SIGH_PATTERN = {
    "phases": [
        {"action": "deep_inhale", "duration_s": 3, 
         "visual_cue": "Scene brightens significantly, expansion"},
        {"action": "sharp_top_up_inhale", "duration_s": 1, 
         "visual_cue": "Quick additional brightening, slight lift effect"},
        {"action": "long_slow_exhale", "duration_s": 6, 
         "visual_cue": "Slow gentle descent, colors warm, maximum calm"},
    ],
    "cycles": 5,
    "total_duration_s": 50,
}
```

**Stage 4 — ARRIVE (20%):** Destination landscape reached. Calm, stable, beautiful. The agent reflects: "Look how far you've come. This is what peace looks like for you right now." Call `analyze_and_generate_art` with `stage="arrive"`.

### Critical design rule

**Never erase the original emotion — transform it.** Storm clouds don't vanish; they part to reveal light. Dark water doesn't drain; it clears and calms. Research on therapeutic pacing shows that sudden shifts feel invalidating. The 4-stage prompt evolution in the image chat session handles this naturally, as each `chat.send_message()` builds on what came before.

---

## 7. Frontend architecture: React with WebSocket audio

A Next.js frontend handles mic capture, WebSocket communication, audio playback, and smooth image transitions.

```typescript
// hooks/useMirrorMind.ts
import { useCallback, useEffect, useRef, useState } from 'react';

interface MirrorState {
  emotion: string;
  stage: string;
  imageUrl: string | null;
  transcript: string;
  isConnected: boolean;
  isListening: boolean;
}

export function useMirrorMind(userId: string) {
  const wsRef = useRef<WebSocket | null>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const [state, setState] = useState<MirrorState>({
    emotion: 'neutral', stage: 'welcome', imageUrl: null,
    transcript: '', isConnected: false, isListening: false,
  });

  const connect = useCallback(async () => {
    const ws = new WebSocket(`wss://${window.location.host}/ws/${userId}`);
    ws.binaryType = 'arraybuffer';
    wsRef.current = ws;

    ws.onopen = () => setState(s => ({ ...s, isConnected: true }));
    
    ws.onmessage = async (event) => {
      if (event.data instanceof ArrayBuffer) {
        // Audio from agent — play it
        playAudioChunk(event.data);
      } else {
        const msg = JSON.parse(event.data);
        if (msg.type === 'image') {
          const url = `data:image/png;base64,${msg.data}`;
          setState(s => ({
            ...s, imageUrl: url, emotion: msg.emotion, stage: msg.stage,
          }));
        }
        if (msg.type === 'transcript') {
          setState(s => ({ ...s, transcript: msg.text }));
        }
      }
    };
  }, [userId]);

  const startListening = useCallback(async () => {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    audioCtxRef.current = new AudioContext({ sampleRate: 16000 });
    const source = audioCtxRef.current.createMediaStreamSource(stream);
    const processor = audioCtxRef.current.createScriptProcessor(4096, 1, 1);
    
    processor.onaudioprocess = (e) => {
      const float32 = e.inputBuffer.getChannelData(0);
      const int16 = new Int16Array(float32.length);
      for (let i = 0; i < float32.length; i++) {
        int16[i] = Math.max(-32768, Math.min(32767, float32[i] * 32768));
      }
      wsRef.current?.send(int16.buffer);
    };
    
    source.connect(processor);
    processor.connect(audioCtxRef.current.destination);
    setState(s => ({ ...s, isListening: true }));
  }, []);

  return { ...state, connect, startListening };
}
```

```tsx
// components/EmotionalCanvas.tsx
export function EmotionalCanvas({ imageUrl, emotion, stage }: Props) {
  return (
    <div className="relative w-full h-screen overflow-hidden bg-black">
      {imageUrl && (
        <img
          src={imageUrl}
          alt={`${emotion} landscape`}
          className="absolute inset-0 w-full h-full object-cover 
                     transition-opacity duration-[3000ms] ease-in-out"
          // 3-second crossfade between emotional landscapes
        />
      )}
      <div className="absolute bottom-8 left-8 text-white/80 backdrop-blur-md 
                      rounded-2xl p-4 bg-black/20">
        <p className="text-sm uppercase tracking-wider">{stage}</p>
        <p className="text-lg font-light">{emotion}</p>
      </div>
    </div>
  );
}
```

The **3-second CSS crossfade** between images (`transition-opacity duration-[3000ms]`) creates the illusion of continuous evolution even though images are generated discretely every 10–30 seconds during the transformation phase.

---

## 8. Google Cloud infrastructure and Terraform

### Cloud Run configuration

```bash
gcloud run deploy mirrormind-backend \
  --source . \
  --region us-central1 \
  --memory 4Gi \
  --cpu 2 \
  --timeout 3600 \
  --concurrency 80 \
  --min-instances 1 \
  --max-instances 10 \
  --session-affinity \
  --set-env-vars "GCP_PROJECT=$PROJECT_ID" \
  --set-secrets "GOOGLE_API_KEY=gemini-api-key:latest" \
  --allow-unauthenticated \
  --port 8080
```

Key settings: **4 GiB memory** (audio buffers + image handling), **3600s timeout** (WebSocket sessions), **session affinity** (sticky WebSocket routing), **min 1 instance** (no cold starts for demo).

### Complete Terraform for +0.2 bonus

```hcl
# terraform/main.tf
terraform {
  required_version = ">= 1.5"
  required_providers {
    google      = { source = "hashicorp/google", version = "~> 5.0" }
    google-beta = { source = "hashicorp/google-beta", version = "~> 5.0" }
  }
}

variable "project_id" { type = string }
variable "region" { type = string; default = "us-central1" }

provider "google" { project = var.project_id; region = var.region }
provider "google-beta" { project = var.project_id; region = var.region }

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com", "firestore.googleapis.com",
    "storage.googleapis.com", "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com", "artifactregistry.googleapis.com",
  ])
  project = var.project_id; service = each.value
  disable_on_destroy = false
}

resource "google_service_account" "sa" {
  account_id   = "mirrormind-sa"
  display_name = "MirrorMind Service Account"
}

resource "google_project_iam_member" "roles" {
  for_each = toset([
    "roles/datastore.user", "roles/storage.objectAdmin",
    "roles/secretmanager.secretAccessor", "roles/logging.logWriter",
  ])
  project = var.project_id; role = each.value
  member  = "serviceAccount:${google_service_account.sa.email}"
}

resource "google_firestore_database" "db" {
  provider    = google-beta
  name        = "(default)"; location_id = var.region
  type        = "FIRESTORE_NATIVE"
  depends_on  = [google_project_service.apis["firestore.googleapis.com"]]
}

resource "google_storage_bucket" "artwork" {
  name     = "mirrormind-artwork-${var.project_id}"
  location = var.region; force_destroy = true
  uniform_bucket_level_access = true
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type"]
    max_age_seconds = 3600
  }
}

resource "google_secret_manager_secret" "api_key" {
  secret_id = "gemini-api-key"
  replication { auto {} }
  depends_on = [google_project_service.apis["secretmanager.googleapis.com"]]
}

resource "google_cloud_run_v2_service" "backend" {
  name     = "mirrormind-backend"; location = var.region
  template {
    containers {
      image = "gcr.io/${var.project_id}/mirrormind-backend:latest"
      resources { limits = { cpu = "2"; memory = "4Gi" } }
      env { name = "GCP_PROJECT"; value = var.project_id }
      env { name = "ARTWORK_BUCKET"; value = google_storage_bucket.artwork.name }
      ports { container_port = 8080 }
    }
    scaling { min_instance_count = 1; max_instance_count = 10 }
    timeout = "3600s"; max_instance_request_concurrency = 80
    service_account = google_service_account.sa.email
    session_affinity = true
  }
  depends_on = [google_project_service.apis["run.googleapis.com"]]
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  name = google_cloud_run_v2_service.backend.name
  location = var.region; role = "roles/run.invoker"
  member = "allUsers"
}

output "url" { value = google_cloud_run_v2_service.backend.uri }
```

Deploy: `terraform init && terraform apply -var="project_id=YOUR_PROJECT"`.

---

## 9. Competitive differentiation: why MirrorMind wins

### Nothing like it exists

No hackathon project or commercial app combines all three of: (1) real-time voice emotion detection, (2) generative art from emotions, and (3) guided therapeutic transformation with evolving visuals. **Calm** and **Headspace** are pre-recorded passive content. **Woebot** and **Wysa** are text-only CBT chatbots. **Endel** generates adaptive soundscapes but doesn't listen to your voice or generate visual art. **MoodGallery** generates art from manually logged moods but has no voice input, no real-time streaming, and no transformation exercise.

### Why Gemini is uniquely required

Without Gemini, this app would require stitching together **5+ separate APIs**: Whisper for STT → Hume AI for emotion detection → GPT-4 for dialog → DALL-E for images → ElevenLabs for TTS. That pipeline would introduce **3–5× higher latency**, lose the natural conversational flow, cost 4–10× more, and — critically — lose the native voice emotion understanding that comes from processing raw audio directly. Gemini's affective dialog detects emotional nuance that text-based sentiment analysis fundamentally cannot capture: a trembling voice saying "I'm fine" reads as positive in text but negative in audio. This is the core insight that makes MirrorMind impossible without Gemini.

### Prize targeting

MirrorMind is competitive for **Best Live Agent** (real-time voice streaming with interruption handling), **Best Multimodal Integration** (voice → emotion → art → voice feedback loop), **Best Innovation** (novel concept of emotional art therapy), and **Best Technical Execution** (6+ GCP services, Terraform, multi-agent ADK architecture).

---

## 10. The 12-day build plan (March 4–16)

### Days 1–3: minimum viable magic

| Day | Goal | Deliverable |
|-----|------|------------|
| **1** | Live API voice connection | Working mic → Gemini → audio response loop |
| **2** | Emotion-to-image pipeline | Speak emotion → Gemini generates landscape |
| **3** | Basic frontend + full loop | React app: speak → see art → hear response |

**Day 1 priority order**: (1) `pip install google-adk google-genai`, (2) get Live API streaming working in a terminal script, (3) add `enable_affective_dialog=True`, (4) add the `analyze_and_generate_art` tool, (5) verify tool calls trigger.

**Day 3 is the critical milestone**: if the core loop works by end of Day 3, everything else is polish and depth.

### Days 4–7: the experience

| Day | Goal |
|-----|------|
| **4** | Multi-agent ADK refactor, session state management |
| **5** | Transformation exercise flow (acknowledge → shift → arrive) |
| **6** | Image evolution via multi-turn chat, breathing synchronization |
| **7** | Frontend polish: crossfade transitions, emotion timeline, waveform viz |

### Days 8–10: production-ready

| Day | Goal |
|-----|------|
| **8** | Cloud Run deployment + Terraform |
| **9** | Edge case handling, Firestore persistence, error recovery |
| **10** | Integration testing on production, performance measurement |

### Days 11–12: submission

| Day | Goal |
|-----|------|
| **11** | Record demo video (4 min), write blog post for dev.to |
| **12** | README, architecture diagram (Excalidraw), final testing, submit |

### What to cut if behind

**Absolute minimum (3 days):** Single FastAPI endpoint, Gemini Live API + single image generation per emotion, basic HTML/JS frontend, Cloud Run deploy with shell script. No multi-turn image editing, no transformation exercise, no Firestore.

**Cut list** (last item cut first): ambient audio → Firestore persistence → emotional journey timeline → breathing synchronization animation → multi-turn image evolution (use single-shot per emotion) → multi-agent ADK (use single agent) → polished UI (use basic HTML).

### Edge case handling

**User goes silent**: After 10s, agent says "I'm here whenever you're ready." After 30s, offer a calming landscape. Use `silence_duration_ms=800` in VAD config for generous pause tolerance.

**Crisis detection**: System prompt includes explicit instructions to pause the exercise and provide the 988 hotline. Additionally, implement keyword monitoring on transcriptions for terms like "kill myself," "want to die," "end it all" as a safety net. Display crisis resources prominently in the UI at all times.

**Image generation fails**: Retry once with a simplified prompt. Fall back to a curated set of 6 pre-generated landscapes (one per emotion) stored as static assets. Never show an error to the user.

**Network interruption**: Frontend uses exponential backoff reconnection. ADK's `session_resumption` preserves context across reconnects. Cache the last displayed image locally.

---

## 11. Demo video structure for maximum impact

```
0:00–0:20  HOOK: "What if your voice could paint?" 
           Show the final product: a user speaking → art appearing.
0:20–0:40  PROBLEM: 1 in 5 adults experience mental health challenges. 
           Art therapy works but costs $150/hour.
0:40–2:30  LIVE DEMO (the money shot):
           - Start talking about a stressful day (show anxiety landscape)
           - Agent responds empathetically (show emotion label updating)
           - Agent offers transformation exercise
           - Breathe together → watch the landscape shift from storm to sunrise
           - Agent reflects on the journey
2:30–3:15  ARCHITECTURE: Flash the diagram. Name-drop: Gemini Live API 
           (affective dialog), Nano Banana 2 (image gen), ADK (multi-agent),
           Cloud Run, Firestore, Terraform.
3:15–3:45  IMPACT: Accessible emotional wellness for anyone with a phone.
           No appointments. No cost. AI-powered art therapy, democratized.
3:45–4:00  CLOSE: "MirrorMind. Your emotions, reflected. Your calm, created.
           Built entirely on Gemini."
```

The live demo section (0:40–2:30) is everything. Record 3 full runs and use the best one. Use OBS for screen recording with a small webcam overlay showing your face for authenticity.

### Blog post for +0.6 bonus

Publish on **dev.to**: "Building MirrorMind: How Gemini's Live API Turns Your Voice Into Healing Art." Cover the emotion → prompt engineering pipeline, the function-calling bridge pattern, and the transformation exercise design. **1,500–2,500 words**. End with: *"This blog post was created for the purposes of the Gemini Live Agent Challenge hackathon. #GeminiLiveAgentChallenge"*. Share on X/Twitter with the hashtag.

---

## Conclusion

MirrorMind's technical architecture reduces to a elegant three-part system: **Gemini Live API** with affective dialog listens to your voice and understands your emotions natively; it calls a **function tool** that triggers **Nano Banana 2's multi-turn image editing** to generate and evolve landscapes; and a **WebSocket bridge** streams both audio responses and image updates to a React frontend simultaneously. The key architectural insight — using function calling to bridge audio-only Live API sessions with image generation — is well-documented in Google's own GenMedia Live reference demo and is the canonical pattern for this exact use case.

The emotional-to-visual mapping is grounded in Russell's circumplex model (valence → brightness; arousal → saturation), and the four-stage transformation (acknowledge → explore → shift → arrive) follows DBT principles of validation-before-change. The physiological sigh, backed by Stanford's 2023 RCT showing superior mood improvement over meditation, should be the primary breathing technique.

With 12 days and a clear priority stack, the critical path is: Days 1–3 get the core loop working (speak → see art → hear response), Days 4–7 build the transformation experience, Days 8–10 deploy and harden, Days 11–12 record and submit. If everything else falls apart, the minimum viable demo — a voice conversation that generates a single emotional landscape — is achievable in 3 days and still demonstrates the core innovation that no other app provides.