'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import type { BreathingPattern, BreathingSyncReturn } from '@/types';

export function useBreathingSync(pattern: BreathingPattern | null): BreathingSyncReturn {
  const [currentPhase, setCurrentPhase] = useState(0);
  const [progress, setProgress] = useState(0);
  const [isActive, setIsActive] = useState(false);
  const [phaseName, setPhaseName] = useState('');

  const animFrameRef = useRef<number>(0);
  const startTimeRef = useRef(0);
  const cycleRef = useRef(0);

  const stop = useCallback(() => {
    if (animFrameRef.current) {
      cancelAnimationFrame(animFrameRef.current);
      animFrameRef.current = 0;
    }
    setIsActive(false);
    setProgress(0);
    setCurrentPhase(0);
    setPhaseName('');
    cycleRef.current = 0;
  }, []);

  useEffect(() => {
    if (!pattern || pattern.phases.length === 0) {
      stop();
      return;
    }

    const phases = pattern.phases;
    const totalCycleDuration = phases.reduce((sum, p) => sum + p.duration, 0) * 1000;
    const totalDuration = totalCycleDuration * pattern.cycles;

    startTimeRef.current = performance.now();
    cycleRef.current = 0;
    setIsActive(true);

    const tick = (now: number) => {
      const elapsed = now - startTimeRef.current;

      if (elapsed >= totalDuration) {
        stop();
        return;
      }

      const cycleElapsed = elapsed % totalCycleDuration;
      const currentCycle = Math.floor(elapsed / totalCycleDuration);
      cycleRef.current = currentCycle;

      let accumulated = 0;
      for (let i = 0; i < phases.length; i++) {
        const phaseDurationMs = phases[i].duration * 1000;
        if (cycleElapsed < accumulated + phaseDurationMs) {
          setCurrentPhase(i);
          setPhaseName(phases[i].action);
          setProgress((cycleElapsed - accumulated) / phaseDurationMs);
          break;
        }
        accumulated += phaseDurationMs;
      }

      animFrameRef.current = requestAnimationFrame(tick);
    };

    animFrameRef.current = requestAnimationFrame(tick);

    return () => {
      if (animFrameRef.current) {
        cancelAnimationFrame(animFrameRef.current);
      }
    };
  }, [pattern, stop]);

  return { currentPhase, progress, isActive, phaseName };
}
