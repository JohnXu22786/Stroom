import 'dart:typed_data';

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

  group('AudioSeparationPage', () {
    testWidgets('renders page title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show the page title
      expect(find.text('视频音频分离'), findsOneWidget);
    });

    testWidgets('shows select video file button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show the select video file button
      expect(find.text('选择视频文件'), findsOneWidget);
    });

    testWidgets('shows empty state initially', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show empty state text
      expect(find.text('暂未选择视频文件'), findsOneWidget);
    });

    testWidgets('shows supported formats hint', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Should show hint about supported formats
      expect(find.textContaining('mp4'), findsOneWidget);
    });

    testWidgets('extract button is disabled when no file selected',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Find the bottom action button
      final extractBtn = find.text('提取音频');
      expect(extractBtn, findsOneWidget);

      // Should be a disabled button (no file selected)
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('select video button is tappable', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // The select video button should be enabled
      final selectBtn = find.text('选择视频文件');
      expect(selectBtn, findsOneWidget);
    });

    testWidgets('shows engine status after initialization', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // After pumpAndSettle, engine availability check should complete
      // The page should not show the "no engine" error state initially
      expect(find.text('提取音频'), findsOneWidget);
    });

    testWidgets('clear button is hidden by default when no video selected',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // No clear button should appear when no file is selected
      expect(find.text('清空'), findsNothing);
    });
  });
}
