import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/models/gallery_entry.dart';

/// A card displaying a gallery entry thumbnail with emotion and date metadata.
///
/// Shows either the thumbnail image or a gradient placeholder, plus overlay
/// information at the bottom and emotion journey dots at the top-right.
class GalleryCard extends StatelessWidget {
  final GalleryEntry entry;
  final VoidCallback onTap;

  const GalleryCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final emotionColor =
        emotionColors[entry.finalEmotion] ?? emotionColors['neutral']!;
    final emotionName =
        emotionDisplayNames[entry.finalEmotion] ?? entry.finalEmotion;

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background: image or gradient placeholder.
                _buildBackground(emotionColor),

                // Bottom overlay gradient.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom info: emotion dot + label, date.
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: emotionColor.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            emotionName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.date,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Top-right: emotion journey dots (up to 5).
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: entry.emotions.take(5).map((e) {
                      final color =
                          emotionColors[e]?.primary ?? emotionColors['neutral']!.primary;
                      return Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(left: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(EmotionColor colors) {
    if (entry.thumbnailUrl != null && entry.thumbnailUrl!.isNotEmpty) {
      // Handle base64 data URIs.
      if (entry.thumbnailUrl!.startsWith('data:')) {
        try {
          final base64String = entry.thumbnailUrl!.split(',').last;
          final bytes = base64Decode(base64String);
          return Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        } catch (_) {
          return _buildGradientPlaceholder(colors);
        }
      }
      // Network image.
      return Image.network(
        entry.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, e, st) => _buildGradientPlaceholder(colors),
      );
    }

    return _buildGradientPlaceholder(colors);
  }

  Widget _buildGradientPlaceholder(EmotionColor colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.4),
            colors.secondary.withValues(alpha: 0.6),
          ],
        ),
      ),
    );
  }
}
