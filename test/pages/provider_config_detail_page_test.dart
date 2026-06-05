import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/provider_config_detail_page.dart';
import 'package:stroom/providers/provider_config.dart';

/// Helper to create a test ProviderEntry with one config
ProviderEntry _createTestEntry({
  String providerName = 'TestProvider',
  String host = 'https://api.test.com',
  String key = 'test-key-123',
  List<ModelConfig> models = const [],
}) {
  return ProviderEntry(
    id: 'test_entry_id',
    type: 'llm',
    name: 'LLM供应商',
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
  ProviderEntriesNotifierFake() {
    state = ProviderEntriesState(
      entries: [
        _createTestEntry(),
      ],
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
  Future<void> pumpDetailPage({int configIndex = 0}) {
    return pumpWidget(
      ProviderScope(
        overrides: [
          providerEntriesProvider.overrideWith(
            (ref) => ProviderEntriesNotifierFake(),
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
    testWidgets('shows read-only display with provider name and host',
        (tester) async {
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

    testWidgets('click edit shows editable fields, save, discard, hides model list',
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
    });

    testWidgets('discard reverts values and returns to display mode',
        (tester) async {
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

    testWidgets('save with empty fields shows validation snackbar',
        (tester) async {
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
    testWidgets('starts in edit mode with editable fields',
        (tester) async {
      await tester.pumpDetailPage(configIndex: -1);
      await tester.pumpAndSettle();

      // Editable fields
      expect(find.byType(TextField), findsNWidgets(3));

      // Save button visible
      expect(find.text('保存'), findsOneWidget);

      // Model list hidden in edit mode
      expect(find.text('模型列表'), findsNothing);
    });

    testWidgets('discard navigates back for new config',
        (tester) async {
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
    testWidgets('save exits edit mode and returns to display mode',
        (tester) async {
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
    Future<void> pumpWithBackButton(WidgetTester tester, {int configIndex = 0}) {
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

    testWidgets('PopScope shows dialog on back with unsaved changes',
        (tester) async {
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

    testWidgets('cancel in unsaved dialog returns to edit mode',
        (tester) async {
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

    testWidgets('confirm discard in dialog navigates back',
        (tester) async {
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
}
