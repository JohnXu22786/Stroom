import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/ocr_model_config_page.dart';

/// Pumps a host screen with a button that pushes [OcrModelConfigPage] and
/// delivers the popped [ModelConfig] result via [onSaved] (mirrors the real
/// navigation flow used by provider_config_detail_page.dart). The host is
/// pumped in "config open" state, i.e. the config page is shown.
Future<void> _pumpConfigPage(
  WidgetTester tester, {
  ModelConfig? model,
  void Function(ModelConfig?)? onSaved,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push<ModelConfig>(
                context,
                MaterialPageRoute(
                  builder: (_) => OcrModelConfigPage(model: model),
                ),
              );
              onSaved?.call(result);
            },
            child: const Text('打开配置'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开配置'));
  await tester.pumpAndSettle();
}

/// Scrolls the config page until [finder] is visible.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Finds the Switch that belongs to the parameter card whose label is
/// [label] (cards are built from LlmToggleSlider / LlmToggleTextField /
/// custom dropdown cards, each containing exactly one Switch).
Finder _switchFor(String label) {
  final card =
      find.ancestor(of: find.text(label), matching: find.byType(Card)).first;
  return find.descendant(of: card, matching: find.byType(Switch));
}

/// Toggles the switch of the param card labeled [label] to [on].
Future<void> _toggleParam(
  WidgetTester tester,
  String label, {
  required bool on,
}) async {
  await _scrollTo(tester, find.text(label));
  final sw = tester.widget<Switch>(_switchFor(label));
  if (sw.value != on) {
    await tester.tap(_switchFor(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Selects the dropdown option [optionText] inside the card labeled [label].
Future<void> _selectDropdownOption(
  WidgetTester tester,
  String label,
  String optionText,
) async {
  await _scrollTo(tester, find.text(label));
  final card =
      find.ancestor(of: find.text(label), matching: find.byType(Card)).first;
  await tester.tap(
    find.descendant(of: card, matching: find.byType(DropdownButton<String>)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
}

/// Enters text into the [index]-th TextField of the page (0 = 模型名称,
/// 1 = 模型 ID, then max tokens / seed / min pixels / max pixels).
Future<void> _enterField(WidgetTester tester, int index, String text) async {
  await tester.enterText(find.byType(TextField).at(index), text);
  await tester.pump();
}

/// Enters text into the TextField inside the card labeled [label].
/// (TextField indices shift as toggles reveal/hide fields, so anchor on the
/// card label instead.)
Future<void> _enterFieldInCard(
  WidgetTester tester,
  String label,
  String text,
) async {
  await _scrollTo(tester, find.text(label));
  final card =
      find.ancestor(of: find.text(label), matching: find.byType(Card)).first;
  await tester.enterText(
    find.descendant(of: card, matching: find.byType(TextField)),
    text,
  );
  await tester.pump();
}

void main() {
  group('OcrModelConfigPage built-in OpenAI-compatible params', () {
    testWidgets(
        'renders OCR-specific param sections (detail, response format, '
        'min/max pixels); LLM sampling params absent', (tester) async {
      await _pumpConfigPage(tester);

      await _scrollTo(tester, find.text('图片细节级别 (Detail)'));
      expect(find.text('图片细节级别 (Detail)'), findsOneWidget);
      await _scrollTo(tester, find.text('输出格式 (Response Format)'));
      expect(find.text('输出格式 (Response Format)'), findsOneWidget);
      await _scrollTo(tester, find.text('最小像素 (min_pixels)'));
      expect(find.text('最小像素 (min_pixels)'), findsOneWidget);
      await _scrollTo(tester, find.text('最大像素 (max_pixels)'));
      expect(find.text('最大像素 (max_pixels)'), findsOneWidget);
      // LLM sampling params (frequency/presence penalty, stop) are not
      // built into the OCR page — the built-in set is OCR-specific.
      expect(find.text('频率惩罚 (Frequency Penalty)'), findsNothing);
      expect(find.text('停止序列 (Stop)'), findsNothing);
    });

    testWidgets('saving with toggles on writes new keys to typeConfig',
        (tester) async {
      ModelConfig? saved;
      await _pumpConfigPage(tester, onSaved: (m) => saved = m);

      // Model ID (index 1 = model ID, index 0 = model name)
      await _enterField(tester, 1, 'qwen-vl-ocr');

      await _toggleParam(tester, '输出格式 (Response Format)', on: true);
      await _selectDropdownOption(
          tester, '输出格式 (Response Format)', 'json_object - 结构化 JSON');
      await _toggleParam(tester, '最小像素 (min_pixels)', on: true);
      await _enterFieldInCard(tester, '最小像素 (min_pixels)', '3072');
      await _toggleParam(tester, '最大像素 (max_pixels)', on: true);
      await _enterFieldInCard(tester, '最大像素 (max_pixels)', '8388608');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      final tc = saved!.typeConfig;
      expect(tc['enableResponseFormat'], isTrue);
      expect(tc['responseFormat'], 'json_object');
      expect(tc['enableMinPixels'], isTrue);
      expect(tc['minPixels'], 3072);
      expect(tc['enableMaxPixels'], isTrue);
      expect(tc['maxPixels'], 8388608);
    });

    testWidgets('saving with toggles off excludes new param values',
        (tester) async {
      ModelConfig? saved;
      await _pumpConfigPage(tester, onSaved: (m) => saved = m);

      await _enterField(tester, 1, 'gpt-4o');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      final tc = saved!.typeConfig;
      expect(tc['enableResponseFormat'], isFalse);
      expect(tc['enableMinPixels'], isFalse);
      expect(tc['enableMaxPixels'], isFalse);
      expect(tc.containsKey('responseFormat'), isFalse);
      expect(tc.containsKey('minPixels'), isFalse);
      expect(tc.containsKey('maxPixels'), isFalse);
    });

    testWidgets('min/max pixels enabled but empty is rejected on save',
        (tester) async {
      await _pumpConfigPage(tester);

      await _enterField(tester, 1, 'gpt-4o');
      await _toggleParam(tester, '最小像素 (min_pixels)', on: true);
      await _toggleParam(tester, '最大像素 (max_pixels)', on: true);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('最小像素已启用但未填写'), findsOneWidget);
      expect(find.byType(OcrModelConfigPage), findsOneWidget);
    });

    testWidgets('min/max pixels must be positive integers', (tester) async {
      await _pumpConfigPage(tester);

      await _enterField(tester, 1, 'gpt-4o');
      await _toggleParam(tester, '最小像素 (min_pixels)', on: true);
      await _enterFieldInCard(tester, '最小像素 (min_pixels)', '-1');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('最小像素必须为正整数'), findsOneWidget);
      expect(find.byType(OcrModelConfigPage), findsOneWidget);
    });

    testWidgets('min_pixels greater than max_pixels is rejected on save',
        (tester) async {
      await _pumpConfigPage(tester);

      await _enterField(tester, 1, 'gpt-4o');
      await _toggleParam(tester, '最小像素 (min_pixels)', on: true);
      await _enterFieldInCard(tester, '最小像素 (min_pixels)', '9999999');
      await _toggleParam(tester, '最大像素 (max_pixels)', on: true);
      await _enterFieldInCard(tester, '最大像素 (max_pixels)', '3072');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('最小像素不能大于最大像素'), findsOneWidget);
      expect(find.byType(OcrModelConfigPage), findsOneWidget);
    });

    testWidgets('detail dropdown offers original level and saves it',
        (tester) async {
      ModelConfig? saved;
      await _pumpConfigPage(tester, onSaved: (m) => saved = m);

      await _enterField(tester, 1, 'gpt-5.4');
      await _toggleParam(tester, '图片细节级别 (Detail)', on: true);
      await _selectDropdownOption(
          tester, '图片细节级别 (Detail)', 'original - 原图 (不缩放)');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.typeConfig['detail'], 'original');
    });

    testWidgets('editing an existing model pre-fills new params',
        (tester) async {
      final model = ModelConfig(
        name: 'OCR模型',
        modelId: 'qwen-vl-ocr',
        typeConfig: {
          'enableResponseFormat': true,
          'responseFormat': 'json_object',
          'enableMinPixels': true,
          'minPixels': 3072,
          'enableMaxPixels': true,
          'maxPixels': 8388608,
        },
      );
      await _pumpConfigPage(tester, model: model);

      // Scroll top → bottom only (scrollUntilVisible cannot scroll up).
      await _scrollTo(tester, find.text('输出格式 (Response Format)'));
      expect(find.text('json_object - 结构化 JSON'), findsOneWidget);

      await _scrollTo(tester, find.text('最小像素 (min_pixels)'));
      expect(find.text('3072'), findsOneWidget);
      expect(find.text('8388608'), findsOneWidget);
    });
  });
}
