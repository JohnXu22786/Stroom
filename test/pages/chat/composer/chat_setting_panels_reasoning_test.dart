import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/chat_setting_panels.dart';
import 'package:stroom/providers/provider_config.dart';

/// Helper to open a panel in a test environment.
Future<void> openPanel(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('ReasoningPanel with effort section', () {
    testWidgets(
        'reasoning panel shows effort section when effort param exists with isEffortParam=true',
        (tester) async {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'reasoning_effort',
          isEffortParam: true,
          options: ['low', 'medium', 'high'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showReasoningPanel(
                      context: context,
                      reasoningEnabled: true,
                      reasoningEffortEnabled: true,
                      reasoningParamSelections: {'reasoning_effort': 'medium'},
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
                      onReasoningEffortToggle: (_) {},
                      onReasoningParamChanged: (name, value) {},
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await openPanel(tester);

      expect(find.text('推理设置'), findsOneWidget);
      expect(find.text('推理'), findsOneWidget);
      // Should show 推理力度 section
      expect(find.text('推理力度'), findsOneWidget);

      // Should show two Switches: one for 推理, one for 推理力度
      expect(find.byType(Switch), findsNWidgets(2));

      // Effort options should be visible when effort toggle is on
      expect(find.text('low'), findsOneWidget);
      expect(find.text('medium'), findsOneWidget);
      expect(find.text('high'), findsOneWidget);
    });

    testWidgets(
        'reasoning panel hides effort options when effort toggle is off',
        (tester) async {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'reasoning_effort',
          isEffortParam: true,
          options: ['low', 'medium', 'high'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showReasoningPanel(
                      context: context,
                      reasoningEnabled: true,
                      reasoningEffortEnabled: false,
                      reasoningParamSelections: {},
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
                      onReasoningEffortToggle: (_) {},
                      onReasoningParamChanged: (name, value) {},
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await openPanel(tester);

      // Should still show the effort toggle
      expect(find.text('推理力度'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(2));

      // But effort options should NOT be visible
      expect(find.text('low'), findsNothing);
      expect(find.text('medium'), findsNothing);
      expect(find.text('high'), findsNothing);
    });

    testWidgets(
        'reasoning panel shows effort section disabled when no isEffortParam exists',
        (tester) async {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'reasoning_effort',
          isEffortParam: false,
          options: ['low', 'medium', 'high'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showReasoningPanel(
                      context: context,
                      reasoningEnabled: true,
                      reasoningEffortEnabled: false,
                      reasoningParamSelections: {'reasoning_effort': 'medium'},
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
                      onReasoningEffortToggle: (_) {},
                      onReasoningParamChanged: (name, value) {},
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await openPanel(tester);

      expect(find.text('推理设置'), findsOneWidget);
      expect(find.text('推理'), findsOneWidget);
      // Effort section is shown but with disabled switch (2 switches total)
      expect(find.byType(Switch), findsNWidgets(2));

      // The hint about no effort param should appear
      expect(
        find.textContaining('当前模型未配置推理力度参数'),
        findsOneWidget,
      );
    });

    testWidgets('tapping effort option calls onReasoningParamChanged',
        (tester) async {
      String? changedParamName;
      String? changedValue;
      final reasoningParams = [
        ReasoningParam(
          paramName: 'reasoning_effort',
          isEffortParam: true,
          options: ['low', 'medium', 'high'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showReasoningPanel(
                      context: context,
                      reasoningEnabled: true,
                      reasoningEffortEnabled: true,
                      reasoningParamSelections: {'reasoning_effort': 'low'},
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
                      onReasoningEffortToggle: (_) {},
                      onReasoningParamChanged: (name, value) {
                        changedParamName = name;
                        changedValue = value;
                      },
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await openPanel(tester);

      // Tap 'high' chip
      await tester.tap(find.text('high'));
      await tester.pump();

      expect(changedParamName, 'reasoning_effort');
      expect(changedValue, 'high');
    });

    testWidgets('effort toggle callback fires when toggled', (tester) async {
      bool? toggledValue;
      final reasoningParams = [
        ReasoningParam(
          paramName: 'reasoning_effort',
          isEffortParam: true,
          options: ['low', 'medium', 'high'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showReasoningPanel(
                      context: context,
                      reasoningEnabled: true,
                      reasoningEffortEnabled: false,
                      reasoningParamSelections: {},
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
                      onReasoningEffortToggle: (value) {
                        toggledValue = value;
                      },
                      onReasoningParamChanged: (name, value) {},
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await openPanel(tester);

      // Find the second Switch (effort toggle) by locating them
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));

      // Tap the second toggle (effort toggle) — it's currently off, tap to turn on
      await tester.tap(switches.last);
      await tester.pump();

      expect(toggledValue, isTrue);
    });

    testWidgets('option chips hidden when reasoning is disabled',
        (tester) async {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'reasoning_effort',
          isEffortParam: true,
          options: ['low', 'medium', 'high'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showReasoningPanel(
                      context: context,
                      reasoningEnabled: false,
                      reasoningEffortEnabled: false,
                      reasoningParamSelections: {},
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
                      onReasoningEffortToggle: (_) {},
                      onReasoningParamChanged: (name, value) {},
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await openPanel(tester);

      expect(find.text('推理设置'), findsOneWidget);
      expect(find.text('推理'), findsOneWidget);

      // Effort section and options should be hidden when reasoning is disabled
      expect(find.text('推理力度'), findsNothing);
      expect(find.text('low'), findsNothing);
      expect(find.text('medium'), findsNothing);
      expect(find.text('high'), findsNothing);
    });

    testWidgets(
        'reasoning panel shows disabled state when no reasoning params configured',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showReasoningPanel(
                      context: context,
                      reasoningEnabled: true,
                      reasoningEffortEnabled: false,
                      reasoningParamSelections: {},
                      reasoningParams: const [],
                      onReasoningToggle: (_) {},
                      onReasoningEffortToggle: (_) {},
                      onReasoningParamChanged: (name, value) {},
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await openPanel(tester);

      expect(find.text('推理设置'), findsOneWidget);

      // Both reasoning toggle (disabled) and effort section (disabled) switches exist
      expect(find.byType(Switch), findsNWidgets(2));

      // Should show some text indicating no params configured
      expect(
        find.textContaining('当前模型未配置推理参数'),
        findsOneWidget,
      );
    });

    testWidgets('options preserve user-added order', (tester) async {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'config.thinkingConfig.thinkingLevel',
          isEffortParam: true,
          options: ['max', 'medium', 'min'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showReasoningPanel(
                      context: context,
                      reasoningEnabled: true,
                      reasoningEffortEnabled: true,
                      reasoningParamSelections: {
                        'config.thinkingConfig.thinkingLevel': 'max'
                      },
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
                      onReasoningEffortToggle: (_) {},
                      onReasoningParamChanged: (name, value) {},
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await openPanel(tester);

      // Just verify all options are present
      expect(find.text('max'), findsOneWidget);
      expect(find.text('medium'), findsOneWidget);
      expect(find.text('min'), findsOneWidget);
    });

    testWidgets(
        'non-effort params not shown in reasoning panel (now in custom params panel)',
        (tester) async {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'thinking.type',
          isEffortParam: false,
          options: ['true', 'false'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showReasoningPanel(
                      context: context,
                      reasoningEnabled: true,
                      reasoningEffortEnabled: false,
                      reasoningParamSelections: {'thinking.type': 'true'},
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
                      onReasoningEffortToggle: (_) {},
                      onReasoningParamChanged: (name, value) {},
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await openPanel(tester);

      // The reasoning panel should NOT show non-effort params
      expect(find.text('thinking.type'), findsNothing);
      expect(find.text('true'), findsNothing);
      expect(find.text('false'), findsNothing);

      // These are now in the separate custom params panel
      // (tested in reasoning_panel_test.dart)
    });
  });
}
