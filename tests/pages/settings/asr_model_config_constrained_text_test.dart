import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/asr_model_config_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets(
      'ASR language and prompt reveal clips while name and model ID wrap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            hintStyle: WidgetStateTextStyle.resolveWith((states) {
              return TextStyle(
                color: states.contains(WidgetState.focused)
                    ? Colors.red
                    : Colors.blue,
              );
            }),
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Scaffold(
          body: AsrModelConfigPage(
            model: ModelConfig(
              name: '',
              modelId: '',
              typeConfig: const {},
              customParams: [],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(AsrModelConfigPage)),
    )!;
    Future<void> verifyHintClip(Finder fieldFinder, String expectedHint) async {
      final field = tester.widget<TextField>(fieldFinder);
      final hint = (field.decoration!.hint! as ExcludeSemantics).child
          as ConstrainedInputHint;
      expect(hint.data, expectedHint);
      final textFinder = find.descendant(
        of: find.byWidget(hint),
        matching: find.byType(ConstrainedText),
      );
      final text = tester.widget<ConstrainedText>(textFinder);
      expect(text.style!.color, Colors.blue);
      await tester.tap(fieldFinder);
      await tester.pump();
      final editable = find.descendant(
        of: fieldFinder,
        matching: find.byType(EditableText),
      );
      expect(
        tester.getSemantics(editable).getSemanticsData().hint,
        expectedHint,
      );
      expect(
          tester.widget<ConstrainedText>(textFinder).style!.color, Colors.red);
      final textContext = tester.element(textFinder);
      final slotWidth = tester.getSize(textFinder).width;
      final naturalWidth = TextPainter(
        text: TextSpan(text: expectedHint, style: text.style),
        textDirection: Directionality.of(textContext),
        textScaler: MediaQuery.textScalerOf(textContext),
        locale: Localizations.localeOf(textContext),
      )..layout();
      expect(naturalWidth.width, greaterThan(slotWidth), reason: expectedHint);
      debugPrint(
        'ASR clipped hint=$expectedHint slotWidth=$slotWidth '
        'intrinsicWidth=${naturalWidth.width} maxLines=${hint.maxLines}',
      );
      await tester.enterText(fieldFinder, 'Native ASR value');
      await tester.pump();
      expect(
          tester.getSemantics(editable).getSemanticsData().hint, expectedHint);
      expect(
        tester.widget<EditableText>(editable).controller.text,
        'Native ASR value',
      );
    }

    void measureNativeHint(String hint) {
      final nativeFieldFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == hint,
      );
      expect(nativeFieldFinder, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(hint));
      final field = tester.widget<TextField>(nativeFieldFinder);
      final hintContext = tester.element(find.text(hint));
      final naturalWidth = TextPainter(
        text: TextSpan(
          text: hint,
          style: Theme.of(hintContext).textTheme.bodyLarge,
        ),
        textDirection: Directionality.of(hintContext),
        textScaler: MediaQuery.textScalerOf(hintContext),
        locale: Localizations.localeOf(hintContext),
      )..layout();
      final slot = tester.getSize(find.text(hint));
      final wrappedNatural = TextPainter(
        text: TextSpan(
          text: hint,
          style: Theme.of(hintContext).textTheme.bodyLarge,
        ),
        textDirection: Directionality.of(hintContext),
        textScaler: MediaQuery.textScalerOf(hintContext),
        locale: Localizations.localeOf(hintContext),
      )..layout(maxWidth: slot.width);
      debugPrint(
          'ASR native hint=$hint field=${tester.getSize(nativeFieldFinder)} '
          'slot=$slot intrinsic=${naturalWidth.width} '
          'wrappedHeight=${wrappedNatural.height} '
          'exceeded=${paragraph.didExceedMaxLines} maxLines=${field.maxLines}');
      expect(paragraph.didExceedMaxLines, isFalse, reason: hint);
      expect(wrappedNatural.height, lessThanOrEqualTo(slot.height),
          reason: hint);
    }

    measureNativeHint(l10n.modelNameHint);
    measureNativeHint(l10n.asrModelIdExample);
    await tester.scrollUntilVisible(
      find.text(l10n.modelAsrLanguageCode),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    final languageFieldFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hint is ExcludeSemantics &&
          ((widget.decoration!.hint! as ExcludeSemantics).child
                      as ConstrainedInputHint)
                  .data ==
              l10n.asrLanguageExample,
    );
    expect(languageFieldFinder, findsOneWidget);
    await verifyHintClip(languageFieldFinder, l10n.asrLanguageExample);

    await tester.scrollUntilVisible(
      find.text(l10n.asrPromptLabel),
      250,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.ensureVisible(find.byType(Switch).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).last);
    await tester.pump(const Duration(milliseconds: 100));
    final promptFieldFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hint is ExcludeSemantics &&
          ((widget.decoration!.hint! as ExcludeSemantics).child
                      as ConstrainedInputHint)
                  .data ==
              l10n.modelAsrPromptHint,
    );
    await tester.ensureVisible(promptFieldFinder);
    await tester.pump(const Duration(milliseconds: 100));
    expect(promptFieldFinder, findsOneWidget);
    await verifyHintClip(promptFieldFinder, l10n.modelAsrPromptHint);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

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
          if (locale == const Locale('de') && textScale == 1.8) {
            final customField = tester
                .widgetList<TextField>(find.byType(TextField))
                .lastWhere((field) => field.decoration?.hintText != null);
            final customHint = customField.decoration!.hintText!;
            final customText = find.text(customHint);
            final paragraph = tester.renderObject<RenderParagraph>(customText);
            final hintSlot = tester.getSize(customText);
            debugPrint('ASR custom parameter hint=$customHint '
                'slot=$hintSlot maxLines=${customField.maxLines} '
                'exceeded=${paragraph.didExceedMaxLines}');
            expect(customField.maxLines, 8);
            expect(paragraph.didExceedMaxLines, isFalse);
          }
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
