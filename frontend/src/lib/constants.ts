import type { EmotionColors } from '@/types';

export const EMOTION_COLORS: EmotionColors = {
  anxiety: {
    primary: '#2c3e6b',
    secondary: '#1a2744',
    glow: 'rgba(44, 62, 107, 0.5)',
  },
  sadness: {
    primary: '#6b7b8d',
    secondary: '#3d4a57',
    glow: 'rgba(107, 123, 141, 0.5)',
  },
  anger: {
    primary: '#8b2500',
    secondary: '#5c1a00',
    glow: 'rgba(139, 37, 0, 0.5)',
  },
  joy: {
    primary: '#d4a017',
    secondary: '#a67c00',
    glow: 'rgba(212, 160, 23, 0.5)',
  },
  calm: {
    primary: '#4a7c59',
    secondary: '#2d5a3a',
    glow: 'rgba(74, 124, 89, 0.5)',
  },
  fear: {
    primary: '#4a2d6b',
    secondary: '#2d1a44',
    glow: 'rgba(74, 45, 107, 0.5)',
  },
  hope: {
    primary: '#d4752e',
    secondary: '#a65a1e',
    glow: 'rgba(212, 117, 46, 0.5)',
  },
  neutral: {
    primary: '#4a5568',
    secondary: '#2d3748',
    glow: 'rgba(74, 85, 104, 0.5)',
  },
};

export const STAGE_LABELS: Record<string, string> = {
  welcome: 'Bienvenida',
  mirror: 'Espejo',
  shift: 'Transformación',
  arrive: 'Llegada',
  complete: 'Completado',
};

export const EMOTION_DISPLAY_NAMES: Record<string, string> = {
  anxiety: 'Ansiedad',
  sadness: 'Tristeza',
  anger: 'Ira',
  joy: 'Alegría',
  calm: 'Calma',
  fear: 'Miedo',
  hope: 'Esperanza',
  love: 'Amor',
  neutral: 'Neutral',
  frustration: 'Frustración',
};

export const STAGE_ORDER = ['welcome', 'mirror', 'shift', 'arrive', 'complete'] as const;

export const WS_URL =
  typeof window !== 'undefined'
    ? (process.env.NEXT_PUBLIC_WS_URL ?? 'ws://localhost:8080/ws')
    : 'ws://localhost:8080/ws';

export const SAMPLE_RATE_CAPTURE = 16000;
export const SAMPLE_RATE_PLAYBACK = 24000;

export const TRANSCRIPT_FADE_MS = 5000;
export const CROSSFADE_DURATION_MS = 3000;

export const DEFAULT_EMOTION = 'neutral';
export const DEFAULT_STAGE = 'welcome' as const;

// Turn-taking / barge-in parameters
export const BARGE_IN_RMS_THRESHOLD = 0.08; // Min RMS energy to count as speech (ambient ~0.01-0.03)
export const BARGE_IN_CONSECUTIVE_CHUNKS = 2; // Chunks above threshold before barge-in triggers (~512ms)
