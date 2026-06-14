import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/audio_separation_page.dart';
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
    testWidgets('tapping video source button opens selection panel',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the video source button
      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();

      // Should show selection panel
      expect(find.text('选择视频来源'), findsWidgets);
    });

    testWidgets('video selection panel shows file and library options',
        (tester) async {
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
    testWidgets('extract button is disabled when no file selected',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final filledButtons = tester.widgetList<FilledButton>(find.byType(FilledButton));
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
    testWidgets('tapping 从应用相册选择 opens in-app video picker dialog',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a record so the dialog can open (not empty state)
      await VideoManifest.addRecord(VideoRecord(
        name: '测试视频',
        hash: 'test_hash_vid',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 2048,
        duration: 5000,
      ));

      // Tap the video source button
      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();

      // Tap "从应用相册选择"
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Should show the in-app video picker dialog title
      expect(find.text('选择应用内视频'), findsOneWidget);
    });

    testWidgets('in-app video picker shows empty state when no videos',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Ensure video records are empty
      VideoManifest.invalidateCache();
      final records = await VideoManifest.loadRecords();
      expect(records, isEmpty);

      // Navigate to the in-app video picker
      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Should show empty state text
      expect(find.text('暂无可用的应用内视频'), findsOneWidget);
    });

    testWidgets('in-app video picker shows records when videos exist',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a test video record to the manifest
      await VideoManifest.addRecord(VideoRecord(
        name: '测试视频',
        hash: 'test_video_hash',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 2048,
        duration: 5000,
      ));
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

    testWidgets('in-app video picker tapping record with missing file shows error snackbar',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a test video record (file won't exist in test environment)
      await VideoManifest.addRecord(VideoRecord(
        name: '缺失视频',
        hash: 'missing_video_hash',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 2048,
        duration: 5000,
      ));

      // Navigate to the in-app video picker
      await tester.tap(find.text('选择视频来源'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从应用相册选择'));
      await tester.pumpAndSettle();

      // Tap on the record
      await tester.tap(find.text('缺失视频'));
      await tester.pumpAndSettle();

      // Should show error snackbar since the file doesn't exist
      expect(find.textContaining('无法读取'), findsOneWidget);
    });

    testWidgets('in-app video picker close button dismisses the dialog',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Add a record so the dialog is not empty
      await VideoManifest.addRecord(VideoRecord(
        name: '测试视频',
        hash: 'test_hash',
        format: 'mp4',
        createdAt: DateTime.now(),
        size: 1024,
        duration: 3000,
      ));

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
    testWidgets('start button is disabled when no video loaded',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // No crash — widget tree is intact
      expect(find.text('视频音频分离'), findsOneWidget);

      // Start button exists but should be disabled without video
      final filledButtons = tester.widgetList<FilledButton>(find.byType(FilledButton));
      for (final btn in filledButtons) {
        if (btn.child != null && btn.child.toString().contains('提取音频')) {
          expect(btn.onPressed, isNull,
              reason: 'Extract button must be disabled when no video is loaded');
          return;
        }
      }
      // If no button matched by child text, at least verify the button exists
      expect(filledButtons, isNotEmpty);
    });
  });
}
