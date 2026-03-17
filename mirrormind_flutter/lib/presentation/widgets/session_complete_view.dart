import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Full-screen overlay displayed when a session has been completed.
///
/// Shows a confirmation message with options to view the gallery or return
/// to the home screen. Fades in via [AnimatedOpacity].
class SessionCompleteView extends StatefulWidget {
  final String? galleryId;
  final String emotion;
  final VoidCallback onGoHome;
  final VoidCallback onGoGallery;

  const SessionCompleteView({
    super.key,
    this.galleryId,
    required this.emotion,
    required this.onGoHome,
    required this.onGoGallery,
  });

  @override
  State<SessionCompleteView> createState() => _SessionCompleteViewState();
}

class _SessionCompleteViewState extends State<SessionCompleteView> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    // Trigger the fade-in after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        emotionColors[widget.emotion] ?? emotionColors['neutral']!;

    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 600),
      child: Container(
        color: Colors.black.withValues(alpha: 0.9),
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Checkmark icon in circle.
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: 0.2),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check,
                    color: colors.primary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),

                // Title.
                const Text(
                  'Sesion completada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle.
                Text(
                  'Tu viaje emocional ha sido guardado',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Gallery button.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onGoGallery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Ver galeria',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Home button.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onGoHome,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Volver al inicio',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
