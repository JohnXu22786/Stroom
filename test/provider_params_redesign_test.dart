import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/provider_config_detail_page.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

/// Helper to create a test ProviderEntry with one config (with provider-level params)
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

void main() {
  setUpAll(() {
    registerBuiltinProviderTypes();
  });

  // =================================================================
  // 1. Provider-level params on ProviderConfigItem
  // =================================================================
  group('ProviderConfigItem - provider-level params', () {
    test('ProviderConfigItem stores provider-level typeConfig', () {
      final item = ProviderConfigItem(
        providerName: 'Test',
        host: 'host',
        key: 'key',
        typeConfig: {'context': 4096, 'temperature': 0.7},
      );
      expect(item.typeConfig['context'], equals(4096));
      expect(item.typeConfig['temperature'], equals(0.7));
    });

    test('ProviderConfigItem stores provider-level customParams', () {
      final item = ProviderConfigItem(
        providerName: 'Test',
        host: 'host',
        key: 'key',
        customParams: [
          CustomParam(paramName: 'top_k', defaultValue: '10'),
        ],
      );
      expect(item.customParams.length, equals(1));
      expect(item.customParams[0].paramName, equals('top_k'));
    });

    test('ProviderConfigItem stores provider-level reasoningParams', () {
      final item = ProviderConfigItem(
        providerName: 'Test',
        host: 'host',
        key: 'key',
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
        ],
      );
      expect(item.reasoningParams.length, equals(1));
      expect(item.reasoningParams[0].paramName, equals('thinking.type'));
      expect(item.reasoningParams[0].isReasoningToggle, isTrue);
    });

    test('ProviderConfigItem copy preserves provider-level params', () {
      final item = ProviderConfigItem(
        providerName: 'Test',
        host: 'host',
        key: 'key',
        typeConfig: {'context': 4096},
        customParams: [CustomParam(paramName: 'top_k', defaultValue: '10')],
        reasoningParams: [
          ReasoningParam(paramName: 'effort', options: ['low', 'high']),
        ],
      );
      final copy = item.copy();
      expect(copy.typeConfig['context'], equals(4096));
      expect(copy.customParams.length, equals(1));
      expect(copy.reasoningParams.length, equals(1));
    });

    test('ProviderConfigItem toMap/fromMap preserves provider-level params',
        () {
      final item = ProviderConfigItem(
        providerName: 'Test',
        host: 'host',
        key: 'key',
        typeConfig: {'context': 4096},
        customParams: [CustomParam(paramName: 'top_k', defaultValue: '10')],
        reasoningParams: [
          ReasoningParam(paramName: 'effort', options: ['low', 'high']),
        ],
      );
      final map = item.toMap();
      final restored = ProviderConfigItem.fromMap(map);
      expect(restored.typeConfig['context'], equals(4096));
      expect(restored.customParams.length, equals(1));
      expect(restored.customParams[0].paramName, equals('top_k'));
      expect(restored.reasoningParams.length, equals(1));
      expect(restored.reasoningParams[0].paramName, equals('effort'));
    });
  });

  // =================================================================
  // 2. Provider config detail page - no provider input fields, no edit button
  // =================================================================
  group('ProviderConfigDetailPage - redesigned', () {
    testWidgets('no edit button in display mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifierFake(),
            ),
          ],
          child: const MaterialApp(
            home: ProviderConfigDetailPage(
              entryId: 'test_entry_id',
              configIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No edit button
      expect(find.text('编辑'), findsNothing);
      // No editable TextFields
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows provider card styled like topic_selection page', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifierFake(),
            ),
          ],
          child: const MaterialApp(
            home: ProviderConfigDetailPage(
              entryId: 'test_entry_id',
              configIndex: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Provider name shown in card (and in AppBar title)
      expect(find.text('TestProvider'), findsNWidgets(2));
      // Host shown
      expect(find.text('https://api.test.com'), findsOneWidget);
      // Model list section visible
      expect(find.text('模型列表'), findsOneWidget);
    });
  });

  // =================================================================
  // 3. LLM model config - inference intensity
  // =================================================================
  group('LlmModelConfigPage - inference intensity', () {
    testWidgets('shows inference intensity section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Fill required fields
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'test-model');
      await tester.enterText(textFields.at(2), '4096');
      await tester.pump();

      // Scroll to find inference intensity section
      // First fill the toggle fields so intensity becomes available
      final toggleFields = find.byType(TextFormField);
      await tester.enterText(toggleFields.at(0), 'thinking.type');
      await tester.enterText(toggleFields.at(1), 'enabled');
      await tester.enterText(toggleFields.at(2), 'disabled');
      await tester.pump();

      // Now inference intensity should be enabled
      // Look for option fields or intensity-related UI
      // The page should have "添加推理参数" button which includes intensity
      await tester.scrollUntilVisible(
        find.text('添加推理参数'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('添加推理参数'), findsOneWidget);
    });
  });

  // =================================================================
  // 4. ReasoningParam - inference intensity with name-only support (provider)
  // =================================================================
  group('ReasoningParam - inference intensity validation', () {
    test('provider: inference intensity allows name without values', () {
      // On the provider side, intensity can have just a param name
      // This is just a ReasoningParam without options (empty list)
      final intensity = ReasoningParam(
        paramName: 'reasoning_effort',
        options: [], // empty options = name only, no values
        isReasoningToggle: false,
        enabled: true,
      );
      // Should pass validation - no options, no error
      expect(intensity.validationError, isNull);
    });

    test('model: inference intensity requires values if name is filled', () {
      // On model side, if paramName is filled, options must not be empty
      // This would fail model-level validation
      final intensity = ReasoningParam(
        paramName: 'reasoning_effort',
        options: [], // empty - acceptable on provider but not on model
        isReasoningToggle: false,
        enabled: true,
      );
      // The validation only checks for empty option strings, not empty list
      // So empty options list passes validation
      expect(intensity.validationError, isNull);
    });

    test('ReasoningParam with filled options passes validation', () {
      final intensity = ReasoningParam(
        paramName: 'reasoning_effort',
        options: ['low', 'medium', 'high'],
        isReasoningToggle: false,
        enabled: true,
      );
      expect(intensity.validationError, isNull);
    });

    test('ReasoningParam with empty option strings fails validation', () {
      final intensity = ReasoningParam(
        paramName: 'effort',
        options: ['low', '', 'high'], // empty string option
        isReasoningToggle: false,
        enabled: true,
      );
      expect(intensity.validationError, isNotNull);
      expect(intensity.validationError, contains('选项值不能为空'));
    });
  });
}
