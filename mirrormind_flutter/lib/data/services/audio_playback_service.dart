import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';

/// Plays back PCM16 audio streamed from the MirrorMind backend.
///
/// Uses a serialized queue to feed chunks one at a time, avoiding the native
/// AudioTrack crash caused by concurrent writes.
class AudioPlaybackService {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isInitialized = false;
  bool _isFeeding = false;
  final Queue<Uint8List> _queue = Queue<Uint8List>();

  /// Initializes the audio player and opens a streaming session at 24 kHz mono.
  Future<void> init() async {
    await _player.openPlayer();
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      sampleRate: 24000,
      numChannels: 1,
      interleaved: true,
      bufferSize: 16384,
    );
    _isInitialized = true;
  }

  /// Enqueues a chunk of PCM16 audio data for playback.
  ///
  /// Chunks are fed to the native player one at a time to prevent concurrent
  /// writes that crash the Android AudioTrack.
  void playChunk(List<int> pcmData) {
    if (!_isInitialized) return;
    _queue.add(Uint8List.fromList(pcmData));
    _drain();
  }

  /// Drains the queue serially — only one feedUint8FromStream at a time.
  Future<void> _drain() async {
    if (_isFeeding || _queue.isEmpty || !_isInitialized) return;
    _isFeeding = true;

    while (_queue.isNotEmpty && _isInitialized) {
      final chunk = _queue.removeFirst();
      try {
        await _player.feedUint8FromStream(chunk);
      } catch (e) {
        dev.log(
          'Audio feed error (${chunk.length} bytes): $e',
          name: 'AudioPlayback',
        );
        // Small delay before retrying to let the native side recover.
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    _isFeeding = false;
  }

  /// Stops the current playback stream and clears the queue.
  Future<void> stop() async {
    _queue.clear();
    if (!_isInitialized) return;
    _isInitialized = false;
    try {
      await _player.stopPlayer();
    } catch (_) {}
  }

  /// Releases all resources held by the player.
  Future<void> dispose() async {
    _queue.clear();
    if (_isInitialized) {
      _isInitialized = false;
      try {
        await _player.stopPlayer();
      } catch (_) {}
    }
    try {
      await _player.closePlayer();
    } catch (_) {}
  }
}
