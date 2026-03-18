import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/user_id_service.dart';

import '../../domain/models/mirror_state.dart';
import '../../domain/models/session_stage.dart';
import '../../domain/models/ws_message.dart';

/// Riverpod provider that exposes the current [MirrorState] and controls the
/// session lifecycle through [SessionNotifier].
final sessionProvider =
    StateNotifierProvider<SessionNotifier, MirrorState>((ref) {
  return SessionNotifier();
});

/// Manages the full lifecycle of a MirrorMind session: WebSocket connection,
/// audio streams, and UI state updates derived from incoming messages.
class SessionNotifier extends StateNotifier<MirrorState> {
  SessionNotifier() : super(const MirrorState());

  SessionRepository? _repository;

  StreamSubscription<String>? _textSub;
  StreamSubscription<List<int>>? _binarySub;

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Establishes the WebSocket connection and begins listening for messages.
  ///
  /// Retrieves the anonymous user ID from [UserIdService], creates a
  /// [SessionRepository], and subscribes to text and binary message streams.
  Future<void> connect() async {
    final userId = await UserIdService.getUserId();

    _repository = SessionRepository(wsBaseUrl);
    await _repository!.connect(userId);

    _textSub = _repository!.textMessages.listen(_handleTextMessage);
    _binarySub = _repository!.binaryMessages.listen(_handleBinaryMessage);

    state = state.copyWith(isConnected: true);
  }

  // ---------------------------------------------------------------------------
  // Message handling
  // ---------------------------------------------------------------------------

  /// Parses an incoming JSON text frame and updates [MirrorState] accordingly.
  void _handleTextMessage(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final message = WsMessage.fromJson(json);

      switch (message) {
        case WsImageMessage():
          final bytes = base64Decode(message.data);
          state = state.copyWith(
            previousImage: state.currentImage,
            currentImage: Uint8List.fromList(bytes),
            emotion: message.emotion,
          );

        case WsTranscriptMessage():
          if (message.author == 'user') {
            state = state.copyWith(transcript: message.text);
          } else {
            state = state.copyWith(agentTranscript: message.text);
          }

        case WsEmotionUpdate():
          state = state.copyWith(
            emotion: message.emotion,
            valence: message.valence,
            arousal: message.arousal,
          );

        case WsBreathingPattern():
          state = state.copyWith(breathingPattern: message.pattern);

        case WsStageChange():
          state = state.copyWith(
            stage: SessionStage.fromString(message.stage),
          );

        case WsSessionComplete():
          state = state.copyWith(
            stage: SessionStage.complete,
            galleryId: message.galleryId,
          );

        case WsAudioMessage():
          final bytes = base64Decode(message.data);
          _repository?.playAudio(bytes);

        case WsError():
          dev.log(
            'WS error: ${message.message}',
            name: 'SessionNotifier',
          );
      }
    } catch (e, st) {
      dev.log(
        'Failed to handle text message',
        name: 'SessionNotifier',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Feeds raw binary PCM audio from the server into the playback service.
  void _handleBinaryMessage(List<int> data) {
    _repository?.playAudio(data);
  }

  // ---------------------------------------------------------------------------
  // Recording controls
  // ---------------------------------------------------------------------------

  /// Starts capturing audio from the microphone and streaming it to the
  /// backend.
  Future<void> startListening() async {
    await _repository?.startListening();
    state = state.copyWith(isListening: true);
  }

  /// Stops the microphone capture.
  Future<void> stopListening() async {
    await _repository?.stopListening();
    state = state.copyWith(isListening: false);
  }

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  /// Sends an end-session signal to the backend so it can finalize the
  /// session and generate gallery artifacts.
  Future<void> endSession() async {
    await _repository?.endSession();
    state = state.copyWith(isListening: false);
  }

  /// Disconnects the WebSocket and releases audio resources.
  Future<void> disconnect() async {
    await _textSub?.cancel();
    _textSub = null;
    await _binarySub?.cancel();
    _binarySub = null;

    await _repository?.disconnect();
    state = state.copyWith(isConnected: false);
  }

  @override
  void dispose() {
    _textSub?.cancel();
    _binarySub?.cancel();
    _repository?.dispose();
    super.dispose();
  }
}
