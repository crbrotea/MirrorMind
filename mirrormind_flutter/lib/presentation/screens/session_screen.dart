import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../domain/models/session_stage.dart';
import '../providers/breathing_provider.dart';
import '../providers/session_provider.dart';

/// Full-screen session screen that layers the emotional canvas, controls, and
/// overlays in a [Stack].
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off the WebSocket connection as soon as the screen mounts.
    Future.microtask(() {
      ref.read(sessionProvider.notifier).connect();
    });
  }

  @override
  void dispose() {
    // We intentionally do NOT call ref.read here because the element may
    // already be unmounted. Instead we schedule the disconnect for the next
    // microtask where the notifier is still alive.
    super.dispose();
  }

  void _disconnect() {
    ref.read(sessionProvider.notifier).disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionProvider);
    final breathingState = ref.watch(breathingProvider(state.breathingPattern));

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _disconnect();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            // Layer 1: Emotional canvas (generated images with crossfade).
            Positioned.fill(child: _EmotionalCanvas(state: state)),

            // Layer 2: Session header.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _SessionHeader(
                stage: state.stage,
                onClose: () {
                  _disconnect();
                  context.go('/');
                },
              ),
            ),

            // Layer 3: Emotion indicator.
            Positioned(
              top: 100,
              left: 16,
              child: _EmotionIndicator(
                emotion: state.emotion,
                valence: state.valence,
                arousal: state.arousal,
              ),
            ),

            // Layer 4: Breathing guide (centered, when active).
            if (breathingState.isActive)
              Center(
                child: _BreathingGuide(
                  phaseName: breathingState.phaseName,
                  progress: breathingState.progress,
                ),
              ),

            // Layer 5: Transcript overlay.
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: _TranscriptOverlay(
                transcript: state.transcript,
                agentTranscript: state.agentTranscript,
              ),
            ),

            // Layer 6: Voice controls.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _VoiceControls(
                isListening: state.isListening,
                isConnected: state.isConnected,
                stage: state.stage,
                onToggle: () {
                  final notifier = ref.read(sessionProvider.notifier);
                  if (state.isListening) {
                    notifier.stopListening();
                  } else {
                    notifier.startListening();
                  }
                },
                onEnd: () => ref.read(sessionProvider.notifier).endSession(),
              ),
            ),

            // Layer 7: Session complete overlay.
            if (state.stage == SessionStage.complete)
              Positioned.fill(
                child: _SessionCompleteView(
                  galleryId: state.galleryId,
                  onGoHome: () {
                    _disconnect();
                    context.go('/');
                  },
                  onViewGallery: () {
                    _disconnect();
                    context.go('/gallery');
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layer widgets
// ---------------------------------------------------------------------------

/// Crossfades between the previous and current generated images.
class _EmotionalCanvas extends StatelessWidget {
  const _EmotionalCanvas({required this.state});

  final dynamic state;

  @override
  Widget build(BuildContext context) {
    final currentImage = (state as dynamic).currentImage;
    final previousImage = (state as dynamic).previousImage;
    final emotion = (state as dynamic).emotion as String;

    final colors = emotionColors[emotion] ?? emotionColors['neutral']!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: crossfadeDurationMs),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.primary, colors.secondary],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (previousImage != null)
            AnimatedOpacity(
              opacity: currentImage != null ? 0.0 : 1.0,
              duration: const Duration(milliseconds: crossfadeDurationMs),
              child: Image.memory(previousImage, fit: BoxFit.cover),
            ),
          if (currentImage != null)
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: crossfadeDurationMs),
              child: Image.memory(currentImage, fit: BoxFit.cover),
            ),
        ],
      ),
    );
  }
}

/// Displays the current stage label and a close button.
class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.stage, required this.onClose});

  final SessionStage stage;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final label = stageLabels[stage.name] ?? stage.name;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the detected emotion and valence/arousal values.
class _EmotionIndicator extends StatelessWidget {
  const _EmotionIndicator({
    required this.emotion,
    required this.valence,
    required this.arousal,
  });

  final String emotion;
  final double valence;
  final double arousal;

  @override
  Widget build(BuildContext context) {
    final displayName = emotionDisplayNames[emotion] ?? emotion;
    final colors = emotionColors[emotion] ?? emotionColors['neutral']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayName,
            style: TextStyle(
              color: colors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'V: ${valence.toStringAsFixed(1)}  A: ${arousal.toStringAsFixed(1)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated breathing guide circle with phase label.
class _BreathingGuide extends StatelessWidget {
  const _BreathingGuide({
    required this.phaseName,
    required this.progress,
  });

  final String phaseName;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final label = phaseLabels[phaseName] ?? phaseName;
    // Scale between 0.6 and 1.0 based on progress and phase.
    final scale = phaseName == 'inhale'
        ? 0.6 + 0.4 * progress
        : phaseName == 'exhale'
            ? 1.0 - 0.4 * progress
            : phaseName == 'hold'
                ? 1.0
                : 0.6;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 16),
          width: 120 * scale,
          height: 120 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 18,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

/// Displays user and agent transcript text at the bottom of the screen.
class _TranscriptOverlay extends StatelessWidget {
  const _TranscriptOverlay({
    required this.transcript,
    required this.agentTranscript,
  });

  final String transcript;
  final String agentTranscript;

  @override
  Widget build(BuildContext context) {
    if (transcript.isEmpty && agentTranscript.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (agentTranscript.isNotEmpty)
            Text(
              agentTranscript,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          if (agentTranscript.isNotEmpty && transcript.isNotEmpty)
            const SizedBox(height: 8),
          if (transcript.isNotEmpty)
            Text(
              transcript,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// Microphone toggle and end-session button.
class _VoiceControls extends StatelessWidget {
  const _VoiceControls({
    required this.isListening,
    required this.isConnected,
    required this.stage,
    required this.onToggle,
    required this.onEnd,
  });

  final bool isListening;
  final bool isConnected;
  final SessionStage stage;
  final VoidCallback onToggle;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // End session button.
            if (stage != SessionStage.welcome &&
                stage != SessionStage.complete)
              IconButton(
                onPressed: onEnd,
                icon: Icon(
                  Icons.stop_circle_outlined,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 36,
                ),
              ),

            const SizedBox(width: 24),

            // Microphone toggle.
            GestureDetector(
              onTap: isConnected ? onToggle : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isListening
                      ? Colors.red.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: isListening
                        ? Colors.red
                        : Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),

            const SizedBox(width: 24),

            // Spacer for symmetry when end-session button is hidden.
            if (stage == SessionStage.welcome ||
                stage == SessionStage.complete)
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

/// Overlay shown when the session is complete.
class _SessionCompleteView extends StatelessWidget {
  const _SessionCompleteView({
    required this.galleryId,
    required this.onGoHome,
    required this.onViewGallery,
  });

  final String? galleryId;
  final VoidCallback onGoHome;
  final VoidCallback onViewGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xDD0A0A1A),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  'Sesion completada',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tu paisaje emocional ha sido guardado',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onViewGallery,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Ver galeria',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onGoHome,
                  child: Text(
                    'Volver al inicio',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
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
