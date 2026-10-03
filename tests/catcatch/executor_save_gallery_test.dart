import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/catcatch/engine/executor_save.dart';
import 'package:stroom/catcatch/engine/task_executor.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';
import 'package:stroom/utils/web_file_store.dart';

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
    await source.writeAsBytes([0, 1, 2, 3, 4]);
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
    expect(await File(saved).readAsBytes(), [0, 1, 2, 3, 4]);
    return saved;
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
    expect(audioRecords.single.format, 'mp4');
    expect(await VideoManifest.loadRecords(), isEmpty);
    expect(
      await File(
              p.join(root.path, 'tts_audio', '${audioRecords.single.hash}.mp4'))
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
    await source.writeAsBytes([5, 6, 7]);
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
}
