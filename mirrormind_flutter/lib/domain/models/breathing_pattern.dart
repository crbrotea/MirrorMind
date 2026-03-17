/// A single phase within a breathing exercise (e.g. inhale for 4 seconds).
class BreathingPhase {
  final String action;
  final double duration;

  const BreathingPhase({
    required this.action,
    required this.duration,
  });

  /// Creates a [BreathingPhase] from a JSON map.
  factory BreathingPhase.fromJson(Map<String, dynamic> json) {
    return BreathingPhase(
      action: json['action'] as String,
      duration: (json['duration'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        'duration': duration,
      };
}

/// A complete breathing pattern composed of a technique, cycle count, and
/// ordered list of phases.
class BreathingPattern {
  final String technique;
  final int cycles;
  final List<BreathingPhase> phases;

  const BreathingPattern({
    required this.technique,
    required this.cycles,
    required this.phases,
  });

  /// Creates a [BreathingPattern] from a JSON map.
  factory BreathingPattern.fromJson(Map<String, dynamic> json) {
    return BreathingPattern(
      technique: json['technique'] as String,
      cycles: json['cycles'] as int,
      phases: (json['phases'] as List<dynamic>)
          .map((p) => BreathingPhase.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'technique': technique,
        'cycles': cycles,
        'phases': phases.map((p) => p.toJson()).toList(),
      };
}
