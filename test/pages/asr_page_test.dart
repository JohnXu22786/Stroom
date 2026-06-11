import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/pages/asr_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/tts_state_provider.dart';
import 'package:stroom/services/manifest_database.dart';

// ============================================================================
// Test Helpers
// ============================================================================

Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      audioRecordsProvider.overrideWith((ref) => AudioRecordsNotifier()),
      providerEntriesProvider.overrideWith(
        (ref) => ProviderEntriesNotifier(),
      ),
    ],
    child: const MaterialApp(
      home: AsrPage(),
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
  });

  group('AsrPage - audio source selection', () {
    testWidgets('shows 选择音频来源 button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('选择音频来源'), findsOneWidget);
    });

    testWidgets('tapping button opens bottom sheet with source options',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Tap the source selection button
      await tester.tap(find.text('选择音频来源'));
      await tester.pumpAndSettle();

      // Verify bottom sheet shows source options
      expect(find.text('应用内录音'), findsOneWidget);
      expect(find.text('系统音频文件'), findsOneWidget);
    });

    testWidgets('bottom sheet shows subtitles for each option',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择音频来源'));
      await tester.pumpAndSettle();

      expect(find.text('从已生成的录音中选择'), findsOneWidget);
      expect(find.text('从设备文件中选择'), findsOneWidget);
    });

    testWidgets('shows snackbar when no in-app audio records available',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Open bottom sheet
      await tester.tap(find.text('选择音频来源'));
      await tester.pumpAndSettle();

      // Tap "应用内录音" option
      await tester.tap(find.text('应用内录音'));
      await tester.pumpAndSettle();

      // Should show a snackbar since no recordings exist
      expect(find.text('暂无可用的应用内录音'), findsOneWidget);
    });
  });
}
