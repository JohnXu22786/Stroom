import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/model_config_page.dart';

void main() {
  for (final locale in const [Locale('de'), Locale('es'), Locale('pt', 'BR')]) {
    for (final width in const [280.0, 320.0, 360.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'model config constrained labels avoid layout overflow at ${locale.toLanguageTag()} ${width.toInt()}px '
          '${brightness.name}',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  locale: locale,
                  theme: ThemeData(useMaterial3: true, brightness: brightness),
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(1.7)),
                    child: child!,
                  ),
                  home: const ModelConfigPage(
                    entryId: 'audit',
                    configIndex: -1,
                    modelIndex: -1,
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            final localizations = AppLocalizations.of(
              tester.element(find.byType(Scaffold).first),
            )!;
            final scrollable = find.byType(Scrollable).first;
            for (final label in [
              localizations.chatCustomParameters,
              localizations.ttsInstructionSupported,
              localizations.ttsStreamSupported,
              localizations.modelAudioTrimTitle,
            ]) {
              await tester.scrollUntilVisible(
                find.text(label),
                300,
                scrollable: scrollable,
              );
              await tester.pump();
              expect(
                tester.takeException(),
                isNull,
                reason: 'while scrolling to $label',
              );
            }
          },
        );
      }
    }
  }
}
