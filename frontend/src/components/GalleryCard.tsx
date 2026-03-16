'use client';

import { EMOTION_COLORS } from '@/lib/constants';
import type { GalleryEntry } from '@/types';

interface GalleryCardProps {
  entry: GalleryEntry;
  onClick: (entry: GalleryEntry) => void;
}

const EMOTION_LABELS: Record<string, string> = {
  anxiety: 'Ansiedad',
  sadness: 'Tristeza',
  anger: 'Enojo',
  joy: 'Alegria',
  calm: 'Calma',
  fear: 'Miedo',
  hope: 'Esperanza',
  neutral: 'Neutral',
};

export default function GalleryCard({ entry, onClick }: GalleryCardProps) {
  const colors = EMOTION_COLORS[entry.finalEmotion] ?? EMOTION_COLORS.neutral;
  const emotionLabel = EMOTION_LABELS[entry.finalEmotion] ?? entry.finalEmotion;

  const formattedDate = new Date(entry.date).toLocaleDateString('es-ES', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });

  return (
    <button
      onClick={() => onClick(entry)}
      className="group relative aspect-[3/4] w-full overflow-hidden rounded-2xl border border-white/10 bg-white/5 backdrop-blur-sm transition-all duration-300 hover:border-white/20 hover:scale-[1.02] focus:outline-none focus-visible:ring-2 focus-visible:ring-white/30"
    >
      {/* Artwork image */}
      {entry.thumbnailUrl ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src={entry.thumbnailUrl}
          alt={`Sesion del ${formattedDate}`}
          className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
        />
      ) : (
        <div
          className="h-full w-full"
          style={{
            background: `linear-gradient(135deg, ${colors.primary}, ${colors.secondary})`,
          }}
        />
      )}

      {/* Overlay gradient */}
      <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-transparent to-transparent" />

      {/* Info */}
      <div className="absolute inset-x-0 bottom-0 p-3">
        <div className="flex items-center gap-1.5 mb-1">
          <span
            className="h-1.5 w-1.5 rounded-full"
            style={{ backgroundColor: colors.primary }}
          />
          <span className="text-xs font-medium text-white/80">{emotionLabel}</span>
        </div>
        <p className="text-[10px] text-white/50">{formattedDate}</p>
      </div>

      {/* Emotion journey dots */}
      <div className="absolute right-2 top-2 flex gap-0.5">
        {entry.emotions.slice(0, 5).map((em, i) => {
          const c = EMOTION_COLORS[em] ?? EMOTION_COLORS.neutral;
          return (
            <span
              key={`${em}-${i}`}
              className="h-1.5 w-1.5 rounded-full"
              style={{ backgroundColor: c.primary }}
            />
          );
        })}
      </div>
    </button>
  );
}
