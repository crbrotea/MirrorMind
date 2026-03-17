import 'dart:typed_data';

import 'breathing_pattern.dart';
import 'session_stage.dart';

/// Represents the full UI state of an active MirrorMind session.
class MirrorState {
  final String emotion;
  final SessionStage stage;
  final Uint8List? currentImage;
  final Uint8List? previousImage;
  final String transcript;
  final String agentTranscript;
  final bool isConnected;
  final bool isListening;
  final BreathingPattern? breathingPattern;
  final double valence;
  final double arousal;
  final String? galleryId;

  const MirrorState({
    this.emotion = 'neutral',
    this.stage = SessionStage.welcome,
    this.currentImage,
    this.previousImage,
    this.transcript = '',
    this.agentTranscript = '',
    this.isConnected = false,
    this.isListening = false,
    this.breathingPattern,
    this.valence = 0.0,
    this.arousal = 0.0,
    this.galleryId,
  });

  /// Returns a new [MirrorState] with the given fields replaced.
  MirrorState copyWith({
    String? emotion,
    SessionStage? stage,
    Uint8List? currentImage,
    Uint8List? previousImage,
    String? transcript,
    String? agentTranscript,
    bool? isConnected,
    bool? isListening,
    BreathingPattern? breathingPattern,
    double? valence,
    double? arousal,
    String? galleryId,
  }) {
    return MirrorState(
      emotion: emotion ?? this.emotion,
      stage: stage ?? this.stage,
      currentImage: currentImage ?? this.currentImage,
      previousImage: previousImage ?? this.previousImage,
      transcript: transcript ?? this.transcript,
      agentTranscript: agentTranscript ?? this.agentTranscript,
      isConnected: isConnected ?? this.isConnected,
      isListening: isListening ?? this.isListening,
      breathingPattern: breathingPattern ?? this.breathingPattern,
      valence: valence ?? this.valence,
      arousal: arousal ?? this.arousal,
      galleryId: galleryId ?? this.galleryId,
    );
  }
}
