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
  /// In noisy environments, this threshold is dynamically raised relative
  /// to the detected noise floor.
  final double silenceDbThreshold;

  /// Minimum silence duration in seconds to consider as a split point.
  /// Default 0.5 seconds (500ms) — short enough to catch sentence pauses.
  /// In noisy environments, this is dynamically lengthened by [EnvironmentAnalyzer].
  final double minSilenceDuration;

  /// RMS analysis frame size in samples. Default 1024 (~23ms at 44.1kHz).
  final int frameSize;

  /// Overlap in seconds added before and after each cut point.
  /// In smart (silence-based) chunking, overlap is always 0 — chunks are
  /// strictly non-overlapping. For fixed-duration and fixed-size methods,
  /// overlap is also 0 by default since the new design avoids overlap entirely.
  /// Default 0.0s.
  final double overlapSeconds;

  /// Fixed duration per chunk in seconds (used by fixedDuration method).
  /// Default 60 seconds (1 minute).
  final double fixedDurationSeconds;

  /// Minimum chunk duration in seconds. Silence gaps that would produce a
  /// chunk below this duration are skipped (merged into adjacent chunk).
  /// Default 20.0 seconds (several sentences).
  final double minChunkDuration;

  /// Target chunk duration in seconds — the sweet spot the chunker aims for.
  /// The scorer prefers cut points that produce chunks close to this duration.
  /// Default 45.0 seconds.
  final double targetChunkDuration;

  /// Maximum chunk duration in seconds — hard limit.
  /// If no good cut point is found within [minChunkDuration..maxChunkDuration],
  /// the chunker force-cuts at the nearest energy valley to this boundary.
  /// Default 60.0 seconds.
  final double maxChunkDuration;

  /// Analysis window in seconds for looking before/after a candidate cut
  /// to assess transition quality and sentence-boundary likelihood.
  /// This is a JUDGMENT window only — output chunks are always non-overlapping.
  /// Default 1.5 seconds.
  final double analysisWindowSeconds;

  const AudioChunkConfig({
    this.maxChunkBytes = 25 * 1024 * 1024,
    this.silenceDbThreshold = -40.0,
    this.minSilenceDuration = 0.5,
    this.frameSize = 1024,
    this.overlapSeconds = 0.0,
    this.fixedDurationSeconds = 60.0,
    this.minChunkDuration = 20.0,
    this.targetChunkDuration = 45.0,
    this.maxChunkDuration = 60.0,
    this.analysisWindowSeconds = 1.5,
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
// Audio Environment Classification
// ============================================================================

/// The detected acoustic environment type.
///
/// Used to dynamically adjust silence thresholds, minimum silence duration,
/// and scoring weights for the smart chunker.
enum AudioEnvironment {
  /// Very low background noise — studio recording, quiet office.
  quiet,

  /// Typical conversational speech with moderate background.
  normalSpeech,

  /// Multi-person environment with variable noise levels.
  meeting,

  /// High background noise — street, cafe, subway.
  noisy,

  /// Continuous music, singing, or instrumental audio.
  music,

  /// Persistent background hum — AC, fan, wind noise.
  continuousNoise,
}

// ============================================================================
// Candidate Cut Point
// ============================================================================

/// A candidate cut point with a quality score.
///
/// Each candidate represents a potential split location (typically the
/// midpoint of a silence gap) with computed quality metrics.
class CandidateCut {
  /// Sample index in the original PCM data.
  final int samplePosition;

  /// Duration of the silence gap in seconds.
  final double silenceDuration;

  /// Confidence that this region is truly silent (0..1).
  /// 1.0 = very confident (deep silence), 0.0 = barely silent.
  final double silenceConfidence;

  /// Energy transition quality at this boundary (0..1).
  /// 1.0 = clean drop from speech to silence and back.
  final double transitionQuality;

  /// Likelihood this is a sentence/phrase boundary (0..1).
  /// Based on energy decline pattern before the gap.
  final double sentenceEndLikelihood;

  /// The computed total score (0..1). Higher = better cut point.
  double totalScore;

  CandidateCut({
    required this.samplePosition,
    required this.silenceDuration,
    required this.silenceConfidence,
    required this.transitionQuality,
    required this.sentenceEndLikelihood,
    this.totalScore = 0.0,
  });
}

// ============================================================================
// Environment Analyzer
// ============================================================================

/// Analyzes audio energy distribution to classify the acoustic environment
/// and adjust chunking parameters dynamically.
class EnvironmentAnalyzer {
  final int frameSize;
  final double silenceDbThreshold;

  const EnvironmentAnalyzer({
    this.frameSize = 1024,
    this.silenceDbThreshold = -40.0,
  });

  /// Analyze PCM samples to classify the audio environment.
  ///
  /// Returns [AudioEnvironment.normalSpeech] if the analysis cannot
  /// determine the environment confidently.
  AudioEnvironment analyze(Float64List samples, int sampleRate) {
    if (samples.length < frameSize) return AudioEnvironment.normalSpeech;

    final frameCount = samples.length ~/ frameSize;
    final dbValues = Float64List(frameCount);

    // Compute RMS dB for each frame
    for (int f = 0; f < frameCount; f++) {
      double sumSq = 0;
      final start = f * frameSize;
      final end = (start + frameSize).clamp(0, samples.length);
      for (int i = start; i < end; i++) {
        sumSq += samples[i] * samples[i];
      }
      final rms = sqrt(sumSq / (end - start));
      dbValues[f] = rms > 1e-10 ? 20 * log(rms) / ln10 : -100.0;
    }

    // Compute statistics
    final sorted = Float64List.fromList(dbValues)..sort();
    final noiseFloor = _percentile(sorted, 0.20);
    final peak = _percentile(sorted, 0.95);
    final dynamicRange = peak - noiseFloor;

    // Count frame types
    int silentFrames = 0;
    for (final db in dbValues) {
      if (db < noiseFloor + 6) silentFrames++;
    }
    final gapDensity = frameCount > 0 ? silentFrames / frameCount : 0.0;

    // Classification tree
    // ── Very low noise floor → quiet ──
    if (noiseFloor < -55 && gapDensity >= 0.05) {
      return AudioEnvironment.quiet;
    }

    // ── Moderate noise, good dynamic range → speech ──
    if (noiseFloor < -35) {
      if (dynamicRange > 25) return AudioEnvironment.normalSpeech;
      // Lower dynamic range with moderate noise → meeting
      if (gapDensity < 0.15) return AudioEnvironment.meeting;
      return AudioEnvironment.normalSpeech;
    }

    // ── High noise floor → noisy ──
    if (noiseFloor < -20) {
      if (dynamicRange < 15 && gapDensity < 0.1) {
        return AudioEnvironment.continuousNoise;
      }
      return AudioEnvironment.noisy;
    }

    // ── Very high energy, few gaps → music ──
    if (gapDensity < 0.05) {
      return AudioEnvironment.music;
    }

    return AudioEnvironment.noisy;
  }

  /// Get the environment-adjusted minimum silence duration in milliseconds.
  ///
  /// In noisy environments, the required silence is longer because
  /// absolute volume-based detection is less reliable.
  double adjustMinSilenceMs(AudioEnvironment env, double baseMs) {
    switch (env) {
      case AudioEnvironment.quiet:
        // Quiet environment: can detect brief pauses reliably
        return baseMs * 0.6;
      case AudioEnvironment.normalSpeech:
        return baseMs;
      case AudioEnvironment.meeting:
        // Multicast environment: require longer pauses to avoid mid-sentence cuts
        return baseMs * 1.3;
      case AudioEnvironment.noisy:
        // High background: need longer silence to be confident
        return baseMs * 1.8;
      case AudioEnvironment.music:
        // Music rarely has true silence — require very long gaps
        return baseMs * 3.0;
      case AudioEnvironment.continuousNoise:
        // Persistent hum: similar to noisy
        return baseMs * 2.0;
    }
  }

  /// Get the environment-adjusted silence dB threshold.
  ///
  /// In noisy environments, the threshold is raised relative to the
  /// noise floor to avoid false positives from background noise.
  double adjustSilenceDbThreshold(AudioEnvironment env, double baseDb) {
    switch (env) {
      case AudioEnvironment.quiet:
        return baseDb - 6; // lower → more sensitive
      case AudioEnvironment.normalSpeech:
        return baseDb;
      case AudioEnvironment.meeting:
        return baseDb + 3;
      case AudioEnvironment.noisy:
        return baseDb + 8;
      case AudioEnvironment.music:
        return baseDb + 15;
      case AudioEnvironment.continuousNoise:
        return baseDb + 10;
    }
  }

  /// Compute the nth percentile from a sorted list.
  static double _percentile(Float64List sorted, double fraction) {
    if (sorted.isEmpty) return -100.0;
    final index =
        (sorted.length * fraction).round().clamp(0, sorted.length - 1);
    return sorted[index];
  }
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
// RMS Frame Energy + Silence Gap Detection
// ============================================================================

/// A detected gap (silence or low-energy region) with quality metrics.
class _DetectedGap {
  final int startSample;
  final int endSample;
  final double durationSeconds;
  final double minDb; // deepest silence within the gap
  final double avgDb; // average dB across the gap

  const _DetectedGap({
    required this.startSample,
    required this.endSample,
    required this.durationSeconds,
    required this.minDb,
    required this.avgDb,
  });

  int get midSample => (startSample + endSample) ~/ 2;
}

/// Detect silence regions in PCM audio using RMS energy.
///
/// Enhanced to compute per-gap quality metrics (min depth, average level)
/// for the smart chunker's candidate scoring.
class SilenceDetector {
  final AudioChunkConfig config;

  const SilenceDetector(this.config);

  /// Analyze PCM samples and return silence regions with quality metrics.
  /// [samples] must be normalized float samples in [-1.0, 1.0].
  /// [sampleRate] is the audio sample rate.
  /// [dbThreshold] overrides [config.silenceDbThreshold] if provided
  /// (used for environment-adjusted thresholds).
  /// [minSilenceSec] overrides [config.minSilenceDuration] if provided.
  List<SilenceGap> detect(
    Float64List samples,
    int sampleRate, {
    double? dbThreshold,
    double? minSilenceSec,
  }) {
    final gaps = detectGaps(samples, sampleRate,
        dbThreshold: dbThreshold, minSilenceSec: minSilenceSec);
    return gaps
        .map((g) => SilenceGap(
              startSample: g.startSample,
              endSample: g.endSample,
              durationSeconds: g.durationSeconds,
            ))
        .toList();
  }

  /// Detect silence gaps with full quality metrics for candidate scoring.
  // ignore: library_private_types_in_public_api
  List<_DetectedGap> detectGaps(
    Float64List samples,
    int sampleRate, {
    double? dbThreshold,
    double? minSilenceSec,
  }) {
    final threshold = dbThreshold ?? config.silenceDbThreshold;
    final minSilenceS = minSilenceSec ?? config.minSilenceDuration;
    final frameSize = config.frameSize;
    final frameCount = samples.length ~/ frameSize;
    if (frameCount == 0) return [];
    final minSilentFrames =
        (minSilenceS * sampleRate / frameSize).ceil().clamp(1, frameCount);

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
      dbValues[f] = rms > 1e-10 ? 20 * log(rms) / ln10 : -100.0;
    }

    // Step 2: Find contiguous silent frames
    final gaps = <_DetectedGap>[];
    int? gapStart;
    double gapMinDb = 0;
    double gapSumDb = 0;
    int gapFrameCount = 0;

    for (int f = 0; f < frameCount; f++) {
      if (dbValues[f] < threshold) {
        if (gapStart == null) {
          gapStart = f;
          gapMinDb = dbValues[f];
          gapSumDb = dbValues[f];
          gapFrameCount = 1;
        } else {
          gapMinDb = gapMinDb < dbValues[f] ? gapMinDb : dbValues[f];
          gapSumDb += dbValues[f];
          gapFrameCount++;
        }
      } else {
        if (gapStart != null && (f - gapStart) >= minSilentFrames) {
          gaps.add(_DetectedGap(
            startSample: gapStart * frameSize,
            endSample: f * frameSize,
            durationSeconds: (f - gapStart) * frameSize / sampleRate,
            minDb: gapMinDb,
            avgDb: gapSumDb / gapFrameCount,
          ));
        }
        gapStart = null;
      }
    }

    // Trailing silence: excluded from cut points (belongs to last chunk).
    // No trailing gap is emitted — the last chunk naturally includes trailing
    // silence without creating a tiny silence-only chunk at the end.

    return gaps;
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
// Audio Chunker (smart silence-based splitting)
// ============================================================================

/// Splits a PCM WAV file into chunks suitable for ASR transcription.
///
/// The smart chunking strategy:
/// 1. Parse WAV header → sample rate, channels, data offset
/// 2. Convert PCM to float samples
/// 3. Analyze audio environment (noise floor, dynamic range, gap density)
/// 4. Adjust thresholds dynamically based on environment
/// 5. Detect silence gaps with quality metrics (depth, average level)
/// 6. Convert gaps to candidate cut points with multi-factor scoring:
///    - Silence duration (longer is better)
///    - Silence depth / confidence
///    - Proximity to target chunk duration
///    - Transition quality (clean drop/rise)
///    - Sentence-boundary likelihood (energy decline pattern)
/// 7. Greedy selection: in range [minChunk, maxChunk], pick best candidate
/// 8. If no candidate: force-cut at maxChunkDuration boundary (nearest energy valley)
/// 9. Output strictly NON-overlapping chunks as valid WAV files
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

  /// Split a WAV file into chunks using smart silence-based detection.
  ///
  /// Uses environmental analysis + candidate scoring + greedy selection.
  /// Falls back to forced chunking if no silence candidates are available.
  List<Uint8List> split(Uint8List wavBytes) {
    // Step 1: Parse header
    final info = parseWavHeader(wavBytes);

    // Step 2: Read PCM as float
    final samples = readPcmSamplesFloat(wavBytes, info);

    // Step 3: Environment analysis → dynamic parameters
    final envAnalyzer = EnvironmentAnalyzer(
      frameSize: config.frameSize,
      silenceDbThreshold: config.silenceDbThreshold,
    );
    final env = envAnalyzer.analyze(samples, info.sampleRate);
    final adjustedMinSilenceS =
        envAnalyzer.adjustMinSilenceMs(env, config.minSilenceDuration * 1000) /
            1000.0;
    final adjustedDbThreshold =
        envAnalyzer.adjustSilenceDbThreshold(env, config.silenceDbThreshold);

    // Step 4: Detect silence gaps with full quality metrics
    final detector = SilenceDetector(config);
    final allGaps = detector.detectGaps(
      samples,
      info.sampleRate,
      dbThreshold: adjustedDbThreshold,
      minSilenceSec: adjustedMinSilenceS,
    );

    // Step 5: Build candidate cut points from gaps
    // Pass the environment-adjusted threshold so confidence scoring reflects
    // the actual detection conditions, not the base default.
    final candidates = _buildCandidates(
        allGaps, samples, info.sampleRate, adjustedDbThreshold);

    // Step 6: Greedy cut selection
    final totalSamples = info.totalSamples;
    final minChunkSamples = (config.minChunkDuration * info.sampleRate).round();
    final targetChunkSamples =
        (config.targetChunkDuration * info.sampleRate).round();
    final maxChunkSamples = (config.maxChunkDuration * info.sampleRate).round();

    final selectedCuts = _selectCutPoints(
      candidates,
      totalSamples: totalSamples,
      minChunkSamples: minChunkSamples,
      targetChunkSamples: targetChunkSamples,
      maxChunkSamples: maxChunkSamples,
      sampleRate: info.sampleRate,
    );

    // Step 7: Convert cut samples to byte offsets (NO overlap)
    final pcmDataOffset = info.dataOffset;
    final bpf = info.bytesPerFrame;

    final byteCuts = <int>[];
    for (final sample in selectedCuts) {
      int byte = pcmDataOffset + (sample * bpf);
      byte = byte.clamp(pcmDataOffset, pcmDataOffset + info.dataSize);
      byteCuts.add(byte);
    }

    // Step 8: Build chunks from byte ranges, enforcing maxChunkBytes
    final chunks = <Uint8List>[];
    for (int i = 0; i < byteCuts.length - 1; i++) {
      final start = byteCuts[i];
      final end = byteCuts[i + 1];
      if (end <= start) continue;

      final chunkBytes = end - start;
      if (chunkBytes <= config.maxChunkBytes) {
        chunks.add(_writeWavChunk(
            wavBytes, info, start - pcmDataOffset, end - pcmDataOffset));
      } else {
        // Sub-split to stay under maxChunkBytes
        final numParts = (chunkBytes / config.maxChunkBytes).ceil();
        for (int p = 0; p < numParts; p++) {
          final subStart = start + (chunkBytes * p) ~/ numParts;
          final subEnd = start + (chunkBytes * (p + 1)) ~/ numParts;
          if (subEnd > subStart) {
            chunks.add(_writeWavChunk(wavBytes, info, subStart - pcmDataOffset,
                subEnd - pcmDataOffset));
          }
        }
      }
    }

    return chunks;
  }

  /// Build [CandidateCut] objects from detected gaps with quality metrics.
  /// [adjustedDbThreshold] is the environment-adjusted silence dB threshold
  /// used during actual gap detection — confidence is computed relative to this.
  List<CandidateCut> _buildCandidates(
    List<_DetectedGap> gaps,
    Float64List samples,
    int sampleRate,
    double adjustedDbThreshold,
  ) {
    final frameSize = config.frameSize;
    final candidates = <CandidateCut>[];

    for (final gap in gaps) {
      // 1. Silence confidence: based on how deep the silence is relative to
      // the threshold that was actually used for detection (environment-adjusted).
      final depthBelowThreshold = adjustedDbThreshold - gap.minDb;
      // Normalize: 6dB below threshold = 0.5, 20dB below = 1.0
      final silenceConf = (depthBelowThreshold / 20.0).clamp(0.0, 1.0);

      // 2. Transition quality: energy drop before and after the gap
      final transition = _computeTransitionQuality(
          samples, gap.startSample, gap.endSample, frameSize);

      // 3. Sentence-end likelihood: energy decline pattern before gap
      final sentenceEnd = _computeSentenceEndLikelihood(
          samples, gap.startSample, frameSize, sampleRate);

      candidates.add(CandidateCut(
        samplePosition: gap.midSample,
        silenceDuration: gap.durationSeconds,
        silenceConfidence: silenceConf,
        transitionQuality: transition,
        sentenceEndLikelihood: sentenceEnd,
      ));
    }

    return candidates;
  }

  /// Compute how clean the energy transition is at a silence gap boundary.
  ///
  /// Looks at the energy envelope before and after the gap:
  /// - A clean transition: energy drops significantly before gap, rises after
  /// - A noisy transition: energy fluctuates on either side
  double _computeTransitionQuality(
    Float64List samples,
    int gapStartSample,
    int gapEndSample,
    int frameSize,
  ) {
    // Look at frames before the gap (pre-gap energy)
    double preGapMax = 0;
    final preStart = (gapStartSample - frameSize * 3).clamp(0, gapStartSample);
    final preEnd = gapStartSample;
    for (int i = preStart; i < preEnd; i++) {
      final absVal = samples[i].abs();
      if (absVal > preGapMax) preGapMax = absVal;
    }

    // Look at frames after the gap (post-gap energy)
    double postGapMax = 0;
    final postStart = gapEndSample;
    final postEnd = (gapEndSample + frameSize * 3).clamp(0, samples.length);
    for (int i = postStart; i < postEnd; i++) {
      final absVal = samples[i].abs();
      if (absVal > postGapMax) postGapMax = absVal;
    }

    // A good transition: pre-gap energy is meaningful, gap is deep,
    // post-gap energy resumes cleanly.
    // Score based on pre/post energy ratio (should be balanced)
    final preDb = preGapMax > 1e-6 ? 20 * log(preGapMax) / ln10 : -100;
    final postDb = postGapMax > 1e-6 ? 20 * log(postGapMax) / ln10 : -100;

    // How similar are pre and post levels? Similar = natural sentence boundary.
    final levelDiff = (preDb - postDb).abs();
    final levelScore = (1.0 - (levelDiff / 30.0)).clamp(0.0, 1.0);

    return levelScore;
  }

  /// Estimate whether the energy decline before a gap looks like a sentence end.
  ///
  /// A sentence end typically shows a gradual energy decline over ~1-2 seconds
  /// rather than an abrupt drop (which would indicate an interruption).
  double _computeSentenceEndLikelihood(
    Float64List samples,
    int gapStartSample,
    int frameSize,
    int sampleRate,
  ) {
    // Look at ~1.5 seconds before the gap
    final windowFrames = (1.5 * sampleRate / frameSize).round().clamp(3, 30);
    final frames = <double>[];
    for (int f = 0; f < windowFrames; f++) {
      final start = (gapStartSample - (windowFrames - f) * frameSize)
          .clamp(0, samples.length);
      final end = (start + frameSize).clamp(0, samples.length);
      double sumAbs = 0;
      for (int i = start; i < end; i++) {
        sumAbs += samples[i].abs();
      }
      frames.add(sumAbs / (end - start));
    }

    if (frames.length < 3) return 0.5;

    // Check if energy is declining (first half > second half)
    final midpoint = frames.length ~/ 2;
    double firstHalf = 0, secondHalf = 0;
    for (int i = 0; i < midpoint; i++) {
      firstHalf += frames[i];
    }
    for (int i = midpoint; i < frames.length; i++) {
      secondHalf += frames[i];
    }
    firstHalf /= midpoint;
    secondHalf /= (frames.length - midpoint);

    if (firstHalf <= 0) return 0.5;

    // decline ratio: 1.0 = complete silence, 0.5 = no change, <0.5 = rising
    final declineRatio = (firstHalf - secondHalf) / firstHalf;
    // Map: declineRatio 0 → 0.3, declineRatio 0.5 → 0.8, declineRatio 1.0 → 1.0
    return (0.3 + declineRatio * 1.4).clamp(0.0, 1.0);
  }

  /// Greedy select cut points that produce chunks within
  /// [minChunkSamples..maxChunkSamples], preferring cuts near
  /// [targetChunkSamples].
  ///
  /// Algorithm:
  /// 1. Start at position 0
  /// 2. Search forward for candidates in [minChunk, maxChunk] range
  /// 3. Score each candidate dynamically (position-dependent, since target
  ///    proximity is relative to the current position)
  /// 4. Pick the highest-scoring candidate
  /// 5. If no candidate in range: force-cut at maxChunk or at the
  ///    nearest energy valley
  /// 6. Repeat until end of audio
  List<int> _selectCutPoints(
    List<CandidateCut> candidates, {
    required int totalSamples,
    required int minChunkSamples,
    required int targetChunkSamples,
    required int maxChunkSamples,
    required int sampleRate,
  }) {
    final cuts = <int>[0];

    // Early return only if audio is too short to warrant any chunking at all.
    if (totalSamples <= minChunkSamples) {
      cuts.add(totalSamples);
      return cuts;
    }

    int currentSample = 0;

    while (currentSample + minChunkSamples < totalSamples) {
      final searchEnd =
          (currentSample + maxChunkSamples).clamp(0, totalSamples);
      final searchStart = currentSample + minChunkSamples;

      // Find candidates in the search range
      final inRange = candidates
          .where((c) =>
              c.samplePosition >= searchStart && c.samplePosition <= searchEnd)
          .toList();

      if (inRange.isEmpty) {
        // ── No candidate in range — force-cut ──
        if (searchEnd >= totalSamples) {
          break; // rest is the final chunk
        }

        // Find the nearest candidate to maxChunk boundary
        // or force-cut at maxChunk position
        final forcePos = _findForceCutPosition(
          candidates,
          currentSample + maxChunkSamples,
          totalSamples,
          sampleRate,
        );
        cuts.add(forcePos);
        currentSample = forcePos;
        continue;
      }

      // ── Score each candidate dynamically ──
      CandidateCut? best;
      double bestScore = -1;

      for (final c in inRange) {
        final score = _scoreCandidate(c, currentSample, targetChunkSamples,
            minChunkSamples, maxChunkSamples, sampleRate);
        c.totalScore = score;
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }

      // Even the best might be poor — if below a quality floor, consider
      // whether we should continue searching or force-cut.
      if (best == null || bestScore < 0.15) {
        // Quality too low: force-cut at max boundary
        final forcePos = _findForceCutPosition(
          candidates,
          currentSample + maxChunkSamples,
          totalSamples,
          sampleRate,
        );
        cuts.add(forcePos);
        currentSample = forcePos;
      } else {
        cuts.add(best.samplePosition);
        currentSample = best.samplePosition;
      }
    }

    cuts.add(totalSamples);
    return cuts;
  }

  /// Score a candidate cut point considering its position relative to current position.
  double _scoreCandidate(
    CandidateCut c,
    int currentSample,
    int targetChunkSamples,
    int minChunkSamples,
    int maxChunkSamples,
    int sampleRate,
  ) {
    final chunkSamples = c.samplePosition - currentSample;

    // 1. Silence quality (35%)
    final silenceScore = _silenceQualityScore(c);

    // 2. Target proximity (25%) — Gaussian around target
    final sigma = targetChunkSamples * 0.3;
    final diff = (chunkSamples - targetChunkSamples).toDouble();
    final targetScore = exp(-(diff * diff) / (2 * sigma * sigma));

    // 3. VAD / silence confidence (25%)
    final vadScore = c.silenceConfidence;

    // 4. Transition quality (10%)
    final transitionScore = c.transitionQuality;

    // 5. Sentence boundary (5%)
    final sentenceScore = c.sentenceEndLikelihood;

    return silenceScore * 0.35 +
        targetScore * 0.25 +
        vadScore * 0.25 +
        transitionScore * 0.10 +
        sentenceScore * 0.05;
  }

  /// Score based on silence duration — logarithmic, saturates at ~4× minSilence.
  double _silenceQualityScore(CandidateCut c) {
    final ratio = c.silenceDuration / config.minSilenceDuration.clamp(0.1, 10);
    // log base 4: at 1× → 0.5, at 4× → 1.0
    return (log(ratio + 1) / log(5)).clamp(0.0, 1.0);
  }

  /// Find a forced cut position near [preferredPos].
  ///
  /// If there's a candidate within a small window around preferredPos,
  /// use it. Otherwise, hard-cut at preferredPos (or totalSamples if past end).
  int _findForceCutPosition(
    List<CandidateCut> candidates,
    int preferredPos,
    int totalSamples,
    int sampleRate,
  ) {
    if (preferredPos >= totalSamples) return totalSamples;

    // Search for candidates within ±3s of preferredPos
    final windowSamples = (3 * sampleRate).round();
    CandidateCut? nearest;
    int nearestDist = windowSamples + 1;

    for (final c in candidates) {
      final dist = (c.samplePosition - preferredPos).abs();
      if (dist < nearestDist && dist <= windowSamples) {
        nearest = c;
        nearestDist = dist;
      }
    }

    if (nearest != null) return nearest.samplePosition;

    return preferredPos.clamp(0, totalSamples);
  }

  /// Split WAV into chunks of fixed [config.fixedDurationSeconds] seconds.
  /// No overlap — chunks are strictly consecutive.
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

      final adjBytes = (endSample - startSample) * bpf;
      if (adjBytes <= config.maxChunkBytes) {
        chunks.add(
            _writeWavChunk(wavBytes, info, startSample * bpf, endSample * bpf));
      } else {
        // Sub-split evenly to stay within maxChunkBytes
        final numParts = (adjBytes / config.maxChunkBytes).ceil();
        for (int p = 0; p < numParts; p++) {
          final subStart =
              startSample + ((endSample - startSample) * p) ~/ numParts;
          final subEnd =
              startSample + ((endSample - startSample) * (p + 1)) ~/ numParts;
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
  /// Simple byte-count splitting — no silence awareness, no overlap.
  List<Uint8List> splitBySize(Uint8List wavBytes) {
    final info = parseWavHeader(wavBytes);
    final bpf = info.bytesPerFrame;
    final totalSamples = info.totalSamples;
    final chunks = <Uint8List>[];

    final chunkSamples = (config.maxChunkBytes ~/ bpf).clamp(1, totalSamples);

    for (int startSample = 0;
        startSample < totalSamples;
        startSample += chunkSamples) {
      int endSample = (startSample + chunkSamples).clamp(0, totalSamples);
      if (endSample <= startSample) break;

      chunks.add(
          _writeWavChunk(wavBytes, info, startSample * bpf, endSample * bpf));
    }

    return chunks;
  }
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
