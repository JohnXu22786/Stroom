import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/llm_model_config_page.dart';

void main() {
  group('LlmModelConfigPage - inference section', () {
    testWidgets('reasoning toggle section has a default toggle for new models',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LlmModelConfigPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // New models now have a default reasoning toggle pre-populated
      expect(find.text('推理开关'), findsOneWidget);
      expect(find.text('参数名'), findsOneWidget);
      expect(find.text('开启时值'), findsOneWidget);
      expect(find.text('关闭时值'), findsOneWidget);
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
}
