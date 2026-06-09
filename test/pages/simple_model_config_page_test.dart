import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/simple_model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

Widget _buildTestApp({ModelConfig? initialModel}) {
  return MaterialApp(
    home: SimpleModelConfigPage(model: initialModel),
  );
}

/// Helper to enter text and settle
Future<void> enterTextAndSettle(WidgetTester tester, Finder finder, String text) async {
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

void main() {
  group('SimpleModelConfigPage - Create new model', () {
    testWidgets('shows title "添加模型" for new model', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('添加模型'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('validates model ID is required', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Click save with empty model ID
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('模型 ID 为必填项'), findsOneWidget);
    });

    testWidgets('validates custom params require both name and default value',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Fill in model ID first
      await enterTextAndSettle(
        tester,
        find.widgetWithText(TextField, '如 gpt-4o'),
        'test-model',
      );

      // Add a custom param
      await tester.tap(find.text('添加参数'));
      await tester.pumpAndSettle();

      // Click save with empty param name and value
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('自定义参数的参数名和默认值不能为空'), findsOneWidget);
    });

    testWidgets('saves and returns ModelConfig with correct data',
        (tester) async {
      ModelConfig? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.push<ModelConfig>(
                context,
                MaterialPageRoute(
                  builder: (_) => const SimpleModelConfigPage(),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Navigate to the page
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Fill in model ID
      await enterTextAndSettle(
        tester,
        find.widgetWithText(TextField, '如 gpt-4o'),
        'gpt-4o',
      );

      // Fill in model name
      await enterTextAndSettle(
        tester,
        find.widgetWithText(TextField, '输入显示名称（可选）'),
        'GPT-4o Vision',
      );

      // Save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Verify result
      expect(result, isNotNull);
      expect(result!.modelId, equals('gpt-4o'));
      expect(result!.name, equals('GPT-4o Vision'));
    });

    testWidgets('auto-fills name from modelId when name is empty',
        (tester) async {
      ModelConfig? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.push<ModelConfig>(
                context,
                MaterialPageRoute(
                  builder: (_) => const SimpleModelConfigPage(),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Navigate to the page
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Fill in model ID only
      await enterTextAndSettle(
        tester,
        find.widgetWithText(TextField, '如 gpt-4o'),
        'whisper-1',
      );

      // Save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Verify result - name should be auto-filled from modelId
      expect(result, isNotNull);
      expect(result!.modelId, equals('whisper-1'));
      expect(result!.name, equals('whisper-1'));
    });

    testWidgets('supports custom params with types', (tester) async {
      ModelConfig? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.push<ModelConfig>(
                context,
                MaterialPageRoute(
                  builder: (_) => const SimpleModelConfigPage(),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Navigate
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Fill model ID
      await enterTextAndSettle(
        tester,
        find.widgetWithText(TextField, '如 gpt-4o'),
        'custom-model',
      );

      // Add a custom param
      await tester.tap(find.text('添加参数'));
      await tester.pumpAndSettle();

      // Fill param name and value
      final paramNameFields = find.widgetWithText(TextFormField, '参数名');
      await tester.enterText(paramNameFields, 'temperature');
      await tester.pumpAndSettle();

      final paramValueFields = find.widgetWithText(TextFormField, '默认参数值');
      await tester.enterText(paramValueFields, '0.7');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.customParams.length, equals(1));
      expect(result!.customParams[0].paramName, equals('temperature'));
      expect(result!.customParams[0].defaultValue, equals('0.7'));
    });
  });

  group('SimpleModelConfigPage - Edit existing model', () {
    testWidgets('loads existing model data', (tester) async {
      final existing = ModelConfig(
        name: 'My Whisper',
        modelId: 'whisper-1',
        customParams: [
          CustomParam(paramName: 'language', defaultValue: 'zh'),
        ],
      );

      await tester.pumpWidget(_buildTestApp(initialModel: existing));
      await tester.pumpAndSettle();

      // Should show edit title (appears in AppBar title + text field value)
      expect(find.text('My Whisper'), findsNWidgets(2));

      // Fields should be populated
      final nameField = tester.widget<TextField>(
        find.widgetWithText(TextField, '输入显示名称（可选）'),
      );
      expect(nameField.controller?.text, equals('My Whisper'));

      final modelIdField = tester.widget<TextField>(
        find.widgetWithText(TextField, '如 gpt-4o'),
      );
      expect(modelIdField.controller?.text, equals('whisper-1'));

      // Custom param should be loaded
      expect(find.text('language'), findsOneWidget);
    });

    testWidgets('editing model and saving returns updated data',
        (tester) async {
      ModelConfig? result;
      final existing = ModelConfig(
        name: 'Old Name',
        modelId: 'old-model',
      );

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.push<ModelConfig>(
                context,
                MaterialPageRoute(
                  builder: (_) => SimpleModelConfigPage(model: existing),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Navigate
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Clear name first so auto-fill from modelId works
      await enterTextAndSettle(
        tester,
        find.widgetWithText(TextField, '输入显示名称（可选）'),
        '',
      );

      // Modify model ID
      await enterTextAndSettle(
        tester,
        find.widgetWithText(TextField, '如 gpt-4o'),
        'new-model-id',
      );

      // Save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.modelId, equals('new-model-id'));
      // Name was cleared, so it should be auto-filled from modelId
      expect(result!.name, equals('new-model-id'));
    });
  });
}
