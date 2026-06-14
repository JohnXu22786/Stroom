/**
 * media_kit Audio Extraction Bridge
 * 
 * Uses Web Audio API to extract audio from video files.
 * No FFmpeg dependency required.
 * 
 * Loaded from web/index.html
 */
(function () {
  'use strict';

  let audioCtx = null;

  /**
   * Extract audio from video bytes using Web Audio API.
   * Returns a WAV file as ArrayBuffer.
   */
  async function extractAudio(videoBytes, videoFormat) {
    // Create a Blob from the video bytes
    const blob = new Blob([videoBytes], { type: `video/${videoFormat}` });
    const url = URL.createObjectURL(blob);

    try {
      // Fetch the blob as ArrayBuffer for AudioContext
      const response = await fetch(url);
      const arrayBuffer = await response.arrayBuffer();

      // Create AudioContext and decode audio data
      if (!audioCtx) {
        audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      }
      const audioBuffer = await audioCtx.decodeAudioData(arrayBuffer);

      // Convert AudioBuffer to WAV format
      const wavBuffer = audioBufferToWav(audioBuffer);
      return new Uint8Array(wavBuffer);
    } finally {
      URL.revokeObjectURL(url);
    }
  }

  /**
   * Convert AudioBuffer to WAV format bytes.
   */
  function audioBufferToWav(buffer) {
    const numChannels = buffer.numberOfChannels;
    const sampleRate = buffer.sampleRate;
    const format = 1; // PCM
    const bitDepth = 16;

    const numSamples = buffer.length;
    const dataSize = numSamples * numChannels * (bitDepth / 8);
    const headerSize = 44;
    const totalSize = headerSize + dataSize;

    const arrayBuffer = new ArrayBuffer(totalSize);
    const view = new DataView(arrayBuffer);

    // RIFF header
    writeString(view, 0, 'RIFF');
    view.setUint32(4, totalSize - 8, true);
    writeString(view, 8, 'WAVE');

    // fmt chunk
    writeString(view, 12, 'fmt ');
    view.setUint32(16, 16, true);
    view.setUint16(20, format, true);
    view.setUint16(22, numChannels, true);
    view.setUint32(24, sampleRate, true);
    view.setUint32(28, sampleRate * numChannels * (bitDepth / 8), true);
    view.setUint16(32, numChannels * (bitDepth / 8), true);
    view.setUint16(34, bitDepth, true);

    // data chunk
    writeString(view, 36, 'data');
    view.setUint32(40, dataSize, true);

    // Write interleaved PCM samples
    let offset = 44;
    const channelData = [];
    for (let c = 0; c < numChannels; c++) {
      channelData.push(buffer.getChannelData(c));
    }

    for (let s = 0; s < numSamples; s++) {
      for (let c = 0; c < numChannels; c++) {
        const sample = Math.max(-1, Math.min(1, channelData[c][s]));
        const int16 = sample < 0 ? sample * 0x8000 : sample * 0x7FFF;
        view.setInt16(offset, int16, true);
        offset += 2;
      }
    }

    return arrayBuffer;
  }

  function writeString(view, offset, string) {
    for (let i = 0; i < string.length; i++) {
      view.setUint8(offset + i, string.charCodeAt(i));
    }
  }

  // Expose global functions for Dart JS interop
  window.__mediaKitAudioSupported = function () {
    return !!(window.AudioContext || window.webkitAudioContext);
  };

  window.__mediaKitExtractAudio = async function (videoBytes, videoFormat) {
    const result = await extractAudio(videoBytes, videoFormat);
    return result;
  };
})();
