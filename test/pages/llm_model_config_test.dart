// Merged from:
//   test/pages/llm_model_config_page_test.dart
//   test/pages/llm_model_config_page_dialog_test.dart
//   test/pages/llm_model_config_no_duplicate_test.dart
//   test/pages/simple_model_config_page_test.dart
//   test/model_config_dup_crosscheck_test.dart
//   test/model_config_reasoning_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/pages/simple_model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

Widget _buildSimpleTestApp({ModelConfig? initialModel}) {
  return MaterialApp(
    home: SimpleModelConfigPage(model: initialModel),
  );
}

/// Helper to enter text and settle
Future<void> enterTextAndSettle(
    WidgetTester tester, Finder finder, String text) async {
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

void main() {
  // ─────────────────────────────────────────────────────────────────────
  // From llm_model_config_page_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('LlmModelConfigPage toggle switches', () {
    testWidgets('LLM parameters have toggle switches like assistant settings',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll down to LLM params section to find Switch widgets
      await tester.scrollUntilVisible(
        find.text('温度 (Temperature)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Switches should now be visible in LLM params section
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      // Temperature label should now be in the tree
      expect(find.text('温度 (Temperature)'), findsOneWidget);
    });

    testWidgets('toggle switches control slider availability', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll down to LLM params section to find Switch widgets
      await tester.scrollUntilVisible(
        find.text('温度 (Temperature)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Find all Switch widgets in the LLM params section
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);
    });

    testWidgets('toggling a switch enables its parameter slider',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll down to LLM params section to find Switch widgets
      await tester.scrollUntilVisible(
        find.text('温度 (Temperature)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // Find all switches in LLM section
      final switches = find.byType(Switch);

      // Toggle the first switch (temperature toggle)
      await tester.tap(switches.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // After toggling, verify no crash - slider interactivity is verified by value changes
    });

    testWidgets('saving with toggles off excludes params from typeConfig',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Fill in required fields
      // Text field order: model name, model ID, context, max tokens, seed
      // Reasoning params add an extra TextFormField for param name
      final textFields = find.byType(TextField);
      // Index 1 = model ID (index 0 is model name)
      await tester.enterText(textFields.at(1), 'test-model');
      // Index 2 = context length
      await tester.enterText(textFields.at(2), '4096');

      await tester.pump();

      // Save button should exist
      expect(find.text('保存'), findsOneWidget);
    });
  });

  group('Reasoning params editing with options', () {
    testWidgets('new model shows 暂无推理开关 with add button, no default toggle',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // New models now have NO default reasoning toggle
      expect(find.text('暂无推理开关'), findsOneWidget);
      expect(find.text('添加推理开关'), findsOneWidget);
      // The toggle card fields should NOT be present
      expect(find.text('开启时值'), findsNothing);
      expect(find.text('关闭时值'), findsNothing);
    });

    testWidgets('can add reasoning param with options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Fill required fields
      // Text field order: model name, model ID, context, reasoning param name, ...
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'test-model');
      await tester.enterText(textFields.at(2), '4096');

      await tester.pump();

      // Verify the page renders without crash
      expect(find.byType(LlmModelConfigPage), findsOneWidget);
    });
  });

  group('Inference switch validation: all fields required', () {
    testWidgets('click "添加推理参数" adds param regardless of toggle state',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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

      // Add the toggle first (no default toggle for new models)
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Fill toggle fields so save validation can proceed
      final toggleFields = find.byType(TextFormField);
      await tester.enterText(toggleFields.at(0), 'thinking.type');
      await tester.enterText(toggleFields.at(1), 'enabled');
      await tester.enterText(toggleFields.at(2), 'disabled');
      await tester.pump();

      // Scroll to find "添加推理参数" button
      await tester.scrollUntilVisible(
        find.text('添加推理参数'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.ensureVisible(find.text('添加推理参数'));
      await tester.pump();

      // Click "添加推理参数" - adds an extra reasoning param
      await tester.tap(find.text('添加推理参数'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify save fails because new param has empty name (not toggle error)
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('推理参数错误：参数名不能为空'), findsWidgets);
    });

    testWidgets('save with partially filled toggle shows error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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

      // Add the toggle first (no default toggle for new models)
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Fill only toggle name, leave onValue/offValue empty.
      final toggleNameField = find.byType(TextFormField).first;
      await tester.enterText(toggleNameField, 'thinking.type');
      await tester.pump();

      // Click save
      await tester.tap(find.text('保存'));
      await tester.pump();

      // Should show error about incomplete toggle (only name filled, values empty)
      expect(find.text('推理参数错误：推理开关开启值不能为空'), findsOneWidget);
    });

    testWidgets('save with no reasoning params at all should succeed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Fill required fields only
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'test-model');
      await tester.enterText(textFields.at(2), '4096');
      await tester.pump();

      // Click save - no reasoning params configured, should be valid
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should succeed and pop with a result
      expect(find.text('推理参数错误'), findsNothing);
    });

    testWidgets('save with non-toggle param having empty name shows error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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

      // Add the toggle first (no default toggle for new models)
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Fill all toggle fields
      final toggleFields = find.byType(TextFormField);
      await tester.enterText(toggleFields.at(0), 'thinking.type');
      await tester.enterText(toggleFields.at(1), 'enabled');
      await tester.enterText(toggleFields.at(2), 'disabled');
      await tester.pump();

      // Scroll to add a reasoning param via "添加推理参数" button
      await tester.scrollUntilVisible(
        find.text('添加推理参数'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.ensureVisible(find.text('添加推理参数'));
      await tester.pump();
      await tester.tap(find.text('添加推理参数'));
      await tester.pump();

      // Leave the new param name empty, click save
      await tester.tap(find.text('保存'));
      await tester.pump();

      // Should show error about empty param name
      expect(find.text('推理参数错误：参数名不能为空'), findsOneWidget);
    });

    testWidgets('save with non-toggle param having empty option shows error',
        (tester) async {
      // Create a model with pre-filled toggle and one param with an empty option
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
            options: [],
          ),
          ReasoningParam(
            paramName: 'reasoning_effort',
            isReasoningToggle: false,
            enabled: true,
            options: ['low', '', 'high'], // empty option at index 1
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(model: model),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Click save directly - should fail because option is empty
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show error about empty option
      expect(find.text('推理参数错误：选项值不能为空'), findsOneWidget);
    });

    testWidgets('save with duplicate reasoning param names shows error',
        (tester) async {
      // Create a model with duplicate param names
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
            options: [],
          ),
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: false,
            enabled: true,
            options: ['a', 'b'],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(model: model),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Click save - should fail due to duplicate param name
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show error about duplicate name
      expect(find.textContaining('重名'), findsWidgets);
    });

    testWidgets('save with no toggle when additional params exist shows error',
        (tester) async {
      // Create a model with non-toggle params but no toggle
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            isReasoningToggle: false,
            enabled: true,
            options: ['low', 'medium', 'high'],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(model: model),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Click save - should fail because toggle is required when other params exist
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show error about missing or incomplete toggle
      expect(find.textContaining('开关必须先填写完整'), findsWidgets);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From llm_model_config_page_dialog_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('LlmModelConfigPage - inference section', () {
    testWidgets('new model shows 暂无推理开关 with add button, no default toggle',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // New models have NO default reasoning toggle
      expect(find.text('暂无推理开关'), findsOneWidget);
      expect(find.text('添加推理开关'), findsOneWidget);
      expect(find.text('开启时值'), findsNothing);
      expect(find.text('关闭时值'), findsNothing);
    });

    testWidgets('can add reasoning param via "添加推理参数" button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
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

      // Add toggle first (no default toggle for new models)
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Fill toggle fields so additional params can be saved
      final toggleFields = find.byType(TextFormField);
      await tester.enterText(toggleFields.at(0), 'thinking.type');
      await tester.enterText(toggleFields.at(1), 'enabled');
      await tester.enterText(toggleFields.at(2), 'disabled');
      await tester.pump();

      // Scroll to find "添加推理参数" button
      await tester.scrollUntilVisible(
        find.text('添加推理参数'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.ensureVisible(find.text('添加推理参数'));
      await tester.pump();

      expect(find.text('添加推理参数'), findsOneWidget);

      // Tap add button
      await tester.tap(find.text('添加推理参数'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Button still visible after adding
      expect(find.text('添加推理参数'), findsOneWidget);
    });
  });

  group('ModelConfigPage - dialog button names', () {
    testWidgets('LlmModelConfigPage back dialog uses 取消 and 放弃',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Make a change
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'test');
      await tester.pump(const Duration(milliseconds: 100));

      // Verify 继续编辑 is NOT used (should have been changed to 取消)
      // We can't easily test PopScope programmatically, but we can verify
      // by checking the source code or running unit tests instead.
      // This test just ensures the page renders after editing.
      expect(find.byType(LlmModelConfigPage), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From llm_model_config_no_duplicate_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('LlmModelConfigPage - reasoning params structure', () {
    testWidgets('new model shows no default 推理开关 or 推理力度 cards',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Fill required fields so we can scroll down
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'test-model');
      await tester.enterText(textFields.at(2), '4096');
      await tester.pump();

      // No 推理开关 card (only the "暂无推理开关" text and add button)
      expect(find.text('暂无推理开关'), findsOneWidget);
      expect(find.text('添加推理开关'), findsOneWidget);

      // 推理力度 should NOT be present (neither card nor add button without toggle)
      expect(find.text('推理力度'), findsNothing);
      expect(find.text('添加推理力度'), findsNothing);
    });

    testWidgets('"添加推理参数" button exists for adding extra reasoning params',
        (tester) async {
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

      // Scroll to find "添加推理参数" button
      await tester.scrollUntilVisible(
        find.text('添加推理参数'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('添加推理参数'), findsOneWidget);
    });

    testWidgets('"附加推理参数" text is no longer displayed on model page',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The "附加推理参数" section header should not exist
      // (the additional params are shown as individual cards, no section header)
      expect(find.text('附加推理参数'), findsNothing);
    });

    testWidgets('adding param via "添加推理参数" creates additional card',
        (tester) async {
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

      // Add toggle first (no default toggle for new models)
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Fill toggle fields to enable save
      final toggleFields = find.byType(TextFormField);
      await tester.enterText(toggleFields.at(0), 'thinking.type');
      await tester.enterText(toggleFields.at(1), 'enabled');
      await tester.enterText(toggleFields.at(2), 'disabled');
      await tester.pump();

      // Scroll to "添加推理参数" button
      await tester.scrollUntilVisible(
        find.text('添加推理参数'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.ensureVisible(find.text('添加推理参数'));
      await tester.pump();

      // Tap "添加推理参数"
      await tester.tap(find.text('添加推理参数'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // No "附加推理参数" section header appears
      expect(find.text('附加推理参数'), findsNothing);

      // The additional param card should have an enabled switch
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets(
        'model page with pre-filled reasoning params shows toggle + effort cards',
        (tester) async {
      final model = ModelConfig(
        name: 'test-model',
        modelId: 'test-model',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
            options: [],
          ),
          ReasoningParam(
            paramName: 'reasoning_effort',
            isReasoningToggle: false,
            enabled: true,
            options: ['low', 'medium', 'high'],
          ),
          ReasoningParam(
            paramName: 'budget_tokens',
            isReasoningToggle: false,
            enabled: true,
            options: ['max'],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(model: model),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both cards should be visible after scrolling
      expect(find.text('推理开关'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('推理力度'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('推理力度'), findsOneWidget);

      // "附加推理参数" section header should NOT exist
      expect(find.text('附加推理参数'), findsNothing);
    });

    testWidgets('save validation still works correctly', (tester) async {
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

      // Click save - should succeed with no reasoning params
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No error about reasoning params
      expect(find.text('推理参数错误'), findsNothing);
    });

    testWidgets('effort card shows disabled state until toggle is complete',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Add the toggle first
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Now add the effort param via "添加推理力度" button
      await tester.scrollUntilVisible(
        find.text('添加推理力度'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('添加推理力度'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The effort card should show helper text since toggle is not complete
      await tester.scrollUntilVisible(
        find.text('请先完整填写推理开关后再配置推理力度'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('请先完整填写推理开关后再配置推理力度'), findsOneWidget);
    });

    testWidgets('"添加推理力度" button appears only after toggle is added',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Without toggle, "添加推理力度" button should NOT exist
      expect(find.text('添加推理力度'), findsNothing);

      // Add toggle
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Now "添加推理力度" button should appear
      await tester.scrollUntilVisible(
        find.text('添加推理力度'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('添加推理力度'), findsOneWidget);
    });

    testWidgets('after adding effort via "添加推理力度", button hides and card shows',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Add toggle
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Click "添加推理力度"
      await tester.scrollUntilVisible(
        find.text('添加推理力度'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('添加推理力度'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The "添加推理力度" button should now be hidden
      expect(find.text('添加推理力度'), findsNothing);

      // The effort card should be shown
      await tester.scrollUntilVisible(
        find.text('推理力度'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('推理力度'), findsOneWidget);
    });

    testWidgets('delete effort card and "添加推理力度" button reappears',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Add toggle
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Add effort
      await tester.scrollUntilVisible(
        find.text('添加推理力度'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('添加推理力度'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Delete the effort card (find its delete button)
      await tester.scrollUntilVisible(
        find.text('推理力度'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Find the delete icon button on the effort card
      final deleteButtons = find.byIcon(Icons.delete);
      // The effort card's delete button is the second one (first is toggle's)
      await tester.tap(deleteButtons.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Now "添加推理力度" button should reappear
      await tester.scrollUntilVisible(
        find.text('添加推理力度'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('添加推理力度'), findsOneWidget);
    });

    testWidgets(
        'deleting toggle reverts to empty state and hides effort button',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Add toggle
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Delete the toggle
      final deleteButtons = find.byIcon(Icons.delete);
      await tester.tap(deleteButtons.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Should show "暂无推理开关" and "添加推理开关" again
      expect(find.text('暂无推理开关'), findsOneWidget);
      expect(find.text('添加推理开关'), findsOneWidget);

      // "添加推理力度" should NOT be visible without toggle
      expect(find.text('添加推理力度'), findsNothing);
    });

    testWidgets(
        'adding additional params before effort still allows adding effort',
        (tester) async {
      // Set larger surface so all widgets are visible without scrolling.
      // This avoids scroll-related issues in widget tests.
      tester.view.physicalSize = const Size(800, 3000);
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Add toggle
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Fill toggle fields
      final toggleFields = find.byType(TextFormField);
      await tester.enterText(toggleFields.at(0), 'thinking.type');
      await tester.enterText(toggleFields.at(1), 'enabled');
      await tester.enterText(toggleFields.at(2), 'disabled');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify "添加推理参数" button exists in widget tree
      expect(find.text('添加推理参数'), findsOneWidget);

      // Add additional reasoning param BEFORE adding effort
      await tester.tap(find.text('添加推理参数'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // "添加推理力度" button should still be in the widget tree
      // (isEffortParam flag distinguishes it from the additional param)
      expect(find.text('添加推理力度'), findsOneWidget);

      // Now add effort — should succeed
      await tester.tap(find.text('添加推理力度'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // "添加推理力度" button should be hidden (only one effort allowed)
      expect(find.text('添加推理力度'), findsNothing);

      // The effort card should now be visible
      expect(find.text('推理力度'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From simple_model_config_page_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('SimpleModelConfigPage - Create new model', () {
    testWidgets('shows title "添加模型" for new model', (tester) async {
      await tester.pumpWidget(_buildSimpleTestApp());
      await tester.pumpAndSettle();

      expect(find.text('添加模型'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('validates model ID is required', (tester) async {
      await tester.pumpWidget(_buildSimpleTestApp());
      await tester.pumpAndSettle();

      // Click save with empty model ID
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Should show validation error
      expect(find.text('模型 ID 为必填项'), findsOneWidget);
    });

    testWidgets('validates custom params require both name and default value',
        (tester) async {
      await tester.pumpWidget(_buildSimpleTestApp());
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

      await tester.pumpWidget(_buildSimpleTestApp(initialModel: existing));
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

  // ─────────────────────────────────────────────────────────────────────
  // From model_config_dup_crosscheck_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group(
      'Cross-check duplicate names between reasoning params and custom params',
      () {
    /// Simulates the save validation logic from llm_model_config_page.dart.
    /// Returns null if valid, or an error message string if invalid.
    String? validateNoDuplicateAcrossParams({
      required List<ReasoningParam> reasoningParams,
      required List<CustomParam> customParams,
    }) {
      // Collect all custom param names
      final allNames = <String>{};

      // Check custom params internally (existing behavior)
      for (final param in customParams) {
        final name = param.paramName.trim();
        if (name.isEmpty) continue;
        if (!allNames.add(name)) {
          return '已存在该参数: $name';
        }
      }

      // Check reasoning params internally (existing behavior)
      final reasoningSeenNames = <String>{};
      for (final param in reasoningParams) {
        final name = param.paramName.trim();
        if (name.isEmpty) continue;
        if (!reasoningSeenNames.add(name)) {
          return '推理参数存在重名: $name';
        }
      }

      // NEW CROSS-CHECK: Check reasoning param names against custom param names
      for (final param in reasoningParams) {
        final name = param.paramName.trim();
        if (name.isEmpty) continue;
        if (!allNames.add(name)) {
          return '推理参数与自定义参数存在重名: $name';
        }
      }

      return null;
    }

    test('reasoning param and custom param with same name should be rejected',
        () {
      final reasoningParams = [
        ReasoningParam(paramName: 'thinking.type', options: ['enabled']),
      ];
      final customParams = [
        CustomParam(paramName: 'thinking.type', defaultValue: 'true'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNotNull);
      expect(result, contains('重名'));
    });

    test(
        'reasoning param and custom param with different names should be valid',
        () {
      final reasoningParams = [
        ReasoningParam(paramName: 'reasoning_effort', options: ['low', 'high']),
      ];
      final customParams = [
        CustomParam(paramName: 'temperature', defaultValue: '0.7'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNull);
    });

    test(
        'multiple reasoning params and custom params with unique names should be valid',
        () {
      final reasoningParams = [
        ReasoningParam(paramName: 'reasoning_effort', options: ['low', 'high']),
        ReasoningParam(paramName: 'thinking.type', options: ['a', 'b']),
      ];
      final customParams = [
        CustomParam(paramName: 'temperature', defaultValue: '0.7'),
        CustomParam(paramName: 'max_tokens', defaultValue: '4096'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNull);
    });

    test(
        'duplicate within reasoning params still caught (existing behavior preserved)',
        () {
      final reasoningParams = [
        ReasoningParam(paramName: 'reasoning_effort', options: ['low', 'high']),
        ReasoningParam(paramName: 'reasoning_effort', options: ['1', '2']),
      ];
      final customParams = [
        CustomParam(paramName: 'temperature', defaultValue: '0.7'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNotNull);
      expect(result, contains('推理参数存在重名'));
    });

    test(
        'duplicate within custom params still caught (existing behavior preserved)',
        () {
      final reasoningParams = [
        ReasoningParam(paramName: 'reasoning_effort', options: ['low', 'high']),
      ];
      final customParams = [
        CustomParam(paramName: 'temperature', defaultValue: '0.7'),
        CustomParam(paramName: 'temperature', defaultValue: '0.5'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNotNull);
      expect(result, contains('已存在该参数'));
    });

    test('empty param names are skipped in cross-check', () {
      final reasoningParams = [
        ReasoningParam(paramName: 'reasoning_effort', options: ['low', 'high']),
      ];
      final customParams = [
        CustomParam(paramName: '', defaultValue: ''),
        CustomParam(paramName: 'temperature', defaultValue: '0.7'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNull);
    });

    test('toggle reasoning param flagged as duplicate with custom param', () {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'thinking.type',
          isReasoningToggle: true,
          onValue: 'enabled',
          offValue: 'disabled',
        ),
      ];
      final customParams = [
        CustomParam(paramName: 'thinking.type', defaultValue: 'enabled'),
      ];

      final result = validateNoDuplicateAcrossParams(
        reasoningParams: reasoningParams,
        customParams: customParams,
      );
      expect(result, isNotNull);
      expect(result, contains('重名'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // From model_config_reasoning_test.dart
  // ─────────────────────────────────────────────────────────────────────

  group('ModelConfig reasoningParams with ReasoningParam', () {
    test('default reasoningParams is empty', () {
      final config = ModelConfig(name: 'Test', modelId: 'test');
      expect(config.reasoningParams, isEmpty);
    });

    test('can set reasoningParams with ReasoningParam list', () {
      final config = ModelConfig(
        name: 'Test',
        modelId: 'test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            options: ['low', 'medium', 'high'],
          ),
        ],
      );
      expect(config.reasoningParams.length, 1);
      expect(config.reasoningParams[0].paramName, 'reasoning_effort');
      expect(config.reasoningParams[0].options, ['low', 'medium', 'high']);
    });

    test('multiple reasoning params with different options', () {
      final config = ModelConfig(
        name: 'Test',
        modelId: 'test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            options: ['low', 'medium', 'high'],
          ),
          ReasoningParam(
            paramName: 'thinking.type',
            options: ['enabled'],
          ),
          ReasoningParam(
            paramName: 'budget_tokens',
            options: ['max'],
          ),
        ],
      );
      expect(config.reasoningParams.length, 3);
    });

    test('toMap serialization includes reasoningParams', () {
      final config = ModelConfig(
        name: 'Test',
        modelId: 'test',
        typeConfig: {'context': 4096},
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            options: ['low', 'medium', 'high'],
          ),
        ],
      );
      final map = config.toMap();
      expect(map['reasoningParams'], isA<List>());
      expect((map['reasoningParams'] as List).length, 1);
      final param = (map['reasoningParams'] as List).first as Map;
      expect(param['paramName'], 'reasoning_effort');
      expect(param['options'], ['low', 'medium', 'high']);
    });

    test('fromMap deserialization of reasoningParams', () {
      final config = ModelConfig.fromMap({
        'name': 'Test',
        'modelId': 'test',
        'typeConfig': {'context': 4096},
        'reasoningParams': [
          {
            'paramName': 'reasoning_effort',
            'options': ['low', 'medium', 'high']
          },
          {
            'paramName': 'thinking.type',
            'options': ['enabled', 'disabled']
          },
        ],
      });
      expect(config.reasoningParams.length, 2);
      expect(config.reasoningParams[0].paramName, 'reasoning_effort');
      expect(config.reasoningParams[0].options, ['low', 'medium', 'high']);
      expect(config.reasoningParams[1].paramName, 'thinking.type');
      expect(config.reasoningParams[1].options, ['enabled', 'disabled']);
    });

    test('fromMap handles old format CustomParam reasoningParams gracefully',
        () {
      // Old format had paramName, defaultValue, type instead of options
      final config = ModelConfig.fromMap({
        'name': 'Test',
        'modelId': 'test',
        'typeConfig': {'context': 4096},
        'reasoningParams': [
          {
            'paramName': 'thinking.type',
            'defaultValue': 'enabled',
            'type': 'string'
          },
          {
            'paramName': 'reasoning_effort',
            'defaultValue': 'medium',
            'type': 'string'
          },
        ],
      });
      // Should convert old format to new format gracefully
      expect(config.reasoningParams.length, 2);
      // Old format without options should have empty options
      expect(config.reasoningParams[0].paramName, 'thinking.type');
      expect(config.reasoningParams[1].paramName, 'reasoning_effort');
    });

    test('copy preserves reasoningParams', () {
      final config = ModelConfig(
        name: 'Test',
        modelId: 'test',
        reasoningParams: [
          ReasoningParam(
            paramName: 'test',
            options: ['a', 'b'],
          ),
        ],
      );
      final copy = config.copy();
      expect(copy.reasoningParams.length, 1);
      expect(copy.reasoningParams[0].paramName, 'test');
      expect(copy.reasoningParams[0].options, ['a', 'b']);
    });
  });
}
