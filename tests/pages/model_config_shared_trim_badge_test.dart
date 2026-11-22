import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/model_config_shared.dart';
import 'package:stroom/providers/tts_config.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('long selected trim preset stays inside its compact header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const presetId = 'long-custom-trim';
    final preset = TrimPreset(
      id: presetId,
      name: 'A deliberately long user defined trim preset name',
      durationSeconds: 0.25,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customTrimPresetsProvider.overrideWith((ref) {
            return _PresetNotifier(preset);
          }),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TrimSection(
                selectedPresetId: presetId,
                onPresetChanged: (_) {},
                isTestingAudio: false,
                testAudioError: null,
                onPlayTestAudio: () {},
                onAddPreset: () {},
                onEditPreset: (_) {},
                onDeletePreset: (_) async => true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final badge = find.ancestor(
      of: find.text(
        'A deliberately long user defined trim preset name（Beginning，0.250s）',
      ),
      matching: find.byType(ConstrainedText),
    );
    expect(badge, findsOneWidget);
    expect(tester.getSize(badge).width, lessThan(280));
    expect(
      find.text(
        'A deliberately long user defined trim preset name（Beginning，0.250s）',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _PresetNotifier extends CustomTrimPresetsNotifier {
  _PresetNotifier(TrimPreset preset) {
    state = [preset];
  }
}
