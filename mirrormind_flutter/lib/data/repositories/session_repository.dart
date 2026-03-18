import 'dart:async';

import 'package:mirrormind_flutter/data/services/audio_capture_service.dart';
import 'package:mirrormind_flutter/data/services/audio_playback_service.dart';
import 'package:mirrormind_flutter/data/services/websocket_service.dart';

/// Orchestrates a MirrorMind session by coordinating the WebSocket connection,
/// audio capture (microphone), and audio playback (agent voice).
class SessionRepository {
  final String _wsUrl;
  final MirrorWebSocket _webSocket = MirrorWebSocket();
  final AudioCaptureService _audioCapture = AudioCaptureService();
  final AudioPlaybackService _audioPlayback = AudioPlaybackService();

  StreamSubscription<List<int>>? _captureSubscription;

  /// Creates a session repository that connects to the given [wsUrl].
  SessionRepository(this._wsUrl);

  /// Stream of incoming JSON text messages from the server.
  Stream<String> get textMessages => _webSocket.textMessages;

  /// Stream of incoming binary messages (agent PCM audio) from the server.
  Stream<List<int>> get binaryMessages => _webSocket.binaryMessages;

  /// Stream of WebSocket connection state changes.
  Stream<ConnectionState> get connectionState => _webSocket.stateChanges;

  /// Connects to the backend WebSocket and initializes audio playback.
  ///
  /// The [userId] is appended to the WebSocket URL path so the server can
  /// associate the connection with the correct user session.
  Future<void> connect(String userId) async {
    final url = '$_wsUrl/$userId';
    await _webSocket.connect(url);
    await _audioPlayback.init();
  }

  /// Disconnects the WebSocket, stops capture and playback.
  Future<void> disconnect() async {
    await stopListening();
    await _audioPlayback.stop();
    await _webSocket.disconnect();
  }

  /// Feeds PCM audio data to the playback service for immediate output.
  void playAudio(List<int> pcmData) {
    _audioPlayback.playChunk(pcmData);
  }

  /// Starts capturing microphone audio and piping it to the WebSocket.
  ///
  /// Each PCM16 chunk from the microphone is sent as a binary frame to the
  /// server for real-time emotion analysis and transcription.
  Future<void> startListening() async {
    final stream = await _audioCapture.startCapture();
    _captureSubscription = stream.listen((chunk) {
      _webSocket.sendBinary(chunk);
    });
  }

  /// Stops capturing audio from the microphone.
  Future<void> stopListening() async {
    await _captureSubscription?.cancel();
    _captureSubscription = null;
    await _audioCapture.stopCapture();
  }

  /// Sends an end-session signal to the server and stops all local streams.
  ///
  /// The server will finalize the session, generate gallery artifacts, and
  /// respond with a `session_complete` message.
  Future<void> endSession() async {
    _webSocket.sendJson({'type': 'end_session'});
    await stopListening();
    await _audioPlayback.stop();
  }

  /// Releases all resources held by this repository.
  ///
  /// After calling dispose, this instance must not be used again.
  Future<void> dispose() async {
    await _captureSubscription?.cancel();
    _captureSubscription = null;
    _audioCapture.dispose();
    await _audioPlayback.dispose();
    _webSocket.dispose();
  }
}
