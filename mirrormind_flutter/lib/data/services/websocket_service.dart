import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Represents the connection state of the WebSocket client.
enum ConnectionState {
  disconnected,
  connecting,
  connected,
}

/// WebSocket client for MirrorMind real-time communication.
///
/// Supports binary frames (PCM audio) and JSON text frames. Automatically
/// reconnects with exponential backoff when the connection drops unexpectedly.
class MirrorWebSocket {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final StreamController<List<int>> _binaryController =
      StreamController<List<int>>.broadcast();
  final StreamController<String> _textController =
      StreamController<String>.broadcast();
  final StreamController<ConnectionState> _stateController =
      StreamController<ConnectionState>.broadcast();

  ConnectionState _state = ConnectionState.disconnected;
  bool _shouldReconnect = false;
  String? _url;

  /// Initial reconnection delay in milliseconds.
  static const int _initialBackoffMs = 1000;

  /// Maximum reconnection delay in milliseconds.
  static const int _maxBackoffMs = 30000;

  int _currentBackoffMs = _initialBackoffMs;

  /// Stream of incoming binary frames (PCM audio data from the server).
  Stream<List<int>> get binaryMessages => _binaryController.stream;

  /// Stream of incoming text frames (JSON messages from the server).
  Stream<String> get textMessages => _textController.stream;

  /// Stream of connection state changes.
  Stream<ConnectionState> get stateChanges => _stateController.stream;

  /// Whether the WebSocket is currently connected.
  bool get isConnected => _state == ConnectionState.connected;

  /// Connects to the given WebSocket [url].
  ///
  /// If already connected, the existing connection is closed first.
  Future<void> connect(String url) async {
    _url = url;
    _shouldReconnect = true;
    await _doConnect(url);
  }

  Future<void> _doConnect(String url) async {
    _setState(ConnectionState.connecting);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel!.ready;

      _setState(ConnectionState.connected);
      _currentBackoffMs = _initialBackoffMs;

      _subscription = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
      );
    } catch (e) {
      _setState(ConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    if (data is List<int>) {
      _binaryController.add(data);
    } else if (data is String) {
      _textController.add(data);
    }
  }

  void _onError(Object error) {
    _setState(ConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _onDone() {
    _setState(ConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _setState(ConnectionState newState) {
    if (_state == newState) return;
    _state = newState;
    _stateController.add(newState);
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _url == null) return;

    final delay = _currentBackoffMs;
    _currentBackoffMs = (_currentBackoffMs * 2).clamp(0, _maxBackoffMs);

    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (_shouldReconnect && _url != null) {
        _doConnect(_url!);
      }
    });
  }

  /// Sends a binary frame (e.g. PCM audio data) over the WebSocket.
  void sendBinary(List<int> data) {
    if (!isConnected || _channel == null) return;
    _channel!.sink.add(data);
  }

  /// Sends a JSON text frame over the WebSocket.
  void sendJson(Map<String, dynamic> data) {
    if (!isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode(data));
  }

  /// Cleanly disconnects from the WebSocket server.
  ///
  /// Disables automatic reconnection before closing.
  Future<void> disconnect() async {
    _shouldReconnect = false;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _setState(ConnectionState.disconnected);
  }

  /// Releases all resources held by this service.
  ///
  /// After calling dispose, this instance must not be used again.
  void dispose() {
    _shouldReconnect = false;
    _subscription?.cancel();
    _channel?.sink.close();
    _binaryController.close();
    _textController.close();
    _stateController.close();
  }
}
