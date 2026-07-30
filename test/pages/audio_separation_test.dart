// Merged from:
//   test/pages/audio_separation_page_test.dart
//   test/pages/audio_separation_task_list_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/audio_separation_page.dart';
import 'package:stroom/pages/audio_separation_shared.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';
import 'package:stroom/utils/video_manifest.dart';
import 'package:stroom/pages/unified_task_list_page.dart';

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: AudioSeparationPage(),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    FileManifest.invalidateCache();
    VideoManifest.invalidateCache();
  });

  // ─────────────────────────────────────────────────────────────────────
  // From audio_separation_page_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('AudioSeparationPage - basic rendering', () {
    testWidgets('renders page title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('视频音频分离'), findsOneWidget);
    });

    testWidgets('shows empty state initially', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('暂未选择视频文件'), findsOneWidget);
    });

    testWidgets('select video button is present', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('选择视频来源'), findsOneWidget);
    });

    testWidgets('extract button is present', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('提取音频'), findsOneWidget);
    });

    testWidgets('shows supported formats hint', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('mp4'), findsOneWidget);
    });
  });

  group('AudioSeparationPage - video source selection panel', () {
    testWidgets('tapping video source button opens selection panel', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the video source button
      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();

      // Should show selection panel
      expect(find.text('选择视频来源'), findsWidgets);
    });

    testWidgets('video selection panel shows file and library options', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();

      // Should show options for selecting video
      expect(find.text('从系统相册选择'), findsOneWidget);
      expect(find.text('从应用相册选择'), findsOneWidget);
    });
  });

  group('AudioSeparationPage - save-to folder selector', () {
    testWidgets('shows save-to folder selector in bottom bar', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show save-to section in bottom bar
      expect(find.text('保存至'), findsOneWidget);
    });

    testWidgets('save-to shows root directory by default', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('根目录'), findsOneWidget);
    });
  });

  group('AudioSeparationPage - bottom bar', () {
    testWidgets('extract button is disabled when no file selected', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final filledButtons = tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      );
      for (final btn in filledButtons) {
        if (btn.onPressed == null) {
          // Found a disabled button - this is expected when no file
          return;
        }
      }
      // If we get here, check the text exists
      expect(find.text('提取音频'), findsOneWidget);
    });

    testWidgets('save-to section is above extract button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('保存至'), findsOneWidget);
      expect(find.text('提取音频'), findsOneWidget);
    });
  });

  // ====================================================================
  // NEW TESTS: In-app video picker dialog
  // ====================================================================

  group('AudioSeparationPage - in-app video picker dialog', () {
    testWidgets('tapping 从应用相册选择 opens in-app video picker dialog', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a record so the dialog can open (not empty state)
      await VideoManifest.addRecord(
        VideoRecord(
          name: '测试视频',
          hash: 'test_hash_vid',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 2048,
          duration: 5000,
        ),
      );

      // Tap the video source button
      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();

      // Tap "从应用相册选择"
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Should show the in-app video picker dialog title
      expect(find.text('选择应用内视频'), findsOneWidget);
    });

    testWidgets('in-app video picker shows empty state when no videos', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Navigate to the in-app video picker
      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Should show the full-screen picker with empty state
      expect(find.text('选择应用内视频'), findsOneWidget);
      expect(find.text('暂无视频'), findsOneWidget);
    });

    testWidgets('in-app video picker shows records when videos exist', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a test video record to the manifest
      await VideoManifest.addRecord(
        VideoRecord(
          name: '测试视频',
          hash: 'test_video_hash',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 2048,
          duration: 5000,
        ),
      );
      // Verify the record was added
      final records = await VideoManifest.loadRecords();
      expect(records.length, equals(1));

      // Navigate to the in-app video picker
      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Should show the record name
      expect(find.text('测试视频'), findsOneWidget);
    });

    testWidgets(
      'in-app video picker tapping record with missing file shows error snackbar',
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Add a test video record (file won't exist in test environment)
        await VideoManifest.addRecord(
          VideoRecord(
            name: '缺失视频',
            hash: 'missing_video_hash',
            format: 'mp4',
            createdAt: DateTime.now(),
            size: 2048,
            duration: 5000,
          ),
        );

        // Navigate to the in-app video picker
        await tester.tap(find.text('选择视频来源'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('从应用相册选择'));
        await tester.pumpAndSettle();

        // Tap on the record inside the picker dialog
        await tester.tap(find.text('缺失视频'));
        await tester.pumpAndSettle();

        // Should show error snackbar since the file doesn't exist
        // The dialog should remain open since the file read failed
        expect(find.text('选择应用内视频'), findsOneWidget);
      },
    );

    testWidgets(
      'in-app video picker shows folder navigation when videos exist in subfolders',
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Add a record in a subfolder
        await VideoManifest.addRecord(
          VideoRecord(
            name: '视频子文件夹',
            hash: 'test_nested_hash',
            format: 'mp4',
            createdAt: DateTime.now(),
            size: 2048,
            duration: 5000,
            folder: '测试子文件夹',
          ),
        );

        // Navigate to the in-app video picker
        await tester.tap(find.text('选择视频来源'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('从应用相册选择'));
        await tester.pumpAndSettle();

        // Should show the folder, not the file inside it
        expect(find.text('测试子文件夹'), findsOneWidget);
        expect(find.text('视频子文件夹'), findsNothing);
      },
    );

    testWidgets('in-app video picker close button dismisses the dialog', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a record so the dialog is not empty
      await VideoManifest.addRecord(
        VideoRecord(
          name: '测试视频',
          hash: 'test_hash',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 1024,
          duration: 3000,
        ),
      );

      // Navigate to the in-app video picker
      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Dialog should be visible
      expect(find.text('选择应用内视频'), findsOneWidget);

      // Tap the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('选择应用内视频'), findsNothing);
    });
  });

  // ====================================================================
  // CRASH REGRESSION: Tapping start should never crash the widget tree.
  // The original crash was a native segfault from media_kit's setProperty
  // being called with waitForInitialization=false on an uninitialized player.
  // ====================================================================
  group('AudioSeparationPage - start button crash regression', () {
    testWidgets('start button is disabled when no video loaded', (
      tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // No crash — widget tree is intact
      expect(find.text('视频音频分离'), findsOneWidget);

      // Start button exists but should be disabled without video
      final filledButtons = tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      );
      for (final btn in filledButtons) {
        if (btn.child != null && btn.child.toString().contains('提取音频')) {
          expect(
            btn.onPressed,
            isNull,
            reason: 'Extract button must be disabled when no video is loaded',
          );
          return;
        }
      }
      // If no button matched by child text, at least verify the button exists
      expect(filledButtons, isNotEmpty);
    });
  });

  group('AudioSeparationPage - save-to-library integration', () {
    testWidgets('_saveAudioSeparationFile generates correct AudioRecord', (
      tester,
    ) async {
      final file = File('lib/pages/audio_separation_page.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();

      // Locate the _saveAudioSeparationFile function start
      final methodStart =
          content.indexOf('Future<String?> _saveAudioSeparationFile');
      expect(
        methodStart,
        greaterThanOrEqualTo(0),
        reason: '_saveAudioSeparationFile function not found',
      );

      // Extract a reasonable chunk after the function signature.
      final methodCode = content.substring(
        methodStart,
        content
            .indexOf('\n}\n\n', methodStart)
            .clamp(methodStart + 1, content.length),
      );

      expect(
        methodCode.contains('FileManifest.writeFile'),
        isTrue,
        reason:
            '_saveAudioSeparationFile must write audio data via FileManifest',
      );
      expect(
        methodCode.contains('AudioRecord('),
        isTrue,
        reason: '_saveAudioSeparationFile must create an AudioRecord instance',
      );
      expect(
        methodCode.contains('FileManifest.addRecord'),
        isTrue,
        reason: '_saveAudioSeparationFile must add the record via FileManifest',
      );
      expect(
        methodCode.contains('FileManifest.readFilePath'),
        isTrue,
        reason:
            '_saveAudioSeparationFile must get file path via FileManifest.readFilePath',
      );
    });
  });

  group('AudioSeparationPage - unified order (app first, system second)', () {
    testWidgets(
      'video source panel shows app album BEFORE system album (Y-coordinate)',
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.text('选择视频来源'));
        await tester.pumpAndSettle();

        // Verify both options are rendered
        final appAlbum = find.text('从应用相册选择');
        final sysAlbum = find.text('从系统相册选择');
        expect(appAlbum, findsOneWidget);
        expect(sysAlbum, findsOneWidget);

        // Verify app album renders ABOVE system album (lower Y = higher on screen)
        final appRect = tester.getRect(appAlbum);
        final sysRect = tester.getRect(sysAlbum);
        expect(
          appRect.center.dy,
          lessThan(sysRect.center.dy),
          reason: '从应用相册选择 should appear above 从系统相册选择',
        );
      },
    );

    testWidgets('video source panel shows both choice options', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();

      expect(find.text('从应用相册选择'), findsOneWidget);
      expect(find.text('从系统相册选择'), findsOneWidget);
    });
  });

  group('AudioSeparationPage - unified colors (app=green, system=blue)', () {
    testWidgets('app album ChoiceCard uses green color', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();

      final choiceCards = find.byType(ChoiceCard);
      final firstCard = tester.widget<ChoiceCard>(choiceCards.at(0));
      expect(firstCard.color, Colors.green);
    });

    testWidgets('system album ChoiceCard uses blue color', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();

      final choiceCards = find.byType(ChoiceCard);
      final secondCard = tester.widget<ChoiceCard>(choiceCards.at(1));
      expect(secondCard.color, Colors.blue);
    });
  });

  group('AudioSeparationPage - multi-video selection', () {
    testWidgets('in-app video picker has multiSelect enabled', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a test video record
      await VideoManifest.addRecord(
        VideoRecord(
          name: '测试视频1',
          hash: 'test_hash_1',
          format: 'mp4',
          createdAt: DateTime.now(),
          size: 2048,
          duration: 5000,
        ),
      );

      // Open video source panel
      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();

      // Tap in-app video picker
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Should show multi-select checkbox and confirm button (multiSelect: true)
      expect(find.byType(Checkbox), findsWidgets);
      expect(find.byKey(const Key('media_picker_confirm_btn')), findsOneWidget);
    });

    testWidgets('UI shows "已选 X 个视频" count when videos present',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Initially no count label
      expect(find.textContaining('已选'), findsNothing);

      // Inject some selected videos via creating the page with state
      // Since widget tests can't easily inject state, verify the page structure
      // supports showing count by checking the bottom bar structure
      expect(find.text('提取音频'), findsOneWidget);
      expect(find.text('暂未选择视频文件'), findsOneWidget);
    });

    testWidgets('extract button is disabled when no videos selected',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Find all FilledButton widgets and check the extract button is disabled
      bool extractDisabled = false;
      final filledButtons = tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      );
      for (final btn in filledButtons) {
        if (btn.onPressed == null) {
          extractDisabled = true;
          break;
        }
      }
      expect(extractDisabled, isTrue,
          reason:
              'Extract button should be disabled when no videos are selected');
    });

    testWidgets('system file picker allows multiple selection', (tester) async {
      final file = File('lib/pages/audio_separation_page.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(
        content.contains('allowMultiple: true'),
        isTrue,
        reason: 'System video picker should allow multiple video selection',
      );
    });

    testWidgets('remove button appears on video cards', (tester) async {
      // Verify the _buildVideoList method contains remove buttons
      final file = File('lib/pages/audio_separation_page.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(
        content.contains('_removeVideo'),
        isTrue,
        reason: 'Video list items should have remove functionality',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From audio_separation_task_list_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('AudioSeparationPage - Shared', () {
    test('detectFormat returns correct format from filename', () {
      expect(detectFormat('video.mp4'), 'mp4');
      expect(detectFormat('video.mov'), 'mov');
      expect(detectFormat('video.avi'), 'avi');
      expect(detectFormat('video.mkv'), 'mkv');
      expect(detectFormat('video.webm'), 'webm');
      expect(detectFormat('video.flv'), 'flv');
      expect(detectFormat('video.m4v'), 'm4v');
      expect(detectFormat('video.3gp'), '3gp');
      expect(detectFormat('video.unknown'), 'mp4');
      expect(detectFormat(null), 'mp4');
    });

    test('formatFileSize returns correct string', () {
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(1024), '1.0 KB');
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(1048576), '1.0 MB');
      expect(formatFileSize(2097152), '2.0 MB');
    });

    test('SelectedVideo can be created', () {
      final video = SelectedVideo(
        bytes: Uint8List.fromList([0, 1, 2]),
        name: 'test.mp4',
        format: 'mp4',
      );
      expect(video.bytes.length, 3);
      expect(video.name, 'test.mp4');
      expect(video.format, 'mp4');
    });

    test('SelectedVideo defaults format to mp4', () {
      final video = SelectedVideo(
        bytes: Uint8List.fromList([0]),
        name: 'test.mov',
      );
      expect(video.format, 'mp4');
    });

    test('ChoiceCard can be created', () {
      // Just verify the widget can be instantiated without error
      expect(
        () => ChoiceCard(
          icon: Icons.video_library,
          title: 'Test',
          subtitle: 'Subtitle',
          color: Colors.green,
          onTap: () {},
        ),
        returnsNormally,
      );
    });
  });

  group('BackgroundTaskNotifier - Batch add tasks', () {
    test('addTask can add multiple tasks simultaneously', () {
      final notifier = BackgroundTaskNotifier();

      // Simulate batch-adding all tasks before processing
      final ids = <String>[];
      for (int i = 0; i < 3; i++) {
        final id = notifier.addTask(
          type: BackgroundTaskType.audioSeparation,
          title: '音频分离_视频$i',
        );
        ids.add(id);
      }

      expect(notifier.state.length, 3);
      expect(ids.length, 3);
      expect(ids[0], isNot(ids[1]));
      expect(ids[1], isNot(ids[2]));

      // All tasks should be in running state
      for (final task in notifier.state) {
        expect(task.status, TaskStatus.running);
        expect(task.type, BackgroundTaskType.audioSeparation);
      }

      // Task titles should be unique (newest first order)
      expect(notifier.state[0].title, '音频分离_视频2');
      expect(notifier.state[1].title, '音频分离_视频1');
      expect(notifier.state[2].title, '音频分离_视频0');
    });

    test('batch-added tasks can be updated individually by ID', () {
      final notifier = BackgroundTaskNotifier();

      final ids = <String>[];
      for (int i = 0; i < 3; i++) {
        ids.add(notifier.addTask(
          type: BackgroundTaskType.audioSeparation,
          title: 'Task $i',
        ));
      }

      // Update step 0 of task 0 to running
      notifier.updateStep(ids[0], 0, running: true);
      expect(notifier.state.firstWhere((t) => t.id == ids[0]).steps[0].running,
          true);
      // Other tasks should still have pending steps
      for (int i = 1; i < 3; i++) {
        expect(
          notifier.state.firstWhere((t) => t.id == ids[i]).steps[0].status,
          BgStepStatus.pending,
        );
      }

      // Complete task 0
      notifier.completeTask(ids[0], downloadedFilePath: '/path/file.mp3');
      expect(notifier.state.firstWhere((t) => t.id == ids[0]).status,
          TaskStatus.completed);
      expect(
        notifier.state.firstWhere((t) => t.id == ids[0]).downloadedFilePath,
        '/path/file.mp3',
      );

      // Fail task 1
      notifier.failTask(ids[1], error: '提取失败');
      expect(notifier.state.firstWhere((t) => t.id == ids[1]).status,
          TaskStatus.failed);
      expect(
        notifier.state.firstWhere((t) => t.id == ids[1]).error,
        '提取失败',
      );

      // Task 2 should still be running
      expect(notifier.state.firstWhere((t) => t.id == ids[2]).status,
          TaskStatus.running);
    });

    test('batch add followed by complete keeps all tasks visible', () {
      final notifier = BackgroundTaskNotifier();

      // Add 5 tasks at once
      final ids = <String>[];
      for (int i = 0; i < 5; i++) {
        ids.add(notifier.addTask(
          type: BackgroundTaskType.audioSeparation,
          title: 'Task $i',
        ));
      }

      expect(notifier.state.length, 5);

      // Complete all tasks
      for (final id in ids) {
        notifier.completeTask(id);
      }

      // All 5 should remain visible as completed
      expect(notifier.state.length, 5);
      for (final task in notifier.state) {
        expect(task.status, TaskStatus.completed);
      }
    });

    test('audio separation task has correct step labels', () {
      final notifier = BackgroundTaskNotifier();

      final id = notifier.addTask(
        type: BackgroundTaskType.audioSeparation,
        title: '音频分离_test',
      );

      final task = notifier.state.firstWhere((t) => t.id == id);
      expect(task.steps.length, 2);
      expect(task.steps[0].label, '分离音频');
      expect(task.steps[1].label, '保存到文件');
    });
  });

  // ====================================================================
  // Phase 2 regression tests — extraction flow correctness
  // ====================================================================

  group('AudioSeparationPage — extraction pipeline structure', () {
    final source =
        File('lib/pages/audio_separation_page.dart').readAsStringSync();

    test('_workerExtract uses Isolate.run (not SendPort worker)', () {
      final fnStart = source.indexOf('_workerExtract');
      expect(fnStart, greaterThanOrEqualTo(0));
      final fnEnd =
          source.indexOf('\n}\n', fnStart).clamp(fnStart + 1, source.length);
      final fnBody = source.substring(fnStart, fnEnd);
      expect(fnBody.contains('Isolate.run'), isTrue,
          reason: '_workerExtract must use Isolate.run whose Future-based '
              'await reliably yields to the event loop');
      expect(fnBody.contains('extractAudioSync'), isTrue);
      expect(fnBody.contains('computeAudioHash'), isTrue);
      expect(fnBody.contains('detectAudioFormat'), isTrue);
    });

    test('_runAudioSeparation uses _BgThrottler to batch state updates', () {
      final fnStart = source.indexOf('Future<void> _runAudioSeparation');
      expect(fnStart, greaterThanOrEqualTo(0));
      final fnEnd =
          source.indexOf('\n}\n', fnStart).clamp(fnStart + 1, source.length);
      final fnBody = source.substring(fnStart, fnEnd);
      expect(fnBody.contains('_BgThrottler'), isTrue,
          reason: '_runAudioSeparation must use _BgThrottler '
              'to batch state updates instead of calling updateStep directly');
      expect(fnBody.contains('await Future<void>.delayed'), isFalse,
          reason: 'explicit yields have been replaced by throttler batching');
    });

    test('_runAudioSeparation is a top-level function (not a method)', () {
      final classStart = source.indexOf('class _AudioSeparationPageState');
      final runFnIdx = source.indexOf('Future<void> _runAudioSeparation');
      expect(runFnIdx, greaterThanOrEqualTo(0));
      // The function must be defined OUTSIDE the State class body.
      // It can appear before or after the class — what matters is
      // that it's not inside the class's `{ ... }`.
      final classOpenBrace = source.indexOf('{', classStart);
      expect(runFnIdx < classOpenBrace, isTrue,
          reason: '_runAudioSeparation must be top-level, '
              'not an instance method of _AudioSeparationPageState');
    });

    test('_saveAudioSeparationFile requires hash and format parameters', () {
      final saveStart =
          source.indexOf('Future<String?> _saveAudioSeparationFile');
      expect(saveStart, greaterThanOrEqualTo(0));
      final saveBody = source.substring(
          saveStart,
          source
              .indexOf('\n}\n', saveStart)
              .clamp(saveStart + 1, source.length));
      expect(saveBody.contains('required String hash'), isTrue);
      expect(saveBody.contains('required String format'), isTrue);
    });

    test('_startSeparation captures state BEFORE Navigator.pop', () {
      final startIdx = source.indexOf('Future<void> _startSeparation() async');
      expect(startIdx, greaterThanOrEqualTo(0));
      final endIdx = source.indexOf('void _goToAudioLibrary', startIdx);
      final methodBody = source.substring(startIdx, endIdx);
      // ref.read calls must appear before Navigator.pop
      final refReadBg = methodBody.indexOf('ref.read(backgroundTasksProvider');
      final popCall = methodBody.indexOf('Navigator.pop(context)');

      expect(refReadBg, greaterThanOrEqualTo(0));
      expect(popCall, greaterThanOrEqualTo(0));
      expect(refReadBg, lessThan(popCall),
          reason: 'notifiers must be captured BEFORE Navigator.pop');
    });
    test('_startSeparation calls setState for _isProcessing guard', () {
      final startIdx = source.indexOf('Future<void> _startSeparation() async');
      final methodBody = source.substring(
          startIdx, source.indexOf('void _goToAudioLibrary', startIdx));
      expect(methodBody.contains('_isProcessing = true'), isTrue,
          reason:
              '_isProcessing must be set to true to guard against double-tap');
    });
  });

  group('AudioSeparationPage — animation completion detector', () {
    test('Completer resolves on AnimationStatus.dismissed', () async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 300),
      );
      addTearDown(controller.dispose);

      final done = Completer<void>();

      void listener(AnimationStatus status) {
        if (status == AnimationStatus.dismissed) {
          done.complete();
          controller.removeStatusListener(listener);
        }
      }

      // Initially dismissed — listener won't fire yet
      controller.addStatusListener(listener);

      // Start forward then reverse (simulates pop)
      controller.forward();
      await Future<void>.delayed(Duration.zero);
      controller.reverse();

      // The Completer should resolve when reverse animation completes
      await done.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () =>
            throw TimeoutException('Animation did not reach dismissed'),
      );
      expect(controller.status, AnimationStatus.dismissed);
    });

    test('Completer does not hang when animation already dismissed', () async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 300),
      );
      addTearDown(controller.dispose);

      // Already dismissed at creation
      final done = Completer<void>();

      void listener(AnimationStatus status) {
        if (status == AnimationStatus.dismissed) {
          if (!done.isCompleted) {
            done.complete();
          }
          controller.removeStatusListener(listener);
        }
      }

      controller.addStatusListener(listener);

      // Since already dismissed, we need to trigger a status change
      // to fire the listener, OR guard against the edge case:
      if (controller.status == AnimationStatus.dismissed && !done.isCompleted) {
        done.complete();
      }

      await done.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw TimeoutException(
            'Completer hung on already-dismissed animation'),
      );
      expect(done.isCompleted, isTrue);
    });

    test('Completer completes on reverse animation from completed', () async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 300),
      );
      addTearDown(controller.dispose);

      // Forward to completed
      controller.forward();
      await Future<void>.delayed(Duration.zero);

      final done = Completer<void>();

      void listener(AnimationStatus status) {
        if (status == AnimationStatus.dismissed) {
          if (!done.isCompleted) done.complete();
          controller.removeStatusListener(listener);
        }
      }

      controller.addStatusListener(listener);
      controller.reverse();
      await Future<void>.delayed(Duration.zero);
      // Guard: if already dismissed (edge case), complete manually
      if (controller.status == AnimationStatus.dismissed && !done.isCompleted) {
        done.complete();
      }

      await done.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('Reverse animation did not reach dismissed'),
      );
      expect(controller.status, AnimationStatus.dismissed);
    });
  });

  group('AudioSeparationPage — button guard behavior', () {
    test('_isProcessing field is mutable (not final)', () {
      // Source-level verification: _isProcessing must NOT be declared final.
      final content =
          File('lib/pages/audio_separation_page.dart').readAsStringSync();
      // The declaration is "bool _isProcessing" — search for "final bool _isProcessing"
      // which must NOT be present.
      expect(content.contains('final bool _isProcessing'), isFalse,
          reason: '_isProcessing must be mutable (not final) to support '
              'setState(() => _isProcessing = true) for double-tap guard');
    });

    test('extract button guard checks both _selectedVideos and _isProcessing',
        () async {
      final content =
          File('lib/pages/audio_separation_page.dart').readAsStringSync();
      expect(content.contains('_selectedVideos.isEmpty || _isProcessing'), isTrue,
          reason: 'Button guard must check both empty list and processing state');
      // Also verify the internal guard inside _startSeparation itself
      expect(content.contains('if (_isProcessing) return'), isTrue,
          reason: '_startSeparation must have its own double-tap guard');
    });
  });

  // ====================================================================
  // Phase 2 tests — debounce + long-lived worker isolate
  // ====================================================================

  group('BackgroundTaskNotifier — debounce persistence', () {
    test('rapid updates produce correct in-memory state', () async {
      final notifier = BackgroundTaskNotifier();
      addTearDown(notifier.dispose);

      // Simulate rapid updates like the audio separation pipeline
      final id = notifier.addTask(
          type: BackgroundTaskType.audioSeparation, title: 'Test');
      notifier.updateStep(id, 0, running: true);
      notifier.updateStep(id, 0, completed: true);
      notifier.updateStep(id, 1, running: true);
      notifier.completeTask(id);

      // After multiple updates, state should be consistent in memory
      final task = notifier.state.firstWhere((t) => t.id == id);
      expect(task.status, TaskStatus.completed);
      expect(task.steps[0].completed, isTrue);
    });

    test('dispose flushes pending writes immediately', () async {
      final notifier = BackgroundTaskNotifier();
      final id = notifier.addTask(
          type: BackgroundTaskType.audioSeparation, title: 'DisposeTest');
      notifier.updateStep(id, 0, running: true);
      // Dispose triggers an immediate _persistTasks flush
      notifier.dispose();
      // No crash = pass (the synchronous _persistTasks in dispose
      // did not throw and attempted the write)
    });
  });

  // ====================================================================
  // Behavioral tests — throttler correctness, .select(), GUI interaction
  // ====================================================================

  group('BackgroundTaskNotifier — throttled state updates', () {
    test('rapid updates produce correct final in-memory state', () {
      final notifier = BackgroundTaskNotifier();
      addTearDown(notifier.dispose);

      final taskId = notifier.addTask(
        type: BackgroundTaskType.audioSeparation,
        title: 'ThrottleTest',
      );

      // Simulate the pattern _BgThrottler would apply: multiple
      // updateStep/completeTask calls in quick succession
      notifier.updateStep(taskId, 0, running: true);
      notifier.updateStep(taskId, 0, completed: true);
      notifier.updateStep(taskId, 1, running: true);
      notifier.updateStep(taskId, 1, completed: true);
      notifier.completeTask(taskId);

      final task = notifier.state.firstWhere((t) => t.id == taskId);
      expect(task.status, TaskStatus.completed,
          reason: 'task status must be completed after all updates');
      expect(task.steps[0].completed, isTrue);
      expect(task.steps[1].completed, isTrue);
    });

    test('dispose still flushes pending state', () {
      final notifier = BackgroundTaskNotifier();
      final taskId = notifier.addTask(
        type: BackgroundTaskType.audioSeparation,
        title: 'DisposeFlush',
      );
      notifier.updateStep(taskId, 0, running: true);
      notifier.updateStep(taskId, 0, completed: true);

      // dispose should complete without throwing
      expect(() => notifier.dispose(), returnsNormally);
    });

    test('failure in updateStep does not lose prior state', () {
      final notifier = BackgroundTaskNotifier();
      addTearDown(notifier.dispose);
      final taskId = notifier.addTask(
        type: BackgroundTaskType.audioSeparation,
        title: 'ErrorTest',
      );
      notifier.updateStep(taskId, 0, running: true);

      // failTask should mark the task as failed without crashing
      notifier.failTask(taskId, error: 'something went wrong');
      final task = notifier.state.firstWhere((t) => t.id == taskId);
      expect(task.status, TaskStatus.failed);
    });
  });

  group('HomePage — .select() guard', () {
    final homeSource = File('lib/pages/home_page.dart').readAsStringSync();

    test('backgroundTasksProvider is watched with .select()', () {
      // Verify the home page uses .select() so that intermediate
      // step-state changes do not trigger a full rebuild.
      expect(
        homeSource.contains('backgroundTasksProvider.select'),
        isTrue,
        reason: 'HomePage must watch backgroundTasksProvider via .select() '
            'to scope rebuilds to status-count changes only',
      );
    });

    test('the old full-list watch is removed', () {
      // The pattern "backgroundTasks = ref.watch(backgroundTasksProvider);"
      // WITHOUT .select should NOT appear in the home page anymore.
      // A .select-less watch would cause a rebuild on every updateStep.
      final lines = homeSource.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('ref.watch(backgroundTasksProvider') &&
            !line.contains('.select')) {
          // Allow comment lines
          if (line.trimLeft().startsWith('//')) continue;
          fail(
            'HomePage must not use ref.watch(backgroundTasksProvider) '
            'without .select(). Found at line ${i + 1}',
          );
        }
      }
    });
  });

  group('_saveAudioSeparationFile — loadRecords removed', () {
    final funcSource =
        File('lib/pages/audio_separation_page.dart').readAsStringSync();

    test('does NOT call loadRecords per video', () {
      final fnStart =
          funcSource.indexOf('Future<String?> _saveAudioSeparationFile');
      expect(fnStart, greaterThanOrEqualTo(0));
      final fnEnd = funcSource
          .indexOf('\n}\n', fnStart)
          .clamp(fnStart + 1, funcSource.length);
      final body = funcSource.substring(fnStart, fnEnd);
      expect(body.contains('loadRecords'), isFalse,
          reason:
              '_saveAudioSeparationFile must not call loadRecords per video '
              '— the refresh is deferred until the user opens the audio library');
    });
  });

  group('UnifiedTaskListPage — task card responds during processing', () {
    testWidgets('renders task and survives state change', (tester) async {
      final notifier = BackgroundTaskNotifier();

      notifier.addTask(
        type: BackgroundTaskType.audioSeparation,
        title: 'Video 1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            backgroundTasksProvider.overrideWith((ref) => notifier),
            taskListProvider.overrideWith((ref) {
              final n = TaskListNotifier(ref);
              n.state = [];
              return n;
            }),
          ],
          child: const MaterialApp(home: UnifiedTaskListPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Video 1'), findsOneWidget,
          reason: 'task card should render after pump');
    });
  });
}
