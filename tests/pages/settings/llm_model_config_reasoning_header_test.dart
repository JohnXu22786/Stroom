import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  testWidgets(
    'additional reasoning parameter headers reflow and keep fields operable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ModelConfig createModel() => ModelConfig(
            name: 'test-model',
            modelId: 'test-model',
            typeConfig: {'context': 4096},
            reasoningParams: [
              ReasoningParam(
                paramName: 'thinking',
                isReasoningToggle: true,
                onValue: 'enabled',
                offValue: 'disabled',
              ),
              ReasoningParam(
                paramName: 'reasoning_effort',
                isEffortParam: true,
                options: ['low', 'high'],
              ),
              ReasoningParam(paramName: 'budget_tokens', options: ['4096']),
              ReasoningParam(paramName: 'sampling_budget', options: ['2048']),
            ],
          );

      ProviderConfigItem createProvider() => ProviderConfigItem(
            providerName: 'Test Provider',
            reasoningParams: [
              ReasoningParam(paramName: 'provider_budget', options: ['2048']),
            ],
          );

      Future<void> pumpAt(Locale locale, double scale) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: LlmModelConfigPage(
              model: createModel(),
              provider: createProvider(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      tester.view.physicalSize = const Size(600, 640);
      await pumpAt(const Locale('fr', 'FR'), 1.0);
      final wideNameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField && widget.initialValue == 'budget_tokens',
      );
      await tester.scrollUntilVisible(
        wideNameField,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      final wideCard =
          find.ancestor(of: wideNameField, matching: find.byType(Card));
      final wideNameRect = tester.getRect(wideNameField);
      final wideTypeRect = tester.getRect(
        find.descendant(
          of: wideCard,
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(
        wideTypeRect.center.dy,
        closeTo(wideNameRect.center.dy, 20),
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(320, 640);

      for (final (locale, scale) in [
        (const Locale('fr', 'FR'), 1.0),
        (const Locale('de'), 1.8),
      ]) {
        await pumpAt(locale, scale);
        final nameField = find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField && widget.initialValue == 'budget_tokens',
        );
        await tester.scrollUntilVisible(
          nameField,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        expect(nameField, findsOneWidget);
        final card = find.ancestor(of: nameField, matching: find.byType(Card));
        final nameRect = tester.getRect(nameField);
        final typeRect = tester.getRect(
          find.descendant(
              of: card, matching: find.byType(DropdownButton<String>)),
        );
        expect(nameRect.left, greaterThanOrEqualTo(0));
        expect(nameRect.right, lessThanOrEqualTo(320));
        expect(typeRect.top, greaterThan(nameRect.bottom));

        if (locale.languageCode == 'fr') {
          await tester.tap(nameField);
          await tester.enterText(nameField, 'edited_budget');
          await tester.pump();
          final editedField = find.byWidgetPredicate(
            (widget) =>
                widget is TextFormField &&
                widget.initialValue == 'edited_budget',
          );
          expect(
            tester
                .widget<EditableText>(
                  find.descendant(
                    of: editedField,
                    matching: find.byType(EditableText),
                  ),
                )
                .focusNode
                .hasFocus,
            isTrue,
          );

          tester.testTextInput.hide();
          await tester.pump();
          final editedCard =
              find.ancestor(of: editedField, matching: find.byType(Card));
          final resetButton = find.descendant(
            of: editedCard,
            matching: find.byIcon(Icons.refresh),
          );
          await tester.ensureVisible(resetButton);
          await tester.pump();
          await tester.tap(resetButton);
          await tester.pump();
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is TextFormField &&
                  widget.initialValue == 'budget_tokens',
            ),
            findsOneWidget,
          );

          final secondField = find.byWidgetPredicate(
            (widget) =>
                widget is TextFormField &&
                widget.initialValue == 'sampling_budget',
          );
          final firstField = find.byWidgetPredicate(
            (widget) =>
                widget is TextFormField &&
                widget.initialValue == 'budget_tokens',
          );
          final secondCard =
              find.ancestor(of: secondField, matching: find.byType(Card));
          final pageScrollable =
              tester.state<ScrollableState>(find.byType(Scrollable).first);
          pageScrollable.position.jumpTo(
            (pageScrollable.position.pixels - 50)
                .clamp(0.0, pageScrollable.position.maxScrollExtent),
          );
          await tester.pump();
          final dragHandle = find.descendant(
            of: secondCard,
            matching: find.byIcon(Icons.drag_handle),
          );
          final dragStart = tester.getCenter(dragHandle);
          final firstCenter = tester.getCenter(firstField);
          await tester.timedDragFrom(
            dragStart,
            Offset(0, firstCenter.dy - dragStart.dy - 20),
            const Duration(milliseconds: 600),
          );
          await tester.pump(const Duration(milliseconds: 600));
          expect(
            tester.getTopLeft(secondField).dy,
            lessThan(tester.getTopLeft(firstField).dy),
          );
        }

        final inheritedField = find.byWidgetPredicate(
          (widget) =>
              widget is TextFormField &&
              widget.initialValue == 'provider_budget',
        );
        await tester.scrollUntilVisible(
          inheritedField,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        final inheritedCard =
            find.ancestor(of: inheritedField, matching: find.byType(Card));
        expect(
          find.descendant(
            of: inheritedCard,
            matching: find.byTooltip(
              AppLocalizations.of(tester.element(inheritedField))!
                  .modelParamDelete,
            ),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
