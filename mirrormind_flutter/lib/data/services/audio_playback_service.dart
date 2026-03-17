import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';

/// Plays back PCM16 audio streamed from the MirrorMind backend.
///
/// Uses `flutter_sound` to play 24 kHz mono PCM16 audio in real time via
/// a streaming sink.
class AudioPlaybackService {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isInitialized = false;

  /// Initializes the audio player and opens a streaming session.
  ///
  /// Must be called before [playChunk]. Configures the player for PCM16
  /// at 24 kHz mono output.
  Future<void> init() async {
    await _player.openPlayer();
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      sampleRate: 24000,
      numChannels: 1,
    );
    _isInitialized = true;
  }

  /// Feeds a chunk of PCM16 audio data to the player for immediate playback.
  ///
  /// [pcmData] should contain raw PCM 16-bit samples at 24 kHz mono.
  /// The player must be initialized via [init] before calling this method.
  Future<void> playChunk(List<int> pcmData) async {
    if (!_isInitialized) return;
    final sink = _player.foodSink;
    if (sink == null) return;
    sink.add(FoodData(Uint8List.fromList(pcmData)));
  }

  /// Stops the current playback stream.
  Future<void> stop() async {
    if (!_isInitialized) return;
    await _player.stopPlayer();
    _isInitialized = false;
  }

  /// Releases all resources held by the player.
  ///
  /// After calling dispose, this instance must not be used again.
  Future<void> dispose() async {
    if (_isInitialized) {
      await _player.stopPlayer();
    }
    await _player.closePlayer();
    _isInitialized = false;
  }
}
