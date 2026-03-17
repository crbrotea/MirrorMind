import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/models/session_stage.dart';

/// Top header bar for the session screen showing elapsed time, stage progress
/// dots, and navigation/end-session controls.
class SessionHeader extends StatefulWidget {
  final SessionStage stage;
  final bool isConnected;
  final VoidCallback onEndSession;
  final VoidCallback onBack;

  const SessionHeader({
    super.key,
    required this.stage,
    required this.isConnected,
    required this.onEndSession,
    required this.onBack,
  });

  @override
  State<SessionHeader> createState() => _SessionHeaderState();
}

class _SessionHeaderState extends State<SessionHeader> {
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant SessionHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected && !oldWidget.isConnected) {
      _startTimerIfNeeded();
    } else if (!widget.isConnected && oldWidget.isConnected) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimerIfNeeded() {
    if (widget.isConnected && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsedSeconds++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// The stages displayed as progress dots (excludes 'complete').
  static const _progressStages = [
    SessionStage.welcome,
    SessionStage.mirror,
    SessionStage.shift,
    SessionStage.arrive,
  ];

  @override
  Widget build(BuildContext context) {
    final stageLabel = stageLabels[widget.stage.name] ?? widget.stage.name;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Back button.
            GestureDetector(
              onTap: widget.onBack,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),

            // Center section: timer + stage dots + stage label.
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Timer.
                  Text(
                    _formattedTime,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontFamily: 'monospace',
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Stage progress dots.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _progressStages.map((s) {
                      final isActive =
                          s.index <= widget.stage.index;
                      return Container(
                        width: 24,
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),

                  // Stage label.
                  Text(
                    stageLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // End session button.
            GestureDetector(
              onTap: widget.onEndSession,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stop,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Fin',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
