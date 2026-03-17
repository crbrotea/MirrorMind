import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Displays the latest user and agent transcript text with auto-fade behavior.
///
/// When either transcript changes the text becomes visible, then fades out
/// after [transcriptFadeMs] milliseconds.
class TranscriptOverlay extends StatefulWidget {
  final String userTranscript;
  final String agentTranscript;

  const TranscriptOverlay({
    super.key,
    required this.userTranscript,
    required this.agentTranscript,
  });

  @override
  State<TranscriptOverlay> createState() => _TranscriptOverlayState();
}

class _TranscriptOverlayState extends State<TranscriptOverlay> {
  double _opacity = 0.0;
  Timer? _fadeTimer;

  @override
  void didUpdateWidget(covariant TranscriptOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final transcriptChanged =
        widget.userTranscript != oldWidget.userTranscript ||
            widget.agentTranscript != oldWidget.agentTranscript;

    if (transcriptChanged &&
        (widget.userTranscript.isNotEmpty ||
            widget.agentTranscript.isNotEmpty)) {
      _show();
    }
  }

  void _show() {
    _fadeTimer?.cancel();
    setState(() => _opacity = 1.0);
    _fadeTimer = Timer(const Duration(milliseconds: transcriptFadeMs), () {
      if (mounted) {
        setState(() => _opacity = 0.0);
      }
    });
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAgent = widget.agentTranscript.isNotEmpty;
    final hasUser = widget.userTranscript.isNotEmpty;

    if (!hasAgent && !hasUser) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 700),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Agent transcript.
            if (hasAgent)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.agentTranscript,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),

            // User transcript.
            if (hasUser)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.userTranscript,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
