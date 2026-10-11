import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/audio_separation_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider_shared.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    FileManifest.invalidateCache();
    VideoManifest.invalidateCache();
  });

  testWidgets('separation failure marks its active step failed', (
    tester,
  ) async {
    final notifier = BackgroundTaskNotifier();
    const retryData = {
      'videos': [
        {'bytes': 'AQID', 'name': 'retry-source.mp4', 'format': 'mp4'},
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [backgroundTasksProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const AudioSeparationPage(retryData: retryData),
                  ),
                ),
                child: const Text('Open retry'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open retry'));
    await tester.pumpAndSettle();
    expect(find.text('retry-source.mp4'), findsOneWidget);

    await tester.tap(find.text('提取音频'));
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 500; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      if (notifier.state.isNotEmpty &&
          notifier.state.single.status == TaskStatus.failed) {
        break;
      }
    }

    expect(notifier.state, hasLength(1));
    final task = notifier.state.single;
    expect(task.status, TaskStatus.failed);
    expect(task.retryData, retryData);
    expect(task.steps.where((step) => step.failed), hasLength(1));
    expect(task.steps.where((step) => step.running), isEmpty);
  });

  test('removing a task during extraction does not save its result', () async {
    final notifier = BackgroundTaskNotifier();
    final extractionStarted = Completer<void>();
    final extractionResult =
        Completer<({Uint8List audioBytes, String hash, String format})>();

    final execution = runAudioSeparationForTesting(
      videos: [
        SelectedVideo(
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'pending.mp4',
        ),
      ],
      bgNotifier: notifier,
      saveFolder: '',
      workerExtract: (_) {
        extractionStarted.complete();
        return extractionResult.future;
      },
    );

    await extractionStarted.future.timeout(const Duration(seconds: 5));
    expect(notifier.state, hasLength(1));
    notifier.removeTask(notifier.state.single.id);
    extractionResult.complete((
      audioBytes: Uint8List.fromList([1, 2, 3, 4]),
      hash: 'removed_audio_task',
      format: 'wav',
    ));

    await execution;

    expect(await FileManifest.readFile('removed_audio_task.wav'), isNull);
    expect(await FileManifest.loadRecords(), isEmpty);
    expect(notifier.state, isEmpty);
  });

  test('normal separation still saves output and completes its task', () async {
    final notifier = BackgroundTaskNotifier();
    final audioBytes = Uint8List.fromList([5, 6, 7, 8]);

    await runAudioSeparationForTesting(
      videos: [
        SelectedVideo(
          bytes: Uint8List.fromList([1, 2, 3]),
          name: 'complete.mp4',
        ),
      ],
      bgNotifier: notifier,
      saveFolder: '',
      workerExtract: (_) async =>
          (audioBytes: audioBytes, hash: 'completed_audio_task', format: 'wav'),
    );

    expect(notifier.state, hasLength(1));
    expect(notifier.state.single.status, TaskStatus.completed);
    expect(await FileManifest.readFile('completed_audio_task.wav'), audioBytes);
    expect(await FileManifest.loadRecords(), hasLength(1));
    expect(
      (await FileManifest.loadRecords()).single.storageFileName,
      'completed_audio_task.wav',
    );
  });
}
