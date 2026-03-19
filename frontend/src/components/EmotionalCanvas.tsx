'use client';

import { useEffect, useRef, useState } from 'react';
import { EMOTION_COLORS } from '@/lib/constants';

interface EmotionalCanvasProps {
  imageUrl: string | null;
  previousImageUrl: string | null;
  emotion: string;
}

export default function EmotionalCanvas({
  imageUrl,
  previousImageUrl,
  emotion,
}: EmotionalCanvasProps) {
  const [frontLayer, setFrontLayer] = useState<'a' | 'b'>('a');
  const layerARef = useRef<string | null>(null);
  const layerBRef = useRef<string | null>(null);

  useEffect(() => {
    if (!imageUrl) return;

    if (frontLayer === 'a') {
      layerBRef.current = imageUrl;
      setFrontLayer('b');
    } else {
      layerARef.current = imageUrl;
      setFrontLayer('a');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [imageUrl]);

  const colors = EMOTION_COLORS[emotion] ?? EMOTION_COLORS.neutral;
  const hasAnyImage = layerARef.current || layerBRef.current || imageUrl || previousImageUrl;

  return (
    <div data-testid="emotional-canvas" className="absolute inset-0 overflow-hidden bg-[#0a0a1a]">
      {/* Ambient gradient when no images */}
      {!hasAnyImage && (
        <div
          className="absolute inset-0 animate-ambient-shift"
          style={{
            background: `radial-gradient(ellipse at 50% 50%, ${colors.primary}40, ${colors.secondary}20, #0a0a1a)`,
          }}
        />
      )}

      {/* Layer A */}
      <div
        className="absolute inset-0 transition-opacity duration-[3000ms] ease-in-out"
        style={{ opacity: frontLayer === 'a' ? 1 : 0 }}
      >
        {(layerARef.current || (frontLayer === 'a' && imageUrl)) && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={layerARef.current ?? imageUrl ?? ''}
            alt="Paisaje emocional"
            className="h-full w-full object-cover"
          />
        )}
      </div>

      {/* Layer B */}
      <div
        className="absolute inset-0 transition-opacity duration-[3000ms] ease-in-out"
        style={{ opacity: frontLayer === 'b' ? 1 : 0 }}
      >
        {(layerBRef.current || (frontLayer === 'b' && imageUrl)) && (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={layerBRef.current ?? imageUrl ?? ''}
            alt="Paisaje emocional"
            className="h-full w-full object-cover"
          />
        )}
      </div>

      {/* Bottom gradient overlay for readability */}
      <div className="absolute inset-x-0 bottom-0 h-1/2 bg-gradient-to-t from-black/80 via-black/40 to-transparent" />

      {/* Top gradient overlay */}
      <div className="absolute inset-x-0 top-0 h-32 bg-gradient-to-b from-black/50 to-transparent" />

      {/* Emotion-tinted vignette */}
      <div
        className="absolute inset-0 transition-all duration-[2000ms]"
        style={{
          boxShadow: `inset 0 0 150px 30px ${colors.glow}`,
        }}
      />
    </div>
  );
}
