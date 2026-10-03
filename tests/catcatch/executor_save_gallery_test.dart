import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/catcatch/engine/executor_save.dart';
import 'package:stroom/catcatch/engine/ffmpeg_converter.dart';
import 'package:stroom/catcatch/engine/task_executor.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/models/media_kind.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/task_flow/models/io_type.dart';
import 'package:stroom/task_flow/services/task_flow_execution_service.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

import 'init_only_fixture.dart';

class _DocumentsDirectory extends PathProviderPlatform {
  _DocumentsDirectory(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('catcatch_save_gallery_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _DocumentsDirectory(root.path);
    AppStorage.resetCache();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    await ManifestDatabase.getAllAudioRecords();
    // Keep manifest rows in memory while exercising native file copies into
    // the isolated documents directory.
    WebFileStore.disableTestMode();
    FileManifest.invalidateCache();
    VideoManifest.invalidateCache();
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    AppStorage.resetCache();
    await root.delete(recursive: true);
  });

  Future<String> save(MediaResource selected) async {
    final source = File(p.join(root.path, 'source', 'capture.mp4'));
    await source.parent.create(recursive: true);
    final fixtureName = selected.mimeType?.startsWith('video/') == true
        ? 'video_only.mp4'
        : 'audio_only.mp4';
    final fixture = File(p.join('tests', 'fixtures', 'catcatch', fixtureName));
    await fixture.copy(source.path);
    final task = CatCatchTask(
      id: 'download',
      url: 'https://example.com',
      expectedDurationSec: 42,
      createdAt: DateTime(2026),
      selectedMedia: selected,
    );
    final saved = await executeSave(
      task: task,
      steps: StepType.values.map(StepStatus.pending).toList(),
      sourcePath: source.path,
      onUpdate: (_) {},
    );
    expect(saved, startsWith(root.path));
    expect(await File(saved).readAsBytes(), await fixture.readAsBytes());
    return saved;
  }

  Future<(String, CatCatchTask)> saveUntypedFixture(String fixtureName,
      {String? declaredMime, String? sourceName}) async {
    final fileName = sourceName ?? fixtureName;
    final source = File(p.join(root.path, 'source', fileName));
    await source.parent.create(recursive: true);
    await File(p.join('tests', 'fixtures', 'catcatch', fixtureName))
        .copy(source.path);
    final task = CatCatchTask(
      id: 'download',
      url: 'https://example.com/$fileName',
      expectedDurationSec: 0,
      createdAt: DateTime(2026),
      selectedMedia: MediaResource(
        url: 'https://example.com/$fileName',
        name: p.basenameWithoutExtension(fileName),
        ext: p.extension(fileName).substring(1),
        mimeType: declaredMime,
      ),
    );
    final saved = await executeSave(
      task: task,
      steps: StepType.values.map(StepStatus.pending).toList(),
      sourcePath: source.path,
      onUpdate: (_) {},
    );
    return (saved, task);
  }

  test('MIME-less audio-only MP4 routes only to the audio gallery', () async {
    final (saved, task) = await saveUntypedFixture('audio_only.mp4');
    expect(
        await catCatchMediaKindFromFile(task, saved), CatCatchMediaKind.audio);
    expect(await FileManifest.loadRecords(), hasLength(1));
    expect(await VideoManifest.loadRecords(), isEmpty);
  });

  test('MIME-less video-only MP4 routes only to the video gallery', () async {
    final (saved, task) = await saveUntypedFixture('video_only.mp4');
    expect(
        await catCatchMediaKindFromFile(task, saved), CatCatchMediaKind.video);
    expect(await VideoManifest.loadRecords(), hasLength(1));
    expect(await FileManifest.loadRecords(), isEmpty);
  });

  for (final container in ['ogg', 'webm', 'mov']) {
    test('MIME-less audio-only $container routes only to the audio gallery',
        () async {
      final (saved, task) = await saveUntypedFixture('audio_only.$container');
      expect(await catCatchMediaKindFromFile(task, saved),
          CatCatchMediaKind.audio);
      expect(await FileManifest.loadRecords(), hasLength(1));
      expect(await VideoManifest.loadRecords(), isEmpty);
    });

    test('MIME-less video-only $container routes only to the video gallery',
        () async {
      final (saved, task) = await saveUntypedFixture('video_only.$container');
      expect(await catCatchMediaKindFromFile(task, saved),
          CatCatchMediaKind.video);
      expect(await VideoManifest.loadRecords(), hasLength(1));
      expect(await FileManifest.loadRecords(), isEmpty);
    });
  }

  for (final container in ['mp4', 'ogg', 'webm', 'mov']) {
    test('audio-only $container with video MIME enters only audio gallery',
        () async {
      final (saved, task) = await saveUntypedFixture('audio_only.$container',
          declaredMime: 'video/$container');
      expect(await catCatchMediaKindFromFile(task, saved),
          CatCatchMediaKind.audio);
      expect(await FileManifest.loadRecords(), hasLength(1));
      expect(await VideoManifest.loadRecords(), isEmpty);
    });

    test('video-only $container with audio MIME enters only video gallery',
        () async {
      final (saved, task) = await saveUntypedFixture('video_only.$container',
          declaredMime: 'audio/$container');
      expect(await catCatchMediaKindFromFile(task, saved),
          CatCatchMediaKind.video);
      expect(await VideoManifest.loadRecords(), hasLength(1));
      expect(await FileManifest.loadRecords(), isEmpty);
    });
  }

  test('MP3 with conflicting video MIME enters only the audio gallery',
      () async {
    final (saved, task) =
        await saveUntypedFixture('audio_only.mp3', declaredMime: 'video/mp4');
    expect(
        await catCatchMediaKindFromFile(task, saved), CatCatchMediaKind.audio);
    final audioRecords = await FileManifest.loadRecords();
    expect(audioRecords, hasLength(1));
    expect(audioRecords.single.format, 'mp3');
    expect(await VideoManifest.loadRecords(), isEmpty);
  });

  for (final extension in ['wav', 'aac', 'flac']) {
    test('valid $extension enters only the audio gallery', () async {
      final (saved, task) = await saveUntypedFixture('audio_only.$extension',
          declaredMime: 'video/mp4');
      expect(await catCatchMediaKindFromFile(task, saved),
          CatCatchMediaKind.audio);
      final records = await FileManifest.loadRecords();
      expect(records, hasLength(1));
      expect(records.single.format, extension);
      expect(await VideoManifest.loadRecords(), isEmpty);
    });
  }

  for (final fixture in [
    (name: 'audio_only.flv', kind: CatCatchMediaKind.audio),
    (name: 'audio_only.avi', kind: CatCatchMediaKind.audio),
    (name: 'video_only.avi', kind: CatCatchMediaKind.video),
    (name: 'video_with_aux.avi', kind: CatCatchMediaKind.video),
    (name: 'video_type1_dv.avi', kind: CatCatchMediaKind.video),
    (name: 'audio_only.mpg', kind: CatCatchMediaKind.audio),
    (name: 'video_program.mpg', kind: CatCatchMediaKind.video),
    (name: 'video_only.flv', kind: CatCatchMediaKind.video),
    (name: 'video_only.mpeg', kind: CatCatchMediaKind.video),
  ]) {
    test('original ${fixture.name} enters its verified gallery', () async {
      final (saved, task) = await saveUntypedFixture(fixture.name);
      expect(await catCatchMediaKindFromFile(task, saved), fixture.kind);
      final extension = p.extension(saved).substring(1);
      if (fixture.kind == CatCatchMediaKind.audio) {
        final records = await FileManifest.loadRecords();
        expect(records, hasLength(1));
        expect(records.single.format, extension);
        expect(await VideoManifest.loadRecords(), isEmpty);
      } else {
        final records = await VideoManifest.loadRecords();
        expect(records, hasLength(1));
        expect(records.single.format, extension);
        expect(await FileManifest.loadRecords(), isEmpty);
      }
    });
  }

  test('original MPEG with MPG suffix enters the video gallery', () async {
    final (saved, task) = await saveUntypedFixture(
      'video_only.mpeg',
      sourceName: 'video_only.mpg',
    );
    expect(
      await catCatchMediaKindFromFile(task, saved),
      CatCatchMediaKind.video,
    );
    final records = await VideoManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.format, 'mpg');
    expect(await FileManifest.loadRecords(), isEmpty);
  });

  for (final boundary in [
    'picture_start',
    'picture_header',
    'truncated_picture_with_slice',
    'slice_start',
    'slice_header',
    'slice_extra_header',
    'terminated_slice_header',
  ]) {
    test('elementary MPEG $boundary is rejected before gallery publication',
        () async {
      final source = File(p.join(root.path, 'source', 'headers.mpeg'));
      await source.parent.create(recursive: true);
      await source.writeAsBytes(await mpegElementaryHeaders(boundary));
      await expectLater(
          executeSave(
              task: CatCatchTask(
                  id: 'download',
                  url: 'https://example.com',
                  expectedDurationSec: 0,
                  createdAt: DateTime(2026)),
              steps: StepType.values.map(StepStatus.pending).toList(),
              sourcePath: source.path,
              onUpdate: (_) {}),
          throwsA(isA<FormatException>()));
      expect(await FileManifest.loadRecords(), isEmpty);
      expect(await VideoManifest.loadRecords(), isEmpty);
      expect(
          await Directory(p.join(root.path, 'catcatch', 'completed')).exists(),
          isFalse);
    });
  }

  test('real elementary MPEG-2 slices enter the video gallery', () async {
    final source = File(p.join(root.path, 'source', 'video.mpeg'));
    await source.parent.create(recursive: true);
    await source.writeAsBytes(await mpegElementaryFixture(mpeg2: true));
    final saved = await executeSave(
        task: CatCatchTask(
            id: 'download',
            url: 'https://example.com',
            expectedDurationSec: 0,
            createdAt: DateTime(2026)),
        steps: StepType.values.map(StepStatus.pending).toList(),
        sourcePath: source.path,
        onUpdate: (_) {});
    expect(await File(saved).readAsBytes(), await source.readAsBytes());
    final records = await VideoManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.format, 'mpeg');
    expect(await FileManifest.loadRecords(), isEmpty);
  });

  for (final invalid in [
    'renumbered_track',
    'xiph_empty',
    'xiph_unterminated',
    'xiph_overflow',
    'fixed_empty',
    'fixed_unequal',
    'ebml_empty',
    'ebml_missing_size',
    'ebml_negative',
    'ebml_overflow',
    'ebml_truncated_vint',
    'unknown_track',
    'video_pes_header',
    'separate_video_streams',
  ]) {
    test('$invalid fails before a completed copy or gallery publication',
        () async {
      final mpeg =
          invalid == 'video_pes_header' || invalid == 'separate_video_streams';
      final source =
          File(p.join(root.path, 'source', 'invalid.${mpeg ? 'mpg' : 'webm'}'));
      await source.parent.create(recursive: true);
      final sample = await mpegElementaryFixture();
      final bytes = switch (invalid) {
        'renumbered_track' => await ebmlRenumberedTrackFixture(),
        'video_pes_header' => await mpegProgramWithPackets([
            mpegFixturePes(
                0xe0, [0x0f, ...await mpegElementaryHeaders('slice_header')]),
          ]),
        'separate_video_streams' => await mpegProgramWithPackets([
            mpegFixturePes(0xe0, [0x0f, ...sample.sublist(0, 33)]),
            mpegFixturePes(0xe1, [0x0f, ...sample.sublist(33, 1209)]),
          ]),
        _ => await ebmlBlockFixture(invalid),
      };
      await source.writeAsBytes(bytes);
      await expectLater(
          executeSave(
              task: CatCatchTask(
                  id: 'download',
                  url: 'https://example.com',
                  expectedDurationSec: 0,
                  createdAt: DateTime(2026)),
              steps: StepType.values.map(StepStatus.pending).toList(),
              sourcePath: source.path,
              onUpdate: (_) {}),
          throwsA(isA<FormatException>()));
      expect(await FileManifest.loadRecords(), isEmpty);
      expect(await VideoManifest.loadRecords(), isEmpty);
      expect(
          await Directory(p.join(root.path, 'catcatch', 'completed')).exists(),
          isFalse);
    });
  }

  for (final container in ['laced_audio', 'laced_video', 'split_video_pes']) {
    test('$container real frames enter their matching gallery', () async {
      final mpeg = container == 'split_video_pes';
      final video = container != 'laced_audio';
      final source =
          File(p.join(root.path, 'source', 'valid.${mpeg ? 'mpg' : 'webm'}'));
      await source.parent.create(recursive: true);
      final sample = await mpegElementaryFixture(mpeg2: true);
      await source.writeAsBytes(mpeg
          ? await mpegProgramWithPackets([
              mpegFixturePes(0xe0, [0x80, 0, 0, ...sample.sublist(0, 51)]),
              mpegFixturePes(0xe0, [0x80, 0, 0, ...sample.sublist(51)]),
            ], mpeg2: true)
          : await ebmlBlockFixture('ebml', video: video));
      final saved = await executeSave(
          task: CatCatchTask(
              id: 'download',
              url: 'https://example.com',
              expectedDurationSec: 0,
              createdAt: DateTime(2026)),
          steps: StepType.values.map(StepStatus.pending).toList(),
          sourcePath: source.path,
          onUpdate: (_) {});
      expect(await File(saved).readAsBytes(), await source.readAsBytes());
      expect(await VideoManifest.loadRecords(), video ? hasLength(1) : isEmpty);
      expect(await FileManifest.loadRecords(), video ? isEmpty : hasLength(1));
    });
  }

  for (final container in [
    'streaming_video',
    'streaming_audio',
    'late_tracks',
    'unmatched_streaming',
    'empty_streaming_lace',
    'chained_theora',
    'chained_dirac',
    'chained_audio'
  ]) {
    test('$container enters only its verified gallery', () async {
      final ogg = container.startsWith('chained');
      final video = [
        'streaming_video',
        'late_tracks',
        'chained_theora',
        'chained_dirac'
      ].contains(container);
      final source = File(
          p.join(root.path, 'source', 'streaming.${ogg ? 'ogg' : 'webm'}'));
      await source.parent.create(recursive: true);
      final bytes = ogg
          ? await oggChainedFixture(container.substring('chained_'.length))
          : await ebmlStreamingFixture(
              withVideo: container != 'streaming_audio',
              tracksAfterCluster: container == 'late_tracks',
              undeclaredVideo: container == 'unmatched_streaming',
              emptyVideo: container == 'empty_streaming_lace');
      await source.writeAsBytes(bytes);
      final saved = await executeSave(
          task: CatCatchTask(
              id: 'download',
              url: 'https://example.com',
              expectedDurationSec: 0,
              createdAt: DateTime(2026)),
          steps: StepType.values.map(StepStatus.pending).toList(),
          sourcePath: source.path,
          onUpdate: (_) {});
      expect(await File(saved).readAsBytes(), bytes);
      expect(await VideoManifest.loadRecords(), video ? hasLength(1) : isEmpty);
      expect(await FileManifest.loadRecords(), video ? isEmpty : hasLength(1));
    });
  }

  for (final group in ['unknown', 'header_only']) {
    test('chained Ogg $group is rejected before publication', () async {
      final source = File(p.join(root.path, 'source', 'chained.ogg'));
      await source.parent.create(recursive: true);
      await source.writeAsBytes(await oggChainedFixture(group));
      await expectLater(
          executeSave(
              task: CatCatchTask(
                  id: 'download',
                  url: 'https://example.com',
                  expectedDurationSec: 0,
                  createdAt: DateTime(2026)),
              steps: StepType.values.map(StepStatus.pending).toList(),
              sourcePath: source.path,
              onUpdate: (_) {}),
          throwsA(isA<FormatException>()));
      expect(await VideoManifest.loadRecords(), isEmpty);
      expect(await FileManifest.loadRecords(), isEmpty);
      expect(
          await Directory(p.join(root.path, 'catcatch', 'completed')).exists(),
          isFalse);
    });
  }

  test('unverified AVI and MPEG fail before a completed copy or gallery row',
      () async {
    for (final extension in ['avi', 'mpeg', 'mpg']) {
      final source = File(p.join(root.path, 'source', 'invalid.$extension'));
      await source.parent.create(recursive: true);
      await source.writeAsBytes(extension == 'avi'
          ? [...'RIFF'.codeUnits, 4, 0, 0, 0, ...'AVI '.codeUnits]
          : [0, 0, 1, 0xba, 0x21, 0, 1, 0, 1, 0x80, 1, 0x83]);
      final task = CatCatchTask(
        id: 'download',
        url: 'https://example.com/invalid.$extension',
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        selectedMedia: MediaResource(
          url: 'https://example.com/invalid.$extension',
          name: 'invalid',
          ext: extension,
        ),
      );
      await expectLater(
        executeSave(
          task: task,
          steps: StepType.values.map(StepStatus.pending).toList(),
          sourcePath: source.path,
          onUpdate: (_) {},
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await FileManifest.loadRecords(), isEmpty);
      expect(await VideoManifest.loadRecords(), isEmpty);
      expect(
          await Directory(p.join(root.path, 'catcatch', 'completed')).exists(),
          isFalse);
    }
  });

  for (final invalid in [
    'avi_junk',
    'avi_empty_rec',
    'avi_empty_sample',
    'avi_wrong_index',
    'mpeg_header_only'
  ]) {
    test('$invalid is rejected before completed copy and gallery publication',
        () async {
      final extension = invalid.startsWith('avi') ? 'avi' : 'mpg';
      final source = File(p.join(root.path, 'source', 'invalid.$extension'));
      await source.parent.create(recursive: true);
      final bytes = invalid == 'mpeg_header_only'
          ? await mpegProgramWithPackets([
              mpegFixturePes(0xe0, [0x0f])
            ])
          : await aviWithMovieChunks(
              'video_only.avi',
              switch (invalid) {
                'avi_junk' => riffFixtureChunk('JUNK', [1]),
                'avi_empty_rec' => riffFixtureChunk('LIST', 'rec '.codeUnits),
                'avi_empty_sample' => riffFixtureChunk('00dc', []),
                _ => riffFixtureChunk('99dc', [1]),
              });
      await source.writeAsBytes(bytes);
      await expectLater(
          executeSave(
              task: CatCatchTask(
                  id: 'download',
                  url: 'https://example.com',
                  expectedDurationSec: 0,
                  createdAt: DateTime(2026)),
              steps: StepType.values.map(StepStatus.pending).toList(),
              sourcePath: source.path,
              onUpdate: (_) {}),
          throwsA(isA<FormatException>()));
      expect(await FileManifest.loadRecords(), isEmpty);
      expect(await VideoManifest.loadRecords(), isEmpty);
      expect(
          await Directory(p.join(root.path, 'catcatch', 'completed')).exists(),
          isFalse);
    });
  }

  test('MPEG video with private AC3 enters the video gallery', () async {
    final source = File(p.join(root.path, 'source', 'with_private.mpg'));
    await source.parent.create(recursive: true);
    await source.writeAsBytes(await mpegProgramWithPackets([
      await mpegVideoSamplePacket(mpeg2: true),
      mpegFixturePes(0xbd, [0x80, 0, 0, 0x80, 1, 0, 0, 0x0b, 0x77, 1]),
    ], mpeg2: true));
    final saved = await executeSave(
        task: CatCatchTask(
            id: 'download',
            url: 'https://example.com',
            expectedDurationSec: 0,
            createdAt: DateTime(2026)),
        steps: StepType.values.map(StepStatus.pending).toList(),
        sourcePath: source.path,
        onUpdate: (_) {});
    expect(await File(saved).exists(), isTrue);
    expect(await VideoManifest.loadRecords(), hasLength(1));
    expect(await FileManifest.loadRecords(), isEmpty);
  });

  test('truncated simple audio fails before a completed copy or gallery row',
      () async {
    final samples = <String, List<int>>{
      'mp3': [0xff, 0xe3, 0x38, 0xc0, 0],
      'wav': [
        ...'RIFF'.codeUnits,
        40,
        0,
        0,
        0,
        ...'WAVEfmt '.codeUnits,
        16,
        0,
        0,
        0,
        1,
        0,
        1,
        0,
        0x40,
        0x1f,
        0,
        0,
        0x80,
        0x3e,
        0,
        0,
        2,
        0,
        16,
        0,
        ...'data'.codeUnits,
        4,
        0,
        0,
        0,
      ],
      'aac': [0xff, 0xf1, 0x6c, 0x40, 0x01, 0x1f, 0xfc, 0],
      'flac': [
        ...'fLaC'.codeUnits,
        0x80,
        0,
        0,
        34,
        ...List<int>.filled(34, 0),
      ],
    };
    for (final entry in samples.entries) {
      final source =
          File(p.join(root.path, 'source', 'truncated.${entry.key}'));
      await source.parent.create(recursive: true);
      await source.writeAsBytes(entry.value);
      final task = CatCatchTask(
        id: 'download',
        url: 'https://example.com/truncated.${entry.key}',
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        selectedMedia: MediaResource(
          url: 'https://example.com/truncated.${entry.key}',
          name: 'truncated',
          ext: entry.key,
          mimeType: 'audio/${entry.key}',
        ),
      );
      await expectLater(
        executeSave(
          task: task,
          steps: StepType.values.map(StepStatus.pending).toList(),
          sourcePath: source.path,
          onUpdate: (_) {},
        ),
        throwsA(isA<FormatException>()),
        reason: entry.key,
      );
      expect(await FileManifest.loadRecords(), isEmpty);
      expect(await VideoManifest.loadRecords(), isEmpty);
      expect(
          await Directory(p.join(root.path, 'catcatch', 'completed')).exists(),
          isFalse);
    }
  });

  for (final extension in ['ev1', 'flv']) {
    test(
      'obfuscated EV1 named .$extension fails before a completed copy or gallery row',
      () async {
        final bytes = await File(
          p.join('tests', 'fixtures', 'catcatch', 'video_only.flv'),
        ).readAsBytes();
        for (var i = 0; i < 100; i++) {
          bytes[i] ^= 0xff;
        }
        final source = File(p.join(root.path, 'source', 'video.$extension'));
        await source.parent.create(recursive: true);
        await source.writeAsBytes(bytes);
        final task = CatCatchTask(
          id: 'download',
          url: 'https://example.com/video.$extension',
          expectedDurationSec: 0,
          createdAt: DateTime(2026),
          selectedMedia: MediaResource(
            url: 'https://example.com/video.$extension',
            name: 'video',
            ext: extension,
          ),
          downloadedFilePath: source.path,
          steps: [
            for (final type in StepType.values)
              type == StepType.saving
                  ? StepStatus.pending(type)
                  : StepStatus.done(type),
          ],
        );
        CatCatchTask? updated;
        final saved = await TaskExecutor.executeTask(
          task: task,
          onUpdate: (value) => updated = value,
        );

        expect(saved, isNull);
        expect(updated?.status, TaskStatus.failed);
        expect(updated?.error, contains('转换为 MP4'));
        expect(await File(source.path).exists(), isTrue);
        final completed = Directory(p.join(root.path, 'catcatch', 'completed'));
        expect(await completed.exists(), isFalse);
        expect(await FileManifest.loadRecords(), isEmpty);
        expect(await VideoManifest.loadRecords(), isEmpty);
      },
    );
  }

  test('audio WMA and video WMV enter their matching galleries', () async {
    await saveUntypedFixture('audio_only.wma', declaredMime: 'video/x-ms-wmv');
    expect(await FileManifest.loadRecords(), hasLength(1));
    expect(await VideoManifest.loadRecords(), isEmpty);

    await saveUntypedFixture('video_only.wmv', declaredMime: 'audio/x-ms-wma');
    expect(await FileManifest.loadRecords(), hasLength(1));
    expect(await VideoManifest.loadRecords(), hasLength(1));
  });

  test('video ASF named WMA is saved as WMV and registered once', () async {
    final completed = Directory(p.join(root.path, 'catcatch', 'completed'));
    await completed.create(recursive: true);
    final occupied = File(p.join(completed.path, 'video_as_audio.wmv'));
    await occupied.writeAsString('existing download');

    final (saved, task) = await saveUntypedFixture('video_only.wmv',
        sourceName: 'video_as_audio.wma', declaredMime: 'audio/x-ms-wma');
    expect(p.basename(saved), 'video_as_audio (2).wmv');
    expect(await File(saved).exists(), isTrue);
    expect(await File(occupied.path).readAsString(), 'existing download');
    expect(await File(p.join(completed.path, 'video_as_audio.wma')).exists(),
        isFalse);
    expect(
        await catCatchMediaKindFromFile(task, saved), CatCatchMediaKind.video);
    expect(await FileManifest.loadRecords(), isEmpty);
    final records = await VideoManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.format, 'wmv');
    expect(
        await File(p.join(root.path, 'videos', '${records.single.hash}.wmv'))
            .exists(),
        isTrue);
  });

  test('audio ASF named WMV is saved as WMA and registered once', () async {
    final (saved, task) = await saveUntypedFixture('audio_only.wma',
        sourceName: 'audio_as_video.wmv', declaredMime: 'video/x-ms-wmv');
    expect(p.extension(saved), '.wma');
    expect(
        await catCatchMediaKindFromFile(task, saved), CatCatchMediaKind.audio);
    expect(await VideoManifest.loadRecords(), isEmpty);
    final records = await FileManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.format, 'wma');
    expect(
        await File(p.join(root.path, 'tts_audio', '${records.single.hash}.wma'))
            .exists(),
        isTrue);
  });

  test('ASF header-only files do not create completed copies or gallery rows',
      () async {
    for (final fixtureName in ['audio_only.wma', 'video_only.wmv']) {
      final fixture = await File(
        p.join('tests', 'fixtures', 'catcatch', fixtureName),
      ).readAsBytes();
      final headerSize = fixture.sublist(16, 24).reversed.fold<int>(
            0,
            (size, byte) => (size << 8) | byte,
          );
      final source = File(p.join(root.path, 'source', fixtureName));
      await source.parent.create(recursive: true);
      await source.writeAsBytes(fixture.sublist(0, headerSize));
      final task = CatCatchTask(
        id: 'download',
        url: 'https://example.com/$fixtureName',
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        selectedMedia: MediaResource(
          url: 'https://example.com/$fixtureName',
          name: p.basenameWithoutExtension(fixtureName),
          ext: p.extension(fixtureName).substring(1),
        ),
      );
      await expectLater(
        executeSave(
          task: task,
          steps: StepType.values.map(StepStatus.pending).toList(),
          sourcePath: source.path,
          onUpdate: (_) {},
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await FileManifest.loadRecords(), isEmpty);
      expect(await VideoManifest.loadRecords(), isEmpty);
      expect(
          await Directory(p.join(root.path, 'catcatch', 'completed')).exists(),
          isFalse);
    }
  });

  for (final alias in [
    (
      fixture: 'audio_only.mp4',
      sourceName: 'audio_only.mp4',
      savedExtension: 'm4a',
      kind: CatCatchMediaKind.audio,
    ),
    (
      fixture: 'video_only.mp4',
      sourceName: 'video_as_audio.m4a',
      savedExtension: 'mp4',
      kind: CatCatchMediaKind.video,
    ),
    (
      fixture: 'audio_only.mov',
      sourceName: 'quicktime_as_mp4.mp4',
      savedExtension: 'mov',
      kind: CatCatchMediaKind.audio,
    ),
    (
      fixture: 'video_only.mov',
      sourceName: 'quicktime_as_m4a.m4a',
      savedExtension: 'mov',
      kind: CatCatchMediaKind.video,
    ),
    (
      fixture: 'audio_only.mp4',
      sourceName: 'iso_as_quicktime.mov',
      savedExtension: 'm4a',
      kind: CatCatchMediaKind.audio,
    ),
    (
      fixture: 'video_only.mp4',
      sourceName: 'video_as_quicktime.mov',
      savedExtension: 'mp4',
      kind: CatCatchMediaKind.video,
    ),
    (
      fixture: 'video_only.ogg',
      sourceName: 'video_only.ogg',
      savedExtension: 'ogv',
      kind: CatCatchMediaKind.video,
    ),
    (
      fixture: 'video_only.ogg',
      sourceName: 'video_as_audio.opus',
      savedExtension: 'ogv',
      kind: CatCatchMediaKind.video,
    ),
    (
      fixture: 'audio_only.opus',
      sourceName: 'audio_only.opus',
      savedExtension: 'opus',
      kind: CatCatchMediaKind.audio,
    ),
    (
      fixture: 'audio_only.ogg',
      sourceName: 'vorbis_as_opus.opus',
      savedExtension: 'ogg',
      kind: CatCatchMediaKind.audio,
    ),
    (
      fixture: 'audio_only.ogg',
      sourceName: 'audio_as_video.ogv',
      savedExtension: 'ogg',
      kind: CatCatchMediaKind.audio,
    ),
    (
      fixture: 'video_only.webm',
      sourceName: 'video_as_audio.weba',
      savedExtension: 'webm',
      kind: CatCatchMediaKind.video,
    ),
    (
      fixture: 'audio_only.webm',
      sourceName: 'webm_as_matroska.mkv',
      savedExtension: 'weba',
      kind: CatCatchMediaKind.audio,
    ),
    (
      fixture: 'video_only.webm',
      sourceName: 'webm_as_matroska.mka',
      savedExtension: 'webm',
      kind: CatCatchMediaKind.video,
    ),
    (
      fixture: 'audio_only.webm',
      sourceName: 'audio_only.webm',
      savedExtension: 'weba',
      kind: CatCatchMediaKind.audio,
    ),
    (
      fixture: 'audio_only.mkv',
      sourceName: 'audio_only.mkv',
      savedExtension: 'mka',
      kind: CatCatchMediaKind.audio,
    ),
    (
      fixture: 'audio_only.mkv',
      sourceName: 'matroska_as_webm.webm',
      savedExtension: 'mka',
      kind: CatCatchMediaKind.audio,
    ),
    (
      fixture: 'video_only.mkv',
      sourceName: 'matroska_as_weba.weba',
      savedExtension: 'mkv',
      kind: CatCatchMediaKind.video,
    ),
    (
      fixture: 'video_only.mkv',
      sourceName: 'video_as_audio.mka',
      savedExtension: 'mkv',
      kind: CatCatchMediaKind.video,
    ),
  ]) {
    test('${alias.sourceName} enters one verified ${alias.kind.name} gallery',
        () async {
      final (saved, task) = await saveUntypedFixture(alias.fixture,
          sourceName: alias.sourceName,
          declaredMime: alias.kind == CatCatchMediaKind.video
              ? 'audio/unknown'
              : 'video/unknown');
      expect(p.extension(saved), '.${alias.savedExtension}');
      expect(
          await File(saved).readAsBytes(),
          await File(p.join('tests', 'fixtures', 'catcatch', alias.fixture))
              .readAsBytes());
      expect(await catCatchMediaKindFromFile(task, saved), alias.kind);

      final audioRecords = await FileManifest.loadRecords();
      final videoRecords = await VideoManifest.loadRecords();
      if (alias.kind == CatCatchMediaKind.audio) {
        expect(audioRecords, hasLength(1));
        expect(audioRecords.single.format, alias.savedExtension);
        expect(videoRecords, isEmpty);
      } else {
        expect(videoRecords, hasLength(1));
        expect(videoRecords.single.format, alias.savedExtension);
        expect(audioRecords, isEmpty);
      }
    });
  }

  for (final alias in [
    (
      fixture: 'video_only.webm',
      sourceName: 'clip.mp4',
      savedExtension: 'webm',
      kind: CatCatchMediaKind.video,
      flowType: IOType.video,
      mime: 'video/webm',
    ),
    (
      fixture: 'audio_only.webm',
      sourceName: 'clip.mp4',
      savedExtension: 'weba',
      kind: CatCatchMediaKind.audio,
      flowType: IOType.audio,
      mime: 'audio/webm',
    ),
    (
      fixture: 'video_only.ogg',
      sourceName: 'clip.mp4',
      savedExtension: 'ogv',
      kind: CatCatchMediaKind.video,
      flowType: IOType.video,
      mime: 'video/ogg',
    ),
    (
      fixture: 'audio_only.ogg',
      sourceName: 'clip.mp4',
      savedExtension: 'ogg',
      kind: CatCatchMediaKind.audio,
      flowType: IOType.audio,
      mime: 'audio/ogg',
    ),
    (
      fixture: 'video_only.mp4',
      sourceName: 'clip.webm',
      savedExtension: 'mp4',
      kind: CatCatchMediaKind.video,
      flowType: IOType.video,
      mime: 'video/mp4',
    ),
    (
      fixture: 'audio_only.mov',
      sourceName: 'clip.mp4',
      savedExtension: 'mov',
      kind: CatCatchMediaKind.audio,
      flowType: IOType.audio,
      mime: 'audio/quicktime',
    ),
    (
      fixture: 'video_only.mkv',
      sourceName: 'clip.mp4',
      savedExtension: 'mkv',
      kind: CatCatchMediaKind.video,
      flowType: IOType.video,
      mime: 'video/x-matroska',
    ),
    (
      fixture: 'audio_only.wma',
      sourceName: 'clip.mp4',
      savedExtension: 'wma',
      kind: CatCatchMediaKind.audio,
      flowType: IOType.audio,
      mime: null,
    ),
    (
      fixture: 'audio_only.wav',
      sourceName: 'clip.mp3',
      savedExtension: 'wav',
      kind: CatCatchMediaKind.audio,
      flowType: IOType.audio,
      mime: null,
    ),
    (
      fixture: 'video_only.avi',
      sourceName: 'clip.mp4',
      savedExtension: 'avi',
      kind: CatCatchMediaKind.video,
      flowType: IOType.video,
      mime: 'video/x-msvideo',
    ),
    (
      fixture: 'video_program.mpg',
      sourceName: 'clip.mp4',
      savedExtension: 'mpeg',
      kind: CatCatchMediaKind.video,
      flowType: IOType.video,
      mime: 'video/mpeg',
    ),
    (
      fixture: 'audio_only.opus',
      sourceName: 'clip.mp4',
      savedExtension: 'opus',
      kind: CatCatchMediaKind.audio,
      flowType: IOType.audio,
      mime: 'audio/ogg',
    ),
    (
      fixture: 'audio_only.mp3',
      sourceName: 'clip.mp4',
      savedExtension: 'mp3',
      kind: CatCatchMediaKind.audio,
      flowType: IOType.audio,
      mime: null,
    ),
    (
      fixture: 'video_only.flv',
      sourceName: 'clip.mp4',
      savedExtension: 'flv',
      kind: CatCatchMediaKind.video,
      flowType: IOType.video,
      mime: 'video/x-flv',
    ),
  ]) {
    test(
        '${alias.fixture} downloaded as ${alias.sourceName} keeps its verified format',
        () async {
      final (saved, task) = await saveUntypedFixture(
        alias.fixture,
        sourceName: alias.sourceName,
        declaredMime: 'video/mp4',
      );
      expect(p.extension(saved), '.${alias.savedExtension}');
      expect(await catCatchMediaKindFromFile(task, saved), alias.kind);
      // ignore: invalid_use_of_visible_for_testing_member
      final payload = await catCatchOutputPayload(saved);
      expect(payload.type, alias.flowType);
      expect(payload.mimeType, alias.mime);
      expect(payload.fileReference, saved);
      final audio = await FileManifest.loadRecords();
      final video = await VideoManifest.loadRecords();
      if (alias.kind == CatCatchMediaKind.audio) {
        expect(audio, hasLength(1));
        expect(audio.single.format, alias.savedExtension);
        expect(video, isEmpty);
      } else {
        expect(video, hasLength(1));
        expect(video.single.format, alias.savedExtension);
        expect(audio, isEmpty);
      }
    });
  }

  test('video MP4 under M4A alias resolves collisions after normalization',
      () async {
    final completed = Directory(p.join(root.path, 'catcatch', 'completed'));
    await completed.create(recursive: true);
    final occupied = File(p.join(completed.path, 'clip.mp4'));
    await occupied.writeAsString('existing download');

    final (saved, _) = await saveUntypedFixture('video_only.mp4',
        sourceName: 'clip.m4a', declaredMime: 'audio/mp4');
    expect(p.basename(saved), 'clip (2).mp4');
    expect(await occupied.readAsString(), 'existing download');
    expect(await File(p.join(completed.path, 'clip.m4a')).exists(), isFalse);
    final records = await VideoManifest.loadRecords();
    expect(records, hasLength(1));
    expect(records.single.name, 'clip (2)');
    expect(records.single.format, 'mp4');
    expect(await FileManifest.loadRecords(), isEmpty);
  });

  test('audio alias copies storage despite a legacy storage extension',
      () async {
    final fixture =
        File(p.join('tests', 'fixtures', 'catcatch', 'audio_only.mp4'));
    final bytes = await fixture.readAsBytes();
    final hash = computeAudioHash(bytes);
    final storageDir = await FileManifest.ttsAudioDir;
    await fixture.copy(p.join(storageDir, '$hash.mp4'));
    await FileManifest.addRecord(AudioRecord(
      name: 'legacy',
      hash: hash,
      format: 'mp4',
      createdAt: DateTime(2025),
      size: bytes.length,
    ));

    await saveUntypedFixture('audio_only.mp4');
    final records = await FileManifest.loadRecords();
    expect(records, hasLength(2));
    expect(records.last.format, 'm4a');
    expect(await File(p.join(storageDir, '$hash.m4a')).readAsBytes(), bytes);
    expect(await VideoManifest.loadRecords(), isEmpty);
  });

  test('video alias copies storage despite a legacy storage extension',
      () async {
    final fixture =
        File(p.join('tests', 'fixtures', 'catcatch', 'video_only.mp4'));
    final bytes = await fixture.readAsBytes();
    final hash = computeVideoHash(bytes);
    final storageDir = await VideoManifest.videoDir;
    await fixture.copy(p.join(storageDir, '$hash.mov'));
    await VideoManifest.addRecord(VideoRecord(
      name: 'legacy',
      hash: hash,
      format: 'mov',
      createdAt: DateTime(2025),
      size: bytes.length,
    ));

    await saveUntypedFixture('video_only.mp4',
        sourceName: 'video_as_audio.m4a');
    final records = await VideoManifest.loadRecords();
    expect(records, hasLength(2));
    expect(records.last.format, 'mp4');
    expect(await File(p.join(storageDir, '$hash.mp4')).readAsBytes(), bytes);
    expect(await FileManifest.loadRecords(), isEmpty);
  });

  test(
      'HTML response saved as MP3 fails without a completed copy or gallery row',
      () async {
    final source = File(p.join(root.path, 'source', 'song.mp3'));
    await source.parent.create(recursive: true);
    await source.writeAsString('<!doctype html><html>Not found</html>');
    final task = CatCatchTask(
      id: 'download',
      url: 'https://example.com/song.mp3',
      expectedDurationSec: 0,
      createdAt: DateTime(2026),
      selectedMedia: const MediaResource(
        url: 'https://example.com/song.mp3',
        name: 'song',
        ext: 'mp3',
        mimeType: 'audio/mpeg',
      ),
    );

    final steps = StepType.values.map(StepStatus.pending).toList();
    await expectLater(
      executeSave(
        task: task,
        steps: steps,
        sourcePath: source.path,
        onUpdate: (_) {},
      ),
      throwsA(isA<FormatException>()),
    );

    expect(await source.readAsString(), contains('<!doctype html>'));
    expect(steps[StepType.saving.index].completed, isFalse);
    final completed = Directory(p.join(root.path, 'catcatch', 'completed'));
    if (await completed.exists()) {
      expect(await completed.list().toList(), isEmpty);
    }
    expect(await FileManifest.loadRecords(), isEmpty);
    expect(await VideoManifest.loadRecords(), isEmpty);
  });

  test('FLV video command fails before completed copy and gallery publication',
      () async {
    final source = File(p.join(root.path, 'source', 'command.flv'));
    await source.parent.create(recursive: true);
    await source.writeAsBytes(flvVideoTagFixture([0x52, 0]));
    await expectLater(
        executeSave(
            task: CatCatchTask(
                id: 'command',
                url: 'https://example.com/command.flv',
                expectedDurationSec: 0,
                createdAt: DateTime(2026)),
            steps: StepType.values.map(StepStatus.pending).toList(),
            sourcePath: source.path,
            onUpdate: (_) {}),
        throwsA(isA<FormatException>()));
    expect(await VideoManifest.loadRecords(), isEmpty);
    expect(await FileManifest.loadRecords(), isEmpty);
    expect(await Directory(p.join(root.path, 'catcatch', 'completed')).exists(),
        isFalse);
  });

  test('valid 32-bit FLAC enters only the audio gallery', () async {
    final source = File(p.join(root.path, 'source', '32_bit.flac'));
    await source.parent.create(recursive: true);
    await source.writeAsBytes(flac32BitFixture());
    final saved = await executeSave(
        task: CatCatchTask(
            id: 'flac',
            url: 'https://example.com/32_bit.flac',
            expectedDurationSec: 0,
            createdAt: DateTime(2026)),
        steps: StepType.values.map(StepStatus.pending).toList(),
        sourcePath: source.path,
        onUpdate: (_) {});
    expect(await File(saved).exists(), isTrue);
    final audioRecords = await FileManifest.loadRecords();
    expect(audioRecords, hasLength(1));
    expect(audioRecords.single.format, 'flac');
    expect(await VideoManifest.loadRecords(), isEmpty);
  });

  for (final kind in ['audio', 'video']) {
    test('$kind FLV header fails before a completed copy or gallery row',
        () async {
      final source = File(p.join(root.path, 'source', 'header.flv'));
      await source.parent.create(recursive: true);
      await source.writeAsBytes(flvHeaderOnly(audio: kind == 'audio'));
      final task = CatCatchTask(
        id: 'header-only',
        url: 'https://example.com/header.flv',
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        selectedMedia: const MediaResource(
          url: 'https://example.com/header.flv',
          name: 'header',
          ext: 'flv',
        ),
      );
      final steps = StepType.values.map(StepStatus.pending).toList();
      await expectLater(
        executeSave(
          task: task,
          steps: steps,
          sourcePath: source.path,
          onUpdate: (_) {},
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await source.exists(), isTrue);
      expect(steps[StepType.saving.index].completed, isFalse);
      expect(await FileManifest.loadRecords(), isEmpty);
      expect(await VideoManifest.loadRecords(), isEmpty);
      final completed = Directory(p.join(root.path, 'catcatch', 'completed'));
      if (await completed.exists()) {
        expect(await completed.list().toList(), isEmpty);
      }
    });
  }

  for (final fourCc in [null, 'hvc1', 'hev1']) {
    for (final configurationOnly in [true, false]) {
      test(
          'HEVC ${fourCc ?? 'legacy'} ${configurationOnly ? 'configuration is rejected' : 'coded frame enters video gallery'}',
          () async {
        final source = File(p.join(root.path, 'source', 'hevc.flv'));
        await source.parent.create(recursive: true);
        await source.writeAsBytes(flvHevcFixture(
            fourCc: fourCc, packetType: configurationOnly ? 0 : 1));
        final saving = executeSave(
            task: CatCatchTask(
                id: 'hevc',
                url: 'https://example.com/hevc.flv',
                expectedDurationSec: 0,
                createdAt: DateTime(2026)),
            steps: StepType.values.map(StepStatus.pending).toList(),
            sourcePath: source.path,
            onUpdate: (_) {});
        if (configurationOnly) {
          await expectLater(saving, throwsA(isA<FormatException>()));
          expect(await VideoManifest.loadRecords(), isEmpty);
          expect(
              await Directory(p.join(root.path, 'catcatch', 'completed'))
                  .exists(),
              isFalse);
        } else {
          final saved = await saving;
          expect(await File(saved).exists(), isTrue);
          expect(await VideoManifest.loadRecords(), hasLength(1));
        }
        expect(await FileManifest.loadRecords(), isEmpty);
      });
    }
  }

  test('MPEG video with DVD navigation enters the video gallery', () async {
    final source = File(p.join(root.path, 'source', 'dvd_navigation.mpg'));
    await source.parent.create(recursive: true);
    await source.writeAsBytes(await mpegProgramWithPackets([
      await mpegVideoSamplePacket(mpeg2: true),
      mpegFixturePes(0xbf, List<int>.filled(980, 0)),
    ], mpeg2: true));
    await executeSave(
        task: CatCatchTask(
            id: 'dvd',
            url: 'https://example.com/navigation.mpg',
            expectedDurationSec: 0,
            createdAt: DateTime(2026)),
        steps: StepType.values.map(StepStatus.pending).toList(),
        sourcePath: source.path,
        onUpdate: (_) {});
    expect(await VideoManifest.loadRecords(), hasLength(1));
    expect(await FileManifest.loadRecords(), isEmpty);
  });

  for (final unknownVideo in [true, false]) {
    test(
        'mixed Ogg ${unknownVideo ? 'unknown stream prevents publication' : 'Dirac video enters only video gallery'}',
        () async {
      final source = File(p.join(root.path, 'source', 'mixed.ogg'));
      await source.parent.create(recursive: true);
      await source
          .writeAsBytes(await oggDiracFixture(unknownVideo: unknownVideo));
      final saving = executeSave(
          task: CatCatchTask(
              id: 'ogg',
              url: 'https://example.com/mixed.ogg',
              expectedDurationSec: 0,
              createdAt: DateTime(2026)),
          steps: StepType.values.map(StepStatus.pending).toList(),
          sourcePath: source.path,
          onUpdate: (_) {});
      if (unknownVideo) {
        await expectLater(saving, throwsA(isA<FormatException>()));
        expect(await VideoManifest.loadRecords(), isEmpty);
        expect(await FileManifest.loadRecords(), isEmpty);
        expect(
            await Directory(p.join(root.path, 'catcatch', 'completed'))
                .exists(),
            isFalse);
      } else {
        final saved = await saving;
        expect(p.extension(saved), '.ogv');
        expect(await VideoManifest.loadRecords(), hasLength(1));
        expect(await FileManifest.loadRecords(), isEmpty);
      }
    });
  }

  for (final fixtureName in ['audio_only.ogg', 'audio_only.opus']) {
    test('$fixtureName codec headers fail before gallery save', () async {
      final sourceDir = Directory(p.join(root.path, 'source'));
      await sourceDir.create(recursive: true);
      final source = await writeHeaderOnlyOggFixture(sourceDir, fixtureName);
      final extension = p.extension(fixtureName).substring(1);
      final task = CatCatchTask(
        id: 'header-only',
        url: 'https://example.com/$fixtureName',
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        selectedMedia: MediaResource(
          url: 'https://example.com/$fixtureName',
          name: 'header',
          ext: extension,
        ),
      );
      final steps = StepType.values.map(StepStatus.pending).toList();
      await expectLater(
        executeSave(
          task: task,
          steps: steps,
          sourcePath: source.path,
          onUpdate: (_) {},
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await source.exists(), isTrue);
      expect(steps[StepType.saving.index].completed, isFalse);
      expect(await FileManifest.loadRecords(), isEmpty);
      expect(await VideoManifest.loadRecords(), isEmpty);
      final completed = Directory(p.join(root.path, 'catcatch', 'completed'));
      if (await completed.exists()) {
        expect(await completed.list().toList(), isEmpty);
      }
    });
  }

  for (final fixtureName in ['audio_only.mp4', 'video_only.webm']) {
    test('$fixtureName initialization segment fails before gallery save',
        () async {
      final sourceDir = Directory(p.join(root.path, 'source'));
      await sourceDir.create(recursive: true);
      final source = await writeInitOnlyFixture(sourceDir, fixtureName);
      final task = CatCatchTask(
        id: 'init-only',
        url: 'https://example.com/$fixtureName',
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        selectedMedia: MediaResource(
          url: 'https://example.com/$fixtureName',
          name: 'init-only',
          ext: p.extension(fixtureName).substring(1),
        ),
      );
      final steps = StepType.values.map(StepStatus.pending).toList();
      await expectLater(
        executeSave(
          task: task,
          steps: steps,
          sourcePath: source.path,
          onUpdate: (_) {},
        ),
        throwsA(isA<FormatException>()),
      );
      expect(await source.exists(), isTrue);
      expect(steps[StepType.saving.index].completed, isFalse);
      final completed = Directory(p.join(root.path, 'catcatch', 'completed'));
      if (await completed.exists()) {
        expect(await completed.list().toList(), isEmpty);
      }
      expect(await FileManifest.loadRecords(), isEmpty);
      expect(await VideoManifest.loadRecords(), isEmpty);
    });
  }

  for (final kind in ['audio', 'video']) {
    test(
        '$kind gallery storage failure keeps save incomplete and removes its copy',
        () async {
      final source = File(p.join(root.path, 'source', '$kind.mp4'));
      await source.parent.create(recursive: true);
      await File(p.join('tests', 'fixtures', 'catcatch', '${kind}_only.mp4'))
          .copy(source.path);
      // A regular file at the storage directory path makes registration fail
      // independently of the completed-copy destination.
      final storageName = kind == 'audio' ? 'tts_audio' : 'videos';
      await File(p.join(root.path, storageName)).writeAsString('blocked');
      final task = CatCatchTask(
        id: 'storage-failure',
        url: 'https://example.com/$kind.mp4',
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        selectedMedia: MediaResource(
          url: 'https://example.com/$kind.mp4',
          name: kind,
          ext: 'mp4',
        ),
        downloadedFilePath: source.path,
        steps: [
          for (final type in StepType.values)
            type == StepType.saving
                ? StepStatus.pending(type)
                : StepStatus.done(type),
        ],
      );
      CatCatchTask? updated;
      final saved = await TaskExecutor.executeTask(
        task: task,
        onUpdate: (value) => updated = value,
      );

      expect(saved, isNull);
      expect(updated?.status, TaskStatus.failed);
      expect(updated?.steps[StepType.saving.index].failed, isTrue);
      expect(updated?.error, contains('FileSystemException'));
      expect(await source.exists(), isTrue);
      expect(
          await Directory(p.join(root.path, 'catcatch', 'completed'))
              .list()
              .toList(),
          isEmpty);
      expect(await FileManifest.loadRecords(), isEmpty);
      expect(await VideoManifest.loadRecords(), isEmpty);
    });
  }

  test('audio-only MP4 enters only the audio gallery after saving', () async {
    final saved = await save(const MediaResource(
      url: 'https://example.com/audio.mp4',
      name: 'audio',
      ext: 'mp4',
      mimeType: 'audio/mp4',
    ));
    expect(saved, contains(p.join('catcatch', 'completed')));

    final audioRecords = await FileManifest.loadRecords();
    expect(audioRecords, hasLength(1));
    expect(audioRecords.single.format, 'm4a');
    expect(await VideoManifest.loadRecords(), isEmpty);
    expect(
      await File(
              p.join(root.path, 'tts_audio', '${audioRecords.single.hash}.m4a'))
          .exists(),
      isTrue,
    );
    expect(await Directory(p.join(root.path, 'videos')).exists(), isFalse);
  });

  test('video MP4 still enters only the video gallery', () async {
    await save(const MediaResource(
      url: 'https://example.com/video.mp4',
      name: 'video',
      ext: 'mp4',
      mimeType: 'video/mp4',
    ));

    final videoRecords = await VideoManifest.loadRecords();
    expect(videoRecords, hasLength(1));
    expect(videoRecords.single.format, 'mp4');
    expect(await FileManifest.loadRecords(), isEmpty);
    expect(
      await File(p.join(root.path, 'videos', '${videoRecords.single.hash}.mp4'))
          .exists(),
      isTrue,
    );
    expect(await Directory(p.join(root.path, 'tts_audio')).exists(), isFalse);
  });

  test('a resource selected during execution reaches the save step', () async {
    final source = File(p.join(root.path, 'source', 'selected.mp4'));
    await source.parent.create(recursive: true);
    await File(p.join('tests', 'fixtures', 'catcatch', 'audio_only.mp4'))
        .copy(source.path);
    const media = MediaResource(
      url: 'https://example.com/audio.mp4',
      name: 'audio',
      ext: 'mp4',
      mimeType: 'audio/mp4',
    );
    final task = CatCatchTask(
      id: 'download',
      url: 'https://example.com',
      expectedDurationSec: 42,
      createdAt: DateTime(2026),
      detectedMedia: const [media],
      downloadedFilePath: source.path,
      steps: [
        for (final type in StepType.values)
          type == StepType.userSelecting || type == StepType.saving
              ? StepStatus.pending(type)
              : StepStatus.done(type),
      ],
    );
    CatCatchTask? updated;
    final saved = await TaskExecutor.executeTask(
      task: task,
      onUpdate: (value) => updated = value,
    );

    expect(saved, isNotNull);
    expect(updated?.status, TaskStatus.completed);
    expect(updated?.selectedMedia, media);
    expect(await FileManifest.loadRecords(), hasLength(1));
    expect(await VideoManifest.loadRecords(), isEmpty);
  });

  for (final fixture in [
    (name: 'audio_only.ogg', video: false, confirmed: false),
    (name: 'video_only.mkv', video: true, confirmed: true),
    (name: 'video_only.webm', video: true, confirmed: true),
    (name: 'video_only.mov', video: true, confirmed: false),
  ]) {
    test('playable ${fixture.name} reaches the gallery without conversion',
        () async {
      final source = File(p.join(root.path, 'source', fixture.name));
      await source.parent.create(recursive: true);
      await File(p.join('tests', 'fixtures', 'catcatch', fixture.name))
          .copy(source.path);
      final extension = p.extension(fixture.name).substring(1);
      final isPlaylist = extension == 'webm' || extension == 'mov';
      final task = CatCatchTask(
        id: 'download',
        url: 'https://example.com/${fixture.name}',
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        selectedMedia: MediaResource(
          url: 'https://example.com/${fixture.name}',
          name: p.basenameWithoutExtension(fixture.name),
          ext: extension,
          isPlaylist: isPlaylist,
        ),
        downloadedFilePath: source.path,
        metadata:
            fixture.confirmed ? const {'pendingConfirm': 'done'} : const {},
        steps: [
          for (final type in StepType.values)
            type == StepType.converting || type == StepType.saving
                ? StepStatus.pending(type)
                : StepStatus.done(type),
        ],
      );
      CatCatchTask? updated;
      final saved = await TaskExecutor.executeTask(
        task: task,
        onUpdate: (value) => updated = value,
      );

      expect(saved, isNotNull);
      expect(updated?.status, TaskStatus.completed);
      expect(
        updated?.steps
            .singleWhere((step) => step.type == StepType.converting)
            .skipped,
        isTrue,
      );
      expect(p.extension(saved!), p.extension(fixture.name));
      expect(await File(saved).readAsBytes(), await source.readAsBytes());
      expect(
        await Directory(p.join(root.path, 'catcatch', 'converted')).exists(),
        isFalse,
      );
      expect(
          await FileManifest.loadRecords(), hasLength(fixture.video ? 0 : 1));
      expect(
          await VideoManifest.loadRecords(), hasLength(fixture.video ? 1 : 0));
    });
  }

  test('converter does not copy Ogg bytes into an MP4 file', () async {
    final source = File(p.join(root.path, 'source', 'audio_only.ogg'));
    await source.parent.create(recursive: true);
    await File('tests/fixtures/catcatch/audio_only.ogg').copy(source.path);
    final output = p.join(root.path, 'converted', 'audio_only.mp4');
    await Directory(p.dirname(output)).create(recursive: true);

    final result = await FFmpegConverter.convertToMp4(
      inputPath: source.path,
      outputPath: output,
    );
    expect(result, source.path);
    expect(await File(output).exists(), isFalse);
  });
}
