import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import 'cancellable_compute.dart';

// Keep derived counts exact when the chunker runs with JavaScript numbers.
const _maxSafeInteger = 9007199254740991;
const _webYieldSortOperationCount = 4096;
const _webYieldCutWorkCount = 1024;
const _webYieldPcmSampleCount = 16384;

Future<void> _yieldWebAnalysis(
  void Function()? onYield, {
  void Function()? checkCancelled,
}) async {
  onYield?.call();
  await Future<void>.delayed(Duration.zero);
  checkCancelled?.call();
}

class _WebPcmWorkBudget {
  final void Function()? onYield;
  final void Function()? checkCancelled;
  int _samplesSinceYield = 0;

  _WebPcmWorkBudget(this.onYield, this.checkCancelled);

  bool recordSample() {
    _samplesSinceYield++;
    if (_samplesSinceYield < _webYieldPcmSampleCount) return false;
    _samplesSinceYield = 0;
    return true;
  }

  Future<void> yieldEventLoop() =>
      _yieldWebAnalysis(onYield, checkCancelled: checkCancelled);
}

void Function()? _cancellationCheck(
  void Function()? checkCancelled,
  Future<Object?>? cancellationSignal,
) {
  if (cancellationSignal == null) return checkCancelled;
  var isCancelled = false;
  Object? cancellationReason;
  cancellationSignal.then<void>(
    (reason) {
      isCancelled = true;
      cancellationReason = reason;
    },
    onError: (Object error, StackTrace stackTrace) {
      isCancelled = true;
      cancellationReason = error;
    },
  );
  return () {
    checkCancelled?.call();
    if (isCancelled) {
      final reason = cancellationReason;
      if (reason != null) throw reason;
      throw StateError('Audio processing was cancelled.');
    }
  };
}

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

  /// Number of complete time-domain frames (one sample per channel).
  int get totalSamples => dataSize ~/ bytesPerFrame;
  double get durationSeconds => totalSamples / sampleRate;
}

class _ParsedWavHeader {
  final WavInfo info;
  final int audioFormat;
  final int? samplesPerBlock;
  final int? factSampleCount;

  const _ParsedWavHeader({
    required this.info,
    required this.audioFormat,
    required this.samplesPerBlock,
    required this.factSampleCount,
  });

  double get passThroughDurationSeconds {
    if (audioFormat == 0x0002 || audioFormat == 0x0011) {
      final blockSampleCount = samplesPerBlock;
      if (blockSampleCount != null) {
        final decodedSampleCount = factSampleCount ??
            (info.dataSize ~/ info.blockAlign) * blockSampleCount;
        return decodedSampleCount / info.sampleRate;
      }
    }
    return info.dataSize / info.byteRate;
  }
}

/// A byte range into a WAV source and the corresponding time range.
class AudioChunk {
  final int startByte;
  final int endByte;
  final double startSecond;
  final double endSecond;
  final bool isOriginal;

  const AudioChunk({
    required this.startByte,
    required this.endByte,
    required this.startSecond,
    required this.endSecond,
    this.isOriginal = false,
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

  /// Reject settings that make chunk boundaries undefined or arithmetic
  /// unstable. Input-rate-dependent limits are checked by
  /// [validateForSampleRate].
  void validate() {
    if (maxChunkBytes <= 0) {
      throw ArgumentError.value(maxChunkBytes, 'maxChunkBytes');
    }
    if (!silenceDbThreshold.isFinite || silenceDbThreshold >= 0) {
      throw ArgumentError.value(silenceDbThreshold, 'silenceDbThreshold');
    }
    if (!minSilenceDuration.isFinite || minSilenceDuration <= 0) {
      throw ArgumentError.value(minSilenceDuration, 'minSilenceDuration');
    }
    if (frameSize <= 0) {
      throw ArgumentError.value(frameSize, 'frameSize');
    }
    if (!overlapSeconds.isFinite || overlapSeconds < 0) {
      throw ArgumentError.value(overlapSeconds, 'overlapSeconds');
    }
    if (!fixedDurationSeconds.isFinite || fixedDurationSeconds <= 0) {
      throw ArgumentError.value(fixedDurationSeconds, 'fixedDurationSeconds');
    }
    if (!minChunkDuration.isFinite || minChunkDuration <= 0) {
      throw ArgumentError.value(minChunkDuration, 'minChunkDuration');
    }
    if (!targetChunkDuration.isFinite ||
        targetChunkDuration < minChunkDuration) {
      throw ArgumentError.value(targetChunkDuration, 'targetChunkDuration');
    }
    if (!maxChunkDuration.isFinite || maxChunkDuration < targetChunkDuration) {
      throw ArgumentError.value(maxChunkDuration, 'maxChunkDuration');
    }
    if (!analysisWindowSeconds.isFinite || analysisWindowSeconds <= 0) {
      throw ArgumentError.value(analysisWindowSeconds, 'analysisWindowSeconds');
    }
  }

  void validateForSampleRate(int sampleRate) {
    validate();
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate');
    }

    for (final (name, duration) in <(String, double)>[
      ('fixedDurationSeconds', fixedDurationSeconds),
      ('minChunkDuration', minChunkDuration),
      ('targetChunkDuration', targetChunkDuration),
      ('maxChunkDuration', maxChunkDuration),
    ]) {
      final samples = duration * sampleRate;
      if (!samples.isFinite || samples < 1 || samples > _maxSafeInteger) {
        throw ArgumentError.value(duration, name);
      }
    }

    final analysisFrames = analysisWindowSeconds * sampleRate / frameSize;
    final silenceFrames = minSilenceDuration * sampleRate / frameSize;
    if (!analysisFrames.isFinite || analysisFrames > _maxSafeInteger) {
      throw ArgumentError.value(analysisWindowSeconds, 'analysisWindowSeconds');
    }
    if (!silenceFrames.isFinite ||
        silenceFrames > _maxSafeInteger ||
        !(minSilenceDuration * 1000).isFinite) {
      throw ArgumentError.value(minSilenceDuration, 'minSilenceDuration');
    }
  }
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
  /// Time-domain frame index in the original PCM data.
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

  /// Analyze pre-computed per-frame dB values to classify the audio environment.
  /// Avoids recomputing frame energies that were already calculated for
  /// silence gap detection.
  AudioEnvironment analyzeFromDb(Float64List dbValues) {
    if (dbValues.isEmpty) return AudioEnvironment.normalSpeech;

    final sorted = Float64List.fromList(dbValues)..sort();
    return _classifyFromDbAndSorted(dbValues, sorted);
  }

  /// Web-compatible classification that yields while sorting and measuring
  /// long frame lists. The sorted values preserve the same percentile inputs
  /// as [analyzeFromDb].
  Future<AudioEnvironment> analyzeFromDbWithEventLoopYield(
    Float64List dbValues, {
    void Function()? onYield,
    void Function()? checkCancelled,
  }) async {
    checkCancelled?.call();
    if (dbValues.isEmpty) return AudioEnvironment.normalSpeech;

    final sorted = await _sortDbValuesWithEventLoopYield(
      dbValues,
      onYield: onYield,
      checkCancelled: checkCancelled,
    );
    final noiseFloor = _percentile(sorted, 0.20);
    final peak = _percentile(sorted, 0.95);
    final dynamicRange = peak - noiseFloor;

    int silentFrames = 0;
    for (var index = 0; index < dbValues.length; index++) {
      final db = dbValues[index];
      if (db < noiseFloor + 6) silentFrames++;
      if ((index + 1) % _webYieldAnalysisFrameCount == 0 &&
          index + 1 < dbValues.length) {
        await _yieldWebAnalysis(onYield, checkCancelled: checkCancelled);
      }
    }
    final gapDensity =
        dbValues.isNotEmpty ? silentFrames / dbValues.length : 0.0;

    return _classifyFromStatistics(noiseFloor, peak, dynamicRange, gapDensity);
  }

  AudioEnvironment _classifyFromDbAndSorted(
    Float64List dbValues,
    Float64List sorted,
  ) {
    final noiseFloor = _percentile(sorted, 0.20);
    final peak = _percentile(sorted, 0.95);
    final dynamicRange = peak - noiseFloor;
    var silentFrames = 0;
    for (final db in dbValues) {
      if (db < noiseFloor + 6) silentFrames++;
    }
    final gapDensity =
        dbValues.isNotEmpty ? silentFrames / dbValues.length : 0.0;
    return _classifyFromStatistics(noiseFloor, peak, dynamicRange, gapDensity);
  }

  AudioEnvironment _classifyFromStatistics(
    double noiseFloor,
    double peak,
    double dynamicRange,
    double gapDensity,
  ) {
    // Classification tree (same logic as analyze())
    if (noiseFloor < -55 && gapDensity >= 0.05) return AudioEnvironment.quiet;
    if (noiseFloor < -35) {
      if (dynamicRange > 25) return AudioEnvironment.normalSpeech;
      if (gapDensity < 0.15) return AudioEnvironment.meeting;
      return AudioEnvironment.normalSpeech;
    }
    if (noiseFloor < -20) {
      if (dynamicRange < 15 && gapDensity < 0.1) {
        return AudioEnvironment.continuousNoise;
      }
      return AudioEnvironment.noisy;
    }
    if (gapDensity < 0.05) return AudioEnvironment.music;
    return AudioEnvironment.noisy;
  }

  Future<Float64List> _sortDbValuesWithEventLoopYield(
    Float64List values, {
    void Function()? onYield,
    void Function()? checkCancelled,
  }) async {
    var source = Float64List.fromList(values);
    if (source.length < 2) return source;
    var target = Float64List(source.length);
    var operations = 0;
    for (var width = 1; width < source.length; width *= 2) {
      for (var start = 0; start < source.length; start += width * 2) {
        final middle = (start + width).clamp(0, source.length);
        final end = (start + width * 2).clamp(0, source.length);
        var left = start;
        var right = middle;
        var output = start;
        while (left < middle || right < end) {
          if (right >= end ||
              (left < middle && source[left] <= source[right])) {
            target[output++] = source[left++];
          } else {
            target[output++] = source[right++];
          }
          operations++;
          if (operations % _webYieldSortOperationCount == 0 &&
              output < source.length) {
            await _yieldWebAnalysis(onYield, checkCancelled: checkCancelled);
          }
        }
      }
      final previousSource = source;
      source = target;
      target = previousSource;
    }
    return source;
  }

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

  /// Compute the nth percentile from a sorted list using nearest-rank method.
  static double _percentile(Float64List sorted, double fraction) {
    if (sorted.isEmpty) return -100.0;
    // Nearest-rank: ceil(P * N) - 1. E.g., N=10, P=0.20 → ceil(2)-1 = 1
    // which is the 20th percentile (2nd of 10 values, 0-indexed).
    final index = (sorted.length * fraction).ceil().clamp(1, sorted.length) - 1;
    return sorted[index];
  }
}

// ============================================================================
// WAV Header Parser (based on FFmpeg wavdec.c + riffdec.c)
// ============================================================================

/// Parse a little-endian PCM WAV header for the PCM chunker.
///
/// Requires 16-bit integer PCM. RIFX is rejected because its samples are
/// big-endian. Throws [FormatException] if the file or its PCM metadata is
/// invalid.
WavInfo parseWavHeader(Uint8List bytes) =>
    _parseWavHeader(bytes, allowNonPcm: false).info;

/// Validate a complete RIFF/WAVE container before uploading it.
///
/// This checks RIFF/chunk bounds and required base metadata for PCM and
/// compressed WAVE formats. Compressed formats are allowed through here; the
/// PCM-only chunker still uses [parseWavHeader].
void validateWavContainer(Uint8List bytes) =>
    _parseWavHeader(bytes, allowNonPcm: true);

double _passThroughDurationSeconds(Uint8List bytes) {
  try {
    return _parseWavHeader(bytes, allowNonPcm: true).passThroughDurationSeconds;
  } on FormatException {
    // AudioChunkMethod.none preserves the legacy pass-through behavior for
    // non-WAV and unsupported WAV inputs, which have no known duration here.
    return 0;
  }
}

const _supportedWavAudioFormatTags = <int>{
  0x0001, // PCM
  0x0002, // Microsoft ADPCM
  0x0003, // IEEE float
  0x0006, // A-law
  0x0007, // mu-law
  0x0011, // IMA/DVI ADPCM
};

_ParsedWavHeader _parseWavHeader(Uint8List bytes, {required bool allowNonPcm}) {
  if (bytes.length < 12) {
    throw FormatException('Truncated WAV header');
  }

  final riffTag = _readFourCC(bytes, 0);
  if (riffTag == 'RIFX') {
    throw FormatException('RIFX big-endian WAV is unsupported');
  }
  if (riffTag != 'RIFF') {
    throw FormatException('Not a little-endian RIFF/WAV file: $riffTag');
  }

  final riffSize = _readUint32(bytes, 4);
  if (riffSize < 4) {
    throw FormatException('Invalid RIFF container size: $riffSize');
  }
  final containerEnd = 8 + riffSize;
  if (containerEnd > bytes.length) {
    throw FormatException(
      'Truncated WAV container: RIFF claims $containerEnd bytes but only '
      '${bytes.length} are present',
    );
  }

  final waveTag = _readFourCC(bytes, 8);
  if (waveTag != 'WAVE') {
    throw FormatException('Not a WAV file: expected WAVE, got $waveTag');
  }

  // --- Scan chunks inside the RIFF container ---
  var offset = 12;
  int? sampleRate;
  int? numChannels;
  int? bitsPerSample;
  int? byteRate;
  int? blockAlign;
  int? fmtExtensionSize;
  int? imaSamplesPerBlock;
  int? msAdpcmSamplesPerBlock;
  int? msAdpcmCoefficientCount;
  int? extensibleValidBitsPerSample;
  int? extensibleChannelMask;
  bool hasExtensibleFormat = false;
  int audioFormat = 0;
  int? dataOffset;
  int? dataSize;
  int? factSampleCount;
  bool gotFmt = false;

  while (offset < containerEnd) {
    if (containerEnd - offset < 8) {
      throw FormatException('Truncated WAV chunk header at byte $offset');
    }

    final tag = _readFourCC(bytes, offset);
    offset += 4;
    final size = _readUint32(bytes, offset);
    offset += 4;

    // Every RIFF chunk is padded to an even byte boundary.
    final paddedSize = size + (size.isOdd ? 1 : 0);
    if (paddedSize > containerEnd - offset) {
      throw FormatException(
        'WAV chunk $tag claims $size bytes beyond the RIFF container',
      );
    }
    final nextChunk = offset + paddedSize;

    switch (tag) {
      case 'fmt ':
        if (gotFmt) {
          offset = nextChunk;
          break;
        }

        if (size < 16) {
          throw FormatException('fmt chunk too small: $size bytes');
        }

        final fmtOffset = offset;
        audioFormat = _readUint16(bytes, offset);
        offset += 2;
        numChannels = _readUint16(bytes, offset);
        offset += 2;
        sampleRate = _readUint32(bytes, offset);
        offset += 4;
        byteRate = _readUint32(bytes, offset);
        offset += 4;
        blockAlign = _readUint16(bytes, offset);
        offset += 2;
        bitsPerSample = _readUint16(bytes, offset);

        var extensionSize = 0;
        if (size > 16) {
          if (size < 18) {
            throw FormatException('fmt chunk is missing its cbSize field');
          }
          extensionSize = _readUint16(bytes, fmtOffset + 16);
          if (extensionSize > size - 18) {
            throw FormatException(
              'fmt extension claims $extensionSize bytes but only '
              '${size - 18} are present',
            );
          }
        }

        if (audioFormat == 0xfffe) {
          hasExtensibleFormat = true;
          if (size < 40 || extensionSize < 22) {
            throw FormatException(
              'WAVE_FORMAT_EXTENSIBLE fmt chunk must contain its 22-byte '
              'extension',
            );
          }
          final validBitsPerSample = _readUint16(bytes, fmtOffset + 18);
          extensibleValidBitsPerSample = validBitsPerSample;
          extensibleChannelMask = _readUint32(bytes, fmtOffset + 20);
          if (validBitsPerSample <= 0 || validBitsPerSample > bitsPerSample) {
            throw FormatException(
              'Invalid WAVE_FORMAT_EXTENSIBLE valid bits: '
              '$validBitsPerSample',
            );
          }

          final subtypeFormatTag = _readUint16(bytes, fmtOffset + 24);
          final subtypeFormatTagHigh = _readUint16(bytes, fmtOffset + 26);
          const supportedSubtypeGuidSuffix = <int>[
            0x00, 0x00, // Data2
            0x10, 0x00, // Data3
            0x80, 0x00, 0x00, 0xaa, 0x00, 0x38, 0x9b, 0x71, // Data4
          ];
          var hasSupportedGuidSuffix = true;
          for (var index = 0;
              index < supportedSubtypeGuidSuffix.length;
              index++) {
            if (bytes[fmtOffset + 28 + index] !=
                supportedSubtypeGuidSuffix[index]) {
              hasSupportedGuidSuffix = false;
              break;
            }
          }
          if (subtypeFormatTagHigh != 0 ||
              !hasSupportedGuidSuffix ||
              !_supportedWavAudioFormatTags.contains(subtypeFormatTag)) {
            throw FormatException(
              'Unsupported WAVE_FORMAT_EXTENSIBLE subtype GUID or format tag',
            );
          }
          if (subtypeFormatTag != 1 && !allowNonPcm) {
            throw FormatException(
              'Unsupported WAVE_FORMAT_EXTENSIBLE subtype GUID',
            );
          }
          // The structural validator retains supported compressed subtypes;
          // the PCM-only path rejects them explicitly above.
          audioFormat = subtypeFormatTag;
        }

        fmtExtensionSize = extensionSize;
        if (audioFormat == 0x0002 && size >= 22) {
          msAdpcmSamplesPerBlock = _readUint16(bytes, fmtOffset + 18);
          msAdpcmCoefficientCount = _readUint16(bytes, fmtOffset + 20);
        }
        if (audioFormat == 0x0011 && size >= 20) {
          imaSamplesPerBlock = _readUint16(bytes, fmtOffset + 18);
        }

        // Preserve valid WAVEFORMATEX extensions by skipping the remaining
        // bytes in this bounded fmt chunk.
        offset = nextChunk;

        gotFmt = true;
        break;

      case 'data':
        if (!gotFmt) {
          throw FormatException('data chunk before fmt chunk');
        }
        if (dataOffset != null) {
          throw const FormatException(
            'Multiple WAV data chunks are unsupported',
          );
        }
        dataOffset = offset;
        dataSize = size;
        offset = nextChunk;
        break;

      case 'fact':
        if (factSampleCount == null && size >= 4) {
          factSampleCount = _readUint32(bytes, offset);
        }
        offset = nextChunk;
        break;

      default:
        // Ignore metadata chunks such as LIST/JUNK while respecting their
        // declared bounds and padding.
        offset = nextChunk;
        break;
    }
  }

  if (!gotFmt) throw FormatException('No fmt chunk found in WAV');
  if (dataOffset == null) throw FormatException('No data chunk found in WAV');

  if (audioFormat == 0) {
    throw const FormatException('Unknown WAV audio format tag: 0');
  }
  if (!_supportedWavAudioFormatTags.contains(audioFormat)) {
    throw FormatException('Unsupported WAV audio format tag: $audioFormat');
  }

  if (audioFormat != 1 && !allowNonPcm) {
    throw FormatException(
      'Unsupported audio format: $audioFormat. Only PCM (1) is supported.',
    );
  }

  if (bitsPerSample != 16 && !allowNonPcm) {
    throw FormatException(
      'Unsupported bit depth: $bitsPerSample. Only 16-bit PCM is supported.',
    );
  }

  final channels = numChannels!;
  final rate = sampleRate!;
  final align = blockAlign!;
  final rateBytes = byteRate!;
  final pcmSize = dataSize!;
  if (channels <= 0) {
    throw FormatException('Invalid WAV channel count: $channels');
  }
  if (hasExtensibleFormat) {
    final channelMask = extensibleChannelMask!;
    var remainingMask = channelMask;
    var speakerCount = 0;
    while (remainingMask != 0) {
      speakerCount += remainingMask & 1;
      remainingMask >>= 1;
    }
    if (channelMask != 0 && speakerCount != channels) {
      throw FormatException(
        'Invalid WAVE_FORMAT_EXTENSIBLE channel mask: $speakerCount speaker '
        'bits for $channels channels',
      );
    }
  }
  if (rate <= 0) {
    throw FormatException('Invalid WAV sample rate: $rate');
  }
  if (align <= 0) {
    throw FormatException('Invalid WAV block alignment: $align');
  }
  if (rateBytes <= 0) {
    throw FormatException('Invalid WAV byte rate: $rateBytes');
  }

  if (audioFormat == 1) {
    if (bitsPerSample == null ||
        !const {8, 16, 24, 32}.contains(bitsPerSample)) {
      throw FormatException('Invalid PCM WAV bit depth: $bitsPerSample');
    }
    _validateLinearWavLayout(
      'PCM',
      channels: channels,
      sampleRate: rate,
      bitsPerSample: bitsPerSample,
      blockAlign: align,
      byteRate: rateBytes,
      dataSize: pcmSize,
    );
  }
  if (pcmSize <= 0) {
    throw FormatException('WAV data chunk is empty');
  }
  if (audioFormat == 1 && pcmSize % align != 0) {
    throw FormatException(
      'WAV data size $pcmSize is not aligned to $align-byte frames',
    );
  }
  if (audioFormat == 3) {
    if (bitsPerSample != 32 && bitsPerSample != 64) {
      throw FormatException(
        'Invalid IEEE float WAV bit depth: $bitsPerSample; expected 32 or 64',
      );
    }
    if (hasExtensibleFormat && extensibleValidBitsPerSample != bitsPerSample) {
      throw FormatException(
        'Invalid IEEE float valid bits: $extensibleValidBitsPerSample',
      );
    }
    _validateLinearWavLayout(
      'IEEE float',
      channels: channels,
      sampleRate: rate,
      bitsPerSample: bitsPerSample!,
      blockAlign: align,
      byteRate: rateBytes,
      dataSize: pcmSize,
    );
  }
  if (audioFormat == 6 || audioFormat == 7) {
    if (bitsPerSample != 8) {
      final encoding = audioFormat == 6 ? 'A-law' : 'mu-law';
      throw FormatException(
        'Invalid $encoding WAV bit depth: $bitsPerSample; expected 8',
      );
    }
    _validateLinearWavLayout(
      audioFormat == 6 ? 'A-law' : 'mu-law',
      channels: channels,
      sampleRate: rate,
      bitsPerSample: bitsPerSample!,
      blockAlign: align,
      byteRate: rateBytes,
      dataSize: pcmSize,
    );
  }
  if (audioFormat == 0x0002) {
    if (hasExtensibleFormat) {
      throw const FormatException(
        'WAVE_FORMAT_EXTENSIBLE Microsoft ADPCM is unsupported',
      );
    }
    if (bitsPerSample != 4) {
      throw FormatException(
        'Invalid Microsoft ADPCM bit depth: $bitsPerSample; expected 4',
      );
    }
    final coefficientCount = msAdpcmCoefficientCount;
    if (coefficientCount == null ||
        coefficientCount < 1 ||
        coefficientCount > 7) {
      throw FormatException(
        'Invalid Microsoft ADPCM coefficient count: $coefficientCount',
      );
    }
    final requiredExtensionSize = 4 + coefficientCount * 4;
    if ((fmtExtensionSize ?? 0) < requiredExtensionSize) {
      throw FormatException(
        'Microsoft ADPCM fmt extension is too small: '
        '${fmtExtensionSize ?? 0} bytes; expected $requiredExtensionSize',
      );
    }
    final samplesPerBlock = msAdpcmSamplesPerBlock;
    if (samplesPerBlock == null || samplesPerBlock < 2) {
      throw FormatException(
        'Invalid Microsoft ADPCM samplesPerBlock: $samplesPerBlock; '
        'must be at least 2',
      );
    }
    final headerBytes = channels * 7;
    if (align < headerBytes) {
      throw FormatException(
        'Invalid Microsoft ADPCM block alignment: $align for $channels channels',
      );
    }
    final maxSamplesPerBlock = ((align - headerBytes) * 2) ~/ channels + 2;
    if (samplesPerBlock > maxSamplesPerBlock) {
      throw FormatException(
        'Invalid Microsoft ADPCM samplesPerBlock: $samplesPerBlock exceeds '
        '$maxSamplesPerBlock for block alignment $align',
      );
    }
    final averageByteRateNumerator = rate * align;
    final minimumByteRate = averageByteRateNumerator ~/ samplesPerBlock;
    final maximumByteRate =
        (averageByteRateNumerator + samplesPerBlock - 1) ~/ samplesPerBlock;
    if (minimumByteRate > 0xffffffff ||
        (rateBytes != minimumByteRate &&
            (maximumByteRate > 0xffffffff || rateBytes != maximumByteRate))) {
      throw FormatException(
        'Invalid Microsoft ADPCM byte rate: expected about '
        '$minimumByteRate-$maximumByteRate, got $rateBytes',
      );
    }
    if (pcmSize % align != 0) {
      throw FormatException(
        'Microsoft ADPCM data size $pcmSize is not aligned to '
        '$align-byte blocks',
      );
    }
  }
  if (audioFormat == 0x0011) {
    if (hasExtensibleFormat) {
      throw const FormatException(
        'WAVE_FORMAT_EXTENSIBLE IMA ADPCM is unsupported',
      );
    }
    if (bitsPerSample != 4) {
      throw FormatException(
        'Invalid IMA ADPCM bit depth: $bitsPerSample; expected 4',
      );
    }
    if ((fmtExtensionSize ?? 0) < 2) {
      throw const FormatException(
        'IMA ADPCM fmt chunk must contain cbSize and samplesPerBlock',
      );
    }
    final samplesPerBlock = imaSamplesPerBlock;
    if (samplesPerBlock == null || samplesPerBlock <= 0) {
      throw FormatException(
        'Invalid IMA ADPCM samplesPerBlock: $samplesPerBlock',
      );
    }
    final headerBytes = channels * 4;
    if (align < headerBytes) {
      throw FormatException(
        'Invalid IMA ADPCM block alignment: $align for $channels channels',
      );
    }
    final encodedBytes = align - headerBytes;
    final maxSamplesPerBlock = (encodedBytes * 2) ~/ channels + 1;
    if (samplesPerBlock > maxSamplesPerBlock) {
      throw FormatException(
        'Invalid IMA ADPCM samplesPerBlock: $samplesPerBlock exceeds '
        '$maxSamplesPerBlock for block alignment $align',
      );
    }
    final averageByteRateNumerator = rate * align;
    final minimumByteRate = averageByteRateNumerator ~/ samplesPerBlock;
    final maximumByteRate =
        (averageByteRateNumerator + samplesPerBlock - 1) ~/ samplesPerBlock;
    if (minimumByteRate > 0xffffffff ||
        (rateBytes != minimumByteRate &&
            (maximumByteRate > 0xffffffff || rateBytes != maximumByteRate))) {
      throw FormatException(
        'Invalid IMA ADPCM byte rate: expected about '
        '$minimumByteRate-$maximumByteRate, got $rateBytes',
      );
    }
    if (pcmSize % align != 0) {
      throw FormatException(
        'IMA ADPCM data size $pcmSize is not aligned to $align-byte blocks',
      );
    }
  }
  if (dataOffset + pcmSize > containerEnd) {
    throw FormatException('WAV data chunk exceeds its RIFF container');
  }

  final samplesPerBlock = switch (audioFormat) {
    0x0002 => msAdpcmSamplesPerBlock,
    0x0011 => imaSamplesPerBlock,
    _ => null,
  };
  return _ParsedWavHeader(
    info: WavInfo(
      sampleRate: rate,
      numChannels: channels,
      bitsPerSample: bitsPerSample!,
      dataOffset: dataOffset,
      dataSize: pcmSize,
      byteRate: rateBytes,
      blockAlign: align,
    ),
    audioFormat: audioFormat,
    samplesPerBlock: samplesPerBlock,
    factSampleCount: factSampleCount,
  );
}

void _validateLinearWavLayout(
  String encoding, {
  required int channels,
  required int sampleRate,
  required int bitsPerSample,
  required int blockAlign,
  required int byteRate,
  required int dataSize,
}) {
  if (bitsPerSample % 8 != 0) {
    throw FormatException(
      'Invalid $encoding WAV bit depth: $bitsPerSample is not byte-aligned',
    );
  }
  final expectedAlign = channels * (bitsPerSample ~/ 8);
  if (blockAlign != expectedAlign) {
    throw FormatException(
      'Invalid $encoding WAV block alignment: expected $expectedAlign, '
      'got $blockAlign',
    );
  }
  final expectedByteRate = sampleRate * expectedAlign;
  if (expectedByteRate > 0xffffffff || byteRate != expectedByteRate) {
    throw FormatException(
      'Invalid $encoding WAV byte rate: expected $expectedByteRate, '
      'got $byteRate',
    );
  }
  if (dataSize % blockAlign != 0) {
    throw FormatException(
      '$encoding WAV data size $dataSize is not aligned to '
      '$blockAlign-byte frames',
    );
  }
}

// ============================================================================
// PCM Sample Reader
// ============================================================================

/// Read PCM samples from WAV data as normalized float values [-1.0, 1.0].
/// Converts from S16LE interleaved format.
///
/// Returns ALL raw interleaved samples (LRLRLR... for stereo). The caller
/// is responsible for de-interleaving if needed via [WavPreprocessor].
Float64List readPcmSamplesFloat(Uint8List wavBytes, WavInfo info) {
  if (info.bitsPerSample != 16 ||
      info.numChannels <= 0 ||
      info.sampleRate <= 0 ||
      info.blockAlign <= 0 ||
      info.blockAlign != info.bytesPerFrame ||
      info.byteRate != info.sampleRate * info.blockAlign ||
      info.dataSize <= 0 ||
      info.dataSize % info.blockAlign != 0 ||
      info.dataOffset < 0 ||
      info.dataOffset > wavBytes.length ||
      info.dataSize > wavBytes.length - info.dataOffset) {
    throw FormatException('Invalid PCM WAV data range or metadata');
  }

  // Total INDIVIDUAL samples, not frames: dataSize / bytesPerSample.
  // For stereo 16-bit: bytesPerSample=2, each frame has 2 samples (L+R).
  final rawSampleCount = info.dataSize ~/ info.bytesPerSample;
  final samples = Float64List(rawSampleCount);
  // ByteData from buffer — compatible with Dart >= 3.0.0
  final dv = wavBytes.buffer.asByteData(
    info.dataOffset + wavBytes.offsetInBytes,
    info.dataSize,
  );

  for (int i = 0; i < rawSampleCount; i++) {
    final s16 = dv.getInt16(i * 2, Endian.little);
    samples[i] = s16 / 32768.0;
  }

  return samples;
}

/// Reads one time-frame's energy sample directly from the source PCM.
///
/// Silence analysis only needs one value per frame. Keeping that value as a
/// view over the source avoids allocating one or two Float64 samples for every
/// input sample in a long recording.
class _PcmFrameReader {
  final WavInfo info;
  final ByteData _pcm;

  _PcmFrameReader(Uint8List wavBytes, this.info)
      : _pcm = wavBytes.buffer.asByteData(
          wavBytes.offsetInBytes + info.dataOffset,
          info.dataSize,
        );

  double frameEnergy(int frameIndex) {
    if (info.numChannels == 1) return _channelSample(frameIndex, 0);

    double peakMagnitude = 0;
    for (var channel = 0; channel < info.numChannels; channel++) {
      final magnitude = _channelSample(frameIndex, channel).abs();
      if (magnitude > peakMagnitude) peakMagnitude = magnitude;
    }
    return peakMagnitude;
  }

  double _channelSample(int frameIndex, int channel) {
    final sampleIndex = frameIndex * info.numChannels + channel;
    return _pcm.getInt16(sampleIndex * 2, Endian.little) / 32768.0;
  }
}

Float64List _computeFrameDbFromReader(_PcmFrameReader reader, int frameSize) {
  final frameCount = reader.info.totalSamples ~/ frameSize;
  if (frameCount == 0) return Float64List(0);
  final dbValues = Float64List(frameCount);
  for (var frame = 0; frame < frameCount; frame++) {
    double sumSq = 0;
    final start = frame * frameSize;
    final end = (start + frameSize).clamp(0, reader.info.totalSamples);
    for (var sample = start; sample < end; sample++) {
      final value = reader.frameEnergy(sample);
      sumSq += value * value;
    }
    final rms = sqrt(sumSq / (end - start));
    dbValues[frame] = rms > 1e-10 ? 20 * log(rms) / ln10 : -100.0;
  }
  return dbValues;
}

Future<Float64List> _computeFrameDbWithEventLoopYield(
  _PcmFrameReader reader,
  int frameSize, {
  required _WebPcmWorkBudget workBudget,
}) async {
  final frameCount = reader.info.totalSamples ~/ frameSize;
  if (frameCount == 0) return Float64List(0);
  final dbValues = Float64List(frameCount);
  for (var frame = 0; frame < frameCount; frame++) {
    double sumSq = 0;
    final start = frame * frameSize;
    final end = (start + frameSize).clamp(0, reader.info.totalSamples);
    for (var sample = start; sample < end; sample++) {
      final value = reader.frameEnergy(sample);
      sumSq += value * value;
      if (workBudget.recordSample()) await workBudget.yieldEventLoop();
    }
    final rms = sqrt(sumSq / (end - start));
    dbValues[frame] = rms > 1e-10 ? 20 * log(rms) / ln10 : -100.0;
    if ((frame + 1) % _webYieldAnalysisFrameCount == 0 &&
        frame + 1 < frameCount) {
      await workBudget.yieldEventLoop();
    }
  }
  return dbValues;
}

class _AudioChunkPlanRequest {
  final IsolateTransferableBytes wavBytes;
  final AudioChunkConfig config;
  final AudioChunkMethod method;
  final int? maxChunks;

  const _AudioChunkPlanRequest(
    this.wavBytes,
    this.config,
    this.method,
    this.maxChunks,
  );
}

List<AudioChunk> _computeAudioChunkPlan(_AudioChunkPlanRequest request) =>
    AudioChunker(config: request.config).plan(
      request.wavBytes.materialize(),
      request.method,
      maxChunks: request.maxChunks,
    );

// ============================================================================
// RMS Frame Energy + Silence Gap Detection
// ============================================================================

/// Compute per-frame RMS dB values for PCM samples.
/// Used as a shared computation between environment analysis and gap detection.
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
    final gaps = detectGaps(
      samples,
      sampleRate,
      dbThreshold: dbThreshold,
      minSilenceSec: minSilenceSec,
    );
    return gaps
        .map(
          (g) => SilenceGap(
            startSample: g.startSample,
            endSample: g.endSample,
            durationSeconds: g.durationSeconds,
          ),
        )
        .toList();
  }

  /// Detect silence gaps from pre-computed per-frame dB values.
  /// Avoids recomputing frame energies when they were already calculated.
  List<_DetectedGap> detectGapsFromDb(
    Float64List dbValues,
    int sampleRate, {
    double? dbThreshold,
    double? minSilenceSec,
  }) =>
      _detectGapsFromDb(
        dbValues,
        sampleRate,
        dbThreshold: dbThreshold,
        minSilenceSec: minSilenceSec,
      );

  List<_DetectedGap> _detectGapsFromDb(
    Float64List dbValues,
    int sampleRate, {
    double? dbThreshold,
    double? minSilenceSec,
  }) {
    config.validateForSampleRate(sampleRate);
    final threshold = dbThreshold ?? config.silenceDbThreshold;
    final minSilenceS = minSilenceSec ?? config.minSilenceDuration;
    final frameSize = config.frameSize;
    final frameCount = dbValues.length;
    if (frameCount == 0) return [];
    final minSilentFrames = (minSilenceS * sampleRate / frameSize).ceil().clamp(
          1,
          frameCount,
        );

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
          gaps.add(
            _DetectedGap(
              startSample: gapStart * frameSize,
              endSample: f * frameSize,
              durationSeconds: (f - gapStart) * frameSize / sampleRate,
              minDb: gapMinDb,
              avgDb: gapSumDb / gapFrameCount,
            ),
          );
        }
        gapStart = null;
      }
    }
    return gaps;
  }

  Future<List<_DetectedGap>> _detectGapsFromDbWithEventLoopYield(
    Float64List dbValues,
    int sampleRate, {
    double? dbThreshold,
    double? minSilenceSec,
    void Function()? onYield,
    void Function()? checkCancelled,
  }) async {
    config.validateForSampleRate(sampleRate);
    final threshold = dbThreshold ?? config.silenceDbThreshold;
    final minSilenceS = minSilenceSec ?? config.minSilenceDuration;
    final frameSize = config.frameSize;
    final frameCount = dbValues.length;
    if (frameCount == 0) return [];
    final minSilentFrames = (minSilenceS * sampleRate / frameSize).ceil().clamp(
          1,
          frameCount,
        );

    final gaps = <_DetectedGap>[];
    int? gapStart;
    double gapMinDb = 0;
    double gapSumDb = 0;
    int gapFrameCount = 0;

    for (var frame = 0; frame < frameCount; frame++) {
      final db = dbValues[frame];
      if (db < threshold) {
        if (gapStart == null) {
          gapStart = frame;
          gapMinDb = db;
          gapSumDb = db;
          gapFrameCount = 1;
        } else {
          gapMinDb = gapMinDb < db ? gapMinDb : db;
          gapSumDb += db;
          gapFrameCount++;
        }
      } else {
        if (gapStart != null && (frame - gapStart) >= minSilentFrames) {
          gaps.add(
            _DetectedGap(
              startSample: gapStart * frameSize,
              endSample: frame * frameSize,
              durationSeconds: (frame - gapStart) * frameSize / sampleRate,
              minDb: gapMinDb,
              avgDb: gapSumDb / gapFrameCount,
            ),
          );
        }
        gapStart = null;
      }

      if ((frame + 1) % _webYieldAnalysisFrameCount == 0 &&
          frame + 1 < frameCount) {
        await _yieldWebAnalysis(onYield, checkCancelled: checkCancelled);
      }
    }
    return gaps;
  }

  /// Detect silence gaps with full quality metrics for candidate scoring.
  // ignore: library_private_types_in_public_api
  List<_DetectedGap> detectGaps(
    Float64List samples,
    int sampleRate, {
    double? dbThreshold,
    double? minSilenceSec,
  }) {
    config.validateForSampleRate(sampleRate);
    final threshold = dbThreshold ?? config.silenceDbThreshold;
    final minSilenceS = minSilenceSec ?? config.minSilenceDuration;
    final frameSize = config.frameSize;
    final frameCount = samples.length ~/ frameSize;
    if (frameCount == 0) return [];
    final minSilentFrames = (minSilenceS * sampleRate / frameSize).ceil().clamp(
          1,
          frameCount,
        );

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
          gaps.add(
            _DetectedGap(
              startSample: gapStart * frameSize,
              endSample: f * frameSize,
              durationSeconds: (f - gapStart) * frameSize / sampleRate,
              minDb: gapMinDb,
              avgDb: gapSumDb / gapFrameCount,
            ),
          );
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
const _webYieldAnalysisFrameCount = 128;
const _webYieldChunkCount = 128;

class AudioChunker {
  final AudioChunkConfig config;

  const AudioChunker({this.config = const AudioChunkConfig()});

  /// Build frame-aligned ranges without copying PCM payloads into chunks.
  List<AudioChunk> plan(
    Uint8List wavBytes,
    AudioChunkMethod method, {
    int? maxChunks,
  }) {
    config.validate();
    _validateMaxChunks(maxChunks);
    switch (method) {
      case AudioChunkMethod.none:
        _checkChunkCapacity(0, maxChunks);
        return [
          AudioChunk(
            startByte: 0,
            endByte: wavBytes.length,
            startSecond: 0,
            endSecond: _passThroughDurationSeconds(wavBytes),
            isOriginal: true,
          ),
        ];
      case AudioChunkMethod.silence:
        return _planSilence(wavBytes, maxChunks: maxChunks);
      case AudioChunkMethod.fixedDuration:
        return _planByDuration(wavBytes, maxChunks: maxChunks);
      case AudioChunkMethod.fixedSize:
        return _planBySize(wavBytes, maxChunks: maxChunks);
    }
  }

  /// Plan silence in a native isolate, or yield between bounded Web batches.
  /// [onNativeIsolateStarted] is a test seam for native full-audio work.
  Future<List<AudioChunk>> planAsync(
    Uint8List wavBytes,
    AudioChunkMethod method, {
    int? maxChunks,
    Future<Object?>? cancellationSignal,
    void Function()? checkCancelled,
    void Function()? onNativeIsolateStarted,
    bool? forceWebPathForTesting,
  }) async {
    checkCancelled?.call();
    if (kIsWeb || forceWebPathForTesting == true) {
      return planWithEventLoopYield(
        wavBytes,
        method,
        maxChunks: maxChunks,
        checkCancelled: checkCancelled,
        cancellationSignal: cancellationSignal,
      );
    }
    final ensureNotCancelled = _cancellationCheck(
      checkCancelled,
      cancellationSignal,
    );
    ensureNotCancelled?.call();
    if (method != AudioChunkMethod.silence) {
      // A fixed plan can still contain many ranges; yield in bounded batches
      // without copying the full WAV into a worker isolate.
      return planWithEventLoopYield(
        wavBytes,
        method,
        maxChunks: maxChunks,
        checkCancelled: checkCancelled,
        cancellationSignal: cancellationSignal,
      );
    }
    final planned = await computeCancellableWithRequestFactory(
      _computeAudioChunkPlan,
      () {
        onNativeIsolateStarted?.call();
        return _AudioChunkPlanRequest(
          IsolateTransferableBytes(wavBytes),
          config,
          method,
          maxChunks,
        );
      },
      debugLabel: 'asr-audio-chunk-plan',
      cancellationSignal: cancellationSignal,
    );
    ensureNotCancelled?.call();
    return planned;
  }

  /// Web-compatible planner. [onYield] is a test seam for bounded yielding.
  Future<List<AudioChunk>> planWithEventLoopYield(
    Uint8List wavBytes,
    AudioChunkMethod method, {
    int? maxChunks,
    void Function()? onYield,
    void Function()? checkCancelled,
    Future<Object?>? cancellationSignal,
  }) async {
    final ensureNotCancelled = _cancellationCheck(
      checkCancelled,
      cancellationSignal,
    );
    ensureNotCancelled?.call();
    config.validate();
    _validateMaxChunks(maxChunks);
    void Function()? guardedOnYield = onYield;
    if (ensureNotCancelled != null) {
      guardedOnYield = () {
        ensureNotCancelled();
        onYield?.call();
      };
    }
    late final List<AudioChunk> chunks;
    switch (method) {
      case AudioChunkMethod.none:
        chunks = plan(wavBytes, method, maxChunks: maxChunks);
        break;
      case AudioChunkMethod.silence:
        chunks = await _planSilenceWithEventLoopYield(
          wavBytes,
          maxChunks: maxChunks,
          onYield: guardedOnYield,
          checkCancelled: ensureNotCancelled,
        );
        break;
      case AudioChunkMethod.fixedDuration:
        chunks = await _planByDurationWithEventLoopYield(
          wavBytes,
          maxChunks: maxChunks,
          onYield: guardedOnYield,
          checkCancelled: ensureNotCancelled,
        );
        break;
      case AudioChunkMethod.fixedSize:
        chunks = await _planBySizeWithEventLoopYield(
          wavBytes,
          maxChunks: maxChunks,
          onYield: guardedOnYield,
          checkCancelled: ensureNotCancelled,
        );
        break;
    }
    if (cancellationSignal != null) {
      // Allow an already-completed signal's listener to run before return.
      await Future<void>.delayed(Duration.zero);
    }
    ensureNotCancelled?.call();
    return chunks;
  }

  /// Materialize one planned PCM range as a valid WAV chunk.
  Uint8List materializeChunk(Uint8List wavBytes, AudioChunk chunk) {
    if (chunk.isOriginal) return wavBytes;
    final info = parseWavHeader(wavBytes);
    _validateForWav(info);
    final start = chunk.startByte - info.dataOffset;
    final end = chunk.endByte - info.dataOffset;
    if (start < 0 || end <= start || end > info.dataSize) {
      throw RangeError('Chunk range is outside the WAV PCM payload');
    }
    if (start % info.bytesPerFrame != 0 || end % info.bytesPerFrame != 0) {
      throw FormatException('Chunk range is not aligned to a PCM frame');
    }
    return _writeWavChunk(wavBytes, info, start, end);
  }

  /// Split a WAV file using the specified [method].
  List<Uint8List> chunk(
    Uint8List wavBytes,
    AudioChunkMethod method, {
    int? maxChunks,
  }) =>
      [
        for (final range in plan(wavBytes, method, maxChunks: maxChunks))
          materializeChunk(wavBytes, range),
      ];

  List<Uint8List> split(Uint8List wavBytes, {int? maxChunks}) =>
      chunk(wavBytes, AudioChunkMethod.silence, maxChunks: maxChunks);

  List<AudioChunk> _planSilence(Uint8List wavBytes, {int? maxChunks}) {
    final info = parseWavHeader(wavBytes);
    _validateForWav(info);
    final reader = _PcmFrameReader(wavBytes, info);
    final frameDb = _computeFrameDbFromReader(reader, config.frameSize);
    final candidates = _silenceCandidates(info, frameDb, reader);
    final selectedCuts = _selectCutPointsForInfo(info, candidates);
    return _rangesFromCuts(info, selectedCuts, maxChunks: maxChunks);
  }

  Future<List<AudioChunk>> _planSilenceWithEventLoopYield(
    Uint8List wavBytes, {
    int? maxChunks,
    void Function()? onYield,
    void Function()? checkCancelled,
  }) async {
    final info = parseWavHeader(wavBytes);
    _validateForWav(info);
    final reader = _PcmFrameReader(wavBytes, info);
    final workBudget = _WebPcmWorkBudget(onYield, checkCancelled);
    final frameDb = await _computeFrameDbWithEventLoopYield(
      reader,
      config.frameSize,
      workBudget: workBudget,
    );
    final gaps = await _silenceGapsWithEventLoopYield(
      info,
      frameDb,
      onYield: onYield,
      checkCancelled: checkCancelled,
    );
    final candidates = await _buildCandidatesWithEventLoopYield(
      gaps.gaps,
      reader,
      info.sampleRate,
      gaps.adjustedDbThreshold,
      onYield: onYield,
      checkCancelled: checkCancelled,
      workBudget: workBudget,
    );
    final selectedCuts = await _selectCutPointsForInfoWithEventLoopYield(
      info,
      candidates,
      onYield: onYield,
      checkCancelled: checkCancelled,
    );
    return _rangesFromCutsWithEventLoopYield(
      info,
      selectedCuts,
      maxChunks: maxChunks,
      onYield: onYield,
      checkCancelled: checkCancelled,
    );
  }

  List<CandidateCut> _silenceCandidates(
    WavInfo info,
    Float64List frameDb,
    _PcmFrameReader reader,
  ) {
    final gaps = _silenceGaps(info, frameDb);
    return _buildCandidates(
      gaps.gaps,
      reader,
      info.sampleRate,
      gaps.adjustedDbThreshold,
    );
  }

  ({List<_DetectedGap> gaps, double adjustedDbThreshold}) _silenceGaps(
    WavInfo info,
    Float64List frameDb,
  ) {
    final envAnalyzer = EnvironmentAnalyzer(
      frameSize: config.frameSize,
      silenceDbThreshold: config.silenceDbThreshold,
    );
    final env = envAnalyzer.analyzeFromDb(frameDb);
    final adjustedMinSilenceS =
        envAnalyzer.adjustMinSilenceMs(env, config.minSilenceDuration * 1000) /
            1000.0;
    final adjustedDbThreshold = envAnalyzer.adjustSilenceDbThreshold(
      env,
      config.silenceDbThreshold,
    );
    return (
      gaps: SilenceDetector(config)._detectGapsFromDb(
        frameDb,
        info.sampleRate,
        dbThreshold: adjustedDbThreshold,
        minSilenceSec: adjustedMinSilenceS,
      ),
      adjustedDbThreshold: adjustedDbThreshold,
    );
  }

  Future<({List<_DetectedGap> gaps, double adjustedDbThreshold})>
      _silenceGapsWithEventLoopYield(
    WavInfo info,
    Float64List frameDb, {
    void Function()? onYield,
    void Function()? checkCancelled,
  }) async {
    final envAnalyzer = EnvironmentAnalyzer(
      frameSize: config.frameSize,
      silenceDbThreshold: config.silenceDbThreshold,
    );
    final env = await envAnalyzer.analyzeFromDbWithEventLoopYield(
      frameDb,
      onYield: onYield,
      checkCancelled: checkCancelled,
    );
    final adjustedMinSilenceS =
        envAnalyzer.adjustMinSilenceMs(env, config.minSilenceDuration * 1000) /
            1000.0;
    final adjustedDbThreshold = envAnalyzer.adjustSilenceDbThreshold(
      env,
      config.silenceDbThreshold,
    );
    return (
      gaps: await SilenceDetector(config)._detectGapsFromDbWithEventLoopYield(
        frameDb,
        info.sampleRate,
        dbThreshold: adjustedDbThreshold,
        minSilenceSec: adjustedMinSilenceS,
        onYield: onYield,
        checkCancelled: checkCancelled,
      ),
      adjustedDbThreshold: adjustedDbThreshold,
    );
  }

  List<int> _selectCutPointsForInfo(
    WavInfo info,
    List<CandidateCut> candidates,
  ) =>
      _selectCutPoints(
        candidates,
        totalSamples: info.totalSamples,
        minChunkSamples: (config.minChunkDuration * info.sampleRate).round(),
        targetChunkSamples:
            (config.targetChunkDuration * info.sampleRate).round(),
        maxChunkSamples: (config.maxChunkDuration * info.sampleRate).round(),
        sampleRate: info.sampleRate,
      );

  Future<List<int>> _selectCutPointsForInfoWithEventLoopYield(
    WavInfo info,
    List<CandidateCut> candidates, {
    void Function()? onYield,
    void Function()? checkCancelled,
  }) async {
    final totalSamples = info.totalSamples;
    final minChunkSamples = (config.minChunkDuration * info.sampleRate).round();
    final targetChunkSamples =
        (config.targetChunkDuration * info.sampleRate).round();
    final maxChunkSamples = (config.maxChunkDuration * info.sampleRate).round();
    final sampleRate = info.sampleRate;
    final cuts = <int>[0];
    if (totalSamples <= minChunkSamples ||
        maxChunkSamples <= 0 ||
        maxChunkSamples < minChunkSamples) {
      cuts.add(totalSamples);
      return cuts;
    }

    var workSinceYield = 0;
    Future<void> yieldWhenNeeded() async {
      workSinceYield++;
      if (workSinceYield >= _webYieldCutWorkCount) {
        workSinceYield = 0;
        await _yieldWebAnalysis(onYield, checkCancelled: checkCancelled);
      }
    }

    int lowerBound(int samplePosition) {
      var low = 0;
      var high = candidates.length;
      while (low < high) {
        final middle = (low + high) ~/ 2;
        if (candidates[middle].samplePosition < samplePosition) {
          low = middle + 1;
        } else {
          high = middle;
        }
      }
      return low;
    }

    Future<int> findForceCutPosition(
      int preferredPos,
      int minimumPosition,
    ) async {
      if (minimumPosition >= totalSamples) return totalSamples;
      final windowSamples = (3 * sampleRate).round();
      CandidateCut? nearest;
      var nearestDist = windowSamples + 1;
      final first = lowerBound(
        minimumPosition > preferredPos - windowSamples
            ? minimumPosition
            : preferredPos - windowSamples,
      );
      for (var index = first; index < candidates.length; index++) {
        final candidate = candidates[index];
        if (candidate.samplePosition >= totalSamples ||
            candidate.samplePosition > preferredPos + windowSamples) {
          break;
        }
        final distance = (candidate.samplePosition - preferredPos).abs();
        if (distance < nearestDist && distance <= windowSamples) {
          nearest = candidate;
          nearestDist = distance;
        }
        await yieldWhenNeeded();
      }
      return nearest?.samplePosition ??
          preferredPos.clamp(minimumPosition, totalSamples);
    }

    var currentSample = 0;
    while (currentSample + minChunkSamples < totalSamples) {
      final searchEnd = (currentSample + maxChunkSamples).clamp(
        0,
        totalSamples,
      );
      final searchStart = currentSample + minChunkSamples;
      final inRange = <CandidateCut>[];
      for (var index = lowerBound(searchStart);
          index < candidates.length &&
              candidates[index].samplePosition <= searchEnd;
          index++) {
        inRange.add(candidates[index]);
        await yieldWhenNeeded();
      }

      if (inRange.isEmpty) {
        if (searchEnd >= totalSamples) break;
        final forcePos = await findForceCutPosition(
          currentSample + maxChunkSamples,
          currentSample + minChunkSamples,
        );
        if (forcePos >= totalSamples) break;
        cuts.add(forcePos);
        currentSample = forcePos;
        await yieldWhenNeeded();
        continue;
      }

      CandidateCut? best;
      var bestScore = -1.0;
      for (final candidate in inRange) {
        final score = _scoreCandidate(
          candidate,
          currentSample,
          targetChunkSamples,
          minChunkSamples,
          maxChunkSamples,
          sampleRate,
        );
        candidate.totalScore = score;
        if (score > bestScore) {
          bestScore = score;
          best = candidate;
        }
        await yieldWhenNeeded();
      }

      if (best == null || bestScore < 0.15) {
        final forcePos = await findForceCutPosition(
          currentSample + maxChunkSamples,
          currentSample + minChunkSamples,
        );
        if (forcePos >= totalSamples) break;
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

  List<AudioChunk> _planByDuration(Uint8List wavBytes, {int? maxChunks}) {
    final info = parseWavHeader(wavBytes);
    _validateForWav(info);
    final framesPerStep =
        (config.fixedDurationSeconds * info.sampleRate).round();
    return _rangesByStep(
      info,
      framesPerStep,
      config.maxChunkBytes ~/ info.bytesPerFrame,
      maxChunks,
    );
  }

  List<AudioChunk> _planBySize(Uint8List wavBytes, {int? maxChunks}) {
    final info = parseWavHeader(wavBytes);
    _validateForWav(info);
    final framesPerChunk = (config.maxChunkBytes ~/ info.bytesPerFrame).clamp(
      1,
      info.totalSamples,
    );
    return _rangesByStep(info, framesPerChunk, framesPerChunk, maxChunks);
  }

  List<AudioChunk> _rangesByStep(
    WavInfo info,
    int framesPerStep,
    int maxFramesPerPart,
    int? maxChunks,
  ) {
    final ranges = <AudioChunk>[];
    for (var start = 0; start < info.totalSamples; start += framesPerStep) {
      _appendFrameRanges(
        ranges,
        info,
        start,
        (start + framesPerStep).clamp(0, info.totalSamples),
        maxFramesPerPart,
        maxChunks,
      );
    }
    return ranges;
  }

  Future<List<AudioChunk>> _planByDurationWithEventLoopYield(
    Uint8List wavBytes, {
    int? maxChunks,
    void Function()? onYield,
    void Function()? checkCancelled,
  }) async {
    final info = parseWavHeader(wavBytes);
    _validateForWav(info);
    final framesPerStep =
        (config.fixedDurationSeconds * info.sampleRate).round();
    return _rangesByStepWithEventLoopYield(
      info,
      framesPerStep,
      config.maxChunkBytes ~/ info.bytesPerFrame,
      maxChunks,
      onYield,
      checkCancelled,
    );
  }

  Future<List<AudioChunk>> _planBySizeWithEventLoopYield(
    Uint8List wavBytes, {
    int? maxChunks,
    void Function()? onYield,
    void Function()? checkCancelled,
  }) async {
    final info = parseWavHeader(wavBytes);
    _validateForWav(info);
    final framesPerChunk = (config.maxChunkBytes ~/ info.bytesPerFrame).clamp(
      1,
      info.totalSamples,
    );
    return _rangesByStepWithEventLoopYield(
      info,
      framesPerChunk,
      framesPerChunk,
      maxChunks,
      onYield,
      checkCancelled,
    );
  }

  Future<List<AudioChunk>> _rangesByStepWithEventLoopYield(
    WavInfo info,
    int framesPerStep,
    int maxFramesPerPart,
    int? maxChunks,
    void Function()? onYield,
    void Function()? checkCancelled,
  ) async {
    final ranges = <AudioChunk>[];
    var nextYieldAt = _webYieldChunkCount;
    for (var start = 0; start < info.totalSamples; start += framesPerStep) {
      final end = (start + framesPerStep).clamp(0, info.totalSamples);
      var partStart = start;
      while (partStart < end) {
        final partEnd = (partStart + maxFramesPerPart).clamp(0, end);
        _checkChunkCapacity(ranges.length, maxChunks);
        ranges.add(_frameRange(info, partStart, partEnd));
        partStart = partEnd;
        if (ranges.length >= nextYieldAt && partStart < info.totalSamples) {
          onYield?.call();
          nextYieldAt = ranges.length + _webYieldChunkCount;
          await Future<void>.delayed(Duration.zero);
          checkCancelled?.call();
        }
      }
    }
    return ranges;
  }

  List<AudioChunk> _rangesFromCuts(
    WavInfo info,
    List<int> selectedCuts, {
    int? maxChunks,
  }) {
    final ranges = <AudioChunk>[];
    for (var index = 0; index < selectedCuts.length - 1; index++) {
      _appendFrameRanges(
        ranges,
        info,
        selectedCuts[index],
        selectedCuts[index + 1],
        config.maxChunkBytes ~/ info.bytesPerFrame,
        maxChunks,
      );
    }
    return ranges;
  }

  Future<List<AudioChunk>> _rangesFromCutsWithEventLoopYield(
    WavInfo info,
    List<int> selectedCuts, {
    int? maxChunks,
    void Function()? onYield,
    void Function()? checkCancelled,
  }) async {
    final ranges = <AudioChunk>[];
    var nextYieldAt = _webYieldChunkCount;
    for (var index = 0; index < selectedCuts.length - 1; index++) {
      var partStart = selectedCuts[index];
      final end = selectedCuts[index + 1];
      final maxFramesPerPart = config.maxChunkBytes ~/ info.bytesPerFrame;
      while (partStart < end) {
        final partEnd = (partStart + maxFramesPerPart).clamp(0, end);
        _checkChunkCapacity(ranges.length, maxChunks);
        ranges.add(_frameRange(info, partStart, partEnd));
        partStart = partEnd;
        if (ranges.length >= nextYieldAt &&
            (partStart < end || index < selectedCuts.length - 2)) {
          onYield?.call();
          nextYieldAt = ranges.length + _webYieldChunkCount;
          await Future<void>.delayed(Duration.zero);
          checkCancelled?.call();
        }
      }
    }
    return ranges;
  }

  void _appendFrameRanges(
    List<AudioChunk> ranges,
    WavInfo info,
    int startFrame,
    int endFrame,
    int maxFramesPerPart,
    int? maxChunks,
  ) {
    if (endFrame <= startFrame) return;
    for (var start = startFrame; start < endFrame; start += maxFramesPerPart) {
      final end = (start + maxFramesPerPart).clamp(0, endFrame);
      _checkChunkCapacity(ranges.length, maxChunks);
      ranges.add(_frameRange(info, start, end));
    }
  }

  AudioChunk _frameRange(WavInfo info, int startFrame, int endFrame) =>
      AudioChunk(
        startByte: info.dataOffset + startFrame * info.bytesPerFrame,
        endByte: info.dataOffset + endFrame * info.bytesPerFrame,
        startSecond: startFrame / info.sampleRate,
        endSecond: endFrame / info.sampleRate,
      );

  /// Build [CandidateCut] objects from detected gaps with quality metrics.
  /// [adjustedDbThreshold] is the environment-adjusted silence dB threshold
  /// used during actual gap detection — confidence is computed relative to this.
  List<CandidateCut> _buildCandidates(
    List<_DetectedGap> gaps,
    _PcmFrameReader reader,
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
        reader,
        gap.startSample,
        gap.endSample,
        frameSize,
      );

      // 3. Sentence-end likelihood: energy decline pattern before gap
      final sentenceEnd = _computeSentenceEndLikelihood(
        reader,
        gap.startSample,
        frameSize,
        sampleRate,
      );

      candidates.add(
        CandidateCut(
          samplePosition: gap.midSample,
          silenceDuration: gap.durationSeconds,
          silenceConfidence: silenceConf,
          transitionQuality: transition,
          sentenceEndLikelihood: sentenceEnd,
        ),
      );
    }

    return candidates;
  }

  Future<List<CandidateCut>> _buildCandidatesWithEventLoopYield(
    List<_DetectedGap> gaps,
    _PcmFrameReader reader,
    int sampleRate,
    double adjustedDbThreshold, {
    void Function()? onYield,
    void Function()? checkCancelled,
    required _WebPcmWorkBudget workBudget,
  }) async {
    final frameSize = config.frameSize;
    final candidates = <CandidateCut>[];
    for (var index = 0; index < gaps.length; index++) {
      final gap = gaps[index];
      final depthBelowThreshold = adjustedDbThreshold - gap.minDb;
      final silenceConf = (depthBelowThreshold / 20.0).clamp(0.0, 1.0);
      final transition = await _computeTransitionQualityWithEventLoopYield(
        reader,
        gap.startSample,
        gap.endSample,
        frameSize,
        workBudget,
      );
      final sentenceEnd = await _computeSentenceEndLikelihoodWithEventLoopYield(
        reader,
        gap.startSample,
        frameSize,
        sampleRate,
        workBudget,
      );
      candidates.add(
        CandidateCut(
          samplePosition: gap.midSample,
          silenceDuration: gap.durationSeconds,
          silenceConfidence: silenceConf,
          transitionQuality: transition,
          sentenceEndLikelihood: sentenceEnd,
        ),
      );
      if ((index + 1) % _webYieldAnalysisFrameCount == 0 &&
          index + 1 < gaps.length) {
        await _yieldWebAnalysis(onYield, checkCancelled: checkCancelled);
      }
    }
    return candidates;
  }

  Future<double> _computeTransitionQualityWithEventLoopYield(
    _PcmFrameReader reader,
    int gapStartSample,
    int gapEndSample,
    int frameSize,
    _WebPcmWorkBudget workBudget,
  ) async {
    double preGapMax = 0;
    final preStart = (gapStartSample - frameSize * 3).clamp(0, gapStartSample);
    for (var index = preStart; index < gapStartSample; index++) {
      final absVal = reader.frameEnergy(index).abs();
      if (absVal > preGapMax) preGapMax = absVal;
      if (workBudget.recordSample()) await workBudget.yieldEventLoop();
    }

    double postGapMax = 0;
    final postEnd = (gapEndSample + frameSize * 3).clamp(
      0,
      reader.info.totalSamples,
    );
    for (var index = gapEndSample; index < postEnd; index++) {
      final absVal = reader.frameEnergy(index).abs();
      if (absVal > postGapMax) postGapMax = absVal;
      if (workBudget.recordSample()) await workBudget.yieldEventLoop();
    }

    final preDb = preGapMax > 1e-6 ? 20 * log(preGapMax) / ln10 : -100;
    final postDb = postGapMax > 1e-6 ? 20 * log(postGapMax) / ln10 : -100;
    final levelDiff = (preDb - postDb).abs();
    return (1.0 - (levelDiff / 30.0)).clamp(0.0, 1.0);
  }

  Future<double> _computeSentenceEndLikelihoodWithEventLoopYield(
    _PcmFrameReader reader,
    int gapStartSample,
    int frameSize,
    int sampleRate,
    _WebPcmWorkBudget workBudget,
  ) async {
    final windowFrames = (config.analysisWindowSeconds * sampleRate / frameSize)
        .round()
        .clamp(3, 30);
    final frames = <double>[];
    for (var frame = 0; frame < windowFrames; frame++) {
      final start = (gapStartSample - (windowFrames - frame) * frameSize).clamp(
        0,
        reader.info.totalSamples,
      );
      final end = (start + frameSize).clamp(0, reader.info.totalSamples);
      double sumAbs = 0;
      for (var index = start; index < end; index++) {
        sumAbs += reader.frameEnergy(index).abs();
        if (workBudget.recordSample()) await workBudget.yieldEventLoop();
      }
      frames.add(sumAbs / (end - start));
    }

    if (frames.length < 3) return 0.5;

    final midpoint = frames.length ~/ 2;
    double firstHalf = 0, secondHalf = 0;
    for (var index = 0; index < midpoint; index++) {
      firstHalf += frames[index];
    }
    for (var index = midpoint; index < frames.length; index++) {
      secondHalf += frames[index];
    }
    firstHalf /= midpoint;
    secondHalf /= (frames.length - midpoint);

    if (firstHalf <= 0) return 0.5;
    final declineRatio = (firstHalf - secondHalf) / firstHalf;
    return (0.3 + declineRatio * 1.4).clamp(0.0, 1.0);
  }

  /// Compute how clean the energy transition is at a silence gap boundary.
  ///
  /// Looks at the energy envelope before and after the gap:
  /// - A clean transition: energy drops significantly before gap, rises after
  /// - A noisy transition: energy fluctuates on either side
  double _computeTransitionQuality(
    _PcmFrameReader reader,
    int gapStartSample,
    int gapEndSample,
    int frameSize,
  ) {
    // Look at frames before the gap (pre-gap energy)
    double preGapMax = 0;
    final preStart = (gapStartSample - frameSize * 3).clamp(0, gapStartSample);
    final preEnd = gapStartSample;
    for (int i = preStart; i < preEnd; i++) {
      final absVal = reader.frameEnergy(i).abs();
      if (absVal > preGapMax) preGapMax = absVal;
    }

    // Look at frames after the gap (post-gap energy)
    double postGapMax = 0;
    final postStart = gapEndSample;
    final postEnd = (gapEndSample + frameSize * 3).clamp(
      0,
      reader.info.totalSamples,
    );
    for (int i = postStart; i < postEnd; i++) {
      final absVal = reader.frameEnergy(i).abs();
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
    _PcmFrameReader reader,
    int gapStartSample,
    int frameSize,
    int sampleRate,
  ) {
    // Look at config.analysisWindowSeconds before the gap
    final windowFrames = (config.analysisWindowSeconds * sampleRate / frameSize)
        .round()
        .clamp(3, 30);
    final frames = <double>[];
    for (int f = 0; f < windowFrames; f++) {
      final start = (gapStartSample - (windowFrames - f) * frameSize).clamp(
        0,
        reader.info.totalSamples,
      );
      final end = (start + frameSize).clamp(0, reader.info.totalSamples);
      double sumAbs = 0;
      for (int i = start; i < end; i++) {
        sumAbs += reader.frameEnergy(i).abs();
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

    // decline ratio: 1.0 = complete silence, 0.5 = half energy, <0.5 = rising
    final declineRatio = (firstHalf - secondHalf) / firstHalf;
    // Map: declineRatio 0 → 0.3, declineRatio 0.5 → 1.0, declineRatio 1.0 → 1.0
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

    // Early return if audio is too short to warrant chunking.
    if (totalSamples <= minChunkSamples) {
      cuts.add(totalSamples);
      return cuts;
    }

    // Guard against invalid config (maxChunk <= 0 or max < min) that
    // would cause an infinite loop in force-cut logic.
    if (maxChunkSamples <= 0 || maxChunkSamples < minChunkSamples) {
      cuts.add(totalSamples);
      return cuts;
    }

    int currentSample = 0;

    while (currentSample + minChunkSamples < totalSamples) {
      final searchEnd = (currentSample + maxChunkSamples).clamp(
        0,
        totalSamples,
      );
      final searchStart = currentSample + minChunkSamples;

      // Find candidates in the search range
      final inRange = candidates
          .where(
            (c) =>
                c.samplePosition >= searchStart &&
                c.samplePosition <= searchEnd,
          )
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
          currentSample + minChunkSamples,
        );
        // Guard against duplicate totalSamples (already added at end)
        if (forcePos >= totalSamples) break;
        cuts.add(forcePos);
        currentSample = forcePos;
        continue;
      }

      // ── Score each candidate dynamically ──
      CandidateCut? best;
      double bestScore = -1;

      for (final c in inRange) {
        final score = _scoreCandidate(
          c,
          currentSample,
          targetChunkSamples,
          minChunkSamples,
          maxChunkSamples,
          sampleRate,
        );
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
          currentSample + minChunkSamples,
        );
        if (forcePos >= totalSamples) break;
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
    final clampedMinSilence = config.minSilenceDuration.clamp(0.1, 10);
    // Guard against NaN (Dart's NaN.clamp returns NaN, which propagates).
    if (clampedMinSilence.isNaN) return 0.5;
    final ratio = c.silenceDuration / clampedMinSilence;
    // log base 5: at ratio=0 → 0, at ratio=4 (4× min silence) → 1.0
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
    int minimumPosition,
  ) {
    if (minimumPosition >= totalSamples) return totalSamples;

    // Search for candidates within ±3s of preferredPos
    final windowSamples = (3 * sampleRate).round();
    CandidateCut? nearest;
    int nearestDist = windowSamples + 1;

    for (final c in candidates) {
      if (c.samplePosition < minimumPosition ||
          c.samplePosition >= totalSamples) {
        continue;
      }
      final dist = (c.samplePosition - preferredPos).abs();
      if (dist < nearestDist && dist <= windowSamples) {
        nearest = c;
        nearestDist = dist;
      }
    }

    if (nearest != null) return nearest.samplePosition;

    return preferredPos.clamp(minimumPosition, totalSamples);
  }

  /// Split WAV into chunks of fixed [config.fixedDurationSeconds] seconds.
  /// No overlap — chunks are strictly consecutive.
  List<Uint8List> splitByDuration(Uint8List wavBytes, {int? maxChunks}) {
    final info = parseWavHeader(wavBytes);
    _validateForWav(info);
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
        _checkChunkCapacity(chunks.length, maxChunks);
        chunks.add(
          _writeWavChunk(wavBytes, info, startSample * bpf, endSample * bpf),
        );
      } else {
        // Split by the maximum number of complete frames that fit under the
        // payload limit, preserving the frame boundary at each cut.
        final maxFramesPerPart = config.maxChunkBytes ~/ bpf;
        for (int subStart = startSample;
            subStart < endSample;
            subStart += maxFramesPerPart) {
          final subEnd = (subStart + maxFramesPerPart).clamp(0, endSample);
          if (subEnd > subStart) {
            _checkChunkCapacity(chunks.length, maxChunks);
            chunks.add(
              _writeWavChunk(wavBytes, info, subStart * bpf, subEnd * bpf),
            );
          }
        }
      }
    }

    return chunks;
  }

  /// Split WAV into chunks that stay under [config.maxChunkBytes].
  /// Simple byte-count splitting — no silence awareness, no overlap.
  List<Uint8List> splitBySize(Uint8List wavBytes, {int? maxChunks}) {
    final info = parseWavHeader(wavBytes);
    _validateForWav(info);
    final bpf = info.bytesPerFrame;
    final totalSamples = info.totalSamples;
    final chunks = <Uint8List>[];

    final chunkSamples = (config.maxChunkBytes ~/ bpf).clamp(1, totalSamples);

    for (int startSample = 0;
        startSample < totalSamples;
        startSample += chunkSamples) {
      int endSample = (startSample + chunkSamples).clamp(0, totalSamples);
      if (endSample <= startSample) break;

      _checkChunkCapacity(chunks.length, maxChunks);
      chunks.add(
        _writeWavChunk(wavBytes, info, startSample * bpf, endSample * bpf),
      );
    }

    return chunks;
  }

  void _validateMaxChunks(int? maxChunks) {
    if (maxChunks != null && maxChunks <= 0) {
      throw ArgumentError.value(maxChunks, 'maxChunks');
    }
  }

  void _checkChunkCapacity(int currentChunks, int? maxChunks) {
    if (maxChunks != null && currentChunks >= maxChunks) {
      throw Exception('初始切块数量超过安全上限 $maxChunks，已停止上传。');
    }
  }

  void _validateForWav(WavInfo info) {
    config.validateForSampleRate(info.sampleRate);
    if (config.maxChunkBytes < info.bytesPerFrame) {
      throw ArgumentError.value(
        config.maxChunkBytes,
        'maxChunkBytes',
        'must fit at least one ${info.bytesPerFrame}-byte PCM frame',
      );
    }
  }
}

// ============================================================================
// WAV Writer (chunk output)
// ============================================================================

/// Write a slice of PCM data as a complete WAV file.
Uint8List _writeWavChunk(
  Uint8List wavBytes,
  WavInfo info,
  int pcmStart,
  int pcmEnd,
) {
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

  // Copy PCM data slice using zero-copy Uint8List.view
  final sliceBytes = Uint8List.view(
    wavBytes.buffer,
    wavBytes.offsetInBytes + info.dataOffset + pcmStart,
    dataSize,
  );
  writer.writeBytes(sliceBytes);

  return writer.toBytes();
}

/// Rebuild a PCM WAV container without ancillary chunks or padding metadata.
Uint8List canonicalizePcmWav(Uint8List wavBytes) {
  final info = parseWavHeader(wavBytes);
  return _writeWavChunk(wavBytes, info, 0, info.dataSize);
}

/// Materialize only the first PCM frame as a valid WAV file.
Uint8List materializeFirstWavFrame(
  Uint8List wavBytes, {
  @visibleForTesting
  void Function(int startByte, int endByte)? onFrameRangeMaterializedForTesting,
}) {
  final info = parseWavHeader(wavBytes);
  if (info.totalSamples == 0) {
    throw RangeError.value(
      info.totalSamples,
      'totalSamples',
      'WAV contains no complete PCM frames',
    );
  }
  final frameEndByte = info.bytesPerFrame;
  onFrameRangeMaterializedForTesting?.call(0, frameEndByte);
  return _writeWavChunk(wavBytes, info, 0, frameEndByte);
}

/// Split a PCM WAV at [frameIndex], keeping both outputs frame-aligned.
///
/// The concatenated PCM data of the returned WAV files is byte-for-byte equal
/// to the source data. This is used when an encoded chunk must be reduced to
/// fit a transport budget.
List<Uint8List> splitWavAtFrame(Uint8List wavBytes, int frameIndex) {
  final info = parseWavHeader(wavBytes);
  if (frameIndex <= 0 || frameIndex >= info.totalSamples) {
    throw RangeError.range(frameIndex, 1, info.totalSamples - 1, 'frameIndex');
  }
  final splitByte = frameIndex * info.bytesPerFrame;
  return [
    _writeWavChunk(wavBytes, info, 0, splitByte),
    _writeWavChunk(wavBytes, info, splitByte, info.dataSize),
  ];
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

  /// Process a WAV file with bounded auxiliary memory.
  Uint8List process(Uint8List wavBytes) {
    if (config == AudioPreprocessConfig.none) return wavBytes;
    final plan = _WavPreprocessPlan(wavBytes, config);
    for (var index = 0; index < plan.outputSampleCount; index++) {
      plan.writeSample(index);
    }
    return plan.finish();
  }

  /// Process on a native isolate, or yield to the event loop on Web.
  Future<Uint8List> processAsync(
    Uint8List wavBytes, {
    void Function()? checkCancelled,
    Future<Object?>? cancellationSignal,
  }) async {
    checkCancelled?.call();
    if (config == AudioPreprocessConfig.none) {
      if (cancellationSignal != null) {
        final ensureNotCancelled = _cancellationCheck(
          checkCancelled,
          cancellationSignal,
        );
        await Future<void>.delayed(Duration.zero);
        ensureNotCancelled?.call();
      }
      return wavBytes;
    }
    if (kIsWeb) {
      return processWithEventLoopYield(
        wavBytes,
        checkCancelled: checkCancelled,
        cancellationSignal: cancellationSignal,
      );
    }
    final processed = await computeCancellableWithRequestFactory(
      _preprocessWavInBackground,
      () => _WavPreprocessRequest(IsolateTransferableBytes(wavBytes), config),
      debugLabel: 'asr-audio-preprocess',
      cancellationSignal: cancellationSignal,
    );
    checkCancelled?.call();
    return processed;
  }

  /// Web-compatible preprocessing with bounded output-sample batches.
  Future<Uint8List> processWithEventLoopYield(
    Uint8List wavBytes, {
    void Function()? onYield,
    void Function()? checkCancelled,
    Future<Object?>? cancellationSignal,
  }) async {
    final ensureNotCancelled = _cancellationCheck(
      checkCancelled,
      cancellationSignal,
    );
    ensureNotCancelled?.call();
    if (config == AudioPreprocessConfig.none) {
      if (cancellationSignal != null) {
        await Future<void>.delayed(Duration.zero);
      }
      ensureNotCancelled?.call();
      return wavBytes;
    }
    final plan = _WavPreprocessPlan(wavBytes, config);
    const batchSize = _webYieldAnalysisFrameCount * 32;
    for (var start = 0; start < plan.outputSampleCount; start += batchSize) {
      ensureNotCancelled?.call();
      final end = (start + batchSize).clamp(0, plan.outputSampleCount);
      for (var index = start; index < end; index++) {
        plan.writeSample(index);
      }
      if (end < plan.outputSampleCount) {
        onYield?.call();
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (cancellationSignal != null) {
      await Future<void>.delayed(Duration.zero);
    }
    ensureNotCancelled?.call();
    return plan.finish();
  }
}

class _WavPreprocessPlan {
  final WavInfo info;
  late final int outputSampleRate;
  late final int outputChannels;
  late final int outputSampleCount;
  late final int _workingSampleCount;
  late final int _dataSize;
  late final int _fileSize;
  late final bool _downmix;
  late final bool _resample;
  late final bool _downsample;
  late final int _filterLength;
  late final ByteData _source;
  late final ByteData _output;

  _WavPreprocessPlan(Uint8List wavBytes, AudioPreprocessConfig config)
      : info = parseWavHeader(wavBytes) {
    final selectedRate = config.targetSampleRate;
    outputSampleRate = selectedRate ?? info.sampleRate;
    _downmix = config.forceMono && info.numChannels > 1;
    outputChannels = _downmix ? 1 : info.numChannels;
    _workingSampleCount =
        _downmix ? info.totalSamples : info.totalSamples * info.numChannels;
    _resample = selectedRate != null && selectedRate != info.sampleRate;
    _downsample = _resample && outputSampleRate < info.sampleRate;
    _filterLength = _downsample
        ? (info.sampleRate / outputSampleRate).round().clamp(1, 32)
        : 1;
    outputSampleCount = _resample
        ? (_workingSampleCount * outputSampleRate / info.sampleRate).round()
        : _workingSampleCount;
    _dataSize = outputSampleCount * 2;
    _fileSize = 44 + _dataSize;
    _source = wavBytes.buffer.asByteData(
      wavBytes.offsetInBytes + info.dataOffset,
      info.dataSize,
    );
    _output = ByteData(_fileSize);
    _writeHeader();
  }

  double _sourceSample(int index) =>
      _source.getInt16(index * 2, Endian.little) / 32768.0;

  double _workingSample(int index) {
    if (!_downmix) return _sourceSample(index);
    double sum = 0;
    final firstChannelSample = index * info.numChannels;
    for (var channel = 0; channel < info.numChannels; channel++) {
      sum += _sourceSample(firstChannelSample + channel);
    }
    return sum / info.numChannels;
  }

  double _filteredSample(int index) {
    if (!_downsample) return _workingSample(index);
    double sum = 0;
    double weightSum = 0;
    for (var delta = -_filterLength; delta <= _filterLength; delta++) {
      final sourceIndex = index + delta;
      if (sourceIndex < 0 || sourceIndex >= _workingSampleCount) continue;
      final weight = 1.0 - delta.abs() / (_filterLength + 1);
      sum += _workingSample(sourceIndex) * weight;
      weightSum += weight;
    }
    return weightSum > 0 ? sum / weightSum : _workingSample(index);
  }

  double _outputSample(int index) {
    if (!_resample) return _workingSample(index);
    final position = index * info.sampleRate / outputSampleRate;
    final first = position.floor();
    final fraction = position - first;
    final left = _filteredSample(first);
    if (first + 1 >= _workingSampleCount) return left;
    final right = _filteredSample(first + 1);
    return left * (1 - fraction) + right * fraction;
  }

  void writeSample(int index) {
    final value = (_outputSample(index) * 32767).round().clamp(-32768, 32767);
    _output.setInt16(44 + index * 2, value, Endian.little);
  }

  Uint8List finish() => Uint8List.view(_output.buffer, 0, _fileSize);

  void _writeHeader() {
    var offset = 0;
    void writeFourCc(String value) {
      for (var index = 0; index < 4; index++) {
        _output.setUint8(offset++, value.codeUnitAt(index));
      }
    }

    void writeUint16(int value) {
      _output.setUint16(offset, value, Endian.little);
      offset += 2;
    }

    void writeUint32(int value) {
      _output.setUint32(offset, value, Endian.little);
      offset += 4;
    }

    final blockAlign = outputChannels * 2;
    writeFourCc('RIFF');
    writeUint32(_fileSize - 8);
    writeFourCc('WAVE');
    writeFourCc('fmt ');
    writeUint32(16);
    writeUint16(1);
    writeUint16(outputChannels);
    writeUint32(outputSampleRate);
    writeUint32(outputSampleRate * blockAlign);
    writeUint16(blockAlign);
    writeUint16(16);
    writeFourCc('data');
    writeUint32(_dataSize);
  }
}

class _WavPreprocessRequest {
  final IsolateTransferableBytes wavBytes;
  final AudioPreprocessConfig config;

  const _WavPreprocessRequest(this.wavBytes, this.config);
}

Uint8List _preprocessWavInBackground(_WavPreprocessRequest request) =>
    WavPreprocessor(
      config: request.config,
    ).process(request.wavBytes.materialize());

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
