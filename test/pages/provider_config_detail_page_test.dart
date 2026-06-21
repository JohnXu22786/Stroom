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
    testWidgets('shows read-only display with provider name and host', (
      tester,
    ) async {
      await tester.pumpDetailPage();

      // Wait for post frame callback to finish
      await tester.pumpAndSettle();

      // Read-only display: provider name as text (in display + AppBar title)
      expect(find.text('TestProvider'), findsNWidgets(2));
      expect(find.text('https://api.test.com'), findsOneWidget);

      // No editable fields
      expect(find.byType(TextField), findsNothing);

      // Edit button visible
      expect(find.text('编辑'), findsOneWidget);

      // Model list section visible
      expect(find.text('模型列表'), findsOneWidget);
    });

    testWidgets(
      'click edit shows editable fields, save, discard, hides model list',
      (tester) async {
        await tester.pumpDetailPage();
        await tester.pumpAndSettle();

        // Enter edit mode
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();

        // Editable fields appear
        expect(find.byType(TextField), findsNWidgets(3));

        // Save and discard buttons
        expect(find.text('保存'), findsOneWidget);
        expect(find.text('放弃'), findsOneWidget);

        // Model list hidden
        expect(find.text('模型列表'), findsNothing);
      },
    );

    testWidgets('discard reverts values and returns to display mode', (
      tester,
    ) async {
      await tester.pumpDetailPage();
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Modify provider name field (first TextField)
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Modified Name');
      await tester.pumpAndSettle();

      // Click discard
      await tester.tap(find.text('放弃'));
      await tester.pumpAndSettle();

      // Value reverted (appears in AppBar title + read-only display)
      expect(find.text('TestProvider'), findsNWidgets(2));
      expect(find.text('Modified Name'), findsNothing);

      // Back to display mode
      expect(find.text('编辑'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('save with empty fields shows validation snackbar', (
      tester,
    ) async {
      await tester.pumpDetailPage();
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Clear provider name field
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, '');
      await tester.pumpAndSettle();

      // Click save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Validation snackbar
      expect(find.text('供应商名称、API 地址 和 Key 均为必填项'), findsOneWidget);
    });
  });

  group('New config creation', () {
    testWidgets('starts in edit mode with editable fields', (tester) async {
      await tester.pumpDetailPage(configIndex: -1);
      await tester.pumpAndSettle();

      // Editable fields
      expect(find.byType(TextField), findsNWidgets(3));

      // Save button visible
      expect(find.text('保存'), findsOneWidget);

      // Model list hidden in edit mode
      expect(find.text('模型列表'), findsNothing);
    });

    testWidgets('discard navigates back for new config', (tester) async {
      await tester.pumpDetailPage(configIndex: -1);
      await tester.pumpAndSettle();

      // Verify we're on the page
      expect(find.byType(TextField), findsNWidgets(3));

      // Click discard
      await tester.tap(find.text('放弃'));
      await tester.pumpAndSettle();

      // Should navigate back - page should no longer be present
      expect(find.byType(ProviderConfigDetailPage), findsNothing);
    });
  });

  group('Save existing config', () {
    testWidgets('save exits edit mode and returns to display mode', (
      tester,
    ) async {
      await tester.pumpDetailPage();
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Modify provider name
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Updated Provider');
      await tester.pumpAndSettle();

      // Click save
      await tester.tap(find.text('保存'));
      // Pump to process async update + exitEditMode setState
      await tester.pump();
      await tester.pump();

      // Back to display mode
      expect(find.byType(TextField), findsNothing);
      expect(find.text('编辑'), findsOneWidget);

      // Updated name shown in display (AppBar title + read-only field)
      expect(find.text('Updated Provider'), findsNWidgets(2));
    });
  });

  group('Unsaved changes dialog', () {
    Future<void> pumpWithBackButton(
      WidgetTester tester, {
      int configIndex = 0,
    }) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifierFake(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProviderConfigDetailPage(
                            entryId: 'test_entry_id',
                            configIndex: configIndex,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('PopScope shows dialog on back with unsaved changes', (
      tester,
    ) async {
      await pumpWithBackButton(tester);
      await tester.pumpAndSettle();

      // Navigate to detail page
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Modify a field
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Changed');
      await tester.pumpAndSettle();

      // Tap back button in AppBar
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Dialog should be visible
      expect(find.text('未保存的更改'), findsOneWidget);
      expect(find.text('有未保存的更改，确定要放弃吗？'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      // "放弃" appears both in AppBar discard button and dialog button
      expect(find.text('放弃'), findsNWidgets(2));
    });

    testWidgets('cancel in unsaved dialog returns to edit mode', (
      tester,
    ) async {
      await pumpWithBackButton(tester);
      await tester.pumpAndSettle();

      // Navigate to detail page
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Changed');
      await tester.pumpAndSettle();

      // Tap back button
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Cancel the dialog
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Still on page in edit mode
      expect(find.text('保存'), findsOneWidget);
      expect(find.text('放弃'), findsOneWidget);
    });

    testWidgets('confirm discard in dialog navigates back', (tester) async {
      await pumpWithBackButton(tester);
      await tester.pumpAndSettle();

      // Navigate to detail page
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter edit mode and change something
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Changed');
      await tester.pumpAndSettle();

      // Tap back button
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Confirm discard (last '放弃' text is in the dialog)
      await tester.tap(find.text('放弃').last);
      await tester.pumpAndSettle();

      // Should navigate back to the home page
      expect(find.text('Open'), findsOneWidget);
    });
  });

  group('API host input field hint text by type', () {
    /// Helper to get the host TextField widget via its key
    TextField _hostField(WidgetTester tester) {
      return tester.widget<TextField>(find.byKey(const ValueKey('host_field')));
    }

    testWidgets('LLM type shows hintText and type-specific helperText', (
      tester,
    ) async {
      await tester.pumpDetailPage(entryType: 'llm', configIndex: -1);
      await tester.pumpAndSettle();

      final hostTextField = _hostField(tester);
      final decoration = hostTextField.decoration;

      // hintText should be a short generic prompt (disappears on typing)
      expect(decoration!.hintText, contains('输入完整的'));

      // helperText should contain instruction + type-specific example
      expect(decoration.helperText, contains('请填写完整的 API 端点地址'));
      expect(decoration.helperText, contains('chat/completions'));
      expect(decoration.helperMaxLines, equals(3));
    });

    testWidgets('TTS type shows type-specific helperText with audio/speech', (
      tester,
    ) async {
      await tester.pumpDetailPage(entryType: 'tts', configIndex: -1);
      await tester.pumpAndSettle();

      final decoration = _hostField(tester).decoration;
      expect(decoration!.helperText, contains('请填写完整的 API 端点地址'));
      expect(decoration.helperText, contains('audio/speech'));
    });

    testWidgets(
      'ASR type shows type-specific helperText with audio/transcriptions',
      (tester) async {
        await tester.pumpDetailPage(entryType: 'asr', configIndex: -1);
        await tester.pumpAndSettle();

        final decoration = _hostField(tester).decoration;
        expect(decoration!.helperText, contains('请填写完整的 API 端点地址'));
        expect(decoration.helperText, contains('audio/transcriptions'));
      },
    );

    testWidgets(
      'OCR type shows type-specific helperText with chat/completions',
      (tester) async {
        await tester.pumpDetailPage(entryType: 'ocr', configIndex: -1);
        await tester.pumpAndSettle();

        final decoration = _hostField(tester).decoration;
        expect(decoration!.helperText, contains('请填写完整的 API 端点地址'));
        expect(decoration.helperText, contains('chat/completions'));
      },
    );

    testWidgets('MCP type shows type-specific helperText with URL example', (
      tester,
    ) async {
      await tester.pumpDetailPage(entryType: 'mcp', configIndex: -1);
      await tester.pumpAndSettle();

      final decoration = _hostField(tester).decoration;
      expect(decoration!.helperText, contains('请填写完整的 API 端点地址'));
      expect(decoration.helperText, contains('localhost'));
    });

    testWidgets('host input field does NOT auto-fill with any value', (
      tester,
    ) async {
      await tester.pumpDetailPage(entryType: 'llm', configIndex: -1);
      await tester.pumpAndSettle();

      final hostTextField = _hostField(tester);
      // The host field should be empty on new config
      expect(hostTextField.controller?.text, isEmpty);
    });

    testWidgets('helperText is null when no type definition available', (
      tester,
    ) async {
      // Use an unregistered type to test null helperText
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            providerEntriesProvider.overrideWith(
              (ref) => ProviderEntriesNotifierFake(
                type: 'unknown_type',
                name: '未知供应商',
              ),
            ),
          ],
          child: const MaterialApp(
            home: ProviderConfigDetailPage(
              entryId: 'test_entry_id',
              configIndex: -1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final decoration = _hostField(tester).decoration;
      // helperText should be null (no layout gap) for unregistered types
      expect(decoration!.helperText, isNull);
    });
  });

  group('Model config page routing by type', () {
    testWidgets('LLM type renders LlmModelConfigPage when adding model', (
      tester,
    ) async {
      await tester.pumpDetailPage(entryType: 'llm', entryName: 'LLM供应商');
      await tester.pumpAndSettle();

      // Enter edit mode
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Save/exit edit mode
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Now in display mode - see 添加 button
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

      // Enter edit mode and save to transition to display mode
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
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

      // Enter edit mode and save to transition to display mode
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Now in display mode - tap 添加
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

      // Enter edit mode and save
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Now in display mode - tap 添加
      await tester.tap(find.text('添加'));
      await tester.pumpAndSettle();

      // Should navigate to ModelConfigPage
      expect(find.byType(ModelConfigPage), findsOneWidget);
      expect(find.byType(SimpleModelConfigPage), findsNothing);
      expect(find.byType(LlmModelConfigPage), findsNothing);
    });
  });
}
