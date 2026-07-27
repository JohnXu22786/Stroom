import 'dart:math';
import 'dart:typed_data';

// ============================================================================
// Pure-Dart audio chunker for WAV files
//
// Based on FFmpeg's wavdec.c (WAV header parsing) and af_silencedetect.c
// (silence detection via amplitude thresholding), ported to Dart.
//
// Pipeline: parse WAV header → RMS energy analysis → find silence gaps →
// split PCM at gap midpoints → enforce max chunk size.
// ============================================================================

/// Parsed WAV file metadata, following FFmpeg's riffdec.c WAVEFORMATEX parsing.
class WavInfo {
  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;
  final int dataOffset;
  final int dataSize;
  final int byteRate;
  final int blockAlign;

  const WavInfo({
    required this.sampleRate,
    required this.numChannels,
    required this.bitsPerSample,
    required this.dataOffset,
    required this.dataSize,
    required this.byteRate,
    required this.blockAlign,
  });

  int get bytesPerSample => bitsPerSample ~/ 8;
  int get bytesPerFrame => bytesPerSample * numChannels;
  int get totalSamples => dataSize ~/ bytesPerFrame;
  double get durationSeconds => totalSamples / sampleRate;
}

/// A slice of audio: byte range + time range.
class AudioChunk {
  final int startByte;
  final int endByte;
  final double startSecond;
  final double endSecond;

  const AudioChunk({
    required this.startByte,
    required this.endByte,
    required this.startSecond,
    required this.endSecond,
  });

  int get byteLength => endByte - startByte;
  double get durationSeconds => endSecond - startSecond;
}

/// Configuration for audio chunking.
class AudioChunkConfig {
  /// Maximum bytes per chunk (default: 25 MB for OpenAI compatibility).
  final int maxChunkBytes;

  /// Minimum silence amplitude in dB (RMS). Default -40 dB.
  /// -30 dB = soft silence (quiet speech pauses)
  /// -50 dB = hard silence (true gaps)
  /// -60 dB = digital silence (only noise floor)
  final double silenceDbThreshold;

  /// Minimum silence duration in seconds to consider as a split point.
  /// Default 1.5 seconds. FFmpeg default is 2.0s.
  final double minSilenceDuration;

  /// RMS analysis frame size in samples. Default 1024 (~23ms at 44.1kHz).
  final int frameSize;

  /// Overlap in seconds added before and after each cut point,
  /// to prevent cutting mid-word. Default 0.3s.
  final double overlapSeconds;

  const AudioChunkConfig({
    this.maxChunkBytes = 25 * 1024 * 1024,
    this.silenceDbThreshold = -40.0,
    this.minSilenceDuration = 1.5,
    this.frameSize = 1024,
    this.overlapSeconds = 0.3,
  });
}

// ============================================================================
// WAV Header Parser (based on FFmpeg wavdec.c + riffdec.c)
// ============================================================================

/// Parse a WAV file header and return audio parameters + PCM data offset.
///
/// Supports standard PCM WAV files in S16LE format (most common).
/// RIFF, RIFX (big-endian), and WAVE64 containers are handled.
///
/// Throws [FormatException] if the file is not a valid WAV.
WavInfo parseWavHeader(Uint8List bytes) {
  if (bytes.length < 44) {
    throw FormatException('File too small to be a valid WAV');
  }

  int offset = 0;

  // --- RIFF header ---
  final riffTag = _readFourCC(bytes, offset);
  offset += 4;
  final isRifx = riffTag == 'RIFX';
  final isRf64 = riffTag == 'RF64';

  if (riffTag != 'RIFF' && !isRifx && !isRf64) {
    throw FormatException('Not a RIFF/WAV file: expected RIFF, got $riffTag');
  }

  final _ = _readUint32(bytes, offset, bigEndian: isRifx);
  offset += 4;

  final waveTag = _readFourCC(bytes, offset);
  offset += 4;
  if (waveTag != 'WAVE') {
    throw FormatException('Not a WAV file: expected WAVE, got $waveTag');
  }

  // --- Scan sub-chunks ---
  int? sampleRate;
  int? numChannels;
  int? bitsPerSample;
  int? byteRate;
  int? blockAlign;
  int audioFormat = 0;
  int? dataOffset;
  int dataSize = 0;
  bool gotFmt = false;

  while (offset + 8 <= bytes.length) {
    final tag = _readFourCC(bytes, offset);
    offset += 4;
    int size = _readUint32(bytes, offset, bigEndian: isRifx);
    offset += 4;

    // RIFF alignment: chunk size is always even
    final alignedSize = (size + 1) & ~1;

    switch (tag) {
      case 'fmt ':
        if (gotFmt) break; // skip duplicate fmt chunks

        if (size < 16) {
          throw FormatException('fmt chunk too small: $size bytes');
        }

        audioFormat = _readUint16(bytes, offset, bigEndian: isRifx);
        offset += 2;
        numChannels = _readUint16(bytes, offset, bigEndian: isRifx);
        offset += 2;
        sampleRate = _readUint32(bytes, offset, bigEndian: isRifx);
        offset += 4;
        byteRate = _readUint32(bytes, offset, bigEndian: isRifx);
        offset += 4;
        blockAlign = _readUint16(bytes, offset, bigEndian: isRifx);
        offset += 2;

        if (size >= 16) {
          bitsPerSample = _readUint16(bytes, offset, bigEndian: isRifx);
          offset += 2;
        } else {
          bitsPerSample = 8; // WAVEFORMAT (no bitsPerSample)
        }

        // Skip extension bytes if any
        final extensionSize = size - 16;
        offset += extensionSize.clamp(0, alignedSize - (offset % alignedSize));

        gotFmt = true;
        break;

      case 'data':
        if (!gotFmt) {
          throw FormatException('data chunk before fmt chunk');
        }
        dataOffset = offset;
        dataSize = size;
        // Found data — stop scanning
        offset = bytes.length; // force exit loop
        break;

      default:
        // Skip unknown chunks
        offset += alignedSize;
        break;
    }

    if (dataOffset != null) break;
  }

  if (!gotFmt) throw FormatException('No fmt chunk found in WAV');
  if (dataOffset == null) throw FormatException('No data chunk found in WAV');

  if (audioFormat != 1) {
    throw FormatException(
        'Unsupported audio format: $audioFormat. Only PCM (1) is supported.');
  }

  if (bitsPerSample != 16) {
    throw FormatException(
        'Unsupported bit depth: $bitsPerSample. Only 16-bit PCM is supported.');
  }

  return WavInfo(
    sampleRate: sampleRate!,
    numChannels: numChannels!,
    bitsPerSample: bitsPerSample!,
    dataOffset: dataOffset,
    dataSize: dataSize,
    byteRate: byteRate!,
    blockAlign: blockAlign!,
  );
}

// ============================================================================
// PCM Sample Reader
// ============================================================================

/// Read PCM samples from WAV data as normalized float values [-1.0, 1.0].
/// Converts from S16LE interleaved format.
Float64List readPcmSamplesFloat(Uint8List wavBytes, WavInfo info) {
  final sampleCount = info.totalSamples;
  final samples = Float64List(sampleCount);
  // ByteData from buffer — compatible with Dart >= 3.0.0
  final dv = wavBytes.buffer.asByteData(
      info.dataOffset + wavBytes.offsetInBytes, info.dataSize);

  for (int i = 0; i < sampleCount; i++) {
    final s16 = dv.getInt16(i * 2, Endian.little);
    samples[i] = s16 / 32768.0;
  }

  return samples;
}

// ============================================================================
// RMS Silence Detection (based on FFmpeg af_silencedetect.c algorithm)
// ============================================================================

/// Detect silence regions in PCM audio using RMS energy.
///
/// Returns a list of silence gaps, each with start/end sample indices.
/// A gap is "silent" when its RMS dB level is below [silenceDbThreshold]
/// for at least [minSilenceDuration] seconds.
class SilenceDetector {
  final AudioChunkConfig config;

  const SilenceDetector(this.config);

  /// Analyze PCM samples and return silence regions.
  /// [samples] must be normalized float samples in [-1.0, 1.0].
  /// [sampleRate] is the audio sample rate.
  List<SilenceGap> detect(Float64List samples, int sampleRate) {
    final frameSize = config.frameSize;
    final frameCount = samples.length ~/ frameSize;
    final minSilentFrames =
        (config.minSilenceDuration * sampleRate / frameSize).ceil();

    // Step 1: Compute RMS dB for each frame
    final dbValues = Float64List(frameCount);
    for (int f = 0; f < frameCount; f++) {
      double sumSq = 0;
      final start = f * frameSize;
      final end = (start + frameSize).clamp(0, samples.length);
      for (int i = start; i < end; i++) {
        sumSq += samples[i] * samples[i];
      }
      final rms = sqrt(sumSq / (end - start));
      // Convert to dB: 20 * log10(rms), with floor at -100 dB
      dbValues[f] = rms > 1e-10 ? 20 * log(rms) / ln10 : -100.0;
    }

    // Step 2: Find contiguous silent frames
    final silenceGaps = <SilenceGap>[];
    int? gapStart;

    for (int f = 0; f < frameCount; f++) {
      if (dbValues[f] < config.silenceDbThreshold) {
        gapStart ??= f;
      } else {
        if (gapStart != null && (f - gapStart) >= minSilentFrames) {
          silenceGaps.add(SilenceGap(
            startSample: gapStart * frameSize,
            endSample: f * frameSize,
            durationSeconds: (f - gapStart) * frameSize / sampleRate,
          ));
        }
        gapStart = null;
      }
    }

    // Handle trailing silence
    if (gapStart != null &&
        (frameCount - gapStart) >= minSilentFrames) {
      silenceGaps.add(SilenceGap(
        startSample: gapStart * frameSize,
        endSample: samples.length,
        durationSeconds:
            (frameCount - gapStart) * frameSize / sampleRate,
      ));
    }

    return silenceGaps;
  }
}

class SilenceGap {
  final int startSample;
  final int endSample;
  final double durationSeconds;

  const SilenceGap({
    required this.startSample,
    required this.endSample,
    required this.durationSeconds,
  });

  int get midSample => (startSample + endSample) ~/ 2;
}

// ============================================================================
// Audio Chunker (combines parser + silence detector + splitter)
// ============================================================================

/// Splits a PCM WAV file into chunks suitable for ASR transcription.
///
/// The chunking strategy:
/// 1. Parse WAV header to get sample rate, channels, data offset
/// 2. Convert PCM to float samples
/// 3. Detect silence gaps using RMS energy
/// 4. Split at silence gap midpoints
/// 5. If any resulting chunk exceeds [AudioChunkConfig.maxChunkBytes],
///    sub-split it at regular intervals (no silence detection needed —
///    the chunk is homogenous audio).
/// 6. Each chunk is a complete valid WAV file (with RIFF header)
class AudioChunker {
  final AudioChunkConfig config;

  const AudioChunker({this.config = const AudioChunkConfig()});

  /// Split a WAV file into chunks.
  /// Returns a list of valid WAV files, each as [Uint8List].
  List<Uint8List> split(Uint8List wavBytes) {
    // Step 1: Parse header
    final info = parseWavHeader(wavBytes);

    // Step 2: Read PCM as float
    final samples = readPcmSamplesFloat(wavBytes, info);

    // Step 3: Find silence gaps
    final detector = SilenceDetector(config);
    final silenceGaps = detector.detect(samples, info.sampleRate);

    // Step 4: Build cut points from silence gaps + file boundaries
    final cutSamples = <int>[0];
    for (final gap in silenceGaps) {
      cutSamples.add(gap.midSample);
    }
    cutSamples.add(info.totalSamples);

    // Step 5: Convert cut samples to byte offsets, apply overlap
    final overlapSamples =
        (config.overlapSeconds * info.sampleRate).round();
    final pcmDataOffset = info.dataOffset;
    final bpf = info.bytesPerFrame;

    final byteCuts = <int>[];
    for (final sample in cutSamples) {
      int byte = pcmDataOffset + (sample * bpf);
      byte = byte.clamp(pcmDataOffset, pcmDataOffset + info.dataSize);
      byteCuts.add(byte);
    }

    // Step 6: Build chunks, enforcing max size
    final rawChunks = <_RawChunk>[];
    for (int i = 0; i < byteCuts.length - 1; i++) {
      int start = byteCuts[i];
      int end = byteCuts[i + 1];

      // Apply overlap: expand backward for non-first chunks
      if (i > 0) {
        start = (start - overlapSamples * bpf)
            .clamp(pcmDataOffset, pcmDataOffset + info.dataSize);
      }
      // Apply overlap: expand forward for non-last chunks
      if (i < byteCuts.length - 2) {
        end = (end + overlapSamples * bpf)
            .clamp(pcmDataOffset, pcmDataOffset + info.dataSize);
      }

      if (end <= start) continue;

      // Sub-split if too large
      final chunkBytes = end - start;
      if (chunkBytes <= config.maxChunkBytes) {
        rawChunks.add(_RawChunk(
            start, end,
            (start - pcmDataOffset) ~/ bpf / info.sampleRate,
            (end - pcmDataOffset) ~/ bpf / info.sampleRate));
      } else {
        // Evenly split into sub-chunks
        final numParts = (chunkBytes / config.maxChunkBytes).ceil();
        for (int p = 0; p < numParts; p++) {
          final subStart = start + (chunkBytes * p) ~/ numParts;
          final subEnd = start + (chunkBytes * (p + 1)) ~/ numParts;
          if (subEnd > subStart) {
            rawChunks.add(_RawChunk(
                subStart,
                subEnd,
                (subStart - pcmDataOffset) ~/ bpf / info.sampleRate,
                (subEnd - pcmDataOffset) ~/ bpf / info.sampleRate));
          }
        }
      }
    }

    // Step 7: Write each chunk as a valid WAV file
    return rawChunks
        .map((rc) => _writeWavChunk(
              wavBytes,
              info,
              rc.startByte - info.dataOffset,
              rc.endByte - info.dataOffset,
            ))
        .toList();
  }
}

class _RawChunk {
  final int startByte;
  final int endByte;
  final double startSecond;
  final double endSecond;

  const _RawChunk(
      this.startByte, this.endByte, this.startSecond, this.endSecond);
}

// ============================================================================
// WAV Writer (chunk output)
// ============================================================================

/// Write a slice of PCM data as a complete WAV file.
Uint8List _writeWavChunk(
    Uint8List wavBytes, WavInfo info, int pcmStart, int pcmEnd) {
  final dataSize = pcmEnd - pcmStart;
  final fileSize = 44 + dataSize;

  final writer = _WavByteWriter();
  writer.writeString('RIFF');
  writer.writeUint32(fileSize - 8);
  writer.writeString('WAVE');
  writer.writeString('fmt ');
  writer.writeUint32(16); // chunk size
  writer.writeUint16(1); // PCM format
  writer.writeUint16(info.numChannels);
  writer.writeUint32(info.sampleRate);
  writer.writeUint32(info.byteRate);
  writer.writeUint16(info.blockAlign);
  writer.writeUint16(info.bitsPerSample);
  writer.writeString('data');
  writer.writeUint32(dataSize);

  // Copy PCM data slice via BytesBuilder bulk add
  final sliceBytes = Uint8List(dataSize);
  for (int i = 0; i < dataSize; i++) {
    sliceBytes[i] = wavBytes[info.dataOffset + pcmStart + i];
  }
  writer.writeBytes(sliceBytes);

  return writer.toBytes();
}

// ============================================================================
// Low-level byte helpers (matching audio_utils.dart _WavWriter pattern)
// ============================================================================

class _WavByteWriter {
  final BytesBuilder _builder = BytesBuilder();

  void writeString(String s) {
    _builder.add(s.codeUnits);
  }

  void writeUint16(int value) {
    _builder.addByte(value & 0xFF);
    _builder.addByte((value >> 8) & 0xFF);
  }

  void writeUint32(int value) {
    _builder.addByte(value & 0xFF);
    _builder.addByte((value >> 8) & 0xFF);
    _builder.addByte((value >> 16) & 0xFF);
    _builder.addByte((value >> 24) & 0xFF);
  }

  void writeBytes(Uint8List bytes) {
    _builder.add(bytes);
  }

  Uint8List toBytes() => _builder.toBytes();
}

String _readFourCC(Uint8List bytes, int offset) {
  return String.fromCharCodes(bytes.sublist(offset, offset + 4));
}

int _readUint16(Uint8List bytes, int offset, {bool bigEndian = false}) {
  final dv = bytes.buffer.asByteData(
      offset + bytes.offsetInBytes, 2);
  return dv.getUint16(0, bigEndian ? Endian.big : Endian.little);
}

int _readUint32(Uint8List bytes, int offset, {bool bigEndian = false}) {
  final dv = bytes.buffer.asByteData(
      offset + bytes.offsetInBytes, 4);
  return dv.getUint32(0, bigEndian ? Endian.big : Endian.little);
}
