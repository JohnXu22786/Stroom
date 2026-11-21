import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/simple_model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets(
    'simple model parameter labels use measured slots and fields stay editable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData(useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: false),
            child: child!,
          ),
          home: Scaffold(
            body: SimpleModelConfigPage(
              model: ModelConfig(
                name: 'Test model',
                modelId: 'test-model',
                customParams: [
                  CustomParam(
                    paramName: 'reasoning_effort',
                    defaultValue: 'high',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final strings = AppLocalizations.of(
        tester.element(find.byType(SimpleModelConfigPage)),
      )!;
      final fields = find.byType(TextFormField);
      await tester.scrollUntilVisible(
        fields.first,
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedText &&
              widget.data == strings.assistantParameterName,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedText &&
              widget.data == strings.modelParamDefaultValue,
        ),
        findsOneWidget,
      );
      expect(fields, findsNWidgets(2));
      expect(tester.takeException(), isNull);

      final parameterNameLabel = find.text(strings.assistantParameterName);
      final defaultValueLabel = find.text(strings.modelParamDefaultValue);
      final parameterNameStart = tester.getTopLeft(parameterNameLabel);
      final defaultValueStart = tester.getTopLeft(defaultValueLabel);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        parameterNameStart.dx - tester.getTopLeft(parameterNameLabel).dx,
        greaterThan(0),
        reason: 'The narrow parameter-name field clips this localized label.',
      );
      expect(
        defaultValueStart.dx - tester.getTopLeft(defaultValueLabel).dx,
        greaterThan(0),
        reason: 'The localized default-value label is clipped in this slot.',
      );

      await tester.ensureVisible(fields.first);
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
      await tester.enterText(fields.first, 'long_parameter_name');
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
        'long_parameter_name',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
