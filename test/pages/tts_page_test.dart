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
    testWidgets('buttons are in correct order: 录音 → 导入', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Find all ElevatedButton.icon widgets
      final buttons = find.byType(ElevatedButton);
      expect(buttons, findsNWidgets(2));

      // Get the positions of the two buttons to verify left-to-right order
      final button0Pos = tester.getTopLeft(buttons.at(0));
      final button1Pos = tester.getTopLeft(buttons.at(1));

      // Both should be on the same horizontal line (same dy)
      expect(button0Pos.dy, button1Pos.dy);

      // And in order from left to right
      expect(button0Pos.dx, lessThan(button1Pos.dx));
    });

    testWidgets('buttons fit without overflow on narrow screen',
        (tester) async {
      // Set a narrow screen (small phone width)
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Both buttons should be visible
      expect(find.widgetWithText(ElevatedButton, '录音'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '导入'), findsOneWidget);

      // No overflow exceptions
      expect(tester.takeException(), isNull);
    });
  });
}
