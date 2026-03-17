import 'dart:async';

import 'package:record/record.dart';

/// Captures PCM16 audio from the device microphone as a stream of chunks.
///
/// Uses the `record` package to stream audio at 16 kHz mono, suitable for
/// sending over WebSocket to the MirrorMind backend.
class AudioCaptureService {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isCapturing = false;

  /// Whether audio capture is currently active.
  bool get isCapturing => _isCapturing;

  /// Starts capturing audio from the microphone.
  ///
  /// Returns a [Stream] of PCM16 audio chunks. Each chunk is a [List<int>]
  /// containing raw PCM 16-bit samples at 16 kHz mono.
  ///
  /// Throws a [StateError] if the microphone permission is not granted.
  Future<Stream<List<int>>> startCapture() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError(
        'Microphone permission not granted. '
        'Please allow microphone access to use MirrorMind.',
      );
    }

    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    );

    final stream = await _recorder.startStream(config);
    _isCapturing = true;
    return stream;
  }

  /// Stops the current audio capture session.
  Future<void> stopCapture() async {
    if (!_isCapturing) return;
    await _recorder.stop();
    _isCapturing = false;
  }

  /// Releases all resources held by this service.
  void dispose() {
    _recorder.dispose();
    _isCapturing = false;
  }
}
