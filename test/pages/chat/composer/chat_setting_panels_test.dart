import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/chat_setting_panels.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/providers/provider_config.dart';

/// Helper to open the model panel in a test environment.
Future<void> openPanel(WidgetTester tester) async {
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('ModelPanel tests', () {
    testWidgets('model panel shows available models', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModelPanel(
                      context: context,
                      models: ['GPT-4o', 'Claude 3'],
                      selectedModelIndex: 0,
                      onModelSelected: (_) {},
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

      // Panel should show title and models
      expect(find.text('选择模型'), findsOneWidget);
      expect(find.text('GPT-4o'), findsOneWidget);
      expect(find.text('Claude 3'), findsOneWidget);
    });

    testWidgets('model panel callback fires on selection', (tester) async {
      int? selectedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModelPanel(
                      context: context,
                      models: ['GPT-4o', 'Claude 3'],
                      selectedModelIndex: 0,
                      onModelSelected: (idx) => selectedIndex = idx,
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

      // Tap the second model
      await tester.tap(find.text('Claude 3').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(selectedIndex, 1);
    });

    testWidgets('model panel dismisses on background tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModelPanel(
                      context: context,
                      models: ['GPT-4o'],
                      selectedModelIndex: 0,
                      onModelSelected: (_) {},
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

      expect(find.text('选择模型'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('选择模型'), findsNothing);
    });
  });

  group('ToolsPanel tests', () {
    testWidgets('tools panel shows available MCP tools with switches',
        (tester) async {
      final tools = [
        ToolDefinition(
          name: 'calculator',
          description: 'Performs math',
          parameters: {},
        ),
        ToolDefinition(
          name: 'web_search',
          description: 'Searches the web',
          parameters: {},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showToolsPanel(
                      context: context,
                      tools: tools,
                      enabledTools: {'calculator'},
                      onToolToggle: (_, __) {},
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

      expect(find.text('可用工具'), findsOneWidget);
      expect(find.text('calculator'), findsOneWidget);
      expect(find.text('web_search'), findsOneWidget);
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('tools panel shows empty state when no tools', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showToolsPanel(
                      context: context,
                      tools: const [],
                      enabledTools: const {},
                      onToolToggle: (_, __) {},
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

      expect(find.text('暂无可用工具'), findsOneWidget);
    });

    testWidgets('tools panel callback fires on toggle', (tester) async {
      final tools = [
        ToolDefinition(
          name: 'calculator',
          description: 'Performs math',
          parameters: {},
        ),
      ];
      String? toggledName;
      bool? toggledEnabled;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showToolsPanel(
                      context: context,
                      tools: tools,
                      enabledTools: const {},
                      onToolToggle: (name, enabled) {
                        toggledName = name;
                        toggledEnabled = enabled;
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

      // Find the switch and toggle it
      final switches = find.byType(Switch);
      await tester.tap(switches.first);
      await tester.pump();

      expect(toggledName, 'calculator');
      expect(toggledEnabled, true);
    });
  });

  group('ReasoningPanel tests (old API - with effort)', () {
    testWidgets('reasoning panel shows toggle and params',
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
                      reasoningParamSelections: {'reasoning_effort': 'medium'},
                      reasoningParams: [
                        ReasoningParam(
                          paramName: 'reasoning_effort',
                          options: ['low', 'medium', 'high'],
                        ),
                      ],
                      onReasoningToggle: (_) {},
                      onReasoningParamChanged: (_, __) {},
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
    });

    testWidgets('option chips appear when reasoning is enabled',
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
                      reasoningParamSelections: {'reasoning_effort': 'medium'},
                      reasoningParams: [
                        ReasoningParam(
                          paramName: 'reasoning_effort',
                          options: ['low', 'medium', 'high'],
                        ),
                      ],
                      onReasoningToggle: (_) {},
                      onReasoningParamChanged: (_, __) {},
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

      expect(find.text('low'), findsOneWidget);
      expect(find.text('medium'), findsOneWidget);
      expect(find.text('high'), findsOneWidget);
    });

    testWidgets('option chips hidden when reasoning is disabled',
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
                      reasoningParams: [
                        ReasoningParam(
                          paramName: 'reasoning_effort',
                          options: ['low', 'medium', 'high'],
                        ),
                      ],
                      onReasoningToggle: (_) {},
                      onReasoningParamChanged: (_, __) {},
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

      expect(find.text('low'), findsNothing);
      expect(find.text('medium'), findsNothing);
      expect(find.text('high'), findsNothing);
    });

    testWidgets('reasoning toggle callback fires', (tester) async {
      bool? toggleValue;
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
                      reasoningParamSelections: {},
                      reasoningParams: [
                        ReasoningParam(
                          paramName: 'reasoning_effort',
                          options: ['low', 'medium', 'high'],
                        ),
                      ],
                      onReasoningToggle: (v) => toggleValue = v,
                      onReasoningParamChanged: (_, __) {},
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

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(toggleValue, false);
    });
  });
}
