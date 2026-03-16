'use client';

import { useCallback, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useMirrorMind } from '@/hooks/useMirrorMind';
import EmotionalCanvas from '@/components/EmotionalCanvas';
import SessionHeader from '@/components/SessionHeader';
import EmotionIndicator from '@/components/EmotionIndicator';
import TranscriptOverlay from '@/components/TranscriptOverlay';
import BreathingGuide from '@/components/BreathingGuide';
import VoiceControls from '@/components/VoiceControls';

export default function SessionPage() {
  const router = useRouter();
  const {
    state,
    captureError,
    connect,
    disconnect,
    startListening,
    stopListening,
    endSession,
  } = useMirrorMind();

  const [isInitializing, setIsInitializing] = useState(true);

  // Connect on mount
  useEffect(() => {
    connect();
    const timer = setTimeout(() => setIsInitializing(false), 1500);
    return () => {
      clearTimeout(timer);
      disconnect();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleEndSession = useCallback(() => {
    endSession();
    setTimeout(() => {
      router.push('/');
    }, 500);
  }, [endSession, router]);

  const handleStartListening = useCallback(async () => {
    await startListening();
  }, [startListening]);

  const handleStopListening = useCallback(() => {
    stopListening();
  }, [stopListening]);

  // Loading state
  if (isInitializing) {
    return (
      <main className="relative flex min-h-dvh items-center justify-center bg-[#0a0a1a]">
        <div className="flex flex-col items-center gap-4 animate-fade-in">
          <div className="h-12 w-12 rounded-full border-2 border-white/10 border-t-white/40 animate-spin" />
          <p className="text-sm text-white/40">Preparing your space...</p>
        </div>
      </main>
    );
  }

  // Session complete
  if (state.stage === 'complete') {
    return (
      <main className="relative flex min-h-dvh items-center justify-center bg-[#0a0a1a]">
        {state.imageUrl && (
          <EmotionalCanvas
            imageUrl={state.imageUrl}
            previousImageUrl={state.previousImageUrl}
            emotion={state.emotion}
          />
        )}
        <div className="relative z-10 flex flex-col items-center gap-6 px-6 text-center animate-float-up">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-white/10 border border-white/15 backdrop-blur-md">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth={1.5}
              className="h-7 w-7 text-white/70"
            >
              <path d="M20 6 9 17l-5-5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
          <h2 className="text-2xl font-light text-white/90">Session complete</h2>
          <p className="max-w-xs text-sm text-white/40">
            Your emotional landscape has been saved. Remember you can always return to this space.
          </p>
          <div className="flex gap-3">
            <button
              onClick={() => router.push('/gallery')}
              className="rounded-full bg-white/10 px-6 py-2.5 text-sm text-white/80 border border-white/10 transition-colors hover:bg-white/15"
            >
              View gallery
            </button>
            <button
              onClick={() => router.push('/')}
              className="rounded-full bg-white/5 px-6 py-2.5 text-sm text-white/50 border border-white/5 transition-colors hover:bg-white/10"
            >
              Home
            </button>
          </div>
        </div>
      </main>
    );
  }

  return (
    <main className="relative h-dvh w-full overflow-hidden">
      {/* Background canvas */}
      <EmotionalCanvas
        imageUrl={state.imageUrl}
        previousImageUrl={state.previousImageUrl}
        emotion={state.emotion}
      />

      {/* Session header */}
      <SessionHeader
        stage={state.stage}
        isConnected={state.isConnected}
        onEndSession={handleEndSession}
      />

      {/* Emotion indicator */}
      <EmotionIndicator emotion={state.emotion} stage={state.stage} />

      {/* Breathing guide */}
      <BreathingGuide pattern={state.breathingPattern} />

      {/* Transcript overlay */}
      <TranscriptOverlay
        userTranscript={state.transcript}
        agentTranscript={state.agentTranscript}
      />

      {/* Voice controls */}
      <VoiceControls
        isListening={state.isListening}
        isConnected={state.isConnected}
        onStartListening={handleStartListening}
        onStopListening={handleStopListening}
        error={captureError}
      />
    </main>
  );
}
