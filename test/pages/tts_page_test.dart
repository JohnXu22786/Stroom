import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/tts_page.dart';
import 'package:stroom/providers/tts_state_provider.dart';
import 'package:stroom/utils/sort_config.dart';
import 'package:stroom/services/manifest_database.dart';

Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      audioRecordsProvider.overrideWith((ref) => AudioRecordsNotifier()),
      folderListProvider.overrideWith((ref) => FolderListNotifier()),
      audioSortConfigProvider.overrideWith(
        (ref) => SortConfigNotifier('audio_sort_config_test'),
      ),
    ],
    child: const MaterialApp(
      home: TtsPage(),
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

  group('TtsPage - audio page buttons', () {
    testWidgets('shows three action buttons: 开始录音, 生成录音, 导入音频',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Verify the three button texts exist
      expect(find.text('开始录音'), findsOneWidget);
      expect(find.text('生成录音'), findsOneWidget);
      expect(find.text('导入音频'), findsOneWidget);
    });

    testWidgets('buttons are in correct order: 开始录音 → 生成录音 → 导入音频',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Find all ElevatedButton.icon widgets
      final buttons = find.byType(ElevatedButton);
      expect(buttons, findsNWidgets(3));

      // Get the positions of the three buttons to verify left-to-right order
      final button0Pos = tester.getTopLeft(buttons.at(0));
      final button1Pos = tester.getTopLeft(buttons.at(1));
      final button2Pos = tester.getTopLeft(buttons.at(2));

      // All three should be on the same horizontal line (same dy)
      expect(button0Pos.dy, button1Pos.dy);
      expect(button1Pos.dy, button2Pos.dy);

      // And in order from left to right
      expect(button0Pos.dx, lessThan(button1Pos.dx));
      expect(button1Pos.dx, lessThan(button2Pos.dx));
    });

    testWidgets('old label 制作录音 is not present', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // "制作录音" should no longer appear anywhere
      expect(find.text('制作录音'), findsNothing);
    });

    testWidgets('开始录音 button has microphone icon', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // A mic icon should be present in the widget tree (on the first button)
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon &&
              (w.icon == Icons.mic ||
                  w.icon == Icons.mic_outlined ||
                  w.icon == Icons.mic_none),
        ),
        findsWidgets,
      );
    });
  });
}
