'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { MirrorWebSocket } from '@/lib/websocket';
import { base64ToArrayBuffer } from '@/lib/audio-utils';
import {
  WS_URL,
  DEFAULT_EMOTION,
  DEFAULT_STAGE,
  BARGE_IN_RMS_THRESHOLD,
  BARGE_IN_CONSECUTIVE_CHUNKS,
} from '@/lib/constants';
import { useAudioCapture } from './useAudioCapture';
import { useAudioPlayback } from './useAudioPlayback';
import type { MirrorState, WSMessageFromServer } from '@/types';

const INITIAL_STATE: MirrorState = {
  emotion: DEFAULT_EMOTION,
  stage: DEFAULT_STAGE,
  imageUrl: null,
  previousImageUrl: null,
  transcript: '',
  agentTranscript: '',
  isConnected: false,
  isListening: false,
  breathingPattern: null,
  valence: 0,
  arousal: 0,
  agentSpeaking: false,
};

export function useMirrorMind(userId: string, getToken: () => Promise<string | null>) {
  const [state, setState] = useState<MirrorState>(INITIAL_STATE);
  const wsRef = useRef<MirrorWebSocket | null>(null);

  // Turn-taking state (ref for synchronous access in audio callbacks)
  const agentSpeakingRef = useRef(false);
  const bargeInCountRef = useRef(0);

  const handlePlaybackStateChange = useCallback((playing: boolean) => {
    if (!playing) {
      // Agent finished speaking — re-open mic upstream
      agentSpeakingRef.current = false;
      bargeInCountRef.current = 0;
      setState((prev) => ({ ...prev, agentSpeaking: false }));
    }
  }, []);

  const { playChunk, stop: stopPlayback } = useAudioPlayback({
    onPlaybackStateChange: handlePlaybackStateChange,
  });

  const handleAudioChunk = useCallback(
    (chunk: ArrayBuffer, rmsEnergy: number) => {
      const ws = wsRef.current;
      if (!ws || !ws.isConnected) return;

      if (agentSpeakingRef.current) {
        // Agent is speaking — check for intentional barge-in
        if (rmsEnergy > BARGE_IN_RMS_THRESHOLD) {
          bargeInCountRef.current++;
          if (bargeInCountRef.current >= BARGE_IN_CONSECUTIVE_CHUNKS) {
            // Barge-in confirmed: stop agent, resume mic
            agentSpeakingRef.current = false;
            bargeInCountRef.current = 0;
            setState((prev) => ({ ...prev, agentSpeaking: false }));
            stopPlayback();
            ws.sendJSON({ type: 'barge_in' });
            ws.sendBinary(chunk); // Forward this chunk immediately
          }
        } else {
          bargeInCountRef.current = 0;
        }
        // Do NOT forward audio while agent speaks (prevents echo interruption)
        return;
      }

      // Normal user turn — forward to server
      ws.sendBinary(chunk);
    },
    [stopPlayback]
  );

  const { startCapture, stopCapture, isCapturing, error: captureError } = useAudioCapture({
    onChunk: handleAudioChunk,
  });

  // Keep isListening in sync with capture state
  useEffect(() => {
    setState((prev) => ({ ...prev, isListening: isCapturing }));
  }, [isCapturing]);

  const handleTextMessage = useCallback(
    (raw: string) => {
      let msg: WSMessageFromServer;
      try {
        msg = JSON.parse(raw) as WSMessageFromServer;
      } catch {
        console.error('[MirrorMind] Invalid JSON from server:', raw);
        return;
      }

      switch (msg.type) {
        case 'image': {
          const dataUri = `data:image/png;base64,${msg.data}`;
          setState((prev) => ({
            ...prev,
            previousImageUrl: prev.imageUrl,
            imageUrl: dataUri,
            emotion: msg.emotion,
            stage: msg.stage as MirrorState['stage'],
          }));
          break;
        }

        case 'transcript':
          if (msg.author === 'user') {
            setState((prev) => ({ ...prev, transcript: msg.text }));
          } else {
            setState((prev) => ({ ...prev, agentTranscript: msg.text }));
          }
          break;

        case 'emotion_update':
          setState((prev) => ({
            ...prev,
            emotion: msg.emotion,
            valence: msg.valence,
            arousal: msg.arousal,
          }));
          break;

        case 'breathing_pattern':
          setState((prev) => ({ ...prev, breathingPattern: msg.pattern }));
          break;

        case 'stage_change':
          setState((prev) => ({
            ...prev,
            stage: msg.stage as MirrorState['stage'],
          }));
          break;

        case 'session_complete':
          setState((prev) => ({ ...prev, stage: 'complete' }));
          break;

        case 'audio': {
          const audioData = base64ToArrayBuffer(msg.data);
          playChunk(audioData);
          break;
        }

        case 'turn_state':
          agentSpeakingRef.current = msg.speaking;
          if (msg.speaking) {
            bargeInCountRef.current = 0;
          }
          setState((prev) => ({ ...prev, agentSpeaking: msg.speaking }));
          break;

        case 'error':
          console.error('[MirrorMind] Server error:', msg.message);
          break;
      }
    },
    [playChunk]
  );

  const handleBinaryMessage = useCallback(
    (data: ArrayBuffer) => {
      // Receiving agent audio — mark agent as speaking (fallback if
      // the turn_state JSON hasn't arrived yet)
      if (!agentSpeakingRef.current) {
        agentSpeakingRef.current = true;
        bargeInCountRef.current = 0;
        setState((prev) => ({ ...prev, agentSpeaking: true }));
      }
      playChunk(data);
    },
    [playChunk]
  );

  const connect = useCallback(async () => {
    if (wsRef.current) {
      wsRef.current.disconnect();
    }

    const ws = new MirrorWebSocket({
      onTextMessage: handleTextMessage,
      onBinaryMessage: handleBinaryMessage,
      onStateChange: (connectionState) => {
        setState((prev) => ({
          ...prev,
          isConnected: connectionState === 'connected',
        }));
      },
    });

    wsRef.current = ws;
    const token = await getToken();
    ws.connect(`${WS_URL}/${userId}?token=${encodeURIComponent(token ?? '')}`);
  }, [handleTextMessage, handleBinaryMessage, userId, getToken]);

  const disconnect = useCallback(() => {
    stopCapture();
    stopPlayback();
    if (wsRef.current) {
      wsRef.current.disconnect();
      wsRef.current = null;
    }
    setState(INITIAL_STATE);
  }, [stopCapture, stopPlayback]);

  const startListening = useCallback(async () => {
    await startCapture();
  }, [startCapture]);

  const stopListening = useCallback(() => {
    stopCapture();
  }, [stopCapture]);

  const sendDesiredEmotion = useCallback((emotion: string) => {
    wsRef.current?.sendJSON({ type: 'desired_emotion', emotion });
  }, []);

  const endSession = useCallback(() => {
    wsRef.current?.sendJSON({ type: 'end_session' });
    stopCapture();
    stopPlayback();
  }, [stopCapture, stopPlayback]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      wsRef.current?.disconnect();
    };
  }, []);

  return {
    state,
    captureError,
    connect,
    disconnect,
    startListening,
    stopListening,
    sendDesiredEmotion,
    endSession,
  };
}
