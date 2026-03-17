import 'breathing_pattern.dart';

/// Sealed base class for all WebSocket messages received from the server.
sealed class WsMessage {
  const WsMessage();

  /// Parses a JSON map into the appropriate [WsMessage] subtype based on the
  /// `type` field.
  factory WsMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;

    switch (type) {
      case 'image':
        return WsImageMessage(
          data: json['data'] as String,
          emotion: json['emotion'] as String,
          stage: json['stage'] as String,
        );
      case 'transcript':
        return WsTranscriptMessage(
          text: json['text'] as String,
          author: json['author'] as String,
        );
      case 'emotion_update':
        return WsEmotionUpdate(
          emotion: json['emotion'] as String,
          valence: (json['valence'] as num).toDouble(),
          arousal: (json['arousal'] as num).toDouble(),
        );
      case 'breathing_pattern':
        return WsBreathingPattern(
          pattern: BreathingPattern.fromJson(json),
        );
      case 'stage_change':
        return WsStageChange(
          stage: json['stage'] as String,
        );
      case 'session_complete':
        return WsSessionComplete(
          galleryId: json['gallery_id'] as String?,
        );
      case 'audio':
        return WsAudioMessage(
          data: json['data'] as String,
        );
      case 'error':
        return WsError(
          message: json['message'] as String,
        );
      default:
        return WsError(
          message: 'Unknown message type: $type',
        );
    }
  }
}

/// A generated image delivered from the server.
class WsImageMessage extends WsMessage {
  final String data;
  final String emotion;
  final String stage;

  const WsImageMessage({
    required this.data,
    required this.emotion,
    required this.stage,
  });
}

/// A transcript of speech from the user or the agent.
class WsTranscriptMessage extends WsMessage {
  final String text;
  final String author;

  const WsTranscriptMessage({
    required this.text,
    required this.author,
  });
}

/// An update to the detected emotional state.
class WsEmotionUpdate extends WsMessage {
  final String emotion;
  final double valence;
  final double arousal;

  const WsEmotionUpdate({
    required this.emotion,
    required this.valence,
    required this.arousal,
  });
}

/// A breathing exercise pattern sent during the shift/arrive stages.
class WsBreathingPattern extends WsMessage {
  final BreathingPattern pattern;

  const WsBreathingPattern({required this.pattern});
}

/// Notification that the session has moved to a new stage.
class WsStageChange extends WsMessage {
  final String stage;

  const WsStageChange({required this.stage});
}

/// Notification that the session is complete, with an optional gallery ID.
class WsSessionComplete extends WsMessage {
  final String? galleryId;

  const WsSessionComplete({this.galleryId});
}

/// Base64-encoded audio data from the server for playback.
class WsAudioMessage extends WsMessage {
  final String data;

  const WsAudioMessage({required this.data});
}

/// An error message from the server.
class WsError extends WsMessage {
  final String message;

  const WsError({required this.message});
}
