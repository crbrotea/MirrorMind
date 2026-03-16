'use client';

import { useCallback, useRef, useState } from 'react';
import { SAMPLE_RATE_PLAYBACK } from '@/lib/constants';
import { int16ToFloat32 } from '@/lib/audio-utils';
import type { AudioPlaybackReturn } from '@/types';

export function useAudioPlayback(): AudioPlaybackReturn {
  const [isPlaying, setIsPlaying] = useState(false);
  const audioContextRef = useRef<AudioContext | null>(null);
  const queueRef = useRef<AudioBuffer[]>([]);
  const nextStartTimeRef = useRef(0);
  const activeSourcesRef = useRef<Set<AudioBufferSourceNode>>(new Set());

  const getContext = useCallback((): AudioContext => {
    if (!audioContextRef.current || audioContextRef.current.state === 'closed') {
      audioContextRef.current = new AudioContext({ sampleRate: SAMPLE_RATE_PLAYBACK });
    }
    return audioContextRef.current;
  }, []);

  const scheduleBuffer = useCallback(
    (audioBuffer: AudioBuffer) => {
      const ctx = getContext();
      const source = ctx.createBufferSource();
      source.buffer = audioBuffer;
      source.connect(ctx.destination);

      activeSourcesRef.current.add(source);
      source.onended = () => {
        activeSourcesRef.current.delete(source);
        if (activeSourcesRef.current.size === 0 && queueRef.current.length === 0) {
          setIsPlaying(false);
        }
      };

      const now = ctx.currentTime;
      const startTime = Math.max(now, nextStartTimeRef.current);
      source.start(startTime);
      nextStartTimeRef.current = startTime + audioBuffer.duration;
      setIsPlaying(true);
    },
    [getContext]
  );

  const playChunk = useCallback(
    (chunk: ArrayBuffer) => {
      const ctx = getContext();

      // Resume context if suspended (autoplay policy)
      if (ctx.state === 'suspended') {
        void ctx.resume();
      }

      const int16 = new Int16Array(chunk);
      const float32 = int16ToFloat32(int16);

      const audioBuffer = ctx.createBuffer(1, float32.length, SAMPLE_RATE_PLAYBACK);
      audioBuffer.getChannelData(0).set(float32);

      queueRef.current.push(audioBuffer);

      // Schedule all queued buffers
      while (queueRef.current.length > 0) {
        const buf = queueRef.current.shift()!;
        scheduleBuffer(buf);
      }
    },
    [getContext, scheduleBuffer]
  );

  const stop = useCallback(() => {
    queueRef.current = [];
    activeSourcesRef.current.forEach((source) => {
      try {
        source.stop();
      } catch {
        // Already stopped
      }
    });
    activeSourcesRef.current.clear();
    nextStartTimeRef.current = 0;
    setIsPlaying(false);
  }, []);

  return { playChunk, stop, isPlaying };
}
