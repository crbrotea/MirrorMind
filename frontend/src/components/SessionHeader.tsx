'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { STAGE_LABELS, STAGE_ORDER } from '@/lib/constants';

interface SessionHeaderProps {
  stage: string;
  isConnected: boolean;
  onEndSession: () => void;
}

export default function SessionHeader({
  stage,
  isConnected,
  onEndSession,
}: SessionHeaderProps) {
  const [elapsed, setElapsed] = useState(0);

  useEffect(() => {
    if (!isConnected) return;

    const interval = setInterval(() => {
      setElapsed((prev) => prev + 1);
    }, 1000);

    return () => clearInterval(interval);
  }, [isConnected]);

  const minutes = Math.floor(elapsed / 60);
  const seconds = elapsed % 60;
  const timeStr = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;

  const stageIndex = STAGE_ORDER.indexOf(stage as typeof STAGE_ORDER[number]);
  const totalStages = STAGE_ORDER.length - 1; // exclude 'complete'
  const progressPercent = stageIndex >= 0 ? (stageIndex / totalStages) * 100 : 0;

  return (
    <div className="absolute inset-x-0 top-0 z-20 flex items-center justify-between px-4 py-3">
      {/* Back button */}
      <Link
        href="/"
        className="flex h-10 w-10 items-center justify-center rounded-full bg-white/5 backdrop-blur-md border border-white/10 transition-colors hover:bg-white/10"
        aria-label="Volver al inicio"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth={2}
          strokeLinecap="round"
          strokeLinejoin="round"
          className="h-4 w-4 text-white/70"
        >
          <path d="M19 12H5" />
          <path d="m12 19-7-7 7-7" />
        </svg>
      </Link>

      {/* Center: Timer + Stage progress */}
      <div className="flex flex-col items-center gap-1">
        <span className="text-xs font-mono text-white/50">{timeStr}</span>
        {/* Stage progress bar */}
        <div className="flex items-center gap-1">
          {STAGE_ORDER.slice(0, -1).map((s, i) => (
            <div
              key={s}
              className="h-0.5 w-6 rounded-full transition-all duration-1000"
              style={{
                backgroundColor:
                  i <= stageIndex ? 'rgba(255,255,255,0.6)' : 'rgba(255,255,255,0.15)',
              }}
            />
          ))}
        </div>
        <span className="text-[10px] text-white/40 uppercase tracking-widest">
          {STAGE_LABELS[stage] ?? stage}
        </span>
      </div>

      {/* End session button */}
      <button
        onClick={onEndSession}
        className="flex h-10 items-center gap-1.5 rounded-full bg-white/5 px-3 backdrop-blur-md border border-white/10 transition-colors hover:bg-white/10"
        aria-label="Finalizar sesión"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth={2}
          strokeLinecap="round"
          strokeLinejoin="round"
          className="h-4 w-4 text-white/70"
        >
          <rect x="3" y="3" width="18" height="18" rx="2" />
          <rect x="8" y="8" width="8" height="8" rx="1" fill="currentColor" />
        </svg>
        <span className="text-xs text-white/60 hidden sm:inline">Fin</span>
      </button>
    </div>
  );
}
