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

/// Finds the [i]-th instruction name field (labels are always rendered,
/// even with a value, so indexing is stable).
Finder _instructionNameField(int i) =>
    find.widgetWithText(TextField, '指令名称（可选）').at(i);

/// Finds the [i]-th instruction content field.
Finder _instructionContentField(int i) =>
    find.widgetWithText(TextField, '指令内容').at(i);

/// Adds a new instruction entry via the 添加指令 button.
Future<void> _addInstruction(WidgetTester tester) async {
  await _scrollTo(tester, find.text('添加指令'));
  await tester.tap(find.text('添加指令'));
  await tester.pumpAndSettle();
}

/// Fills the [i]-th instruction entry (name and content).
Future<void> _fillInstruction(
  WidgetTester tester,
  int i, {
  String? name,
  String content = '',
}) async {
  if (name != null) {
    await tester.enterText(_instructionNameField(i), name);
    await tester.pump();
  }
  if (content.isNotEmpty) {
    await tester.enterText(_instructionContentField(i), content);
    await tester.pump();
  }
}

void main() {
  group('OcrModelConfigPage built-in OpenAI-compatible params', () {
    testWidgets(
        'renders instruction section, add button and 3 universal params; '
        'removed params absent', (tester) async {
      await _pumpConfigPage(tester);

      await _scrollTo(tester, find.text('用户指令'));
      expect(find.text('用户指令'), findsOneWidget);
      expect(find.text('添加指令'), findsOneWidget);
      expect(
        find.text('可选。不添加时仅发送图片，可添加多条指令，'
            '在文字识别页的模型选择下方选择使用哪条。'),
        findsOneWidget,
      );
      expect(find.text('暂无指令'), findsOneWidget);

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

    testWidgets('adding multiple instructions saves them to typeConfig',
        (tester) async {
      ModelConfig? saved;
      await _pumpConfigPage(tester, onSaved: (m) => saved = m);

      // Model ID (index 1 = model ID, index 0 = model name)
      await _enterField(tester, 1, 'qwen-vl-ocr');

      await _addInstruction(tester);
      await _fillInstruction(tester, 0,
          name: '发票', content: '提取发票号码和金额，以 JSON 输出');
      await _addInstruction(tester);
      await _fillInstruction(tester, 1, content: '提取表格内容并按行输出');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.typeConfig['userInstructions'], [
        {'name': '发票', 'content': '提取发票号码和金额，以 JSON 输出'},
        {'name': '', 'content': '提取表格内容并按行输出'},
      ]);
    });

    testWidgets('instruction entries with blank content are not saved',
        (tester) async {
      ModelConfig? saved;
      await _pumpConfigPage(tester, onSaved: (m) => saved = m);

      await _enterField(tester, 1, 'qwen-vl-ocr');

      await _addInstruction(tester);
      await _fillInstruction(tester, 0, content: '提取发票号码');
      await _addInstruction(tester);
      // Second entry left blank.
      await _fillInstruction(tester, 1, name: '空指令', content: '   \n\n  ');

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.typeConfig['userInstructions'], [
        {'name': '', 'content': '提取发票号码'},
      ]);
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

    testWidgets('editing an existing model pre-fills instructions',
        (tester) async {
      final model = ModelConfig(
        name: 'OCR模型',
        modelId: 'qwen-vl-ocr',
        typeConfig: {
          'userInstructions': [
            {'name': '发票', 'content': '提取发票号码和金额'},
            {'name': '', 'content': '提取表格内容'},
          ],
        },
      );
      await _pumpConfigPage(tester, model: model);

      await _scrollTo(tester, find.text('用户指令'));
      expect(find.text('提取发票号码和金额'), findsOneWidget);
      expect(find.text('提取表格内容'), findsOneWidget);
    });

    testWidgets('legacy userInstruction string loads as one instruction',
        (tester) async {
      ModelConfig? saved;
      final model = ModelConfig(
        name: 'OCR模型',
        modelId: 'qwen-vl-ocr',
        typeConfig: {'userInstruction': '旧指令内容'},
      );
      await _pumpConfigPage(tester, model: model, onSaved: (m) => saved = m);

      await _scrollTo(tester, find.text('用户指令'));
      expect(find.text('旧指令内容'), findsOneWidget);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.typeConfig['userInstructions'], [
        {'name': '', 'content': '旧指令内容'},
      ]);
    });

    testWidgets('name-only instruction counts as an unsaved change',
        (tester) async {
      await _pumpConfigPage(tester);

      await _addInstruction(tester);
      await _fillInstruction(tester, 0, name: '只有名称');

      // Back navigation must trigger the unsaved-changes dialog.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('放弃修改？'), findsOneWidget);
    });

    testWidgets('removing an instruction drops it on save', (tester) async {
      ModelConfig? saved;
      final model = ModelConfig(
        name: 'OCR模型',
        modelId: 'qwen-vl-ocr',
        typeConfig: {
          'userInstructions': [
            {'name': '第一条', 'content': '内容一'},
            {'name': '第二条', 'content': '内容二'},
          ],
        },
      );
      await _pumpConfigPage(tester, model: model, onSaved: (m) => saved = m);

      await _scrollTo(tester, find.text('用户指令'));
      // Delete the first instruction card.
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.typeConfig['userInstructions'], [
        {'name': '第二条', 'content': '内容二'},
      ]);
    });
  });
}
