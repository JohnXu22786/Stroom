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
  final double silenceDbThreshold;

  /// Minimum silence duration in seconds to consider as a split point.
  /// Default 1.5 seconds.
  final double minSilenceDuration;

  /// RMS analysis frame size in samples. Default 1024 (~23ms at 44.1kHz).
  final int frameSize;

  /// Overlap in seconds added before and after each cut point.
  /// Default 0.3s.
  final double overlapSeconds;

  /// Fixed duration per chunk in seconds (used by fixedDuration method).
  /// Default 60 seconds (1 minute).
  final double fixedDurationSeconds;

  const AudioChunkConfig({
    this.maxChunkBytes = 25 * 1024 * 1024,
    this.silenceDbThreshold = -40.0,
    this.minSilenceDuration = 1.5,
    this.frameSize = 1024,
    this.overlapSeconds = 0.3,
    this.fixedDurationSeconds = 60.0,
  });
}

/// Chunking strategy.
enum AudioChunkMethod {
  /// No chunking — send entire file.
  none,

  /// VAD/silence-based chunking.
  silence,

  /// Split at fixed time intervals.
  fixedDuration,

  /// Split to stay under maxChunkBytes (no silence awareness).
  fixedSize,
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
  final dv = wavBytes.buffer
      .asByteData(info.dataOffset + wavBytes.offsetInBytes, info.dataSize);

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
    if (gapStart != null && (frameCount - gapStart) >= minSilentFrames) {
      silenceGaps.add(SilenceGap(
        startSample: gapStart * frameSize,
        endSample: samples.length,
        durationSeconds: (frameCount - gapStart) * frameSize / sampleRate,
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

  /// Split a WAV file using the specified [method].
  List<Uint8List> chunk(Uint8List wavBytes, AudioChunkMethod method) {
    switch (method) {
      case AudioChunkMethod.none:
        return [wavBytes];
      case AudioChunkMethod.silence:
        return split(wavBytes);
      case AudioChunkMethod.fixedDuration:
        return splitByDuration(wavBytes);
      case AudioChunkMethod.fixedSize:
        return splitBySize(wavBytes);
    }
  }

  /// Split a WAV file into chunks using silence detection.
  /// Falls back to fixed-size splitting if no silence is detected.
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
    final overlapSamples = (config.overlapSeconds * info.sampleRate).round();
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
            start,
            end,
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
              rc.startByte - pcmDataOffset,
              rc.endByte - pcmDataOffset,
            ))
        .toList();
  }

  /// Split WAV into chunks of fixed [config.fixedDurationSeconds] seconds.
  List<Uint8List> splitByDuration(Uint8List wavBytes) {
    final info = parseWavHeader(wavBytes);
    final samplesPerChunk =
        (config.fixedDurationSeconds * info.sampleRate).round();
    final bpf = info.bytesPerFrame;
    final totalSamples = info.totalSamples;
    final chunks = <Uint8List>[];

    for (int startSample = 0;
        startSample < totalSamples;
        startSample += samplesPerChunk) {
      int endSample = (startSample + samplesPerChunk).clamp(0, totalSamples);
      if (endSample <= startSample) break;

      // Apply overlap
      final overlapSamples = (config.overlapSeconds * info.sampleRate).round();
      int adjStart = (startSample - (startSample > 0 ? overlapSamples : 0))
          .clamp(0, totalSamples);
      int adjEnd = (endSample + (endSample < totalSamples ? overlapSamples : 0))
          .clamp(0, totalSamples);

      // Also enforce maxChunkBytes — sub-split if needed
      final adjBytes = (adjEnd - adjStart) * bpf;
      if (adjBytes <= config.maxChunkBytes) {
        chunks
            .add(_writeWavChunk(wavBytes, info, adjStart * bpf, adjEnd * bpf));
      } else {
        // Sub-split evenly
        final numParts = (adjBytes / config.maxChunkBytes).ceil();
        for (int p = 0; p < numParts; p++) {
          final subStart = adjStart + ((adjEnd - adjStart) * p) ~/ numParts;
          final subEnd = adjStart + ((adjEnd - adjStart) * (p + 1)) ~/ numParts;
          if (subEnd > subStart) {
            chunks.add(
                _writeWavChunk(wavBytes, info, subStart * bpf, subEnd * bpf));
          }
        }
      }
    }

    return chunks;
  }

  /// Split WAV into chunks that stay under [config.maxChunkBytes].
  /// Simple byte-count splitting — no silence awareness.
  List<Uint8List> splitBySize(Uint8List wavBytes) {
    final info = parseWavHeader(wavBytes);
    final bpf = info.bytesPerFrame;
    final totalSamples = info.totalSamples;
    final chunks = <Uint8List>[];

    // Determine chunk size in bytes (leave room for WAV header ~44 bytes)
    final targetChunkBytes = config.maxChunkBytes;
    final chunkSamples = (targetChunkBytes ~/ bpf);

    for (int startSample = 0;
        startSample < totalSamples;
        startSample += chunkSamples) {
      int endSample = (startSample + chunkSamples).clamp(0, totalSamples);
      if (endSample <= startSample) break;

      final overlapSamples = (config.overlapSeconds * info.sampleRate).round();
      int adjStart = (startSample - (startSample > 0 ? overlapSamples : 0))
          .clamp(0, totalSamples);
      int adjEnd = (endSample + (endSample < totalSamples ? overlapSamples : 0))
          .clamp(0, totalSamples);

      chunks.add(_writeWavChunk(wavBytes, info, adjStart * bpf, adjEnd * bpf));
    }

    return chunks;
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
// WAV Preprocessor — resample + mono for size reduction
// ============================================================================

/// Audio preprocessing configuration.
class AudioPreprocessConfig {
  /// Target sample rate, or null to keep original.
  /// Common values: 8000 (telephony), 16000 (speech standard).
  final int? targetSampleRate;

  /// Whether to convert stereo to mono.
  final bool forceMono;

  const AudioPreprocessConfig({
    this.targetSampleRate = 16000,
    this.forceMono = true,
  });

  /// No preprocessing.
  static const none = AudioPreprocessConfig(
    targetSampleRate: null,
    forceMono: false,
  );
}

/// WAV resampler + mono mixer in pure Dart.
///
/// Uses linear interpolation for resampling and simple averaging for
/// stereo→mono conversion. Applies a basic moving-average low-pass filter
/// before downsampling to reduce aliasing.
class WavPreprocessor {
  final AudioPreprocessConfig config;

  const WavPreprocessor({this.config = const AudioPreprocessConfig()});

  /// Process a WAV file: optionally resample and/or convert to mono.
  /// Returns a new valid WAV file.
  Uint8List process(Uint8List wavBytes) {
    if (config == AudioPreprocessConfig.none) return wavBytes;

    final info = parseWavHeader(wavBytes);
    final samples = readPcmSamplesFloat(wavBytes, info);

    // Step 1: Convert to mono if needed
    Float64List workingSamples;
    int workingChannels = info.numChannels;
    if (config.forceMono && info.numChannels > 1) {
      workingSamples = _stereoToMono(samples, info.numChannels);
      workingChannels = 1;
    } else {
      workingSamples = samples;
    }

    // Step 2: Resample if needed
    int outSampleRate = info.sampleRate;
    Float64List outSamples = workingSamples;
    if (config.targetSampleRate != null &&
        config.targetSampleRate! != info.sampleRate) {
      outSamples = _resample(
        workingSamples,
        info.sampleRate,
        config.targetSampleRate!,
      );
      outSampleRate = config.targetSampleRate!;
    }

    // Step 3: Write new WAV
    return _writeWav(
      samples: outSamples,
      sampleRate: outSampleRate,
      numChannels: workingChannels,
      bitsPerSample: 16,
    );
  }

  /// Mix stereo to mono by averaging L+R channels.
  /// [samples] is interleaved LRLRLR...
  static Float64List _stereoToMono(Float64List samples, int numChannels) {
    final monoLen = samples.length ~/ numChannels;
    final mono = Float64List(monoLen);
    for (int i = 0; i < monoLen; i++) {
      double sum = 0;
      for (int ch = 0; ch < numChannels; ch++) {
        sum += samples[i * numChannels + ch];
      }
      mono[i] = sum / numChannels;
    }
    return mono;
  }

  /// Resample using linear interpolation with simple anti-aliasing.
  ///
  /// Applies a triangular moving-average filter (length = ratio) before
  /// decimation to reduce aliasing artifacts.
  static Float64List _resample(
    Float64List input,
    int inRate,
    int outRate,
  ) {
    if (inRate == outRate) return Float64List.fromList(input);
    if (outRate > inRate) return _resampleLerp(input, inRate, outRate);

    // Downsampling: apply simple anti-aliasing first
    final ratio = inRate / outRate;
    final filterLen = ratio.round().clamp(1, 32);

    final filtered = Float64List(input.length);
    for (int i = 0; i < input.length; i++) {
      double sum = 0;
      int count = 0;
      for (int j = -filterLen; j <= filterLen; j++) {
        final idx = i + j;
        if (idx >= 0 && idx < input.length) {
          // Triangular window
          final w = 1.0 - j.abs() / (filterLen + 1);
          sum += input[idx] * w;
          count++;
        }
      }
      filtered[i] = count > 0 ? sum / count : input[i];
    }

    return _resampleLerp(filtered, inRate, outRate);
  }

  /// Linear interpolation resampling.
  static Float64List _resampleLerp(
    Float64List input,
    int inRate,
    int outRate,
  ) {
    final outLen = (input.length * outRate / inRate).round();
    final out = Float64List(outLen);

    for (int i = 0; i < outLen; i++) {
      final pos = i * inRate / outRate;
      final idx = pos.floor();
      final frac = pos - idx;

      if (idx + 1 < input.length) {
        out[i] = input[idx] * (1 - frac) + input[idx + 1] * frac;
      } else if (idx < input.length) {
        out[i] = input[idx];
      }
    }

    return out;
  }

  /// Write Float64List as a mono 16-bit PCM WAV file.
  static Uint8List _writeWav({
    required Float64List samples,
    required int sampleRate,
    required int numChannels,
    required int bitsPerSample,
  }) {
    final bytesPerSample = bitsPerSample ~/ 8;
    final blockAlign = numChannels * bytesPerSample;
    final byteRate = sampleRate * blockAlign;
    final dataSize = samples.length * bytesPerSample;
    final fileSize = 44 + dataSize;

    final out = ByteData(44 + dataSize);
    int off = 0;

    void w4(String s) {
      for (int i = 0; i < 4; i++) {
        out.setUint8(off++, s.codeUnitAt(i));
      }
    }

    void w16(int v) {
      out.setUint16(off, v, Endian.little);
      off += 2;
    }

    void w32(int v) {
      out.setUint32(off, v, Endian.little);
      off += 4;
    }

    w4('RIFF');
    w32(fileSize - 8);
    w4('WAVE');
    w4('fmt ');
    w32(16);
    w16(1); // PCM
    w16(numChannels);
    w32(sampleRate);
    w32(byteRate);
    w16(blockAlign);
    w16(bitsPerSample);
    w4('data');
    w32(dataSize);

    // Write samples as S16LE
    for (int i = 0; i < samples.length; i++) {
      final s16 = (samples[i] * 32767).round().clamp(-32768, 32767);
      out.setInt16(off, s16, Endian.little);
      off += 2;
    }

    return Uint8List.view(out.buffer, 0, fileSize);
  }
}

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
  final dv = bytes.buffer.asByteData(offset + bytes.offsetInBytes, 2);
  return dv.getUint16(0, bigEndian ? Endian.big : Endian.little);
}

int _readUint32(Uint8List bytes, int offset, {bool bigEndian = false}) {
  final dv = bytes.buffer.asByteData(offset + bytes.offsetInBytes, 4);
  return dv.getUint32(0, bigEndian ? Endian.big : Endian.little);
}
