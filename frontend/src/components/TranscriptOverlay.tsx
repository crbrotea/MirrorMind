'use client';

import { useEffect, useRef, useState } from 'react';
import { TRANSCRIPT_FADE_MS } from '@/lib/constants';

interface TranscriptOverlayProps {
  userTranscript: string;
  agentTranscript: string;
}

export default function TranscriptOverlay({
  userTranscript,
  agentTranscript,
}: TranscriptOverlayProps) {
  const [visible, setVisible] = useState(false);
  const fadeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const prevUserRef = useRef(userTranscript);
  const prevAgentRef = useRef(agentTranscript);

  useEffect(() => {
    const userChanged = userTranscript !== prevUserRef.current;
    const agentChanged = agentTranscript !== prevAgentRef.current;
    prevUserRef.current = userTranscript;
    prevAgentRef.current = agentTranscript;

    if (userChanged || agentChanged) {
      setVisible(true);

      if (fadeTimerRef.current) {
        clearTimeout(fadeTimerRef.current);
      }

      fadeTimerRef.current = setTimeout(() => {
        setVisible(false);
        fadeTimerRef.current = null;
      }, TRANSCRIPT_FADE_MS);
    }

    return () => {
      if (fadeTimerRef.current) {
        clearTimeout(fadeTimerRef.current);
      }
    };
  }, [userTranscript, agentTranscript]);

  const hasContent = userTranscript || agentTranscript;

  if (!hasContent) return null;

  return (
    <div
      className={`
        absolute inset-x-0 bottom-28 flex flex-col items-center gap-2 px-6
        transition-opacity duration-700
        ${visible ? 'opacity-100' : 'opacity-0'}
      `}
    >
      {/* Agent transcript */}
      {agentTranscript && (
        <div data-testid="agent-transcript" className="max-w-md rounded-xl bg-white/10 px-4 py-2.5 backdrop-blur-lg border border-white/10">
          <p className="text-sm leading-relaxed text-white/90">{agentTranscript}</p>
        </div>
      )}

      {/* User transcript */}
      {userTranscript && (
        <div data-testid="user-transcript" className="max-w-md rounded-xl bg-white/5 px-4 py-2 backdrop-blur-md border border-white/5">
          <p className="text-sm leading-relaxed text-white/60 italic">{userTranscript}</p>
        </div>
      )}
    </div>
  );
}
