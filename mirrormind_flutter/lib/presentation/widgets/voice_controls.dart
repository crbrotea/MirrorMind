import 'package:flutter/material.dart';

import 'waveform_painter.dart';

/// Voice input controls displayed at the bottom of the session screen.
///
/// Shows a microphone FAB with pulse animation when listening, a waveform
/// visualizer, error display, and connection status text.
class VoiceControls extends StatefulWidget {
  final bool isListening;
  final bool isConnected;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final String? error;

  const VoiceControls({
    super.key,
    required this.isListening,
    required this.isConnected,
    required this.onStart,
    required this.onStop,
    this.error,
  });

  @override
  State<VoiceControls> createState() => _VoiceControlsState();
}

class _VoiceControlsState extends State<VoiceControls>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant VoiceControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isListening && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isConnected) return;
    if (widget.isListening) {
      widget.onStop();
    } else {
      widget.onStart();
    }
  }

  String get _statusText {
    if (!widget.isConnected) return 'Conectando...';
    if (widget.isListening) return 'Escuchando...';
    return 'Toca para hablar';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Waveform visualizer.
        WaveformWidget(isListening: widget.isListening),
        const SizedBox(height: 16),

        // Mic FAB with pulse rings.
        SizedBox(
          width: 100,
          height: 100,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulse ring.
                if (widget.isListening)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withValues(
                              alpha: 0.15 * (1.4 - _pulseAnimation.value),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // Inner pulse ring.
                if (widget.isListening)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final innerScale =
                          1.0 + (_pulseAnimation.value - 1.0) * 0.6;
                      return Transform.scale(
                        scale: innerScale,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withValues(
                              alpha: 0.1 * (1.4 - _pulseAnimation.value),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // Main button.
                GestureDetector(
                  onTap: _handleTap,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _buttonColor,
                    ),
                    child: Icon(
                      widget.isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Error text.
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.error!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // Status text.
        Text(
          _statusText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Color get _buttonColor {
    if (widget.isListening) return Colors.red;
    if (widget.isConnected) return Colors.white.withValues(alpha: 0.1);
    return Colors.white.withValues(alpha: 0.05);
  }
}
