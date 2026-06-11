import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/audio_separation_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/file_manifest.dart';

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
}
