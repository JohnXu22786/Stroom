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

void main() {
  group('OcrModelConfigPage built-in OpenAI-compatible params', () {
    testWidgets(
        'renders 3 universal params; instruction section and '
        'removed params absent', (tester) async {
      await _pumpConfigPage(tester);

      // Instructions are generic now — configured on the OCR page, not
      // per model, so no instruction section here.
      expect(find.text('用户指令'), findsNothing);
      expect(find.text('添加指令'), findsNothing);

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

    testWidgets('saving without instructions excludes userInstructions key',
        (tester) async {
      ModelConfig? saved;
      await _pumpConfigPage(tester, onSaved: (m) => saved = m);

      await _enterField(tester, 1, 'gpt-4o');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.typeConfig.containsKey('userInstructions'), isFalse);
      expect(saved!.typeConfig.containsKey('userInstruction'), isFalse);
    });

    testWidgets(
        'saving an existing model preserves legacy instruction keys until '
        'the generic-store migration consumes them', (tester) async {
      ModelConfig? saved;
      final model = ModelConfig(
        name: 'OCR模型',
        modelId: 'qwen-vl-ocr',
        typeConfig: {
          'userInstructions': [
            {'name': '发票', 'content': '提取发票号码和金额'},
          ],
        },
      );
      await _pumpConfigPage(tester, model: model, onSaved: (m) => saved = m);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // The legacy keys survive the save — the OCR page migration may not
      // have run yet, and dropping them here would lose the instructions.
      expect(saved, isNotNull);
      expect(saved!.typeConfig['userInstructions'], [
        {'name': '发票', 'content': '提取发票号码和金额'},
      ]);
    });
  });
}
