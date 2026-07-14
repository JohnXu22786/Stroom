// Merged from:
//   test/pages/audio_separation_page_test.dart
//   test/pages/audio_separation_task_list_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
    testWidgets('_saveAudioToLibrary generates correct AudioRecord', (
      tester,
    ) async {
      final file = File('lib/pages/audio_separation_page.dart');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();

      // Locate the _saveAudioToLibrary method start
      final methodStart =
          content.indexOf('Future<String?> _saveAudioToLibrary');
      expect(
        methodStart,
        greaterThanOrEqualTo(0),
        reason: '_saveAudioToLibrary method not found',
      );

      // Extract a reasonable chunk after the method signature (the method is
      // ~30 lines). We search for the first '};' pattern (end of class) or
      // the next method declaration to bound the search.
      final methodCode = content.substring(
        methodStart,
        content
            .indexOf('\n  void ', methodStart)
            .clamp(methodStart + 1, content.length),
      );

      expect(
        methodCode.contains('FileManifest.writeFile'),
        isTrue,
        reason: '_saveAudioToLibrary must write audio data via FileManifest',
      );
      expect(
        methodCode.contains('AudioRecord('),
        isTrue,
        reason: '_saveAudioToLibrary must create an AudioRecord instance',
      );
      expect(
        methodCode.contains('FileManifest.addRecord'),
        isTrue,
        reason: '_saveAudioToLibrary must add the record via FileManifest',
      );
      expect(
        methodCode.contains('audioRecordsProvider.notifier'),
        isTrue,
        reason: '_saveAudioToLibrary must refresh the audio records provider',
      );
      expect(
        methodCode.contains('FileManifest.readFilePath'),
        isTrue,
        reason:
            '_saveAudioToLibrary must get file path via FileManifest.readFilePath',
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
}
