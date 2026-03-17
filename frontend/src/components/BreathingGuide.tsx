'use client';

import { useBreathingSync } from '@/hooks/useBreathingSync';
import type { BreathingPattern } from '@/types';

interface BreathingGuideProps {
  pattern: BreathingPattern | null;
}

const PHASE_LABELS: Record<string, string> = {
  inhale: 'Inhala',
  hold: 'Mantén',
  exhale: 'Exhala',
  rest: 'Descansa',
};

export default function BreathingGuide({ pattern }: BreathingGuideProps) {
  const { progress, isActive, phaseName } = useBreathingSync(pattern);

  if (!isActive || !pattern) return null;

  // Calculate scale: inhale expands, exhale contracts, hold/rest stays
  let scale = 1;
  if (phaseName === 'inhale') {
    scale = 0.6 + progress * 0.6; // 0.6 -> 1.2
  } else if (phaseName === 'exhale') {
    scale = 1.2 - progress * 0.6; // 1.2 -> 0.6
  } else if (phaseName === 'hold') {
    scale = 1.2;
  } else {
    scale = 0.6;
  }

  // Opacity pulse
  const opacity = phaseName === 'hold' || phaseName === 'rest' ? 0.6 : 0.4 + progress * 0.4;

  const label = PHASE_LABELS[phaseName] ?? phaseName;

  return (
    <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-10">
      <div className="relative flex items-center justify-center">
        {/* Outer glow */}
        <div
          className="absolute rounded-full transition-transform duration-200 ease-out"
          style={{
            width: 200,
            height: 200,
            transform: `scale(${scale * 1.15})`,
            background: `radial-gradient(circle, rgba(255,255,255,${opacity * 0.15}) 0%, transparent 70%)`,
          }}
        />

        {/* Main circle */}
        <div
          className="flex items-center justify-center rounded-full border border-white/20 backdrop-blur-sm transition-transform duration-200 ease-out"
          style={{
            width: 160,
            height: 160,
            transform: `scale(${scale})`,
            background: `rgba(255, 255, 255, ${opacity * 0.1})`,
          }}
        >
          <div className="text-center">
            <p className="text-lg font-light text-white/90 tracking-wider">{label}</p>
            <p className="mt-1 text-xs text-white/50">
              {pattern.technique === 'box'
                ? 'Respiración cuadrada'
                : pattern.technique === 'calm'
                  ? 'Respiración calmante'
                  : 'Suspiro fisiológico'}
            </p>
          </div>
        </div>

        {/* Inner ring */}
        <div
          className="absolute rounded-full border border-white/10 transition-transform duration-200 ease-out"
          style={{
            width: 120,
            height: 120,
            transform: `scale(${scale})`,
          }}
        />
      </div>
    </div>
  );
}
