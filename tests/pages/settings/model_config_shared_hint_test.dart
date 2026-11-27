import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/pages/ocr_model_config_page.dart';
import 'package:stroom/pages/simple_model_config_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('measures sibling model-name hint routes', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    final cases = <(String, Widget)>[
      ('LLM', const LlmModelConfigPage()),
      ('OCR', const OcrModelConfigPage()),
      ('simple model', const SimpleModelConfigPage()),
    ];
    for (final (name, page) in cases) {
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
          home: page,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      )!;
      final hint = l10n.modelNameHint;
      final field = find.byWidgetPredicate((widget) {
        if (widget is! TextField) return false;
        if (widget.decoration?.hintText == hint) return true;
        final customHint = widget.decoration?.hint;
        return customHint is ExcludeSemantics &&
            (customHint.child as ConstrainedInputHint).data == hint;
      });
      expect(field, findsOneWidget, reason: name);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(hint));
      final fieldWidget = tester.widget<TextField>(field);
      final hintContext = tester.element(find.text(hint));
      final slot = name == 'simple model'
          ? tester.getSize(find.byType(ConstrainedInputHint))
          : tester.getSize(find.text(hint));
      final natural = TextPainter(
        text: TextSpan(
          text: hint,
          style: Theme.of(hintContext).textTheme.bodyLarge,
        ),
        textDirection: Directionality.of(hintContext),
        textScaler: MediaQuery.textScalerOf(hintContext),
        locale: Localizations.localeOf(hintContext),
      )..layout();
      debugPrint(
        '$name model-name hint=$hint slot=$slot '
        'intrinsic=${natural.width} maxLines=${fieldWidget.maxLines} '
        'exceeded=${paragraph.didExceedMaxLines}',
      );
      expect(
        name == 'simple model'
            ? natural.width > slot.width
            : paragraph.didExceedMaxLines,
        name == 'simple model',
        reason: name,
      );
      if (name == 'simple model') {
        final editable = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        expect(tester.getSemantics(editable).getSemanticsData().hint, hint);
        final visualHint = find.byWidgetPredicate(
          (widget) => widget is ConstrainedText && widget.data == hint,
        );
        expect(tester.widget<ConstrainedText>(visualHint).style!.color,
            Colors.blue);
        await tester.tap(field);
        await tester.pump();
        expect(tester.widget<ConstrainedText>(visualHint).style!.color,
            Colors.red);
        await tester.enterText(field, 'Edited model');
        await tester.pump();
        expect(tester.getSemantics(editable).getSemanticsData().hint, hint);
        expect(
          tester.widget<EditableText>(editable).controller.text,
          'Edited model',
        );
      }
    }
    semantics.dispose();
  });
}
