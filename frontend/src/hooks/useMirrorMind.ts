'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { MirrorWebSocket } from '@/lib/websocket';
import { base64ToArrayBuffer } from '@/lib/audio-utils';
import { WS_URL, DEFAULT_EMOTION, DEFAULT_STAGE } from '@/lib/constants';
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
};

export function useMirrorMind() {
  const [state, setState] = useState<MirrorState>(INITIAL_STATE);
  const wsRef = useRef<MirrorWebSocket | null>(null);

  const { playChunk, stop: stopPlayback } = useAudioPlayback();

  const handleAudioChunk = useCallback(
    (chunk: ArrayBuffer) => {
      const ws = wsRef.current;
      if (ws && ws.isConnected) {
        ws.sendBinary(chunk);
      }
    },
    []
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
        case 'image':
          setState((prev) => ({
            ...prev,
            previousImageUrl: prev.imageUrl,
            imageUrl: msg.type === 'image' ? msg.data : prev.imageUrl,
            emotion: msg.type === 'image' ? msg.emotion : prev.emotion,
            stage: (msg.type === 'image' ? msg.stage : prev.stage) as MirrorState['stage'],
          }));
          break;

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

        case 'error':
          console.error('[MirrorMind] Server error:', msg.message);
          break;
      }
    },
    [playChunk]
  );

  const handleBinaryMessage = useCallback(
    (data: ArrayBuffer) => {
      playChunk(data);
    },
    [playChunk]
  );

  const connect = useCallback(() => {
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
    ws.connect(WS_URL);
  }, [handleTextMessage, handleBinaryMessage]);

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
