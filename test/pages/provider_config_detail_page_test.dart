import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/provider_config_detail_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
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
  ProviderEntriesNotifierFake({String type = 'llm', String name = 'LLM供应商'}) {
    state = ProviderEntriesState(
      entries: [_createTestEntry(type: type, name: name)],
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
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) =>
                ProviderEntriesNotifierFake(type: entryType, name: entryName),
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

    testWidgets('OCR type renders SimpleModelConfigPage when adding model', (
      tester,
    ) async {
      await tester.pumpDetailPage(entryType: 'ocr', entryName: 'OCR供应商');
      await tester.pumpAndSettle();

      // Now in display mode - tap 添加
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      // Should navigate to SimpleModelConfigPage
      expect(find.byType(SimpleModelConfigPage), findsOneWidget);
      // LlmModelConfigPage should not be shown
      expect(find.byType(LlmModelConfigPage), findsNothing);
    });

    testWidgets('ASR type renders SimpleModelConfigPage when adding model', (
      tester,
    ) async {
      await tester.pumpDetailPage(entryType: 'asr', entryName: '音频转写供应商');
      await tester.pumpAndSettle();

      // Tap 添加
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      // Should navigate to SimpleModelConfigPage
      expect(find.byType(SimpleModelConfigPage), findsOneWidget);
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
}
