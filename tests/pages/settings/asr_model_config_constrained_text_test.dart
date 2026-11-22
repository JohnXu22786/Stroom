import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/asr_model_config_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets(
    'ASR custom parameter labels stay bounded and fields remain editable',
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
              home: Scaffold(
                body: AsrModelConfigPage(
                  model: ModelConfig(
                    name: 'Test model',
                    modelId: 'test-model',
                    customParams: [
                      CustomParam(
                        paramName: '',
                        defaultValue: '',
                        type: 'json',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final l10n = AppLocalizations.of(
            tester.element(find.byType(AsrModelConfigPage)),
          )!;
          for (var i = 0; i < 5; i++) {
            await tester.drag(find.byType(ListView), const Offset(0, -500));
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is ConstrainedText &&
                  widget.data == l10n.assistantParameterName,
            ),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is ConstrainedText &&
                  widget.data == l10n.modelParamDefaultValue,
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          final fields = find.byType(TextFormField);
          expect(fields, findsNWidgets(2));
          if (locale == const Locale('de') && textScale == 1.0) {
            await tester.tap(fields.first);
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              tester
                  .widget<EditableText>(find.byType(EditableText).first)
                  .focusNode
                  .hasFocus,
              isTrue,
            );
            await tester.enterText(
              fields.first,
              'reasoning_effort_with_a_long_name',
            );
            await tester.enterText(fields.last, 'x');
            await tester.pump(const Duration(milliseconds: 100));
            expect(find.textContaining('第'), findsOneWidget);
            expect(find.byType(EditableText), findsNWidgets(2));

            await tester.tap(find.byType(DropdownButton<String>));
            await tester.pump(const Duration(milliseconds: 300));
            await tester.tap(find.text(l10n.paramTypeStringLabel).last);
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.byType(DropdownButton<String>), findsOneWidget);
            expect(find.textContaining('第'), findsNothing);
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
}
