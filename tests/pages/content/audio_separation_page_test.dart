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
}
