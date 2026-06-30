import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/tts_create_page.dart';
import 'package:stroom/providers/tts_config.dart';
import 'package:stroom/providers/tts_state_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';

Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      providerEntriesProvider.overrideWith((ref) => ProviderEntriesNotifier()),
      ttsStateProvider.overrideWith((ref) => TTSStateNotifier(ref)),
      synthesisConfigProvider.overrideWith((ref) => SynthesisConfigNotifier()),
      taskListProvider.overrideWith((ref) => TaskListNotifier(ref)),
      customTrimPresetsProvider.overrideWith(
        (ref) => CustomTrimPresetsNotifier(),
      ),
    ],
    child: const MaterialApp(
      home: TTSCreatePage(),
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
  });

  group('TTSCreatePage - renamed titles', () {
    testWidgets('AppBar title shows 生成录音 instead of 制作录音', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      // The widget may have animations that never settle in test environment,
      // so use manual pump steps
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // Consume any lifecycle/dispose exceptions from Riverpod
      tester.takeException();

      // Verify the AppBar title shows 生成录音
      expect(find.text('生成录音'), findsWidgets);

      // The old title should not be present
      expect(find.text('制作录音'), findsNothing);
    });
  });
}
