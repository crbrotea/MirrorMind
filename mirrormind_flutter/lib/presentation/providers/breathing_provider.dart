import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/breathing_pattern.dart';

/// UI state for the breathing guide animation.
class BreathingState {
  final int currentPhase;
  final double progress;
  final bool isActive;
  final String phaseName;

  const BreathingState({
    this.currentPhase = 0,
    this.progress = 0.0,
    this.isActive = false,
    this.phaseName = '',
  });

  BreathingState copyWith({
    int? currentPhase,
    double? progress,
    bool? isActive,
    String? phaseName,
  }) {
    return BreathingState(
      currentPhase: currentPhase ?? this.currentPhase,
      progress: progress ?? this.progress,
      isActive: isActive ?? this.isActive,
      phaseName: phaseName ?? this.phaseName,
    );
  }
}

/// Riverpod provider keyed by an optional [BreathingPattern].
///
/// When the pattern is non-null the notifier auto-starts the breathing
/// animation cycle. When null, the state remains inactive.
final breathingProvider = StateNotifierProvider.family<BreathingNotifier,
    BreathingState, BreathingPattern?>(
  (ref, pattern) => BreathingNotifier(pattern),
);

/// Drives the breathing guide animation by ticking at ~60 fps and mapping
/// elapsed time onto the current phase and progress within that phase.
class BreathingNotifier extends StateNotifier<BreathingState> {
  BreathingNotifier(this._pattern) : super(const BreathingState()) {
    if (_pattern != null && _pattern.phases.isNotEmpty) {
      start();
    }
  }

  final BreathingPattern? _pattern;
  Timer? _timer;
  DateTime? _startTime;

  /// Begins (or restarts) the breathing animation cycle.
  void start() {
    if (_pattern == null || _pattern.phases.isEmpty) return;

    _startTime = DateTime.now();
    state = state.copyWith(
      isActive: true,
      currentPhase: 0,
      progress: 0.0,
      phaseName: _pattern.phases.first.action,
    );

    // Tick at roughly 60 fps for smooth progress updates.
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  /// Stops the breathing animation and resets state.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _startTime = null;
    state = const BreathingState();
  }

  void _tick() {
    final pattern = _pattern;
    if (pattern == null || pattern.phases.isEmpty || _startTime == null) return;

    // Total duration of one cycle in seconds.
    final cycleDuration = pattern.phases.fold<double>(
      0.0,
      (sum, phase) => sum + phase.duration,
    );
    if (cycleDuration <= 0) return;

    final elapsed =
        DateTime.now().difference(_startTime!).inMilliseconds / 1000.0;

    final totalDuration = cycleDuration * pattern.cycles;

    // Stop when all cycles are complete.
    if (elapsed >= totalDuration) {
      stop();
      return;
    }

    // Position within the current cycle.
    final cycleElapsed = elapsed % cycleDuration;

    // Determine which phase we are in.
    double accumulated = 0.0;
    int phaseIndex = 0;
    for (int i = 0; i < pattern.phases.length; i++) {
      final phaseDuration = pattern.phases[i].duration;
      if (cycleElapsed < accumulated + phaseDuration) {
        phaseIndex = i;
        break;
      }
      accumulated += phaseDuration;
    }

    final currentPhaseDuration = pattern.phases[phaseIndex].duration;
    final phaseElapsed = cycleElapsed - accumulated;
    final progress =
        currentPhaseDuration > 0 ? (phaseElapsed / currentPhaseDuration) : 0.0;

    state = BreathingState(
      currentPhase: phaseIndex,
      progress: progress.clamp(0.0, 1.0),
      isActive: true,
      phaseName: pattern.phases[phaseIndex].action,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
