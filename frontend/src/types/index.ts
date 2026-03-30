export interface MirrorState {
  emotion: string;
  stage: 'welcome' | 'mirror' | 'shift' | 'arrive' | 'complete';
  imageUrl: string | null;
  previousImageUrl: string | null;
  transcript: string;
  agentTranscript: string;
  isConnected: boolean;
  isListening: boolean;
  breathingPattern: BreathingPattern | null;
  valence: number;
  arousal: number;
  agentSpeaking: boolean;
}

export type WSMessageFromServer =
  | { type: 'image'; data: string; emotion: string; stage: string }
  | { type: 'transcript'; text: string; author: 'user' | 'agent' }
  | { type: 'emotion_update'; emotion: string; valence: number; arousal: number }
  | { type: 'breathing_pattern'; pattern: BreathingPattern }
  | { type: 'stage_change'; stage: string }
  | { type: 'session_complete'; gallery_id: string }
  | { type: 'audio'; data: string }
  | { type: 'turn_state'; speaking: boolean }
  | { type: 'error'; message: string };

export type WSMessageToServer =
  | { type: 'text'; text: string }
  | { type: 'desired_emotion'; emotion: string }
  | { type: 'end_session' }
  | { type: 'barge_in' };

export interface BreathingPattern {
  technique: 'box' | 'calm' | 'sigh';
  phases: { action: string; duration: number }[];
  cycles: number;
  totalSeconds: number;
}

export interface GalleryEntry {
  sessionId: string;
  date: string;
  emotions: string[];
  finalEmotion: string;
  finalImageUrl: string;
  thumbnailUrl: string;
}

export interface EmotionColors {
  [key: string]: { primary: string; secondary: string; glow: string };
}

export interface AudioCaptureReturn {
  startCapture: () => Promise<void>;
  stopCapture: () => void;
  isCapturing: boolean;
  error: string | null;
}

export interface AudioPlaybackReturn {
  playChunk: (chunk: ArrayBuffer) => void;
  stop: () => void;
  isPlaying: boolean;
}

export interface BreathingSyncReturn {
  currentPhase: number;
  progress: number;
  isActive: boolean;
  phaseName: string;
}

export interface WebSocketClient {
  connect: (url: string) => void;
  disconnect: () => void;
  sendBinary: (data: ArrayBuffer) => void;
  sendJSON: (data: WSMessageToServer) => void;
  isConnected: boolean;
}

export interface AdminUser {
  id: string;
  email: string;
  first_name: string | null;
  last_name: string | null;
  image_url: string | null;
  points: number;
  role: string;
  created_at: number;
  last_sign_in_at: number | null;
}

export interface UserPoints {
  points: number;
  user_id: string;
}
