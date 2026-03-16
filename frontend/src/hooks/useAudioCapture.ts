'use client';

import { useCallback, useRef, useState } from 'react';
import { SAMPLE_RATE_CAPTURE } from '@/lib/constants';
import type { AudioCaptureReturn } from '@/types';

interface UseAudioCaptureOptions {
  onChunk: (chunk: ArrayBuffer) => void;
}

export function useAudioCapture({ onChunk }: UseAudioCaptureOptions): AudioCaptureReturn {
  const [isCapturing, setIsCapturing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const audioContextRef = useRef<AudioContext | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const workletNodeRef = useRef<AudioWorkletNode | null>(null);
  const sourceRef = useRef<MediaStreamAudioSourceNode | null>(null);
  const onChunkRef = useRef(onChunk);
  onChunkRef.current = onChunk;

  const startCapture = useCallback(async () => {
    try {
      setError(null);

      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          sampleRate: SAMPLE_RATE_CAPTURE,
          channelCount: 1,
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        },
      });
      streamRef.current = stream;

      const audioContext = new AudioContext({ sampleRate: SAMPLE_RATE_CAPTURE });
      audioContextRef.current = audioContext;

      await audioContext.audioWorklet.addModule('/audio-worklet-processor.js');

      const source = audioContext.createMediaStreamSource(stream);
      sourceRef.current = source;

      const workletNode = new AudioWorkletNode(audioContext, 'pcm-capture-processor');
      workletNodeRef.current = workletNode;

      workletNode.port.onmessage = (event: MessageEvent) => {
        if (event.data.type === 'pcm-chunk') {
          onChunkRef.current(event.data.samples as ArrayBuffer);
        }
      };

      source.connect(workletNode);
      workletNode.connect(audioContext.destination);

      setIsCapturing(true);
    } catch (err) {
      const message =
        err instanceof DOMException && err.name === 'NotAllowedError'
          ? 'Permiso de microfono denegado. Activa el microfono en la configuracion del navegador.'
          : 'No se pudo acceder al microfono. Verifica que tu dispositivo tenga uno disponible.';
      setError(message);
      setIsCapturing(false);
    }
  }, []);

  const stopCapture = useCallback(() => {
    if (workletNodeRef.current) {
      workletNodeRef.current.disconnect();
      workletNodeRef.current.port.close();
      workletNodeRef.current = null;
    }

    if (sourceRef.current) {
      sourceRef.current.disconnect();
      sourceRef.current = null;
    }

    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    }

    if (audioContextRef.current) {
      void audioContextRef.current.close();
      audioContextRef.current = null;
    }

    setIsCapturing(false);
  }, []);

  return { startCapture, stopCapture, isCapturing, error };
}
