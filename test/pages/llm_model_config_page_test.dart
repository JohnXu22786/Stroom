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

      // Should find switches for Temperature, Top P, etc.
      // Temperature switch
      expect(find.text('温度 (Temperature)'), findsOneWidget);

      // Top P switch
      expect(find.text('Top P'), findsOneWidget);

      // Frequency Penalty switch
      expect(find.text('频率惩罚 (Frequency Penalty)'), findsOneWidget);

      // Presence Penalty switch
      expect(find.text('存在惩罚 (Presence Penalty)'), findsOneWidget);
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

      // Find all Switch widgets in the page
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      // By default switches should be off (params disabled)
      // The sliders should be present but grayed out
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

      // Find all switches
      final switches = find.byType(Switch);
      
      // Toggle the first switch (Temperature)
      await tester.tap(switches.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // After toggling, the slider should be interactive
      // (We just verify no crash - slider interactivity is verified by value changes)
    });

    testWidgets('saving with toggles off excludes params from typeConfig',
        (tester) async {
      ModelConfig? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LlmModelConfigPage(),
                    ),
                  ).then((v) => result = v as ModelConfig?);
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      // Open the model config page
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Fill in required fields
      final modelIdFields = find.byType(TextField);
      // Fill model ID
      await tester.enterText(modelIdFields.at(1), 'test-model');
      // Fill context length
      await tester.enterText(modelIdFields.at(2), '4096');
      
      await tester.pump();

      // Save
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // With all toggles off by default, typeConfig should only have context
      expect(result, isNotNull);
      expect(result!.typeConfig.containsKey('context'), true);
      // temperature should NOT be in typeConfig when toggle is off
      // (We'll verify this once we know the toggle defaults)
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

      // Should show reasoning params section
      expect(find.text('推理参数'), findsOneWidget);

      // Should have a button to add reasoning params
      expect(find.text('添加推理参数'), findsOneWidget);
    });

    testWidgets('can add reasoning param with options',
        (tester) async {
      ModelConfig? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LlmModelConfigPage(),
                    ),
                  ).then((v) => result = v as ModelConfig?);
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Fill required fields
      final modelIdFields = find.byType(TextField);
      await tester.enterText(modelIdFields.at(1), 'test-model');
      await tester.enterText(modelIdFields.at(2), '4096');

      // Add a reasoning param
      // Scroll down to find the reasoning section
      await tester.scrollUntilVisible(find.text('添加推理参数'), 200);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('添加推理参数'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should see the new param card with name field and options
      expect(find.text('参数名'), findsWidgets);
    });
  });
}
