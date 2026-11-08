import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/asr_retry_storage.dart';
import 'package:stroom/utils/audio_chunker.dart';

class _BenchmarkRetryStorageAdapter implements AsrRetryStorageAdapter {
  final files = <String, Uint8List>{};

  @override
  Future<void> write(String key, Uint8List bytes) async {
    files[key] = bytes;
  }

  @override
  Future<Uint8List?> read(String key) async {
    final bytes = files[key];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  Future<void> delete(String key) async {
    files.remove(key);
  }

  @override
  Future<List<String>> keysWithPrefix(String prefix) async =>
      files.keys.where((key) => key.startsWith(prefix)).toList();
}

Uint8List _wavHeader(int dataSize) {
  const sampleRate = 16000;
  const channels = 1;
  const bytesPerSample = 2;
  final header = Uint8List(44);
  final data = ByteData.sublistView(header);

  void tag(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      data.setUint8(offset + index, value.codeUnitAt(index));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, dataSize + 36, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * channels * bytesPerSample, Endian.little);
  data.setUint16(32, channels * bytesPerSample, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, dataSize, Endian.little);
  return header;
}

Future<void> _writeZeroWav(File file, int minutes) async {
  const sampleRate = 16000;
  const channels = 1;
  const bytesPerSample = 2;
  final dataSize = minutes * 60 * sampleRate * channels * bytesPerSample;
  final sink = file.openWrite();
  sink.add(_wavHeader(dataSize));
  final zeroBlock = Uint8List(1024 * 1024);
  var remaining = dataSize;
  while (remaining > 0) {
    final count = remaining.clamp(0, zeroBlock.length);
    sink.add(
      count == zeroBlock.length ? zeroBlock : zeroBlock.sublist(0, count),
    );
    remaining -= count;
  }
  await sink.flush();
  await sink.close();
}

int _vmHwmBytes() {
  if (!Platform.isLinux) return -1;
  final lines = File('/proc/self/status').readAsLinesSync();
  final line = lines.firstWhere((entry) => entry.startsWith('VmHWM:'));
  return int.parse(RegExp(r'\d+').firstMatch(line)!.group(0)!) * 1024;
}

Future<Map<String, Object?>> _runScenario(
  int minutesPerFile,
  int fileCount, {
  required String mode,
  Future<void> Function()? beforeInputGeneration,
}) async {
  final eager = mode == 'eager-allocation-control';
  const sampleRate = 16000;
  const bytesPerFrame = 2;
  final tempDir = await Directory.systemTemp.createTemp(
    'asr-resource-benchmark-',
  );
  final beforeBuildHwm = _vmHwmBytes();

  final buildWatch = Stopwatch()..start();
  await beforeInputGeneration?.call();
  final files = <File>[];
  for (var index = 0; index < fileCount; index++) {
    final file = File('${tempDir.path}/audio-$index.wav');
    await _writeZeroWav(file, minutesPerFile);
    files.add(file);
  }
  buildWatch.stop();
  final afterBuildHwm = _vmHwmBytes();

  final timerWatch = Stopwatch()..start();
  var previousTickMs = 0;
  var maxTimerGapMs = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
    final now = timerWatch.elapsedMilliseconds;
    final gap = now - previousTickMs;
    if (gap > maxTimerGapMs) maxTimerGapMs = gap;
    previousTickMs = now;
  });
  await Future<void>.delayed(const Duration(milliseconds: 20));

  final chunker = const AudioChunker();
  final perFile = <Map<String, Object?>>[];
  var totalChunks = 0;
  var totalCoveredPcmBytes = 0;
  var totalSourcePcmBytes = 0;
  var totalCoveredFrames = 0;
  var totalSourceFrames = 0;
  var inputReadMs = 0;
  final retainedSources = <Uint8List>[];
  final retainedChunks = <Uint8List>[];
  final resourceWorkWatch = Stopwatch();
  final retryStageWatch = Stopwatch();
  final processingWatch = Stopwatch()..start();
  final retryAdapter = _BenchmarkRetryStorageAdapter();
  final retryStore = AsrRetryAudioStore(adapter: retryAdapter);
  for (final file in files) {
    final readWatch = Stopwatch()..start();
    final source = await file.readAsBytes();
    readWatch.stop();
    inputReadMs += readWatch.elapsedMilliseconds;
    retryStageWatch.start();
    final retryReference = await retryStore.save(
      source,
      name: file.uri.pathSegments.last,
      format: 'wav',
    );
    await retryStore.releaseProtection(retryReference);
    await retryStore.delete(retryReference);
    retryStageWatch.stop();
    var planningSource = source;
    if (eager) {
      final pageSnapshot = Uint8List.fromList(source);
      final schedulerSnapshot = Uint8List.fromList(pageSnapshot);
      retainedSources
        ..add(source)
        ..add(pageSnapshot)
        ..add(schedulerSnapshot);
      planningSource = schedulerSnapshot;
    }
    resourceWorkWatch.start();
    final planWatch = Stopwatch()..start();
    final ranges = await chunker.planAsync(
      planningSource,
      AudioChunkMethod.silence,
    );
    planWatch.stop();

    var coveredPcmBytes = 0;
    var coveredFrames = 0;
    final materializeWatch = Stopwatch()..start();
    for (final range in ranges) {
      final chunk = chunker.materializeChunk(planningSource, range);
      if (eager) retainedChunks.add(chunk);
      final info = parseWavHeader(chunk);
      coveredPcmBytes += info.dataSize;
      coveredFrames += info.totalSamples;
      if (!eager) await Future<void>.delayed(Duration.zero);
    }
    materializeWatch.stop();
    resourceWorkWatch.stop();

    final sourceInfo = parseWavHeader(planningSource);
    perFile.add({
      'planMs': planWatch.elapsedMilliseconds,
      'materializeMs': materializeWatch.elapsedMilliseconds,
      'chunkCount': ranges.length,
      'coveredPcmBytes': coveredPcmBytes,
      'sourcePcmBytes': sourceInfo.dataSize,
      'coveredFrames': coveredFrames,
      'sourceFrames': sourceInfo.totalSamples,
    });
    totalChunks += ranges.length;
    totalCoveredPcmBytes += coveredPcmBytes;
    totalSourcePcmBytes += sourceInfo.dataSize;
    totalCoveredFrames += coveredFrames;
    totalSourceFrames += sourceInfo.totalSamples;
    if (!eager) await Future<void>.delayed(Duration.zero);
  }
  processingWatch.stop();
  final afterProcessingHwm = _vmHwmBytes();
  final retainedSourceBytes = retainedSources.fold<int>(
    0,
    (sum, bytes) => sum + bytes.length,
  );
  final retainedChunkBytes = retainedChunks.fold<int>(
    0,
    (sum, bytes) => sum + bytes.length,
  );
  await Future<void>.delayed(const Duration(milliseconds: 30));
  timer.cancel();

  final totalInputBytes =
      fileCount * (minutesPerFile * 60 * sampleRate * bytesPerFrame + 44);
  final result = <String, Object?>{
    'mode': mode,
    'minutesPerFile': minutesPerFile,
    'fileCount': fileCount,
    'inputMiB': totalInputBytes / 1048576,
    'inputBuildMs': buildWatch.elapsedMilliseconds,
    'inputReadMs': inputReadMs,
    'retryAudioStageMs': retryStageWatch.elapsedMilliseconds,
    'planAndMaterializeMs': resourceWorkWatch.elapsedMilliseconds,
    'processingMs': processingWatch.elapsedMilliseconds,
    'beforeInputHwmBytes': beforeBuildHwm,
    'afterInputFilesHwmBytes': afterBuildHwm,
    'afterProcessingHwmBytes': afterProcessingHwm,
    'eagerRetainedSourceBytes': retainedSourceBytes,
    'eagerRetainedChunkBytes': retainedChunkBytes,
    'maxEventLoopTimerGapMs': maxTimerGapMs,
    'chunkCount': totalChunks,
    'coveredPcmBytes': totalCoveredPcmBytes,
    'sourcePcmBytes': totalSourcePcmBytes,
    'coveredFrames': totalCoveredFrames,
    'sourceFrames': totalSourceFrames,
    'files': perFile,
  };
  await tempDir.delete(recursive: true);
  return result;
}

void main() {
  test('responsiveness timing excludes input generation setup', () async {
    final result = await _runScenario(
      1,
      1,
      mode: 'lazy-segmented',
      beforeInputGeneration: () async =>
          sleep(const Duration(milliseconds: 400)),
    );

    expect(result['inputBuildMs'], greaterThanOrEqualTo(400));
    expect(result['maxEventLoopTimerGapMs'], lessThan(300));
  });

  final environment = Platform.environment;
  final skipBenchmark = !environment.containsKey('ASR_BENCH_MINUTES') &&
      !environment.containsKey('ASR_BENCH_FILE_COUNT') &&
      !environment.containsKey('ASR_BENCH_MODE');
  test(
    'runs one ASR resource benchmark scenario',
    () async {
      final minutes = int.tryParse(environment['ASR_BENCH_MINUTES'] ?? '');
      final fileCount = int.tryParse(environment['ASR_BENCH_FILE_COUNT'] ?? '');
      final mode = environment['ASR_BENCH_MODE'];
      if (minutes == null ||
          minutes <= 0 ||
          fileCount == null ||
          fileCount <= 0 ||
          (mode != 'eager-allocation-control' && mode != 'lazy-segmented')) {
        fail(
          'Set ASR_BENCH_MINUTES and ASR_BENCH_FILE_COUNT to positive integers, and ASR_BENCH_MODE to eager-allocation-control or lazy-segmented.',
        );
      }

      final result = await _runScenario(minutes, fileCount, mode: mode!);
      stdout.writeln('ASR_RESOURCE_BENCHMARK ${jsonEncode(result)}');
      expect(result['coveredPcmBytes'], result['sourcePcmBytes']);
      expect(result['coveredFrames'], result['sourceFrames']);
    },
    skip: skipBenchmark ? 'Manual benchmark configuration is not set' : false,
  );
}
