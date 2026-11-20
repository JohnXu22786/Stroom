import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  for (final textScale in [1.0, 1.8]) {
    testWidgets(
      'reasoning field labels fit 320x640 at ${textScale}x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final model = ModelConfig(
          name: 'test-model',
          modelId: 'test-model',
          typeConfig: {'context': 4096},
          reasoningParams: [
            ReasoningParam(
              paramName: 'thinking.type',
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
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('fr', 'FR'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: LlmModelConfigPage(model: model),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final l10n = AppLocalizations.of(
          tester.element(find.byType(Scaffold)),
        )!;
        final toggleHeading = find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedText && widget.data == l10n.reasoningToggle,
        );
        await tester.scrollUntilVisible(
          toggleHeading,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.getSize(toggleHeading).height, lessThan(40));

        final onLabel = find.text(l10n.reasoningOnValue);
        await tester.scrollUntilVisible(
          onLabel,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();

        expect(find.text(l10n.reasoningOffValue), findsOneWidget);
        expect(find.byType(ConstrainedText), findsWidgets);
        expect(tester.takeException(), isNull);
        final onField = find.ancestor(
          of: onLabel,
          matching: find.byType(TextFormField),
        );
        await tester.tap(onField);
        await tester.enterText(onField, 'active');
        await tester.pump();
        expect(find.text('active'), findsOneWidget);
        expect(tester.testTextInput.isVisible, isTrue);

        tester.testTextInput.hide();
        await tester.pump();
        final toggleEnabledSwitch = find.byType(Switch).first;
        await tester.scrollUntilVisible(
          toggleEnabledSwitch,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.tap(toggleEnabledSwitch);
        await tester.pump();
        expect(find.text('active'), findsOneWidget);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
