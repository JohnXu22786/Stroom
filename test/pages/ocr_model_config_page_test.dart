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

/// Enters text into the [index]-th TextField of the page (0 = 模型名称,
/// 1 = 模型 ID, then max tokens / min pixels / max pixels).
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
        'renders user instruction field, 3 universal params; removed '
        'params absent', (tester) async {
      await _pumpConfigPage(tester);

      await _scrollTo(tester, find.text('用户指令 (可选)'));
      expect(find.text('用户指令 (可选)'), findsOneWidget);
      expect(
        find.text('可选填写。不填写时仅发送图片，使用默认识别行为；'
            '填写后随图片一起发送给模型，可指定提取内容、输出格式等。'),
        findsOneWidget,
      );

      await _scrollTo(tester, find.text('温度 (Temperature)'));
      expect(find.text('温度 (Temperature)'), findsOneWidget);
      await _scrollTo(tester, find.text('Top P'));
      expect(find.text('Top P'), findsOneWidget);
      await _scrollTo(tester, find.text('最大 Token 数'));
      expect(find.text('最大 Token 数'), findsOneWidget);

      // Params verified non-universal for OCR models are not built in.
      expect(find.text('图片细节级别 (Detail)'), findsNothing);
      expect(find.text('随机种子 (Seed)'), findsNothing);
      expect(find.text('输出格式 (Response Format)'), findsNothing);
      expect(find.text('最小像素 (min_pixels)'), findsNothing);
      expect(find.text('频率惩罚 (Frequency Penalty)'), findsNothing);
    });

    testWidgets('saving with user instruction writes it to typeConfig',
        (tester) async {
      ModelConfig? saved;
      await _pumpConfigPage(tester, onSaved: (m) => saved = m);

      // Model ID (index 1 = model ID, index 0 = model name)
      await _enterField(tester, 1, 'qwen-vl-ocr');

      await _enterFieldInCard(tester, '用户指令 (可选)', '提取发票号码和金额，以 JSON 输出');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.typeConfig['userInstruction'], '提取发票号码和金额，以 JSON 输出');
    });

    testWidgets('saving without instruction excludes userInstruction key',
        (tester) async {
      ModelConfig? saved;
      await _pumpConfigPage(tester, onSaved: (m) => saved = m);

      await _enterField(tester, 1, 'gpt-4o');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.typeConfig.containsKey('userInstruction'), isFalse);
    });

    testWidgets('whitespace-only instruction is not saved', (tester) async {
      ModelConfig? saved;
      await _pumpConfigPage(tester, onSaved: (m) => saved = m);

      await _enterField(tester, 1, 'gpt-4o');
      await _enterFieldInCard(tester, '用户指令 (可选)', '   \n\n  ');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.typeConfig.containsKey('userInstruction'), isFalse);
    });

    testWidgets('clearing a pre-filled instruction removes the key on save',
        (tester) async {
      ModelConfig? saved;
      final model = ModelConfig(
        name: 'OCR模型',
        modelId: 'qwen-vl-ocr',
        typeConfig: {'userInstruction': '旧指令'},
      );
      await _pumpConfigPage(tester, model: model, onSaved: (m) => saved = m);

      await _enterFieldInCard(tester, '用户指令 (可选)', '');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.typeConfig.containsKey('userInstruction'), isFalse);
    });

    testWidgets('editing an existing model pre-fills user instruction',
        (tester) async {
      final model = ModelConfig(
        name: 'OCR模型',
        modelId: 'qwen-vl-ocr',
        typeConfig: {
          'userInstruction': '提取表格内容并按行输出',
          'enableTemperature': true,
          'temperature': 0.5,
        },
      );
      await _pumpConfigPage(tester, model: model);

      await _scrollTo(tester, find.text('用户指令 (可选)'));
      expect(find.text('提取表格内容并按行输出'), findsOneWidget);
    });
  });
}
