import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets(
    'custom parameter labels stay bounded while parameter fields remain editable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final locale in const [
        Locale('de'),
        Locale('pt', 'BR'),
        Locale('ar'),
      ]) {
        for (final textScale in const [1.0, 1.8]) {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: ThemeData(useMaterial3: true),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: LlmModelConfigPage(
                model: ModelConfig(
                  name: 'Test model',
                  modelId: 'test-model',
                  typeConfig: {'context': 4096},
                  customParams: [
                    CustomParam(
                      paramName: 'reasoning_effort',
                      defaultValue: '{"mode": "deep"}',
                      type: 'json',
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          final l10n = AppLocalizations.of(
            tester.element(find.byType(LlmModelConfigPage)),
          )!;
          final heading = find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedText &&
                widget.data == l10n.chatCustomParameters,
          );
          for (var i = 0; i < 16 && heading.evaluate().isEmpty; i++) {
            await tester.drag(find.byType(ListView), const Offset(0, -360));
            await tester.pump(const Duration(milliseconds: 100));
          }
          await tester.pump(const Duration(milliseconds: 100));
          expect(heading, findsOneWidget);

          final nameLabel = find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedText &&
                widget.data == l10n.assistantParameterName,
          );
          for (var i = 0; i < 8 && nameLabel.evaluate().isEmpty; i++) {
            await tester.drag(find.byType(ListView), const Offset(0, -180));
            await tester.pump(const Duration(milliseconds: 100));
          }

          for (final label in [
            l10n.assistantParameterName,
            l10n.modelParamDefaultValue,
          ]) {
            expect(
              find.byWidgetPredicate(
                (widget) => widget is ConstrainedText && widget.data == label,
              ),
              findsOneWidget,
              reason: 'bounded label should be rendered: $label',
            );
          }
          expect(tester.takeException(), isNull);

          if (locale == const Locale('de') && textScale == 1.0) {
            final nameField = find.byType(TextFormField).first;
            final jsonField = find.byType(TextFormField).last;
            await tester.tap(nameField);
            await tester.enterText(nameField, 'reasoning_effort');
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              tester
                  .widget<EditableText>(find.byType(EditableText).first)
                  .focusNode
                  .hasFocus,
              isTrue,
            );

            await tester.enterText(jsonField, 'not json');
            await tester.pump(const Duration(milliseconds: 100));
            final jsonInputDecorator = tester.widget<InputDecorator>(
              find.descendant(
                of: jsonField,
                matching: find.byType(InputDecorator),
              ),
            );
            expect(jsonInputDecorator.decoration.errorText, isNotNull);

            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );
}
