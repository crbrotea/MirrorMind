/**
 * AudioWorkletProcessor that captures microphone audio,
 * converts Float32 samples to Int16 PCM, and posts chunks
 * to the main thread for WebSocket transmission.
 */
class PCMCaptureProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this._buffer = [];
    this._bufferSize = 4096; // ~256ms at 16kHz
  }

  process(inputs) {
    const input = inputs[0];
    if (!input || !input[0]) return true;

    const channelData = input[0];

    for (let i = 0; i < channelData.length; i++) {
      const s = Math.max(-1, Math.min(1, channelData[i]));
      this._buffer.push(s < 0 ? s * 0x8000 : s * 0x7fff);
    }

    if (this._buffer.length >= this._bufferSize) {
      const int16 = new Int16Array(this._buffer.splice(0, this._bufferSize));
      this.port.postMessage(
        { type: 'pcm-chunk', samples: int16.buffer },
        [int16.buffer]
      );
    }

    return true;
  }
}

registerProcessor('pcm-capture-processor', PCMCaptureProcessor);
