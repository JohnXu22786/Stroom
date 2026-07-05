import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/llm_model_config_page.dart';
import 'package:stroom/providers/provider_config.dart';

void main() {
  group('LlmModelConfigPage - reasoning params structure', () {
    testWidgets('shows 推理开关 card and 推理力度 card for new model',
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

      // 推理开关 card should be present
      expect(find.text('推理开关'), findsOneWidget);

      // Scroll to find 推理力度
      await tester.scrollUntilVisible(
        find.text('推理力度'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('推理力度'), findsOneWidget);
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

      // Click save - should succeed with empty toggle (all fields empty)
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

      // Scroll down to find the effort card
      await tester.scrollUntilVisible(
        find.text('请先完整填写推理开关后再配置推理力度'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();

      // The effort card should show helper text since toggle is not complete
      expect(find.text('请先完整填写推理开关后再配置推理力度'), findsOneWidget);
    });
  });
}
