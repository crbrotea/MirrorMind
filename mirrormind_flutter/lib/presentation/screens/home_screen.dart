import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';

/// The dark, immersive landing screen for MirrorMind.
///
/// Displays the app title, subtitle, and navigation buttons to start a session
/// or browse the gallery. Animated floating orbs provide a calming background.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Background animated orbs.
          const Positioned.fill(child: FloatingOrbs()),

          // Foreground content.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // App title.
                  Text(
                    'MirrorMind',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w300,
                          letterSpacing: 2,
                        ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle.
                  Text(
                    'Tu espejo emocional',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                  ),

                  const Spacer(flex: 4),

                  // Begin session button.
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/session'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        side: const BorderSide(color: Colors.white),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Comenzar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gallery link.
                  TextButton(
                    onPressed: () => context.go('/gallery'),
                    child: Text(
                      'Ver galeria',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating orbs background animation
// ---------------------------------------------------------------------------

/// Data describing a single floating orb.
class _Orb {
  _Orb({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.dx,
    required this.dy,
  });

  double x;
  double y;
  final double radius;
  final Color color;
  final double dx;
  final double dy;
}

/// A full-screen widget that renders softly glowing, slowly drifting circles
/// to create an atmospheric background.
class FloatingOrbs extends StatefulWidget {
  const FloatingOrbs({super.key});

  @override
  State<FloatingOrbs> createState() => _FloatingOrbsState();
}

class _FloatingOrbsState extends State<FloatingOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Orb> _orbs = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(_tick);

    // Generate random orbs.
    const colors = [
      Color(0x264A5568),
      Color(0x262C3E6B),
      Color(0x264A7C59),
      Color(0x26D4A017),
      Color(0x264A2D6B),
    ];
    for (int i = 0; i < 6; i++) {
      _orbs.add(
        _Orb(
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          radius: 60 + _rng.nextDouble() * 100,
          color: colors[i % colors.length],
          dx: (_rng.nextDouble() - 0.5) * 0.0004,
          dy: (_rng.nextDouble() - 0.5) * 0.0004,
        ),
      );
    }
  }

  void _tick() {
    for (final orb in _orbs) {
      orb.x = (orb.x + orb.dx) % 1.0;
      orb.y = (orb.y + orb.dy) % 1.0;
      if (orb.x < 0) orb.x += 1.0;
      if (orb.y < 0) orb.y += 1.0;
    }
    // Trigger repaint.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_tick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OrbPainter(_orbs),
      size: Size.infinite,
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.orbs);

  final List<_Orb> orbs;

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in orbs) {
      final center = Offset(orb.x * size.width, orb.y * size.height);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [orb.color, orb.color.withValues(alpha: 0)],
        ).createShader(
          Rect.fromCircle(center: center, radius: orb.radius),
        );
      canvas.drawCircle(center, orb.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) => true;
}
