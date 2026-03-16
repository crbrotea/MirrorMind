'use client';

import { useCallback, useEffect, useRef } from 'react';

interface VoiceControlsProps {
  isListening: boolean;
  isConnected: boolean;
  onStartListening: () => void;
  onStopListening: () => void;
  error: string | null;
}

export default function VoiceControls({
  isListening,
  isConnected,
  onStartListening,
  onStopListening,
  error,
}: VoiceControlsProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animFrameRef = useRef<number>(0);
  const analyserRef = useRef<AnalyserNode | null>(null);

  // Simple waveform visualization
  useEffect(() => {
    if (!isListening) {
      if (animFrameRef.current) {
        cancelAnimationFrame(animFrameRef.current);
        animFrameRef.current = 0;
      }
      // Clear canvas
      const canvas = canvasRef.current;
      if (canvas) {
        const ctx = canvas.getContext('2d');
        if (ctx) {
          ctx.clearRect(0, 0, canvas.width, canvas.height);
        }
      }
      return;
    }

    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Simulate waveform with smooth sine waves
    let phase = 0;

    const draw = () => {
      const w = canvas.width;
      const h = canvas.height;
      ctx.clearRect(0, 0, w, h);

      ctx.strokeStyle = 'rgba(255, 255, 255, 0.6)';
      ctx.lineWidth = 2;
      ctx.beginPath();

      phase += 0.05;
      const bars = 40;
      const barWidth = w / bars;

      for (let i = 0; i < bars; i++) {
        const amplitude =
          Math.sin(phase + i * 0.3) * 0.3 +
          Math.sin(phase * 1.5 + i * 0.2) * 0.2 +
          Math.random() * 0.15;
        const barHeight = Math.abs(amplitude) * h * 0.8;
        const x = i * barWidth + barWidth / 2;
        const y = (h - barHeight) / 2;

        ctx.fillStyle = `rgba(255, 255, 255, ${0.3 + Math.abs(amplitude) * 0.5})`;
        ctx.fillRect(x - 1, y, 2, barHeight);
      }

      animFrameRef.current = requestAnimationFrame(draw);
    };

    draw();

    return () => {
      if (animFrameRef.current) {
        cancelAnimationFrame(animFrameRef.current);
      }
    };
  }, [isListening]);

  const handleToggle = useCallback(() => {
    if (isListening) {
      onStopListening();
    } else {
      onStartListening();
    }
  }, [isListening, onStartListening, onStopListening]);

  return (
    <div className="absolute inset-x-0 bottom-0 flex flex-col items-center pb-8 pt-4">
      {/* Waveform */}
      <canvas
        ref={canvasRef}
        width={240}
        height={48}
        className={`mb-4 transition-opacity duration-500 ${isListening ? 'opacity-100' : 'opacity-0'}`}
      />

      {/* Mic button */}
      <button
        onClick={handleToggle}
        disabled={!isConnected}
        className={`
          group relative flex h-16 w-16 items-center justify-center rounded-full
          transition-all duration-300 ease-out
          ${
            isListening
              ? 'bg-red-500/80 shadow-[0_0_30px_rgba(239,68,68,0.4)]'
              : isConnected
                ? 'bg-white/10 hover:bg-white/20 shadow-[0_0_20px_rgba(255,255,255,0.1)]'
                : 'bg-white/5 cursor-not-allowed opacity-50'
          }
          backdrop-blur-md border border-white/20
          min-h-[48px] min-w-[48px]
        `}
        aria-label={isListening ? 'Detener microfono' : 'Iniciar microfono'}
      >
        {/* Pulse rings when recording */}
        {isListening && (
          <>
            <span className="absolute inset-0 animate-ping-slow rounded-full bg-red-500/30" />
            <span className="absolute -inset-2 animate-ping-slower rounded-full bg-red-500/15" />
          </>
        )}

        {/* Mic icon */}
        <svg
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth={2}
          strokeLinecap="round"
          strokeLinejoin="round"
          className={`h-6 w-6 transition-colors ${isListening ? 'text-white' : 'text-white/70 group-hover:text-white'}`}
        >
          {isListening ? (
            // Stop icon
            <rect x="6" y="6" width="12" height="12" rx="1" fill="currentColor" />
          ) : (
            // Mic icon
            <>
              <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
              <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
              <line x1="12" y1="19" x2="12" y2="22" />
            </>
          )}
        </svg>
      </button>

      {/* Error message */}
      {error && (
        <p className="mt-3 max-w-xs text-center text-sm text-red-400/90">{error}</p>
      )}

      {/* Status text */}
      {!error && (
        <p className="mt-3 text-xs text-white/40">
          {!isConnected
            ? 'Conectando...'
            : isListening
              ? 'Escuchando...'
              : 'Toca para hablar'}
        </p>
      )}
    </div>
  );
}
