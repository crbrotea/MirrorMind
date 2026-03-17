import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

/// Captures PCM16 audio from the device microphone as a stream of chunks.
///
/// Uses `flutter_sound` recorder to stream audio at 16 kHz mono, suitable for
/// sending over WebSocket to the MirrorMind backend.
class AudioCaptureService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();
  bool _isCapturing = false;
  bool _isOpened = false;

  /// Whether audio capture is currently active.
  bool get isCapturing => _isCapturing;

  /// Starts capturing audio from the microphone.
  ///
  /// Returns a [Stream] of PCM16 audio chunks. Each chunk is a [List<int>]
  /// containing raw PCM 16-bit samples at 16 kHz mono.
  ///
  /// Throws a [StateError] if the microphone permission is not granted.
  Future<Stream<List<int>>> startCapture() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw StateError(
        'Microphone permission not granted. '
        'Please allow microphone access to use MirrorMind.',
      );
    }

    if (!_isOpened) {
      await _recorder.openRecorder();
      _isOpened = true;
    }

    await _recorder.startRecorder(
      toStream: _controller.sink,
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
    );
    _isCapturing = true;
    return _controller.stream;
  }

  /// Stops the current audio capture session.
  Future<void> stopCapture() async {
    if (!_isCapturing) return;
    await _recorder.stopRecorder();
    _isCapturing = false;
  }

  /// Releases all resources held by this service.
  Future<void> dispose() async {
    if (_isCapturing) {
      await _recorder.stopRecorder();
    }
    if (_isOpened) {
      await _recorder.closeRecorder();
    }
    await _controller.close();
    _isCapturing = false;
    _isOpened = false;
  }
}
