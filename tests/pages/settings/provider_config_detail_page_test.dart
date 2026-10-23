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
  String? credentialRef,
  Map<String, dynamic> legacyFields = const {},
  Map<String, dynamic> configLegacyFields = const {},
}) {
  return ProviderEntry(
    id: 'test_entry_id',
    type: type,
    name: name,
    legacyFields: legacyFields,
    configs: [
      ProviderConfigItem(
        providerName: providerName,
        host: host,
        key: key,
        credentialRef: credentialRef,
        models: models,
        legacyFields: configLegacyFields,
      ),
    ],
  );
}

/// Fake notifier that immediately provides test data
class ProviderEntriesNotifierFake extends ProviderEntriesNotifier {
  bool lastUpdateRequiredPersistence = false;

  ProviderEntriesNotifierFake({
    String type = 'llm',
    String name = 'LLM供应商',
    List<ProviderEntry>? entries,
  }) {
    state = ProviderEntriesState(
      entries: entries ?? [_createTestEntry(type: type, name: name)],
    );
  }

  void removeEntryForTest(String id) {
    state = ProviderEntriesState(
      entries: state.entries.where((entry) => entry.id != id).toList(),
    );
  }

  void removeConfigForTest(String entryId, String configId) {
    state = ProviderEntriesState(
      entries: [
        for (final entry in state.entries)
          if (entry.id == entryId)
            ProviderEntry(
              id: entry.id,
              type: entry.type,
              name: entry.name,
              enabled: entry.enabled,
              legacyFields: entry.legacyFields,
              configs: entry.configs
                  .where((config) => config.id != configId)
                  .toList(),
            )
          else
            entry,
      ],
    );
  }

  @override
  Future<void> update(
    String id,
    ProviderEntry updated, {
    bool requirePersistence = false,
  }) async {
    lastUpdateRequiredPersistence = requirePersistence;
    state = ProviderEntriesState(
      entries: state.entries.map((e) => e.id == id ? updated : e).toList(),
    );
  }
}

class ProviderEntriesNotifierFailingSaveFake
    extends ProviderEntriesNotifierFake {
  ProviderEntriesNotifierFailingSaveFake({List<ProviderEntry>? entries})
    : super(entries: entries);

  @override
  Future<void> update(
    String id,
    ProviderEntry updated, {
    bool requirePersistence = false,
  }) async {
    throw StateError('Provider settings were removed before the save.');
  }
}

/// Extension to present the page for testing
extension on WidgetTester {
  Future<void> pumpDetailPage({
    int configIndex = 0,
    String entryType = 'llm',
    String entryName = 'LLM供应商',
    List<ModelConfig> models = const [],
    ProviderEntry? entry,
    bool failUpdate = false,
    String? credentialRef,
    Map<String, dynamic> legacyFields = const {},
    Map<String, dynamic> configLegacyFields = const {},
  }) {
    final entries = entry != null
        ? [entry]
        : models.isNotEmpty ||
              legacyFields.isNotEmpty ||
              configLegacyFields.isNotEmpty
        ? [
            _createTestEntry(
              type: entryType,
              name: entryName,
              models: models,
              credentialRef: credentialRef,
              legacyFields: legacyFields,
              configLegacyFields: configLegacyFields,
            ),
          ]
        : null;
    return pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => failUpdate
                ? ProviderEntriesNotifierFailingSaveFake(entries: entries)
                : ProviderEntriesNotifierFake(
                    type: entryType,
                    name: entryName,
                    entries: entries,
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

    testWidgets('keeps provider details unchanged when a required save fails', (
      tester,
    ) async {
      await tester.pumpDetailPage(failUpdate: true);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('编辑供应商设置'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Unsaved provider');
      await tester.enterText(
        find.byType(TextField).at(1),
        'https://unsaved.example.test',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('TestProvider'), findsWidgets);
      expect(find.text('Unsaved provider'), findsNothing);
      expect(find.textContaining('保存失败'), findsOneWidget);
    });

    testWidgets('preserves unknown provider fields when saving settings', (
      tester,
    ) async {
      await tester.pumpDetailPage(
        legacyFields: const {'futureProviderSetting': 'preserve-me'},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('编辑供应商设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProviderConfigDetailPage));
      final entries = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(providerEntriesProvider).entries;
      expect(
        entries.single.legacyFields['futureProviderSetting'],
        'preserve-me',
      );
    });

    testWidgets(
      'preserves config credential reference and metadata when saving settings',
      (tester) async {
        await tester.pumpDetailPage(
          credentialRef: 'credential/stable-reference',
          configLegacyFields: const {'futureConfigSetting': 'preserve-me'},
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('编辑供应商设置'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(ProviderConfigDetailPage));
        final savedConfig = ProviderScope.containerOf(
          context,
          listen: false,
        ).read(providerEntriesProvider).entries.single.configs.single;
        expect(savedConfig.credentialRef, 'credential/stable-reference');
        expect(savedConfig.legacyFields['futureConfigSetting'], 'preserve-me');
      },
    );

    testWidgets('preserves unknown provider fields when adding a model', (
      tester,
    ) async {
      await tester.pumpDetailPage(
        legacyFields: const {'futureProviderSetting': 'preserve-me'},
        configLegacyFields: const {'futureConfigSetting': 'config-preserve-me'},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'added-model-id');
      await tester.enterText(find.byType(TextField).at(2), '4096');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProviderConfigDetailPage));
      final entries = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(providerEntriesProvider).entries;
      final notifier =
          ProviderScope.containerOf(
                context,
                listen: false,
              ).read(providerEntriesProvider.notifier)
              as ProviderEntriesNotifierFake;
      expect(notifier.lastUpdateRequiredPersistence, isTrue);
      expect(
        entries.single.legacyFields['futureProviderSetting'],
        'preserve-me',
      );
      expect(
        entries.single.configs.single.legacyFields['futureConfigSetting'],
        'config-preserve-me',
      );
    });

    testWidgets('preserves unknown provider fields when editing a model', (
      tester,
    ) async {
      await tester.pumpDetailPage(
        models: [
          ModelConfig(
            name: 'Existing model',
            modelId: 'existing-model-id',
            typeConfig: const {'context': 4096},
          ),
        ],
        legacyFields: const {'futureProviderSetting': 'preserve-me'},
        configLegacyFields: const {'futureConfigSetting': 'config-preserve-me'},
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Existing model'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'edited-model-id');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProviderConfigDetailPage));
      final entries = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(providerEntriesProvider).entries;
      final notifier =
          ProviderScope.containerOf(
                context,
                listen: false,
              ).read(providerEntriesProvider.notifier)
              as ProviderEntriesNotifierFake;
      expect(notifier.lastUpdateRequiredPersistence, isTrue);
      expect(
        entries.single.legacyFields['futureProviderSetting'],
        'preserve-me',
      );
      expect(
        entries.single.configs.single.legacyFields['futureConfigSetting'],
        'config-preserve-me',
      );
    });

    testWidgets(
      'reports failure if the entry is removed while adding a model',
      (tester) async {
        await tester.pumpDetailPage();
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(ProviderConfigDetailPage));
        final notifier =
            ProviderScope.containerOf(
                  context,
                  listen: false,
                ).read(providerEntriesProvider.notifier)
                as ProviderEntriesNotifierFake;
        await tester.tap(find.text('添加'));
        await tester.pumpAndSettle();

        notifier.removeEntryForTest('test_entry_id');
        await tester.pump();

        await tester.enterText(find.byType(TextField).at(1), 'added-model-id');
        await tester.enterText(find.byType(TextField).at(2), '4096');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        expect(find.textContaining('保存失败'), findsOneWidget);
        expect(notifier.state.entries, isEmpty);
      },
    );

    testWidgets(
      'reports failure if the config is removed while editing a model',
      (tester) async {
        await tester.pumpDetailPage(
          models: [
            ModelConfig(
              name: 'Existing model',
              modelId: 'existing-model-id',
              typeConfig: const {'context': 4096},
            ),
          ],
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(ProviderConfigDetailPage));
        final notifier =
            ProviderScope.containerOf(
                  context,
                  listen: false,
                ).read(providerEntriesProvider.notifier)
                as ProviderEntriesNotifierFake;
        await tester.tap(find.text('Existing model'));
        await tester.pumpAndSettle();

        notifier.removeConfigForTest(
          'test_entry_id',
          notifier.state.entries.single.configs.single.id,
        );
        await tester.pump();
        await tester.enterText(find.byType(TextField).at(1), 'edited-model-id');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        expect(notifier.state.entries.single.configs, isEmpty);
        expect(find.textContaining('保存失败'), findsOneWidget);
      },
    );

    testWidgets(
      'reports failure if the entry is removed before model deletion',
      (tester) async {
        await tester.pumpDetailPage(
          models: [
            ModelConfig(name: 'Existing model', modelId: 'existing-model-id'),
          ],
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(ProviderConfigDetailPage));
        final notifier =
            ProviderScope.containerOf(
                  context,
                  listen: false,
                ).read(providerEntriesProvider.notifier)
                as ProviderEntriesNotifierFake;
        await tester.tap(find.byIcon(Icons.delete).first);
        await tester.pumpAndSettle();
        notifier.removeEntryForTest('test_entry_id');
        await tester.pump();
        await tester.tap(find.text('删除').last);
        await tester.pumpAndSettle();

        expect(find.textContaining('保存失败'), findsOneWidget);
        expect(notifier.state.entries, isEmpty);
      },
    );

    testWidgets(
      'does not save an edited model into another config after selected config removal',
      (tester) async {
        final selectedConfig = ProviderConfigItem(
          id: 'selected-config',
          providerName: 'SelectedProvider',
          host: 'https://selected.example.com',
          key: 'selected-key',
          models: [
            ModelConfig(
              name: 'Selected model',
              modelId: 'selected-model-id',
              typeConfig: const {'context': 4096},
            ),
          ],
        );
        final otherConfig = ProviderConfigItem(
          id: 'other-config',
          providerName: 'OtherProvider',
          host: 'https://other.example.com',
          key: 'other-key',
          models: [
            ModelConfig(
              name: 'Other model',
              modelId: 'other-model-id',
              typeConfig: const {'context': 4096},
            ),
          ],
        );
        await tester.pumpDetailPage(
          entry: ProviderEntry(
            id: 'test_entry_id',
            type: 'llm',
            name: 'LLM供应商',
            configs: [selectedConfig, otherConfig],
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(ProviderConfigDetailPage));
        final notifier =
            ProviderScope.containerOf(
                  context,
                  listen: false,
                ).read(providerEntriesProvider.notifier)
                as ProviderEntriesNotifierFake;
        await tester.tap(find.text('Selected model'));
        await tester.pumpAndSettle();

        notifier.removeConfigForTest('test_entry_id', 'selected-config');
        await tester.pump();
        await tester.enterText(find.byType(TextField).at(1), 'edited-model-id');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        final remainingConfig = notifier.state.entries.single.configs.single;
        expect(remainingConfig.id, 'other-config');
        expect(remainingConfig.models.single.modelId, 'other-model-id');
        expect(find.textContaining('保存失败'), findsOneWidget);
      },
    );

    testWidgets(
      'does not save an added model into another config after selected config removal',
      (tester) async {
        final selectedConfig = ProviderConfigItem(
          id: 'selected-config',
          providerName: 'SelectedProvider',
          host: 'https://selected.example.com',
          key: 'selected-key',
        );
        final otherConfig = ProviderConfigItem(
          id: 'other-config',
          providerName: 'OtherProvider',
          host: 'https://other.example.com',
          key: 'other-key',
          models: [
            ModelConfig(
              name: 'Other model',
              modelId: 'other-model-id',
              typeConfig: const {'context': 4096},
            ),
          ],
        );
        await tester.pumpDetailPage(
          entry: ProviderEntry(
            id: 'test_entry_id',
            type: 'llm',
            name: 'LLM供应商',
            configs: [selectedConfig, otherConfig],
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(ProviderConfigDetailPage));
        final notifier =
            ProviderScope.containerOf(
                  context,
                  listen: false,
                ).read(providerEntriesProvider.notifier)
                as ProviderEntriesNotifierFake;
        await tester.tap(find.text('添加'));
        await tester.pumpAndSettle();

        notifier.removeConfigForTest('test_entry_id', 'selected-config');
        await tester.pump();
        await tester.enterText(find.byType(TextField).at(1), 'added-model-id');
        await tester.enterText(find.byType(TextField).at(2), '4096');
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();

        final remainingConfig = notifier.state.entries.single.configs.single;
        expect(remainingConfig.id, 'other-config');
        expect(
          remainingConfig.models.map((model) => model.modelId),
          ['other-model-id'],
        );
        expect(find.textContaining('保存失败'), findsOneWidget);
      },
    );
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

    testWidgets('saving a new config stays on the model list page instead of '
        'popping back to the provider list', (tester) async {
      await tester.pumpDetailPage(configIndex: -1);
      await tester.pumpAndSettle();

      // Settings panel auto-opened with the provider fields
      expect(find.byType(TextField), findsNWidgets(3));

      // Fill in the required provider info
      await tester.enterText(find.byType(TextField).at(0), 'NewProvider');
      await tester.enterText(
        find.byType(TextField).at(1),
        'https://api.new.com',
      );
      await tester.enterText(find.byType(TextField).at(2), 'new-key');

      // Save the new provider
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // The detail page is NOT popped: still on the model list page of the
      // newly created provider (regression: used to pop back to the list).
      expect(find.byType(ProviderConfigDetailPage), findsOneWidget);
      // New provider name shown (AppBar title + provider card)
      expect(find.text('NewProvider'), findsWidgets);
      // Model list section visible
      expect(find.text('模型列表'), findsOneWidget);

      // The new config was persisted into the entry
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProviderConfigDetailPage)),
      );
      final state = container.read(providerEntriesProvider);
      expect(state.entries.single.configs.first.providerName, 'NewProvider');
      expect(state.entries.single.configs.first.host, 'https://api.new.com');
      expect(state.entries.single.configs.first.key, 'new-key');
    });

    testWidgets('models added after saving a new config are persisted into the '
        'newly created config (not dropped or routed to the old config)', (
      tester,
    ) async {
      // Create and save a new provider, exactly like the save test above
      await tester.pumpDetailPage(configIndex: -1);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(3));
      await tester.enterText(find.byType(TextField).at(0), 'NewProvider');
      await tester.enterText(
        find.byType(TextField).at(1),
        'https://api.new.com',
      );
      await tester.enterText(find.byType(TextField).at(2), 'new-key');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Page is now in existing-config mode for the new provider
      expect(find.text('NewProvider'), findsWidgets);

      // Add an LLM model right after the save
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      // LlmModelConfigPage basic fields: [0]=name (optional), [1]=model ID
      // (required), [2]=context length (required)
      await tester.enterText(find.byType(TextField).at(1), 'new-model-id');
      await tester.enterText(find.byType(TextField).at(2), '4096');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Back on the detail page; the model is visible (regression: the model
      // would be dropped into _pendingModels, which is no longer displayed
      // once the page flipped to existing-config mode).
      expect(find.byType(ProviderConfigDetailPage), findsOneWidget);
      expect(find.text('new-model-id'), findsWidgets);

      // The model is persisted into configs[0] = the new provider's config
      // (regression: any model CRUD still using widget.configIndex == -1
      // would throw a RangeError or write into the wrong config).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProviderConfigDetailPage)),
      );
      final state = container.read(providerEntriesProvider);
      final newConfig = state.entries.single.configs.first;
      expect(newConfig.providerName, 'NewProvider');
      expect(newConfig.models.single.modelId, 'new-model-id');

      // LLM entries become drag-sortable only after the mode switch
      expect(find.byType(ReorderableListView), findsOneWidget);
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
    testWidgets('llm model list is reorderable and follows the saved order', (
      tester,
    ) async {
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

    testWidgets('non-llm pages keep the plain non-reorderable model list', (
      tester,
    ) async {
      await tester.pumpDetailPage(
        entryType: 'tts',
        entryName: 'TTS供应商',
        models: [ModelConfig(name: 'voice-1', modelId: 'v1')],
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.text('voice-1'), findsOneWidget);
    });

    testWidgets('dragging a model updates the combined order, keeping other '
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

    testWidgets('delete after reorder removes the right stored model', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'model_order': ['model-2 | TestProvider', 'model-1 | TestProvider'],
      });
      await tester.pumpDetailPage(
        models: [
          ModelConfig(name: 'model-1', modelId: 'id-1'),
          ModelConfig(name: 'model-2', modelId: 'id-2'),
        ],
        legacyFields: const {'futureProviderSetting': 'preserve-me'},
        configLegacyFields: const {'futureConfigSetting': 'config-preserve-me'},
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

      final context = tester.element(find.byType(ProviderConfigDetailPage));
      final entries = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(providerEntriesProvider).entries;
      final notifier =
          ProviderScope.containerOf(
                context,
                listen: false,
              ).read(providerEntriesProvider.notifier)
              as ProviderEntriesNotifierFake;
      expect(notifier.lastUpdateRequiredPersistence, isTrue);
      expect(
        entries.single.legacyFields['futureProviderSetting'],
        'preserve-me',
      );
      expect(
        entries.single.configs.single.legacyFields['futureConfigSetting'],
        'config-preserve-me',
      );
    });
  });
}
