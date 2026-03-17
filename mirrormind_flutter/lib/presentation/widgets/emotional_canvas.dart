import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Full-screen canvas that crossfades between AI-generated emotion images.
///
/// Uses a two-layer approach where [AnimatedOpacity] crossfades between
/// front and back layers over [crossfadeDurationMs] milliseconds.
class EmotionalCanvas extends StatefulWidget {
  final Uint8List? currentImage;
  final Uint8List? previousImage;
  final String emotion;

  const EmotionalCanvas({
    super.key,
    this.currentImage,
    this.previousImage,
    required this.emotion,
  });

  @override
  State<EmotionalCanvas> createState() => _EmotionalCanvasState();
}

class _EmotionalCanvasState extends State<EmotionalCanvas> {
  /// When true, layer A is in front; when false, layer B is in front.
  bool _frontIsA = true;

  /// Image data for each layer.
  Uint8List? _layerAImage;
  Uint8List? _layerBImage;

  @override
  void initState() {
    super.initState();
    _layerAImage = widget.currentImage;
  }

  @override
  void didUpdateWidget(covariant EmotionalCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentImage != oldWidget.currentImage &&
        widget.currentImage != null) {
      setState(() {
        if (_frontIsA) {
          // A is currently visible; load new image into B and bring B forward.
          _layerBImage = widget.currentImage;
        } else {
          // B is currently visible; load new image into A and bring A forward.
          _layerAImage = widget.currentImage;
        }
        _frontIsA = !_frontIsA;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        emotionColors[widget.emotion] ?? emotionColors['neutral']!;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base background color.
        Container(color: backgroundColor),

        // Back layer (behind the crossfade).
        _buildImageLayer(
          image: _frontIsA ? _layerBImage : _layerAImage,
          opacity: 1.0,
          emotionColors: colors,
        ),

        // Front layer with animated opacity for crossfade.
        AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: crossfadeDurationMs),
          child: _buildImageLayer(
            image: _frontIsA ? _layerAImage : _layerBImage,
            opacity: 1.0,
            emotionColors: colors,
          ),
        ),

        // Top gradient overlay: black/50 to transparent going downward.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Bottom gradient overlay: black/80 to transparent going upward.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Emotion-tinted vignette.
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: colors.glow,
                  blurRadius: 120,
                  spreadRadius: 40,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a single image layer or a placeholder gradient when no image data
  /// is available.
  Widget _buildImageLayer({
    required Uint8List? image,
    required double opacity,
    required EmotionColor emotionColors,
  }) {
    if (image != null) {
      return Opacity(
        opacity: opacity,
        child: Image.memory(
          image,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        ),
      );
    }

    // Placeholder: radial gradient using emotion colors.
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            emotionColors.primary.withValues(alpha: 0.3),
            emotionColors.secondary.withValues(alpha: 0.1),
            backgroundColor,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
