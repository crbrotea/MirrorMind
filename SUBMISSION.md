## Inspiration

The mental health crisis is staggering: 1 in 5 adults experiences a mental health condition each year, yet the average wait time to see a therapist is 48 days. Digital solutions were supposed to bridge this gap — but they haven't. Mental health apps have a 3.3% retention rate at 30 days. Why? Because typing into a text chatbot feels nothing like being truly heard.

We asked ourselves: What if AI could actually feel how you feel — not from what you type, but from how you sound? And what if, instead of giving you a generic CBT worksheet, it showed you your emotions as a living, breathing work of art — and then helped you transform them in real time?

That question became Brotea Mirror Mind.

The inspiration came from three converging ideas:

- **Art therapy research** shows that externalizing emotions visually reduces their intensity — seeing your anxiety as a storm outside of yourself is itself therapeutic.
- **Gemini's affective dialog** can detect emotional nuance directly from voice — a trembling "I'm fine" reads as positive in text but deeply anxious in audio. No other model does this natively.
- **The retention problem** in digital mental health exists because apps produce nothing users value enough to return to. Brotea Mirror Mind creates a personal gallery of emotional art — something beautiful, unique, and worth revisiting.

## What it does

Brotea Mirror Mind is a voice-first emotional wellness companion that transforms your spoken self-expression into real-time generative art.

The experience flows in four stages:

1. **Speak freely.** Open the app, start talking about your day — your frustrations, your joys, whatever's on your mind. There's no form, no prompts, no "rate your mood 1-10."
2. **See your emotions reflected.** As you speak, Brotea Mirror Mind listens to your voice tone, pace, and words. It generates an artistic landscape that mirrors your emotional state — anxiety becomes a stormy sea with dark clouds; sadness becomes a quiet, misty plain under twilight; joy becomes a sunlit meadow of wildflowers.
3. **Transform through breathing.** When you're ready, the agent guides you through an evidence-based breathing exercise selected for your detected emotion — physiological sighing for anxiety (backed by Stanford research), 4-7-8 breathing for sadness, or box breathing for frustration. As you breathe, the artwork evolves: the storm parts, light breaks through, the sea calms.
4. **Arrive at calm.** The final landscape reflects where you've traveled emotionally. Over time, your sessions build into a personal gallery — a visual timeline of your emotional journey.

## How we built it

### Architecture

Brotea Mirror Mind uses a dual-pipeline architecture that bridges Gemini's Live API (voice) with Gemini's Image Generation (art) through a function-calling pattern:

```
Browser Mic → WebSocket → Cloud Run (FastAPI + ADK)
  → Gemini Live API (affective dialog, native audio)
    → Detects emotion from voice
    → Calls analyze_and_generate_art tool
      → Gemini 2.0 Flash Preview Image Generation
      → Multi-turn chat for evolving landscapes
    → Returns audio response to user
  → WebSocket pushes generated image as JSON
  → React frontend renders with 3-second CSS crossfade
```

### Core technologies

- **Gemini Live API** (`gemini-2.5-flash-preview-native-audio-dialog`) with `enable_affective_dialog=True` and `proactive_audio=True` — processes raw audio waveforms to detect emotional nuance in voice (tone, pitch, pace, trembling, sighs) without converting to text first.
- **Gemini Image Generation** (`gemini-2.0-flash-preview-image-generation`) with `response_modalities=["TEXT", "IMAGE"]` — generates artistic landscapes from emotion-informed prompts. Multi-turn chat sessions maintain visual consistency as landscapes evolve.
- **Google ADK (Agent Development Kit)** — orchestrates a single agent with two function tools for image generation and breathing exercise timing. Uses `InMemoryRunner` with `LiveRequestQueue` for real-time streaming.
- **Next.js 16** (App Router) + React 19 + TypeScript — frontend with Web Audio API (`AudioWorkletNode`) for low-latency PCM capture and queue-based playback.
- **Tailwind CSS 4** — styling with CSS crossfade transitions for seamless art evolution.
- **Google Cloud Run** — hosts the FastAPI backend with WebSocket support and single-worker uvicorn for audio/image processing.
- **Firebase/Firestore** (optional) — persists session history and emotional journey data, with in-memory fallback for development.

### The emotion-to-art mapping system

We built a prompt engineering system grounded in color psychology research (Wilms & Oberfeld, 2018) and Russell's valence-arousal circumplex model:

- **Valence** (pleasant ↔ unpleasant) maps to brightness and color warmth (r = .69)
- **Arousal** (high ↔ low) maps to saturation and visual dynamism (r = .60)

Nine emotions (anxiety, sadness, anger, joy, calm, fear, hope, love, frustration) each map to a specific landscape archetype with defined color palettes, lighting conditions, terrain features, and art styles. The Live API agent composes rich visual descriptions that blend these templates with the specific content the user shares — so two anxious users get different storms based on their unique words.

### The transformation engine

The visual transformation uses Gemini's multi-turn conversational image editing. Each subsequent message builds on the previous image in the same chat session, creating gradual evolution:

```
Landscape(t+1) = f(Landscape(t), Δemotion, breathing_phase)
```

The breathing system selects from three evidence-based techniques based on the detected emotion:

- **Physiological Sigh** (Balban et al., 2023, Cell Reports Medicine) — for anxiety/stress: deep inhale (3s) → sharp top-up inhale (1s) → long slow exhale (6s). 5 cycles over 50 seconds.
- **4-7-8 Calm Breathing** — for sadness/exhaustion: inhale (4s) → hold (7s) → exhale (8s). 3 cycles over 57 seconds.
- **Box Breathing** — for frustration/general regulation: inhale (4s) → hold (4s) → exhale (4s) → hold (4s). 4 cycles over 64 seconds.

Each breathing phase includes visual cues that drive the landscape transformation. The CSS crossfade transition (3 seconds) creates the illusion of continuous visual flow.

### Single agent design

```
Agent: mirror_mind (Live API, native audio)
  ├── Tool: analyze_and_generate_art()
  │     → Calls Gemini 2.0 Flash Image in a separate chat session
  │     → Maintains visual consistency via multi-turn context
  │     → Stores images in session state for WebSocket delivery
  │
  ├── Tool: get_breathing_pattern()
  │     → Returns timing for sigh/box/calm breathing techniques
  │     → Includes visual cues for synchronizing art evolution
  │
  └── Safety: Crisis language detection
        → 988 Suicide & Crisis Lifeline prominently displayed
```

### WebSocket protocol

A single WebSocket connection per session carries both audio and structured data:

- **Binary frames** (bidirectional): PCM Int16 audio — 16 kHz mono from client, 24 kHz mono from server.
- **JSON text frames** (server → client): images (base64 PNG + emotion + stage), transcripts, emotion updates, breathing patterns, stage changes, and session completion events.

The frontend distinguishes between the two by checking `event.data instanceof ArrayBuffer` (audio) vs. JSON parse (image/transcript).

## Challenges we ran into

### The audio-image synchronization problem

The biggest technical challenge: Gemini's Live API supports only one response modality per session — AUDIO or TEXT, never IMAGE. We couldn't generate art and speak simultaneously in the same API call.

**Our solution:** Function calling as a bridge. The Live API agent calls `analyze_and_generate_art`, which triggers a separate Gemini Image API call in a dedicated multi-turn chat session. The generated image is stored in ADK session state and pushed to the frontend through the same WebSocket connection as a JSON message, while audio continues streaming as binary data. The frontend distinguishes between the two by checking `event.data instanceof ArrayBuffer` (audio) vs. JSON parse (image/transcript).

### Emotional ambiguity in voice

Affective dialog doesn't return explicit emotion labels — it adjusts its response style based on detected emotional signals. We needed structured emotional data for the art pipeline.

**Our solution:** The system prompt instructs the agent to articulate its emotional assessment when calling the image tool. The model's native understanding of voice becomes the semantic bridge to visual art, expressed through its tool call parameters.

### Image generation latency during live conversation

Generating a landscape takes 2–5 seconds. During that time, the voice conversation continues — if the agent pauses to wait for the image, the experience breaks.

**Our solution:** The tool call is effectively asynchronous from the user's perspective. The Live API agent calls the tool, receives a confirmation, and continues speaking while the frontend receives the image separately via WebSocket. The agent says "Let me paint what I'm hearing..." and by the time the sentence finishes, the image appears. The latency becomes a feature — it creates anticipation.

### Visual consistency across transformations

Without a seed parameter, each image generation produces unique results. A storm in frame 1 might look nothing like the storm evolving in frame 2.

**Our solution:** Multi-turn chat sessions. By sending each subsequent landscape description as a follow-up message in the same Gemini chat, visual context is maintained naturally across turns. The terrain, composition, and style elements persist through the conversation history. If the multi-turn chat fails, a fallback mechanism creates a fresh chat and retries single-shot.

### Therapeutic safety

Building anything adjacent to mental health requires extreme care. We are not therapists, and Brotea Mirror Mind is not therapy.

**Our approach:**

- Framed explicitly as a "creative emotional wellness tool" — never claims to diagnose or treat
- Crisis language detection monitors transcription for self-harm indicators
- 988 Suicide & Crisis Lifeline displayed prominently in the UI at all times
- System prompt includes hard stops: if crisis language is detected, the agent pauses the exercise, validates the user's feelings, and provides the 988 number immediately
- No clinical claims anywhere in the app or submission materials

## Accomplishments that we're proud of

- **The closed emotional feedback loop.** We built something that doesn't exist anywhere else: speak → see your emotion as art → breathe → watch the art transform → feel the shift internally. The visual transformation reinforces the breathing exercise, creating a biofeedback loop through generative art. Test users described it as "watching my anxiety leave my body."
- **Solving the audio-image bridge.** The function-calling pattern that connects Gemini's Live API (audio-only) to Gemini's Image Generation (visual) is an elegant architectural solution to a real platform constraint. The conversation never pauses — art appears while the voice continues guiding you.
- **Real emotional detection from voice alone.** A user saying "I'm fine" in a shaky, flat voice triggers a muted, overcast landscape — not a sunny meadow. Affective dialog reads what text analysis cannot: the difference between words and how they're spoken.
- **The transformation pacing.** After dozens of prompt iterations, we achieved a natural four-stage flow (welcome → mirror → shift → arrive) that validates the user's emotions before attempting change — a core principle from Dialectical Behavior Therapy. The art never erases the original emotion; storms don't vanish, they part to reveal light.
- **Character consistency across evolving landscapes.** Using multi-turn chat sessions with Gemini's image generation, terrain features and compositional elements persist across 4–6 transformation stages — the same mountain appears throughout, just with different lighting and weather. This makes the evolution feel like one continuous journey, not random images.
- **Containerized and deployment-ready.** The backend is Dockerized and Cloud Run-ready with a single-worker uvicorn configuration, health checks, and non-root security. Firestore provides optional persistence with an in-memory fallback for rapid development.

## What we learned

- **Voice carries more emotion than words.** The gap between what someone types ("I'm okay") and how they sound (trembling, flat, rushed) is enormous. Affective dialog doesn't just detect sadness — it detects the flavor of sadness: resignation vs. grief vs. exhaustion.
- **Art externalizes emotion in ways conversation can't.** Test users reported that seeing their anxiety as a landscape made it feel more manageable — "It's just a storm, and storms pass." This aligns with decades of art therapy research, but experiencing it through AI-generated art in real time felt genuinely new.
- **The transformation is the product.** A static image of emotion is interesting; the evolution from storm to sunrise is powerful. Watching your internal state change in the external world creates a feedback loop that reinforces the breathing exercise.
- **Gemini's native audio models are underappreciated.** Most developers use Gemini for text. The native audio path — processing waveforms directly without speech-to-text — captures micro-expressions of emotion that no text pipeline can match. This is Gemini's hidden superpower.
- **The hardest part isn't the tech — it's the pacing.** Getting the right rhythm between listening, reflecting, offering transformation, and guiding breathing required dozens of prompt iterations. Therapeutic pacing is an art, and encoding it in a system prompt was the most challenging design problem of the project.

## What's next for Brotea Mirror Mind

- **Emotional journey gallery:** A persistent timeline view of all generated artwork across sessions, showing emotional patterns over weeks and months — your mental health journey visualized as an art collection.
- **Cloud Storage for gallery:** Persistent image storage replacing the current in-memory approach, enabling artwork to survive across sessions and server restarts.
- **Infrastructure as code:** Terraform deployment for Cloud Run, Firestore, IAM, and secrets to enable one-command provisioning of the entire stack.
- **Therapist integration:** Export session summaries (with user consent) that therapists can review between appointments — not replacing therapy, but enriching it with emotional data from between sessions.
- **Ambient mode:** Background listening during daily activities that periodically generates "emotional snapshots" — a passive mood journal through art, no active effort required.
- **Multi-language support:** Affective dialog works across languages since it reads voice tone, not words — expanding Brotea Mirror Mind to serve the global mental health gap, especially in communities with limited access to therapy.
- **Wearable integration:** Heart rate and skin conductance from smartwatches as additional emotional signals, creating richer multi-modal emotion detection synchronized with the visual transformation.
- **Group sessions:** Shared canvases where multiple users contribute to a collective emotional landscape — potential applications in support groups, couples therapy preparation, and team wellness.
