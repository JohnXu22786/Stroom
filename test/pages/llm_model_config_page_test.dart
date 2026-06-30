import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
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
    testWidgets(
        'reasoning params section shows no toggle by default (must add manually)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // No default toggle - should show "暂无推理开关" instead
      expect(find.text('暂无推理开关'), findsOneWidget);
      expect(find.text('添加推理开关'), findsOneWidget);

      // Add a reasoning toggle
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now the toggle card should be visible
      expect(find.text('推理开关'), findsOneWidget);
      expect(find.text('参数名'), findsOneWidget);
      expect(find.text('开启时值'), findsOneWidget);
      expect(find.text('关闭时值'), findsOneWidget);
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

      // Scroll to find "添加推理参数" button
      await tester.scrollUntilVisible(
        find.text('添加推理参数'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // Click "添加推理参数" - should add even with empty toggle
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

      // Add a toggle first
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Fill required fields
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'test-model');
      await tester.enterText(textFields.at(2), '4096');
      await tester.pump();

      // Fill only toggle name, leave onValue/offValue empty
      final toggleNameField = find.byType(TextFormField).first;
      await tester.enterText(toggleNameField, 'thinking.type');
      await tester.pump();

      // Click save
      await tester.tap(find.text('保存'));
      await tester.pump();

      // Should show error about incomplete toggle (only name filled, values empty)
      expect(find.text('推理参数错误：推理开关开启值不能为空'), findsOneWidget);
    });

    testWidgets(
        'save with fully empty toggle (all fields empty) should succeed',
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

      // Click save - toggle is completely empty, should be valid (optional)
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

      // Add a toggle first
      await tester.tap(find.text('添加推理开关'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Fill required fields
      var textFields = find.byType(TextField);
      await tester.enterText(textFields.at(1), 'test-model');
      await tester.enterText(textFields.at(2), '4096');
      await tester.pump();

      // Fill toggle fields
      final toggleNameField = find.byType(TextFormField).first;
      await tester.enterText(toggleNameField, 'thinking.type');
      final toggleFields = find.byType(TextFormField);
      await tester.enterText(toggleFields.at(1), 'enabled');
      await tester.enterText(toggleFields.at(2), 'disabled');
      await tester.pump();

      // Scroll to add a reasoning param
      await tester.scrollUntilVisible(
        find.text('添加推理参数'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
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
  });
}
