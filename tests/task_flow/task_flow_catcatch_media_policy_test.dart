// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:stroom/catcatch/engine/executor_media.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/task_flow/models/block_type_definition.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/models/task_flow_exception.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/task_flow/services/block_executors/catcatch_executor.dart';
import 'package:stroom/task_flow/services/task_flow_validator.dart';
import 'package:stroom/utils/provider_models.dart';

import '../catcatch/init_only_fixture.dart';

class _Notifier extends Mock implements CatCatchNotifier {}

Future<String> _runCompletedUntypedMedia(String path,
    {required bool audioOutput, String? declaredMime}) {
  final sourceUrl = 'https://x/untyped${p.extension(path)}';
  final notifier = _Notifier();
  final executions = TaskFlowExecutionNotifier();
  final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
  final subTask = FlowSubTask(
    blockTypeKey: 'catcatch',
    blockLabel: '下载',
    subTaskId: 'pending',
    subTaskType: 'catcatch',
    status: TaskStatus.waiting,
  );
  executions.addSubTask(execId, subTask);
  late String taskId;
  when(() => notifier.addTask(any(), any(),
      taskId: any(named: 'taskId'),
      deferSingleResourceSelection: true)).thenAnswer((invocation) {
    taskId = invocation.namedArguments[#taskId] as String;
    return taskId;
  });
  when(() => notifier.state).thenAnswer((_) => [
        catcatch.CatCatchTask(
          id: taskId,
          url: sourceUrl,
          expectedDurationSec: 0,
          createdAt: DateTime(2026),
          status: catcatch.TaskStatus.completed,
          downloadedFilePath: path,
          selectedMedia: MediaResource(
            url: sourceUrl,
            name: 'untyped',
            ext: p.extension(path).substring(1),
            mimeType: declaredMime,
          ),
        ),
      ]);
  final block = TaskFlowBlock(
    typeKey: BlockType.catcatch,
    params: {'audioOutput': audioOutput, 'automaticResourceSelection': true},
  );
  return executeCatCatchBlock(
    def: block.getDefinition()!,
    block: block,
    input: sourceUrl,
    execId: execId,
    execNotifier: executions,
    flowSubTask: subTask,
    catcatchNotifier: notifier,
    pollInterval: const Duration(milliseconds: 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => registerFallbackValue(
      const MediaResource(
        url: 'https://example.com',
        name: 'fallback',
        ext: 'mp4',
      ),
    ),
  );

  const audio = MediaResource(
    url: 'https://x/a.mp4',
    name: 'audio',
    ext: 'mp4',
    mimeType: 'audio/mp4',
  );
  const split = MediaResource(
    url: 'https://x/s.mp4',
    name: 'split',
    ext: 'mp4',
    isLikelySplitTrack: true,
  );
  const videoZ = MediaResource(
    url: 'https://x/z.mp4',
    name: 'video',
    ext: 'mp4',
    mimeType: 'video/mp4',
  );
  const videoA = MediaResource(
    url: 'https://x/b.mp4',
    name: 'video',
    ext: 'mp4',
    mimeType: 'video/mp4',
  );
  const playlist = MediaResource(
    url: 'https://x/list.m3u8',
    name: 'list',
    ext: 'm3u8',
    isPlaylist: true,
  );

  test(
    'automatic choice ignores discovery order and incomplete split tracks',
    () {
      for (final resources in [
        [audio, split, videoZ, playlist, videoA],
        [videoA, playlist, videoZ, split, audio],
      ]) {
        expect(
          selectAutomaticCatCatchResource(resources, desiredType: IOType.video),
          videoA,
        );
        expect(
          selectAutomaticCatCatchResource(resources, desiredType: IOType.audio),
          audio,
        );
      }
      expect(
        selectAutomaticCatCatchResource([
          playlist,
          audio,
        ], desiredType: IOType.video),
        playlist,
      );
      expect(
        selectAutomaticCatCatchResource([split], desiredType: IOType.video),
        isNull,
      );
      expect(
        selectAutomaticCatCatchResource([audio], desiredType: IOType.video),
        audio,
      );
      for (final ext in [
        'mp4',
        'm4a',
        'mov',
        'ogg',
        'ogv',
        'opus',
        'webm',
        'weba',
        'mkv',
        'mka',
        'wma',
        'wmv',
        'avi',
        'mpeg',
        'mpg',
      ]) {
        final untyped = MediaResource(
          url: 'https://x/untyped.$ext',
          name: 'untyped',
          ext: ext,
        );
        expect(
          selectAutomaticCatCatchResource([untyped], desiredType: IOType.audio),
          untyped,
        );
        expect(
          selectAutomaticCatCatchResource([untyped], desiredType: IOType.video),
          untyped,
        );
      }
    },
  );

  test('shared container MIME guides preference without blocking verification',
      () {
    for (final (extension, mime, output) in [
      ('mkv', 'audio/x-matroska', IOType.audio),
      ('mka', 'video/x-matroska', IOType.video),
      ('wma', 'video/x-ms-wmv', IOType.video),
      ('wmv', 'audio/x-ms-wma', IOType.audio),
      ('avi', 'audio/x-msvideo', IOType.audio),
      ('mpg', 'audio/mpeg', IOType.audio),
    ]) {
      final resource = MediaResource(
        url: 'https://x/media.$extension',
        name: 'media',
        ext: extension,
        mimeType: mime,
      );
      expect(
        selectAutomaticCatCatchResource([resource], desiredType: output),
        resource,
        reason: extension,
      );
      expect(
        selectAutomaticCatCatchResource(
          [resource],
          desiredType: output == IOType.audio ? IOType.video : IOType.audio,
        ),
        resource,
        reason: extension,
      );
    }

    const videoDimensions = MediaResource(
      url: 'https://x/visual.wma',
      name: 'visual',
      ext: 'wma',
      mimeType: 'audio/x-ms-wma',
      width: 1920,
      height: 1080,
    );
    expect(
      selectAutomaticCatCatchResource(
        [videoDimensions],
        desiredType: IOType.video,
      ),
      videoDimensions,
    );
    expect(
      selectAutomaticCatCatchResource(
        [videoDimensions],
        desiredType: IOType.audio,
      ),
      videoDimensions,
    );
  });

  test('misleading MP4 MIME is a fallback behind a matching candidate', () {
    const advertisedVideo = MediaResource(
      url: 'https://x/audio-only.mp4',
      name: 'audio-only',
      ext: 'mp4',
      mimeType: 'video/mp4',
    );
    const advertisedAudio = MediaResource(
      url: 'https://x/video-only.mp4',
      name: 'video-only',
      ext: 'mp4',
      mimeType: 'audio/mp4',
    );
    expect(
      selectAutomaticCatCatchResource(
        [advertisedVideo],
        desiredType: IOType.audio,
      ),
      advertisedVideo,
    );
    expect(
      selectAutomaticCatCatchResource(
        [advertisedAudio],
        desiredType: IOType.video,
      ),
      advertisedAudio,
    );
    expect(
      selectAutomaticCatCatchResource(
        [advertisedVideo, audio],
        desiredType: IOType.audio,
      ),
      audio,
    );
    expect(
      selectAutomaticCatCatchResource(
        [advertisedAudio, videoA],
        desiredType: IOType.video,
      ),
      videoA,
    );
  });

  test('audio/mp4 and video/mp4 with matching duration form a split pair', () {
    final detected = detectSplitTracks(const [
      MediaResource(
        url: 'https://x/audio.mp4',
        name: 'capture_audio',
        ext: 'mp4',
        mimeType: 'audio/mp4',
        duration: '00:01:00',
      ),
      MediaResource(
        url: 'https://x/video.mp4',
        name: 'capture_video',
        ext: 'mp4',
        mimeType: 'video/mp4',
        duration: '00:01:00',
      ),
    ]);
    expect(detected.every((media) => media.isLikelySplitTrack), isTrue);
    expect(detected.first.groupId, detected.last.groupId);
    expect(
      selectAutomaticCatCatchResource(detected, desiredType: IOType.video),
      isNull,
    );
    expect(
      selectAutomaticCatCatchResource(detected, desiredType: IOType.audio),
      isNull,
    );
  });

  test('MIME-less WebView MP4 audio pairs with video-only MP4', () {
    for (final (audioDuration, videoDuration, audioName, videoName) in [
      ('00:01:00', '00:01:01', 'resource_813', 'resource_945'),
      (null, null, 'capture_audio', 'capture_video'),
    ]) {
      final detected = detectSplitTracks([
        MediaResource(
          url: 'https://x/capture_audio.mp4',
          name: audioName,
          ext: 'mp4',
          initiator: 'https://x/watch',
          isPlayable: true,
          duration: audioDuration,
        ),
        MediaResource(
          url: 'https://x/capture_video.mp4',
          name: videoName,
          ext: 'mp4',
          mimeType: 'video/mp4',
          initiator: 'https://x/watch',
          isPlayable: true,
          width: 1920,
          height: 1080,
          duration: videoDuration,
        ),
      ]);
      expect(detected.every((media) => media.isLikelySplitTrack), isTrue);
      expect(detected.first.groupId, detected.last.groupId);
      expect(
        selectAutomaticCatCatchResource(detected, desiredType: IOType.video),
        isNull,
      );
    }
  });

  test('two untyped WebView MP4 resources with matching duration need review',
      () {
    final detected = detectSplitTracks(const [
      MediaResource(
        url: 'https://x/segment-813.mp4',
        name: 'segment-813',
        ext: 'mp4',
        duration: '00:01:00',
        initiator: 'https://x/watch',
      ),
      MediaResource(
        url: 'https://x/segment-945.mp4',
        name: 'segment-945',
        ext: 'mp4',
        duration: '00:01:01',
        initiator: 'https://x/watch',
      ),
    ]);
    expect(detected.every((media) => media.isLikelySplitTrack), isTrue);
    expect(detected.first.groupId, detected.last.groupId);
    expect(
      selectAutomaticCatCatchResource(detected, desiredType: IOType.video),
      isNull,
    );
    expect(
      selectAutomaticCatCatchResource(detected, desiredType: IOType.audio),
      isNull,
    );
  });

  test('lone untyped MP4 stays selectable; unrelated durations do not pair',
      () {
    const untyped = MediaResource(
      url: 'https://x/complete.mp4',
      name: 'complete',
      ext: 'mp4',
      duration: '00:01:00',
    );
    expect(detectSplitTracks([untyped]).single.isLikelySplitTrack, isFalse);
    expect(
      selectAutomaticCatCatchResource([untyped], desiredType: IOType.video),
      untyped,
    );

    for (final mime in [null, 'video/mp4']) {
      final detected = detectSplitTracks([
        untyped,
        MediaResource(
          url: 'https://x/unrelated.mp4',
          name: 'unrelated',
          ext: 'mp4',
          mimeType: mime,
          duration: '00:03:00',
        ),
      ]);
      expect(detected.every((media) => !media.isLikelySplitTrack), isTrue);
      expect(detected.every((media) => media.groupId == null), isTrue);
    }
  });

  test('shared container MIME can identify split tracks despite extension', () {
    for (final (audioExt, audioMime, videoExt, videoMime) in [
      ('mkv', 'audio/x-matroska', 'mp4', 'video/mp4'),
      ('wmv', 'audio/x-ms-wma', 'mp4', 'video/mp4'),
      ('mp3', 'audio/mpeg', 'wma', 'video/x-ms-wmv'),
    ]) {
      final detected = detectSplitTracks([
        MediaResource(
          url: 'https://x/capture_audio.$audioExt',
          name: 'capture_audio',
          ext: audioExt,
          mimeType: audioMime,
          duration: '00:01:00',
        ),
        MediaResource(
          url: 'https://x/capture_video.$videoExt',
          name: 'capture_video',
          ext: videoExt,
          mimeType: videoMime,
          duration: '00:01:00',
        ),
      ]);
      expect(detected.every((media) => media.isLikelySplitTrack), isTrue,
          reason: '$audioExt + $videoExt');
      expect(detected.first.groupId, detected.last.groupId);
    }
  });

  test('WebView audio aliases pair with a video-only resource without MIME',
      () {
    for (final ext in ['m4a', 'weba']) {
      final audioTrack = MediaResource(
        url: 'https://x/capture_audio.$ext',
        name: 'capture_audio',
        ext: ext,
        initiator: 'https://x/watch',
        isPlayable: true,
      );
      final detected = detectSplitTracks([
        audioTrack,
        const MediaResource(
          url: 'https://x/capture_video.mp4',
          name: 'capture_video',
          ext: 'mp4',
          mimeType: 'video/mp4',
          initiator: 'https://x/watch',
          isPlayable: true,
        ),
      ]);
      expect(detected.every((media) => media.isLikelySplitTrack), isTrue,
          reason: ext);
      expect(detected.first.groupId, detected.last.groupId, reason: ext);
      expect(
        selectAutomaticCatCatchResource(detected, desiredType: IOType.video),
        isNull,
        reason: ext,
      );
      expect(
        selectAutomaticCatCatchResource(detected, desiredType: IOType.audio),
        isNull,
        reason: ext,
      );
      // The alias alone may still contain video; final bytes decide its type.
      expect(
        selectAutomaticCatCatchResource([audioTrack],
            desiredType: IOType.video),
        audioTrack,
      );
    }
  });

  test('video dimensions keep a misnamed audio alias out of a split pair', () {
    const completeVideo = MediaResource(
      url: 'https://x/capture_audio.m4a',
      name: 'capture_audio',
      ext: 'm4a',
      width: 1920,
      height: 1080,
      duration: '00:01:00',
    );
    final detected = detectSplitTracks(const [
      completeVideo,
      MediaResource(
        url: 'https://x/capture_video.mp4',
        name: 'capture_video',
        ext: 'mp4',
        mimeType: 'video/mp4',
        duration: '00:01:00',
      ),
    ]);
    expect(detected.every((media) => !media.isLikelySplitTrack), isTrue);
    expect(detected.every((media) => media.groupId == null), isTrue);
    expect(
      selectAutomaticCatCatchResource(detected, desiredType: IOType.video),
      completeVideo,
    );
  });

  test('video dimensions override misleading audio MIME in split detection',
      () {
    final detected = detectSplitTracks(const [
      MediaResource(
        url: 'https://x/first.mp4',
        name: 'capture_first',
        ext: 'mp4',
        mimeType: 'audio/mp4',
        width: 1920,
        height: 1080,
        duration: '00:01:00',
      ),
      MediaResource(
        url: 'https://x/second.mp4',
        name: 'capture_second',
        ext: 'mp4',
        mimeType: 'video/mp4',
        width: 1920,
        height: 1080,
        duration: '00:01:00',
      ),
    ]);
    expect(detected.every((media) => !media.isLikelySplitTrack), isTrue);
    expect(detected.every((media) => media.groupId == null), isTrue);
  });

  test('untyped shared containers do not mark a complete MP3 as split', () {
    const completeAudio = MediaResource(
      url: 'https://x/complete.mp3',
      name: 'complete',
      ext: 'mp3',
      mimeType: 'audio/mpeg',
      duration: '00:01:00',
    );
    for (final ext in [
      'mp4',
      'ogg',
      'webm',
      'mov',
      'mkv',
      'mka',
      'wma',
      'wmv'
    ]) {
      final detected = detectSplitTracks([
        MediaResource(
          url: 'https://x/unknown.$ext',
          name: 'unknown',
          ext: ext,
          duration: '00:01:00',
        ),
        completeAudio,
      ]);
      expect(detected.every((media) => !media.isLikelySplitTrack), isTrue);
      expect(detected.every((media) => media.groupId == null), isTrue);
      expect(
        selectAutomaticCatCatchResource(detected, desiredType: IOType.audio),
        completeAudio,
      );
    }
  });

  test('MP3 extension wins over conflicting video MIME before selection', () {
    const mislabeled = MediaResource(
      url: 'https://x/audio.mp3',
      name: 'audio',
      ext: 'mp3',
      mimeType: 'video/mp4',
      duration: '00:01:00',
    );
    expect(
      selectAutomaticCatCatchResource([mislabeled], desiredType: IOType.audio),
      mislabeled,
    );
    expect(
      selectAutomaticCatCatchResource([mislabeled], desiredType: IOType.video),
      isNull,
    );
    final detected = detectSplitTracks(const [
      mislabeled,
      MediaResource(
        url: 'https://x/other.mp3',
        name: 'other',
        ext: 'mp3',
        duration: '00:01:00',
      ),
    ]);
    expect(detected.every((media) => !media.isLikelySplitTrack), isTrue);
  });

  test('MP3 extension wins over conflicting video MIME in flow output',
      () async {
    final path = p.absolute('tests/fixtures/catcatch/audio_only.mp3');
    expect(
      await _runCompletedUntypedMedia(path,
          audioOutput: true, declaredMime: 'video/mp4'),
      path,
    );
    await expectLater(
      _runCompletedUntypedMedia(path,
          audioOutput: false, declaredMime: 'video/mp4'),
      throwsA(isA<BlockExecutionException>().having(
        (e) => e.message,
        'message',
        contains('下载结果为音频'),
      )),
    );
  });

  test('HTML response named MP3 fails before entering an audio flow', () async {
    final directory = await Directory.systemTemp.createTemp('catcatch_kind_');
    try {
      final path = p.join(directory.path, 'song.mp3');
      await File(path).writeAsString('<!doctype html><html>Not found</html>');
      await expectLater(
        _runCompletedUntypedMedia(path,
            audioOutput: true, declaredMime: 'audio/mpeg'),
        throwsA(isA<BlockExecutionException>().having(
          (e) => e.message,
          'message',
          contains('无法验证下载文件的音视频类型'),
        )),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  for (final extension in ['wav', 'aac']) {
    test('valid $extension passes an audio flow despite video MIME', () async {
      final path = p.absolute('tests/fixtures/catcatch/audio_only.$extension');
      expect(
        await _runCompletedUntypedMedia(path,
            audioOutput: true, declaredMime: 'video/mp4'),
        path,
      );
    });
  }

  test('video ASF named WMA cannot pass an audio flow', () async {
    final directory = await Directory.systemTemp.createTemp('catcatch_kind_');
    try {
      final path = p.join(directory.path, 'video_as_audio.wma');
      await File(p.join('tests', 'fixtures', 'catcatch', 'video_only.wmv'))
          .copy(path);
      await expectLater(
        _runCompletedUntypedMedia(path,
            audioOutput: true, declaredMime: 'audio/x-ms-wma'),
        throwsA(isA<BlockExecutionException>().having(
          (e) => e.message,
          'message',
          contains('下载结果为视频'),
        )),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('MIME-less audio MP4 passes audio flow and fails video flow', () async {
    final path = p.absolute('tests/fixtures/catcatch/audio_only.mp4');
    expect(await _runCompletedUntypedMedia(path, audioOutput: true), path);
    await expectLater(
      _runCompletedUntypedMedia(path, audioOutput: false),
      throwsA(isA<BlockExecutionException>().having(
        (e) => e.message,
        'message',
        contains('下载结果为音频'),
      )),
    );
  });

  test('MIME-less video MP4 passes video flow and fails audio flow', () async {
    final path = p.absolute('tests/fixtures/catcatch/video_only.mp4');
    expect(await _runCompletedUntypedMedia(path, audioOutput: false), path);
    await expectLater(
      _runCompletedUntypedMedia(path, audioOutput: true),
      throwsA(isA<BlockExecutionException>().having(
        (e) => e.message,
        'message',
        contains('下载结果为视频'),
      )),
    );
  });

  test('unverifiable MIME-less MP4 fails clearly', () async {
    final directory = await Directory.systemTemp.createTemp('catcatch_kind_');
    try {
      final path = p.join(directory.path, 'unknown.mp4');
      await File(path).writeAsBytes([0, 1, 2, 3]);
      await expectLater(
        _runCompletedUntypedMedia(path, audioOutput: false),
        throwsA(isA<BlockExecutionException>().having(
          (e) => e.message,
          'message',
          contains('无法验证下载文件的音视频类型'),
        )),
      );
      await expectLater(
        _runCompletedUntypedMedia(path,
            audioOutput: false, declaredMime: 'video/mp4'),
        throwsA(isA<BlockExecutionException>().having(
          (e) => e.message,
          'message',
          contains('无法验证下载文件的音视频类型'),
        )),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  for (final fixtureName in ['audio_only.mp4', 'video_only.webm']) {
    test('$fixtureName initialization segment cannot enter a flow', () async {
      final directory =
          await Directory.systemTemp.createTemp('catcatch_init_flow_');
      try {
        final file = await writeInitOnlyFixture(directory, fixtureName);
        await expectLater(
          _runCompletedUntypedMedia(file.path,
              audioOutput: fixtureName.startsWith('audio')),
          throwsA(isA<BlockExecutionException>().having(
            (e) => e.message,
            'message',
            contains('无法验证下载文件的音视频类型'),
          )),
        );
      } finally {
        await directory.delete(recursive: true);
      }
    });
  }

  for (final container in ['ogg', 'webm', 'mov']) {
    test('MIME-less audio $container passes audio flow and fails video flow',
        () async {
      final path = p.absolute('tests/fixtures/catcatch/audio_only.$container');
      expect(await _runCompletedUntypedMedia(path, audioOutput: true), path);
      await expectLater(
        _runCompletedUntypedMedia(path, audioOutput: false),
        throwsA(isA<BlockExecutionException>().having(
          (e) => e.message,
          'message',
          contains('下载结果为音频'),
        )),
      );
    });

    test('MIME-less video $container passes video flow and fails audio flow',
        () async {
      final path = p.absolute('tests/fixtures/catcatch/video_only.$container');
      expect(await _runCompletedUntypedMedia(path, audioOutput: false), path);
      await expectLater(
        _runCompletedUntypedMedia(path, audioOutput: true),
        throwsA(isA<BlockExecutionException>().having(
          (e) => e.message,
          'message',
          contains('下载结果为视频'),
        )),
      );
    });

    test('unverifiable MIME-less $container fails clearly', () async {
      final directory = await Directory.systemTemp.createTemp('catcatch_kind_');
      try {
        final path = p.join(directory.path, 'unknown.$container');
        await File(path).writeAsBytes([0, 1, 2, 3]);
        await expectLater(
          _runCompletedUntypedMedia(path, audioOutput: false),
          throwsA(isA<BlockExecutionException>().having(
            (e) => e.message,
            'message',
            contains('无法验证下载文件的音视频类型'),
          )),
        );
        await expectLater(
          _runCompletedUntypedMedia(path,
              audioOutput: false, declaredMime: 'video/$container'),
          throwsA(isA<BlockExecutionException>().having(
            (e) => e.message,
            'message',
            contains('无法验证下载文件的音视频类型'),
          )),
        );
      } finally {
        await directory.delete(recursive: true);
      }
    });
  }

  for (final container in ['mp4', 'ogg', 'webm', 'mov']) {
    test('audio-only $container overrides video MIME in flow output', () async {
      final path = p.absolute('tests/fixtures/catcatch/audio_only.$container');
      expect(
        await _runCompletedUntypedMedia(path,
            audioOutput: true, declaredMime: 'video/$container'),
        path,
      );
      await expectLater(
        _runCompletedUntypedMedia(path,
            audioOutput: false, declaredMime: 'video/$container'),
        throwsA(isA<BlockExecutionException>().having(
          (e) => e.message,
          'message',
          contains('下载结果为音频'),
        )),
      );
    });

    test('video-only $container overrides audio MIME in flow output', () async {
      final path = p.absolute('tests/fixtures/catcatch/video_only.$container');
      expect(
        await _runCompletedUntypedMedia(path,
            audioOutput: false, declaredMime: 'audio/$container'),
        path,
      );
      await expectLater(
        _runCompletedUntypedMedia(path,
            audioOutput: true, declaredMime: 'audio/$container'),
        throwsA(isA<BlockExecutionException>().having(
          (e) => e.message,
          'message',
          contains('下载结果为视频'),
        )),
      );
    });
  }

  test('audio output survives serialization and connects to ASR', () async {
    final model = ModelConfig(name: 'ASR', modelId: 'asr');
    final config = ProviderConfigItem(
      host: 'https://example.com',
      key: 'key',
      models: [model],
    );
    final providers = ProviderEntriesState(
      entries: [
        ProviderEntry(name: 'ASR', type: 'asr', configs: [config]),
      ],
    );
    final download = TaskFlowBlock(
      typeKey: BlockType.catcatch,
      params: {'audioOutput': true},
    );
    final restored = TaskFlowBlock.fromMap(download.toMap());
    expect(restored.getDefinition()!.outputType, IOType.audio);
    final flow = TaskFlowDefinition(
      name: 'Audio',
      blocks: [
        restored,
        TaskFlowBlock(
          typeKey: BlockType.asr,
          params: {
            'modelRef': providerModelReference((config: config, model: model)),
          },
        ),
      ],
    );
    await validateTaskFlow(
      flow,
      [const FlowRunInput(text: 'https://example.com')],
      providers: providers,
      assistants: [],
    );
    final video = flow.copyWith(
      blocks: [restored.copyWithParam('audioOutput', false), flow.blocks.last],
    );
    await expectLater(
      validateTaskFlow(
        video,
        [const FlowRunInput(text: 'https://example.com')],
        providers: providers,
        assistants: [],
      ),
      throwsA(
        isA<TaskFlowValidationException>().having(
          (e) => e.blockIndex,
          'incompatible ASR step',
          1,
        ),
      ),
    );
  });

  for (final media in [
    split,
    const MediaResource(
      url: 'https://x/unknown.bin',
      name: 'unknown',
      ext: 'bin',
      mimeType: 'application/octet-stream',
    ),
  ]) {
    test('a lone ${media.name} resource is rejected before selection',
        () async {
      final notifier = _Notifier();
      final executions = TaskFlowExecutionNotifier();
      final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
      final subTask = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '下载',
        subTaskId: 'pending',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting,
      );
      executions.addSubTask(execId, subTask);
      late String taskId;
      when(() => notifier.addTask(any(), any(),
          taskId: any(named: 'taskId'),
          deferSingleResourceSelection: true)).thenAnswer((invocation) {
        taskId = invocation.namedArguments[#taskId] as String;
        return taskId;
      });
      when(() => notifier.state).thenAnswer((_) => [
            catcatch.CatCatchTask(
              id: taskId,
              url: 'https://x',
              expectedDurationSec: 0,
              createdAt: DateTime(2026),
              detectedMedia: [media],
              steps: const [
                catcatch.StepStatus(
                  type: catcatch.StepType.userSelecting,
                  running: true,
                ),
              ],
            ),
          ]);
      when(() => notifier.removeTask(any())).thenReturn(null);

      await expectLater(
        executeCatCatchBlock(
          def: BlockTypeDefinition.catcatch,
          block: TaskFlowBlock(
              typeKey: BlockType.catcatch,
              params: {'automaticResourceSelection': true}),
          input: 'https://x',
          execId: execId,
          execNotifier: executions,
          flowSubTask: subTask,
          catcatchNotifier: notifier,
          pollInterval: const Duration(milliseconds: 1),
        ),
        throwsA(isA<BlockExecutionException>().having(
          (e) => e.message,
          'message',
          contains('没有可安全自动选择的完整资源'),
        )),
      );
      verify(() => notifier.removeTask(taskId)).called(1);
      verifyNever(() => notifier.selectMedia(any(), any()));
      expect(executions.state.single.subTasks.single.status, TaskStatus.failed);
    });
  }

  test('a valid sole resource passes flow selection and completes', () async {
    final videoPath = p.absolute('tests/fixtures/catcatch/video_only.mp4');
    final notifier = _Notifier();
    final executions = TaskFlowExecutionNotifier();
    final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
    final subTask = FlowSubTask(
      blockTypeKey: 'catcatch',
      blockLabel: '下载',
      subTaskId: 'pending',
      subTaskType: 'catcatch',
      status: TaskStatus.waiting,
    );
    executions.addSubTask(execId, subTask);
    late String taskId;
    MediaResource? selected;
    var stateReads = 0;
    when(() => notifier.addTask(any(), any(),
        taskId: any(named: 'taskId'),
        deferSingleResourceSelection: true)).thenAnswer((invocation) {
      taskId = invocation.namedArguments[#taskId] as String;
      return taskId;
    });
    when(() => notifier.selectMedia(any(), any())).thenAnswer((invocation) {
      selected = invocation.positionalArguments[1] as MediaResource;
    });
    when(() => notifier.state).thenAnswer((_) {
      stateReads++;
      // Discovery can expose media before filtering and split detection.
      final selectionReady = stateReads > 2;
      return [
        catcatch.CatCatchTask(
          id: taskId,
          url: 'https://x',
          expectedDurationSec: 0,
          createdAt: DateTime(2026),
          status: selected == null
              ? catcatch.TaskStatus.running
              : catcatch.TaskStatus.completed,
          detectedMedia: selectionReady ? const [videoA] : const [audio],
          selectedMedia: selected,
          steps: selected == null
              ? [
                  catcatch.StepStatus(
                    type: catcatch.StepType.userSelecting,
                    running: selectionReady,
                  ),
                ]
              : const [],
          downloadedFilePath: selected == null ? null : videoPath,
        ),
      ];
    });

    final result = await executeCatCatchBlock(
      def: BlockTypeDefinition.catcatch,
      block: TaskFlowBlock(
          typeKey: BlockType.catcatch,
          params: {'automaticResourceSelection': true}),
      input: 'https://x',
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      catcatchNotifier: notifier,
      pollInterval: const Duration(milliseconds: 1),
    );
    expect(result, videoPath);
    expect(selected, videoA);
    expect(stateReads, greaterThanOrEqualTo(4));
    verify(() => notifier.selectMedia(taskId, videoA)).called(1);
    expect(
        executions.state.single.subTasks.single.status, TaskStatus.completed);
  });

  test(
    'automatic download chooses declared video and confirms conversion',
    () async {
      final videoPath = p.absolute('tests/fixtures/catcatch/video_only.mp4');
      final notifier = _Notifier();
      final executions = TaskFlowExecutionNotifier();
      final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
      final subTask = FlowSubTask(
        blockTypeKey: 'catcatch',
        blockLabel: '下载',
        subTaskId: 'pending',
        subTaskType: 'catcatch',
        status: TaskStatus.waiting,
      );
      executions.addSubTask(execId, subTask);
      late String taskId;
      var stage = 0;
      MediaResource? selected;
      when(() => notifier.addTask(any(), any(),
          taskId: any(named: 'taskId'),
          deferSingleResourceSelection: true)).thenAnswer((invocation) {
        taskId = invocation.namedArguments[#taskId] as String;
        return taskId;
      });
      when(() => notifier.selectMedia(any(), any())).thenAnswer((invocation) {
        selected = invocation.positionalArguments[1] as MediaResource;
        stage = 1;
      });
      when(() => notifier.confirmAndContinue(any()))
          .thenAnswer((_) => stage = 2);
      when(() => notifier.state).thenAnswer(
        (_) => [
          catcatch.CatCatchTask(
            id: taskId,
            url: 'https://x',
            expectedDurationSec: 0,
            createdAt: DateTime(2026),
            status: stage == 2
                ? catcatch.TaskStatus.completed
                : catcatch.TaskStatus.running,
            detectedMedia: const [audio, videoZ, videoA],
            selectedMedia: selected,
            metadata: stage == 1 ? {'pendingConfirm': 'special_format'} : {},
            steps: stage == 0
                ? [
                    const catcatch.StepStatus(
                      type: catcatch.StepType.userSelecting,
                      running: true,
                    ),
                  ]
                : [],
            downloadedFilePath: stage == 2 ? videoPath : null,
          ),
        ],
      );
      final result = await executeCatCatchBlock(
        def: BlockTypeDefinition.catcatch,
        block: TaskFlowBlock(
            typeKey: BlockType.catcatch,
            params: {'automaticResourceSelection': true}),
        input: 'https://x',
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        catcatchNotifier: notifier,
        pollInterval: const Duration(milliseconds: 1),
      );
      expect(result, videoPath);
      expect(selected, videoA);
      verify(() => notifier.confirmAndContinue(taskId)).called(1);
    },
  );

  test('wrong downloaded media type fails before the next block', () async {
    final audioPath = p.absolute('tests/fixtures/catcatch/audio_only.mp3');
    final notifier = _Notifier();
    final executions = TaskFlowExecutionNotifier();
    final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
    final subTask = FlowSubTask(
      blockTypeKey: 'catcatch',
      blockLabel: '下载',
      subTaskId: 'pending',
      subTaskType: 'catcatch',
      status: TaskStatus.waiting,
    );
    executions.addSubTask(execId, subTask);
    late String taskId;
    when(() => notifier.addTask(any(), any(),
        taskId: any(named: 'taskId'),
        deferSingleResourceSelection: true)).thenAnswer((invocation) {
      taskId = invocation.namedArguments[#taskId] as String;
      return taskId;
    });
    when(() => notifier.state).thenAnswer(
      (_) => [
        catcatch.CatCatchTask(
          id: taskId,
          url: 'https://x',
          expectedDurationSec: 0,
          createdAt: DateTime(2026),
          status: catcatch.TaskStatus.completed,
          downloadedFilePath: audioPath,
        ),
      ],
    );
    await expectLater(
      executeCatCatchBlock(
        def: BlockTypeDefinition.catcatch,
        block: TaskFlowBlock(
            typeKey: BlockType.catcatch,
            params: {'automaticResourceSelection': true}),
        input: 'https://x',
        execId: execId,
        execNotifier: executions,
        flowSubTask: subTask,
        catcatchNotifier: notifier,
        pollInterval: const Duration(milliseconds: 1),
      ),
      throwsA(
        isA<BlockExecutionException>().having(
          (e) => e.message,
          'message',
          contains('音频'),
        ),
      ),
    );
    expect(executions.state.single.subTasks.single.status, TaskStatus.failed);
  });

  test('converted audio remains audio inside an MP4 container', () async {
    final task = catcatch.CatCatchTask(
      id: 'task',
      url: 'https://x',
      expectedDurationSec: 0,
      createdAt: DateTime(2026),
      downloadedFilePath: p.absolute('tests/fixtures/catcatch/audio_only.mp4'),
      selectedMedia: audio,
    );
    expect(await catCatchOutputType(task), IOType.audio);
  });

  test('selected video/ogg completes despite ambiguous .ogg filename',
      () async {
    final videoPath = p.absolute('tests/fixtures/catcatch/video_only.ogg');
    final notifier = _Notifier();
    final executions = TaskFlowExecutionNotifier();
    final execId = executions.addExecution(flowId: 'flow', flowName: 'Flow');
    final subTask = FlowSubTask(
      blockTypeKey: 'catcatch',
      blockLabel: '下载',
      subTaskId: 'pending',
      subTaskType: 'catcatch',
      status: TaskStatus.waiting,
    );
    executions.addSubTask(execId, subTask);
    late String taskId;
    when(() => notifier.addTask(any(), any(),
        taskId: any(named: 'taskId'),
        deferSingleResourceSelection: true)).thenAnswer((invocation) {
      taskId = invocation.namedArguments[#taskId] as String;
      return taskId;
    });
    when(() => notifier.state).thenAnswer((_) => [
          catcatch.CatCatchTask(
            id: taskId,
            url: 'https://x',
            expectedDurationSec: 0,
            createdAt: DateTime(2026),
            status: catcatch.TaskStatus.completed,
            downloadedFilePath: videoPath,
            selectedMedia: const MediaResource(
              url: 'https://x/video.ogg',
              name: 'video',
              ext: 'ogg',
              mimeType: 'video/ogg',
            ),
          )
        ]);

    final path = await executeCatCatchBlock(
      def: BlockTypeDefinition.catcatch,
      block: TaskFlowBlock(
          typeKey: BlockType.catcatch,
          params: {'automaticResourceSelection': true}),
      input: 'https://x',
      execId: execId,
      execNotifier: executions,
      flowSubTask: subTask,
      catcatchNotifier: notifier,
      pollInterval: const Duration(milliseconds: 1),
    );
    expect(path, videoPath);
    expect(
        executions.state.single.subTasks.single.status, TaskStatus.completed);
  });
}
