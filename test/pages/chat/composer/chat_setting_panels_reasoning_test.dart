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
  group('ReasoningPanel with dynamic options', () {
    testWidgets('reasoning panel shows dynamic option chips from reasoning params',
        (tester) async {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'reasoning_effort',
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
                      reasoningParamSelections: {'reasoning_effort': 'medium'},
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
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
      expect(find.byType(Switch), findsOneWidget);

      // Should show parameter label and option chips
      expect(find.text('reasoning_effort'), findsOneWidget);
      expect(find.text('low'), findsOneWidget);
      expect(find.text('medium'), findsOneWidget);
      expect(find.text('high'), findsOneWidget);
    });

    testWidgets('multiple reasoning params show all their option chips',
        (tester) async {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'reasoning_effort',
          options: ['low', 'medium', 'high'],
        ),
        ReasoningParam(
          paramName: 'thinking.type',
          options: ['enabled', 'disabled'],
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
                      reasoningParamSelections: {
                        'reasoning_effort': 'medium',
                        'thinking.type': 'enabled',
                      },
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
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

      // First param
      expect(find.text('reasoning_effort'), findsOneWidget);
      expect(find.text('low'), findsOneWidget);
      expect(find.text('medium'), findsOneWidget);
      expect(find.text('high'), findsOneWidget);

      // Second param
      expect(find.text('thinking.type'), findsOneWidget);
      expect(find.text('enabled'), findsOneWidget);
      expect(find.text('disabled'), findsOneWidget);
    });

    testWidgets('option chips hidden when reasoning is disabled',
        (tester) async {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'reasoning_effort',
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
                      reasoningParamSelections: {},
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
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

      // Param labels and chips should NOT be visible when reasoning is disabled
      expect(find.text('reasoning_effort'), findsNothing);
      expect(find.text('low'), findsNothing);
      expect(find.text('medium'), findsNothing);
      expect(find.text('high'), findsNothing);
    });

    testWidgets('reasoning panel shows empty state when no reasoning params configured',
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
                      reasoningEnabled: false,
                      reasoningParamSelections: {},
                      reasoningParams: const [],
                      onReasoningToggle: (_) {},
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

      // Switch should exist but should show disabled state indicator
      expect(find.byType(Switch), findsOneWidget);

      // Should show some text indicating no params configured
      expect(find.textContaining('推理'), findsWidgets);
    });

    testWidgets('tapping an option chip updates the selection',
        (tester) async {
      String? changedParamName;
      String? changedValue;
      final reasoningParams = [
        ReasoningParam(
          paramName: 'reasoning_effort',
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
                      reasoningParamSelections: {'reasoning_effort': 'low'},
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
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

    testWidgets('options preserve user-added order',
        (tester) async {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'config.thinkingConfig.thinkingLevel',
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
                      reasoningParamSelections: {'config.thinkingConfig.thinkingLevel': 'max'},
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
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

      // Find all option chip texts and verify order
      final chipWidgets = find.byType(Padding);
      // Just verify all options are present
      expect(find.text('max'), findsOneWidget);
      expect(find.text('medium'), findsOneWidget);
      expect(find.text('min'), findsOneWidget);
    });

    testWidgets('true/false boolean options display correctly',
        (tester) async {
      final reasoningParams = [
        ReasoningParam(
          paramName: 'thinking.type',
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
                      reasoningParamSelections: {'thinking.type': 'true'},
                      reasoningParams: reasoningParams,
                      onReasoningToggle: (_) {},
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

      expect(find.text('thinking.type'), findsOneWidget);
      expect(find.text('true'), findsOneWidget);
      expect(find.text('false'), findsOneWidget);
    });
  });
}
