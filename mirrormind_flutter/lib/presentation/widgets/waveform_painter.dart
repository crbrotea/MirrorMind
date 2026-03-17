import 'dart:math';

import 'package:flutter/material.dart';

/// Animated waveform visualization displayed while the microphone is active.
///
/// Renders 40 vertical bars whose heights are modulated by overlapping sine
/// waves plus a small random component, producing an organic, audio-like
/// waveform effect.
class WaveformWidget extends StatefulWidget {
  final bool isListening;

  const WaveformWidget({super.key, required this.isListening});

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.isListening ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        width: 240,
        height: 48,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: WaveformPainter(phase: _controller.value * 2 * pi),
            );
          },
        ),
      ),
    );
  }
}

/// Alias for [AnimatedBuilder] to keep the code concise.
/// Flutter's built-in [AnimatedBuilder] is used directly above.

/// Custom painter that draws 40 vertical bars with sine-wave modulation.
class WaveformPainter extends CustomPainter {
  final double phase;
  static final Random _random = Random();

  WaveformPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 40;
    final double barWidth = size.width / barCount;
    final double maxBarHeight = size.height;

    for (int i = 0; i < barCount; i++) {
      // Composite amplitude from two sine waves + random noise.
      final double amplitude = sin(phase + i * 0.3) * 0.3 +
          sin(phase * 1.5 + i * 0.2) * 0.2 +
          _random.nextDouble() * 0.15;

      final double normalizedAmplitude = amplitude.abs().clamp(0.05, 1.0);
      final double barHeight = normalizedAmplitude * maxBarHeight;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3 + normalizedAmplitude * 0.5)
        ..style = PaintingStyle.fill;

      final double x = i * barWidth;
      final double y = (size.height - barHeight) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 1, y, barWidth - 2, barHeight),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}
