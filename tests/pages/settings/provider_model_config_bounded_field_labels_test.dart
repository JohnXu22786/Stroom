import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/model_config_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets(
    'localized TTS and custom parameter field labels are bounded and editable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('de'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(useMaterial3: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: const ModelConfigPage(
              entryId: 'missing-entry',
              configIndex: -1,
              modelIndex: -1,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final localizations = AppLocalizations.of(
        tester.element(find.byType(ModelConfigPage)),
      )!;
      final scrollable = find.byType(Scrollable).first;

      Future<void> expectBoundedLabel(String text) async {
        final label = find.byWidgetPredicate(
          (widget) => widget is ConstrainedText && widget.data == text,
        );
        await tester.scrollUntilVisible(label, 240, scrollable: scrollable);
        expect(label, findsOneWidget, reason: 'bounded field label: $text');
        await tester.pump(const Duration(milliseconds: 100));
      }

      for (final label in [
        localizations.ttsMinVolume,
        localizations.ttsMaxVolume,
        localizations.ttsMinSpeed,
        localizations.ttsMaxSpeed,
        localizations.ttsMaxAudioLength,
      ]) {
        await expectBoundedLabel(label);
      }

      final nativeField = find.byType(TextField).last;
      await tester.tap(nativeField);
      await tester.enterText(nativeField, '1000');
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: nativeField,
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(tester.widget<TextField>(nativeField).controller!.text, '1000');

      expect(tester.takeException(), isNull);
    },
  );
}
