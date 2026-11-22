import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('reveals a clipped French endpoint field label', (tester) async {
    final strings = await _showEndpointSelector(
      tester,
      locale: const Locale('fr', 'FR'),
      textScale: 1.8,
    );
    final label = _endpointLabel(strings);
    final labelWidget = tester.widget<ConstrainedText>(label);
    final text = find.descendant(of: label, matching: find.byType(Text));
    final clip = find.descendant(of: label, matching: find.byType(ClipRect));

    expect(labelWidget.data, strings.providerEndpointTypeLabel);
    expect(clip, findsOneWidget);

    final textContext = tester.element(text);
    final renderedText = tester.widget<Text>(text);
    final naturalText = TextPainter(
      text: TextSpan(text: labelWidget.data, style: renderedText.style),
      textDirection: Directionality.of(textContext),
      locale: Localizations.localeOf(textContext),
      textScaler: MediaQuery.textScalerOf(textContext),
      maxLines: 1,
    )..layout();
    expect(
      naturalText.width,
      greaterThan(tester.getSize(clip).width + 1),
      reason: 'the localized field label must exceed its actual clip slot',
    );

    final startX = tester.getTopLeft(text).dx;
    var moved = false;
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if ((tester.getTopLeft(text).dx - startX).abs() > 1) {
        moved = true;
        break;
      }
    }
    expect(moved, isTrue, reason: 'the clipped field label should reveal');

    final dropdown = find.byType(DropdownButtonFormField<String>);
    final dropdownButton = find.descendant(
      of: dropdown,
      matching: find.byType(DropdownButton<String>),
    );
    await tester.tap(dropdown);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(strings.llmEndpointAnthropic), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<DropdownButton<String>>(dropdownButton).value,
      'openai.chat_completions',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a fitting English endpoint field label stationary', (
    tester,
  ) async {
    final strings = await _showEndpointSelector(
      tester,
      locale: const Locale('en'),
      textScale: 1,
    );
    final label = _endpointLabel(strings);
    final labelWidget = tester.widget<ConstrainedText>(label);
    final text = find.descendant(of: label, matching: find.byType(Text));
    final clip = find.descendant(of: label, matching: find.byType(ClipRect));

    expect(labelWidget.data, strings.providerEndpointTypeLabel);
    expect(clip, findsNothing);

    final textContext = tester.element(text);
    final renderedText = tester.widget<Text>(text);
    final naturalText = TextPainter(
      text: TextSpan(text: labelWidget.data, style: renderedText.style),
      textDirection: Directionality.of(textContext),
      locale: Localizations.localeOf(textContext),
      textScaler: MediaQuery.textScalerOf(textContext),
      maxLines: 1,
    )..layout();
    expect(naturalText.width, lessThanOrEqualTo(tester.getSize(label).width));

    final start = tester.getTopLeft(text);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(text), start);

    final dropdown = find.byType(DropdownButtonFormField<String>);
    final dropdownButton = find.descendant(
      of: dropdown,
      matching: find.byType(DropdownButton<String>),
    );
    expect(
      tester.widget<DropdownButton<String>>(dropdownButton).value,
      'openai.chat_completions',
    );
    expect(
      tester.widget<DropdownButton<String>>(dropdownButton).items,
      hasLength(3),
    );
    await tester.tap(dropdown);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(strings.llmEndpointAnthropic), findsOneWidget);
    expect(find.text(strings.endpointResponsesApi), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<DropdownButton<String>>(dropdownButton).value,
      'openai.chat_completions',
    );
    expect(tester.takeException(), isNull);
  });
}

Future<AppLocalizations> _showEndpointSelector(
  WidgetTester tester, {
  required Locale locale,
  required double textScale,
}) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: LlmModelConfigPage(
        model: ModelConfig(
          name: 'Capture model',
          modelId: 'capture-model',
          typeConfig: const {'context': 4096},
          endpointType: 'openai',
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  final strings = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
  final listView = find.byType(ListView);
  final endpointToggle = find.byType(SwitchListTile);
  for (var i = 0; i < 16 && endpointToggle.evaluate().isEmpty; i++) {
    await tester.drag(listView, const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(endpointToggle, findsOneWidget);
  final dropdown = find.byType(DropdownButtonFormField<String>);
  await tester.ensureVisible(dropdown);
  await tester.pump(const Duration(milliseconds: 300));
  return strings;
}

Finder _endpointLabel(AppLocalizations strings) => find.byWidgetPredicate(
  (widget) =>
      widget is ConstrainedText &&
      widget.data == strings.providerEndpointTypeLabel,
  description: 'localized endpoint field label',
);
