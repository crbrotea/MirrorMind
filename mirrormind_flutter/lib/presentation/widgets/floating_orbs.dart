import 'dart:math';

import 'package:flutter/material.dart';

/// Animated floating orbs used as a subtle background decoration on the home
/// screen.
///
/// Renders several semi-transparent radial gradient circles that drift slowly
/// using sine-wave motion over a long animation loop.
class FloatingOrbs extends StatefulWidget {
  const FloatingOrbs({super.key});

  @override
  State<FloatingOrbs> createState() => _FloatingOrbsState();
}

class _FloatingOrbsState extends State<FloatingOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static final List<_OrbData> _orbs = [
    _OrbData(
      baseX: 0.2,
      baseY: 0.15,
      radius: 100,
      color: Colors.white.withValues(alpha: 0.04),
      phaseX: 0.0,
      phaseY: 0.5,
      speedX: 0.7,
      speedY: 0.5,
    ),
    _OrbData(
      baseX: 0.75,
      baseY: 0.25,
      radius: 80,
      color: const Color(0xFF4A7C59).withValues(alpha: 0.05),
      phaseX: 1.0,
      phaseY: 2.0,
      speedX: 0.5,
      speedY: 0.8,
    ),
    _OrbData(
      baseX: 0.5,
      baseY: 0.6,
      radius: 120,
      color: const Color(0xFF2C3E6B).withValues(alpha: 0.04),
      phaseX: 2.0,
      phaseY: 0.0,
      speedX: 0.3,
      speedY: 0.6,
    ),
    _OrbData(
      baseX: 0.15,
      baseY: 0.75,
      radius: 60,
      color: const Color(0xFFD4A017).withValues(alpha: 0.03),
      phaseX: 3.0,
      phaseY: 1.5,
      speedX: 0.6,
      speedY: 0.4,
    ),
    _OrbData(
      baseX: 0.85,
      baseY: 0.7,
      radius: 90,
      color: const Color(0xFF4A2D6B).withValues(alpha: 0.05),
      phaseX: 0.5,
      phaseY: 3.0,
      speedX: 0.4,
      speedY: 0.7,
    ),
    _OrbData(
      baseX: 0.45,
      baseY: 0.3,
      radius: 40,
      color: Colors.white.withValues(alpha: 0.06),
      phaseX: 1.5,
      phaseY: 2.5,
      speedX: 0.8,
      speedY: 0.3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 * pi;
        return CustomPaint(
          size: Size.infinite,
          painter: _OrbsPainter(orbs: _orbs, time: t),
        );
      },
    );
  }
}

/// Data describing a single floating orb.
class _OrbData {
  final double baseX;
  final double baseY;
  final double radius;
  final Color color;
  final double phaseX;
  final double phaseY;
  final double speedX;
  final double speedY;

  const _OrbData({
    required this.baseX,
    required this.baseY,
    required this.radius,
    required this.color,
    required this.phaseX,
    required this.phaseY,
    required this.speedX,
    required this.speedY,
  });
}

class _OrbsPainter extends CustomPainter {
  final List<_OrbData> orbs;
  final double time;

  _OrbsPainter({required this.orbs, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in orbs) {
      final dx = sin(time * orb.speedX + orb.phaseX) * 30;
      final dy = sin(time * orb.speedY + orb.phaseY) * 30;

      final center = Offset(
        orb.baseX * size.width + dx,
        orb.baseY * size.height + dy,
      );

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [orb.color, orb.color.withValues(alpha: 0.0)],
        ).createShader(
          Rect.fromCircle(center: center, radius: orb.radius),
        );

      canvas.drawCircle(center, orb.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbsPainter oldDelegate) =>
      oldDelegate.time != time;
}
