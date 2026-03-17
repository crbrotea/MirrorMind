import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/models/breathing_pattern.dart';

/// Centered breathing guide overlay that animates a circle through inhale,
/// hold, exhale, and rest phases based on a [BreathingPattern].
///
/// Ignores pointer events so users can interact with elements underneath.
class BreathingGuide extends StatefulWidget {
  final BreathingPattern? pattern;

  const BreathingGuide({super.key, this.pattern});

  @override
  State<BreathingGuide> createState() => _BreathingGuideState();
}

class _BreathingGuideState extends State<BreathingGuide> {
  /// Index of the current phase within the pattern's phase list.
  int _phaseIndex = 0;

  /// How many full cycles have been completed.
  int _completedCycles = 0;

  /// Progress through the current phase, from 0.0 to 1.0.
  double _progress = 0.0;

  /// Whether the breathing exercise is actively running.
  bool _active = false;

  Timer? _ticker;

  static const _tickIntervalMs = 50;

  @override
  void initState() {
    super.initState();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant BreathingGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pattern != oldWidget.pattern) {
      _stop();
      _startIfNeeded();
    }
  }

  void _startIfNeeded() {
    if (widget.pattern != null && widget.pattern!.phases.isNotEmpty) {
      _phaseIndex = 0;
      _completedCycles = 0;
      _progress = 0.0;
      _active = true;
      _ticker = Timer.periodic(
        const Duration(milliseconds: _tickIntervalMs),
        _onTick,
      );
    }
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    _active = false;
  }

  void _onTick(Timer timer) {
    final pattern = widget.pattern;
    if (pattern == null || pattern.phases.isEmpty) {
      _stop();
      return;
    }

    final phase = pattern.phases[_phaseIndex];
    final phaseDurationMs = (phase.duration * 1000).toInt();
    final increment = _tickIntervalMs / phaseDurationMs;

    setState(() {
      _progress += increment;
      if (_progress >= 1.0) {
        _progress = 0.0;
        _phaseIndex++;
        if (_phaseIndex >= pattern.phases.length) {
          _phaseIndex = 0;
          _completedCycles++;
          if (_completedCycles >= pattern.cycles) {
            _stop();
            return;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  double get _scale {
    if (!_active || widget.pattern == null || widget.pattern!.phases.isEmpty) {
      return 0.6;
    }
    final action = widget.pattern!.phases[_phaseIndex].action;
    switch (action) {
      case 'inhale':
        return 0.6 + _progress * 0.6;
      case 'exhale':
        return 1.2 - _progress * 0.6;
      case 'hold':
        return 1.2;
      case 'rest':
        return 0.6;
      default:
        return 0.6;
    }
  }

  String get _phaseLabel {
    if (!_active || widget.pattern == null || widget.pattern!.phases.isEmpty) {
      return '';
    }
    final action = widget.pattern!.phases[_phaseIndex].action;
    return phaseLabels[action] ?? action;
  }

  @override
  Widget build(BuildContext context) {
    if (!_active || widget.pattern == null) {
      return const SizedBox.shrink();
    }

    final technique = techniqueLabel(widget.pattern!.technique);

    return IgnorePointer(
      child: Center(
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow circle.
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),

                // Main circle.
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _phaseLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        technique,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Inner ring.
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
