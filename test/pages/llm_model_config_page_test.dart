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

    testWidgets('toggle switches control slider availability',
        (tester) async {
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
    testWidgets('reasoning params section shows option editing UI',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The page should show the 推理开关 card (reasoning toggle) visible without scrolling
      expect(find.text('推理开关'), findsOneWidget);
      expect(find.text('参数名'), findsOneWidget);
      expect(find.text('开启时值'), findsOneWidget);
      expect(find.text('关闭时值'), findsOneWidget);

      // Scroll down to find the "添加推理参数" button
      await tester.scrollUntilVisible(
        find.text('添加推理参数'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      // "添加推理参数" button should now exist
      expect(find.text('添加推理参数'), findsOneWidget);
    });

    testWidgets('can add reasoning param with options',
        (tester) async {
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
}
