'use client';

import { EMOTION_COLORS, EMOTION_DISPLAY_NAMES, STAGE_LABELS } from '@/lib/constants';

interface EmotionIndicatorProps {
  emotion: string;
  stage: string;
}

export default function EmotionIndicator({ emotion, stage }: EmotionIndicatorProps) {
  const colors = EMOTION_COLORS[emotion] ?? EMOTION_COLORS.neutral;
  const emotionLabel = EMOTION_DISPLAY_NAMES[emotion] ?? emotion;
  const stageLabel = STAGE_LABELS[stage] ?? stage;

  return (
    <div className="absolute left-4 top-16 z-20 flex flex-col gap-1.5">
      {/* Emotion badge */}
      <div
        className="flex items-center gap-2 rounded-full px-3 py-1.5 backdrop-blur-md border border-white/10 transition-all duration-1000"
        style={{
          background: `${colors.primary}30`,
          boxShadow: `0 0 20px ${colors.glow}`,
        }}
      >
        <span
          className="h-2 w-2 rounded-full animate-pulse-glow"
          style={{ backgroundColor: colors.primary }}
        />
        <span className="text-xs font-medium text-white/80 tracking-wide">
          {emotionLabel}
        </span>
      </div>

      {/* Stage badge */}
      <div className="flex items-center rounded-full bg-white/5 px-3 py-1 backdrop-blur-md border border-white/5">
        <span className="text-[10px] text-white/50 uppercase tracking-widest">
          {stageLabel}
        </span>
      </div>
    </div>
  );
}
