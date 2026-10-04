import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/engine/task_executor.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/models/media_resource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const split = MediaResource(
    url: 'https://example.com/split.mp4',
    name: 'split',
    ext: 'mp4',
    isLikelySplitTrack: true,
  );
  const audio = MediaResource(
    url: 'https://example.com/audio.mp4',
    name: 'audio',
    ext: 'mp4',
    mimeType: 'audio/mp4',
  );
  const video = MediaResource(
    url: 'https://example.com/video.mp4',
    name: 'video',
    ext: 'mp4',
    mimeType: 'video/mp4',
  );

  Future<CatCatchTask?> runSelection(MediaResource media,
      {bool deferSingleResourceSelection = false}) async {
    final token = CancelToken();
    final task = CatCatchTask(
      id: 'selection',
      url: 'https://example.com',
      expectedDurationSec: 0,
      createdAt: DateTime(2026),
      detectedMedia: [media],
      metadata: {
        if (deferSingleResourceSelection)
          'deferSingleResourceSelection': 'true',
      },
      steps: [
        for (final type in StepType.values)
          type == StepType.userSelecting
              ? StepStatus.pending(type)
              : StepStatus.done(type),
      ],
    );
    CatCatchTask? lastUpdate;
    await TaskExecutor.executeTask(
      task: task,
      cancelToken: token,
      onUpdate: (updated) {
        lastUpdate = updated;
        // Stop before the download step if the ordinary CatCatch path selects.
        if (updated.selectedMedia != null) token.cancel();
      },
    );
    return lastUpdate;
  }

  test('flow keeps a lone split track, wrong type, or valid video for policy',
      () async {
    for (final media in [split, audio, video]) {
      final updated = await runSelection(
        media,
        deferSingleResourceSelection: true,
      );
      expect(updated?.detectedMedia, [media]);
      expect(updated?.selectedMedia, isNull);
      expect(
        updated?.steps
            .firstWhere((s) => s.type == StepType.userSelecting)
            .running,
        isTrue,
      );
    }
  });

  test('ordinary CatCatch still selects its sole resource', () async {
    final updated = await runSelection(video);
    expect(updated?.selectedMedia, video);
    expect(
      updated?.steps
          .firstWhere((s) => s.type == StepType.userSelecting)
          .completed,
      isTrue,
    );
  });
}
