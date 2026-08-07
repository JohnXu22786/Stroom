import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/pages/provider_config_detail_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/pages/asr_model_config_page.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/pages/ocr_model_config_page.dart';
import 'package:stroom/pages/simple_model_config_page.dart';
import 'package:stroom/pages/model_config_page.dart';

/// Helper to create a test ProviderEntry with one config
ProviderEntry _createTestEntry({
  String providerName = 'TestProvider',
  String host = 'https://api.test.com',
  String key = 'test-key-123',
  List<ModelConfig> models = const [],
  String type = 'llm',
  String name = 'LLM供应商',
}) {
  return ProviderEntry(
    id: 'test_entry_id',
    type: type,
    name: name,
    configs: [
      ProviderConfigItem(
        providerName: providerName,
        host: host,
        key: key,
        models: models,
      ),
    ],
  );
}

/// Fake notifier that immediately provides test data
class ProviderEntriesNotifierFake extends ProviderEntriesNotifier {
  ProviderEntriesNotifierFake({
    String type = 'llm',
    String name = 'LLM供应商',
    List<ProviderEntry>? entries,
  }) {
    state = ProviderEntriesState(
      entries: entries ?? [_createTestEntry(type: type, name: name)],
    );
  }

  @override
  Future<void> update(String id, ProviderEntry updated) async {
    state = ProviderEntriesState(
      entries: state.entries.map((e) => e.id == id ? updated : e).toList(),
    );
  }
}

/// Extension to present the page for testing
extension on WidgetTester {
  Future<void> pumpDetailPage({
    int configIndex = 0,
    String entryType = 'llm',
    String entryName = 'LLM供应商',
    List<ModelConfig> models = const [],
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifierFake(
              type: entryType,
              name: entryName,
              entries: models.isNotEmpty
                  ? [
                      _createTestEntry(
                        type: entryType,
                        name: entryName,
                        models: models,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
        child: MaterialApp(
          home: ProviderConfigDetailPage(
            entryId: 'test_entry_id',
            configIndex: configIndex,
          ),
        ),
      ),
    );
  }
}

/// 返回当前页面上模型 ListTile 的标题文本列表（按显示顺序）。
List<String> modelTileTitles(WidgetTester tester) {
  return tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((t) => (t.title as Text?)?.data ?? '')
      .where((s) => s.isNotEmpty)
      .toList();
}

void main() {
  setUpAll(() {
    registerBuiltinProviderTypes();
  });

  group('Display mode (existing config)', () {
    testWidgets('shows provider card and model list, no edit button', (
      tester,
    ) async {
      await tester.pumpDetailPage();
      await tester.pumpAndSettle();

      // Provider name shown in card (and AppBar title)
      expect(find.text('TestProvider'), findsNWidgets(2));
      // Host shown
      expect(find.text('https://api.test.com'), findsOneWidget);

      // No edit button (removed by redesign)
      expect(find.text('编辑'), findsNothing);

      // Model list section visible
      expect(find.text('模型列表'), findsOneWidget);
    });

    testWidgets('model list section is visible in default display', (
      tester,
    ) async {
      await tester.pumpDetailPage();
      await tester.pumpAndSettle();

      // Model section header visible
      expect(find.text('模型列表'), findsOneWidget);
      // Add model button visible
      expect(find.text('添加'), findsOneWidget);
    });
  });

  group('New config creation', () {
    testWidgets('opens settings panel auto for new config with 3 TextFields', (
      tester,
    ) async {
      await tester.pumpDetailPage(configIndex: -1);
      await tester.pumpAndSettle();

      // Settings panel opened with TextFields for provider name, host, key
      expect(find.byType(TextField), findsNWidgets(3));
    });
  });

  group('Model config page routing by type', () {
    testWidgets('LLM type renders LlmModelConfigPage when adding model', (
      tester,
    ) async {
      await tester.pumpDetailPage(entryType: 'llm', entryName: 'LLM供应商');
      await tester.pumpAndSettle();

      // Model section visible, tap 添加
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      // Should navigate to LlmModelConfigPage
      expect(find.byType(LlmModelConfigPage), findsOneWidget);
      // SimpleModelConfigPage should not be shown
      expect(find.byType(SimpleModelConfigPage), findsNothing);
    });

    testWidgets('OCR type renders OcrModelConfigPage when adding model', (
      tester,
    ) async {
      await tester.pumpDetailPage(entryType: 'ocr', entryName: 'OCR供应商');
      await tester.pumpAndSettle();

      // Now in display mode - tap 添加
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      // Should navigate to OcrModelConfigPage (not SimpleModelConfigPage)
      expect(find.byType(OcrModelConfigPage), findsOneWidget);
      expect(find.byType(SimpleModelConfigPage), findsNothing);
      expect(find.byType(LlmModelConfigPage), findsNothing);
    });

    testWidgets('ASR type renders AsrModelConfigPage when adding model', (
      tester,
    ) async {
      await tester.pumpDetailPage(entryType: 'asr', entryName: '音频转写供应商');
      await tester.pumpAndSettle();

      // Tap 添加
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      // Should navigate to AsrModelConfigPage (not SimpleModelConfigPage)
      expect(find.byType(AsrModelConfigPage), findsOneWidget);
      expect(find.byType(SimpleModelConfigPage), findsNothing);
      expect(find.byType(LlmModelConfigPage), findsNothing);
    });

    testWidgets('TTS type renders ModelConfigPage when adding model', (
      tester,
    ) async {
      await tester.pumpDetailPage(entryType: 'tts', entryName: 'TTS供应商');
      await tester.pumpAndSettle();

      // Tap 添加
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      // Should navigate to ModelConfigPage
      expect(find.byType(ModelConfigPage), findsOneWidget);
      expect(find.byType(SimpleModelConfigPage), findsNothing);
      expect(find.byType(LlmModelConfigPage), findsNothing);
    });
  });

  group('LLM model drag-sort sync with chat order', () {
    testWidgets('llm model list is reorderable and follows the saved order',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'model_order': ['model-2 | TestProvider', 'model-1 | TestProvider'],
      });
      await tester.pumpDetailPage(
        models: [
          ModelConfig(name: 'model-1', modelId: 'id-1'),
          ModelConfig(name: 'model-2', modelId: 'id-2'),
        ],
      );
      await tester.pumpAndSettle();

      // LLM 页面使用可拖动列表
      expect(find.byType(ReorderableListView), findsOneWidget);
      // 显示顺序 = 全局顺序过滤掉其它供应商后的结果
      expect(modelTileTitles(tester), ['model-2', 'model-1']);
    });

    testWidgets('non-llm pages keep the plain non-reorderable model list',
        (tester) async {
      await tester.pumpDetailPage(
        entryType: 'tts',
        entryName: 'TTS供应商',
        models: [ModelConfig(name: 'voice-1', modelId: 'v1')],
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.text('voice-1'), findsOneWidget);
    });

    testWidgets(
        'dragging a model updates the combined order, keeping other '
        'providers in place', (tester) async {
      SharedPreferences.setMockInitialValues({
        'model_order': [
          'A1 | ProviderA',
          'B1 | ProviderB',
          'A2 | ProviderA',
          'B2 | ProviderB',
        ],
      });
      final entry = ProviderEntry(
        id: 'test_entry_id',
        type: 'llm',
        name: 'LLM供应商',
        configs: [
          ProviderConfigItem(
            providerName: 'ProviderA',
            host: 'https://api.a.com',
            key: 'k',
            models: [
              ModelConfig(name: 'A1', modelId: 'a1'),
              ModelConfig(name: 'A2', modelId: 'a2'),
            ],
          ),
          ProviderConfigItem(
            providerName: 'ProviderB',
            host: 'https://api.b.com',
            key: 'k',
            models: [
              ModelConfig(name: 'B1', modelId: 'b1'),
              ModelConfig(name: 'B2', modelId: 'b2'),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifierFake(entries: [entry]),
            ),
          ],
          child: MaterialApp(
            home: const ProviderConfigDetailPage(
              entryId: 'test_entry_id',
              configIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 显示顺序来自全局顺序：本配置的 A1 在 A2 前面
      expect(modelTileTitles(tester), ['A1', 'A2']);

      // 把 A1 拖到 A2 之后（onReorderItem 的 newIndex 已是移除后的索引：
      // 真实拖拽中框架会传 (0, 1)）
      final listView = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      listView.onReorderItem?.call(0, 1);
      await tester.pumpAndSettle();

      // 页面显示顺序随之更新
      expect(modelTileTitles(tester), ['A2', 'A1']);

      // 全局顺序：本供应商的子序列被替换，其它供应商保持原位
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('model_order'), [
        'A2 | ProviderA',
        'B1 | ProviderB',
        'A1 | ProviderA',
        'B2 | ProviderB',
      ]);
    });

    testWidgets('delete after reorder removes the right stored model',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'model_order': ['model-2 | TestProvider', 'model-1 | TestProvider'],
      });
      await tester.pumpDetailPage(
        models: [
          ModelConfig(name: 'model-1', modelId: 'id-1'),
          ModelConfig(name: 'model-2', modelId: 'id-2'),
        ],
      );
      await tester.pumpAndSettle();

      // 显示顺序是 [model-2, model-1]，存储顺序是 [model-1, model-2]
      expect(modelTileTitles(tester), ['model-2', 'model-1']);

      // 删除"显示在第一行"的 model-2 —— 必须删除存储中的 model-2
      // （存储索引 1），而不是按显示索引 0 误删 model-1。
      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 若映射错误（删掉 model-1），剩余显示会是 model-2
      expect(modelTileTitles(tester), ['model-1']);
    });
  });
}
