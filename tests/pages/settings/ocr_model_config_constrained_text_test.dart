import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/ocr_model_config_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets(
    'OCR configuration labels stay bounded while controls remain native',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final model = ModelConfig(
        name: 'OCR model',
        modelId: 'test-model',
        customParams: [
          CustomParam(
            paramName: 'reasoning_effort',
            type: 'json',
            defaultValue: '{"mode":"fast"}',
            options: ['fast', 'deep'],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(body: OcrModelConfigPage(model: model)),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(OcrModelConfigPage));
      final l10n = AppLocalizations.of(context)!;

      final budgetField = find.byKey(
        const Key('ocr_model_request_size_budget_mib'),
      );
      await tester.scrollUntilVisible(
        budgetField,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedText &&
              widget.data == l10n.ocrRequestSizeOverride,
        ),
        findsOneWidget,
      );
      final budgetInput = tester.widget<TextField>(budgetField);
      expect(
        budgetInput.keyboardType,
        const TextInputType.numberWithOptions(decimal: true),
      );
      expect(budgetInput.decoration!.suffixText, 'MiB');
      expect(budgetInput.decoration!.border, isA<OutlineInputBorder>());
      expect(budgetInput.controller!.text, isEmpty);
      await tester.tap(budgetField);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: budgetField,
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(budgetField, '0');
      final saveButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(TextButton),
      );
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(l10n.ocrJsonSizePositive), findsOneWidget);
      expect(tester.widget<TextField>(budgetField).controller!.text, '0');
      await tester.enterText(budgetField, '1.5');

      for (var i = 0; i < 6; i++) {
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
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: fields.first,
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'reasoning_effort',
      );
      await tester.ensureVisible(fields.first);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(fields.first);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: fields.first,
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(fields.first, '');
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: fields.first,
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        isEmpty,
      );
      await tester.enterText(fields.first, 'reasoning_effort_long_name');
      await tester.enterText(fields.last, '{invalid');
      await tester.pump();
      expect(
        tester
            .widget<InputDecorator>(
              find.descendant(
                of: fields.last,
                matching: find.byType(InputDecorator),
              ),
            )
            .decoration
            .errorText,
        isNotEmpty,
      );
      expect(find.byType(EditableText), findsNWidgets(3));

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(l10n.paramTypeStringLabel).last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(
        tester
            .widget<InputDecorator>(
              find.descendant(
                of: fields.last,
                matching: find.byType(InputDecorator),
              ),
            )
            .decoration
            .errorText,
        isNull,
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: fields.last,
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'fast',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
