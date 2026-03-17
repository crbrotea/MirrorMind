import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/models/session_stage.dart';

/// Displays the current emotion and session stage as floating badges.
///
/// Positioned at the top-left of the session screen, showing a colored
/// emotion pill badge and a stage label badge underneath.
class EmotionIndicator extends StatelessWidget {
  final String emotion;
  final SessionStage stage;

  const EmotionIndicator({
    super.key,
    required this.emotion,
    required this.stage,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        emotionColors[emotion] ?? emotionColors['neutral']!;
    final displayName = emotionDisplayNames[emotion] ?? emotion;
    final stageLabel = stageLabels[stage.name] ?? stage.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Emotion badge.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.glow,
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing dot.
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Stage badge.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            stageLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
