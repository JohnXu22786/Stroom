import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/widgets/chat_attachment_panel.dart';
import 'package:stroom/models/tool_call.dart';

/// Helper to open the panel in a test environment.
Future<void> openPanel(WidgetTester tester) async {
  await tester.tap(find.text('Open Panel'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300)); // For animation

  // DraggableScrollableSheet inside modal bottom sheet needs pump
  await tester.pump(const Duration(milliseconds: 100));
}

/// Builds the test app and opens the panel.
Future<void> showPanelForTest(
  WidgetTester tester, {
  List<String> models = const [],
  int selectedModelIndex = 0,
  void Function(int)? onModelSelected,
  List<ToolDefinition> tools = const [],
  bool reasoningEnabled = false,
  String reasoningEffort = 'medium',
  Set<String> enabledTools = const {},
  void Function(bool)? onReasoningToggle,
  void Function(String)? onReasoningEffortChange,
  void Function(String, bool)? onToolToggle,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showChatAttachmentPanel(
                  context: context,
                  models: models,
                  selectedModelIndex: selectedModelIndex,
                  onModelSelected: onModelSelected ?? (_) {},
                  tools: tools,
                  reasoningEnabled: reasoningEnabled,
                  reasoningEffort: reasoningEffort,
                  enabledTools: enabledTools,
                  onReasoningToggle: onReasoningToggle ?? (_) {},
                  onReasoningEffortChange: onReasoningEffortChange ?? (_) {},
                  onToolToggle: onToolToggle ?? (_, __) {},
                  onPickFromCamera: () {},
                  onPickFromGallery: () {},
                  onPickFromFilePicker: () {},
                );
              },
              child: const Text('Open Panel'),
            );
          },
        ),
      ),
    ),
  );

  await openPanel(tester);
}

/// Scroll the panel's scrollable widget.
Future<void> scrollPanel(WidgetTester tester, Offset offset) async {
  final scrollable = find.byType(Scrollable).last;
  await tester.drag(scrollable, offset);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('ChatAttachmentPanel widget tests', () {
    testWidgets('panel opens with title', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await showPanelForTest(tester);

      // The panel title should be visible
      expect(find.text('Chat 设置'), findsOneWidget);
    });

    testWidgets('Files section shows camera and gallery buttons',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await showPanelForTest(tester);

      // File action buttons should be visible at the top of the scrollable panel
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('相册'), findsOneWidget);
    });

    testWidgets('Model section shows when models provided', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await showPanelForTest(tester, models: ['GPT-4o | OpenRouter', 'Claude | OpenRouter']);

      // Model section header should be visible
      expect(find.text('模型'), findsOneWidget);
      // Model names should appear in the dropdown
      expect(find.text('GPT-4o | OpenRouter'), findsOneWidget);
    });

    testWidgets('Model section hidden when no models', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await showPanelForTest(tester, models: []);

      // Model section header should NOT be visible when empty
      expect(find.text('模型'), findsNothing);
    });

    testWidgets('Reasoning section header visible after scroll',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await showPanelForTest(tester, reasoningEnabled: true);

      // Scroll down to find reasoning section
      await scrollPanel(tester, const Offset(0, -300));

      // The reasoning section header should now be visible
      expect(find.text('推理设置'), findsOneWidget);
    });

    testWidgets('Tools section shows available MCP tools', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tools = [
        ToolDefinition(
          name: 'calculator',
          description: 'Performs math calculations',
          parameters: {},
        ),
        ToolDefinition(
          name: 'web_search',
          description: 'Searches the web',
          parameters: {},
        ),
      ];

      await showPanelForTest(tester, tools: tools);

      // Tool names should appear in the panel
      expect(find.text('calculator'), findsOneWidget);
      expect(find.text('web_search'), findsOneWidget);
    });

    testWidgets('"暂无可用工具" shown when no MCP tools available',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await showPanelForTest(tester, tools: []);

      // Should show empty state message
      expect(find.text('暂无可用工具'), findsOneWidget);
    });

    testWidgets('tools are shown with Switch widgets', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tools = [
        ToolDefinition(
          name: 'calculator',
          description: 'Math',
          parameters: {},
        ),
      ];

      await showPanelForTest(tester, tools: tools);

      // At least one switch should exist for the tool
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('effort chips exist in the widget tree', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await showPanelForTest(tester, reasoningEnabled: true);

      // Scroll to make effort chips visible
      await scrollPanel(tester, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 200));

      // The effort chips should exist in the widget tree
      expect(find.text('高'), findsOneWidget);
      expect(find.text('中'), findsOneWidget);
      expect(find.text('低'), findsOneWidget);
    });

    testWidgets('panel dismisses when tapping overlay background',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await showPanelForTest(tester);

      // Panel should show title
      expect(find.text('Chat 设置'), findsOneWidget);

      // Tap on the barrier (background overlay)
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Panel should dismiss
      expect(find.text('Chat 设置'), findsNothing);
    });

    testWidgets('tool switch reflects initial enabledTools set', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tools = [
        ToolDefinition(
          name: 'calculator',
          description: 'Math tool',
          parameters: {},
        ),
      ];

      await showPanelForTest(
        tester,
        tools: tools,
        enabledTools: {'calculator'},
      );

      // Scroll down to the tools section
      await scrollPanel(tester, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 200));

      // Find the SwitchListTile (used only for tool toggles, not for reasoning)
      final toolTile = find.byType(SwitchListTile);
      expect(toolTile, findsOneWidget);

      // The SwitchListTile's value reflects the toggle state
      final tile = tester.widget<SwitchListTile>(toolTile);
      expect(tile.value, isTrue);
    });

    testWidgets('tool switch is OFF when tool not in enabledTools',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tools = [
        ToolDefinition(
          name: 'calculator',
          description: 'Math tool',
          parameters: {},
        ),
      ];

      await showPanelForTest(
        tester,
        tools: tools,
        enabledTools: <String>{}, // Start with all OFF
      );

      // Scroll down to the tools section
      await scrollPanel(tester, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 200));

      // Find the SwitchListTile (used only for tool toggles)
      final toolTile = find.byType(SwitchListTile);
      expect(toolTile, findsOneWidget);

      // The SwitchListTile's value should be false
      final tile = tester.widget<SwitchListTile>(toolTile);
      expect(tile.value, isFalse);
    });

    testWidgets('toggling a tool ON fires onToolToggle callback',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tools = [
        ToolDefinition(
          name: 'web_search',
          description: 'Search tool',
          parameters: {},
        ),
      ];

      String? toggledToolName;
      bool? toggledValue;

      await showPanelForTest(
        tester,
        tools: tools,
        enabledTools: <String>{}, // Start with all OFF
        onToolToggle: (name, enabled) {
          toggledToolName = name;
          toggledValue = enabled;
        },
      );

      // Scroll down to the tools section
      await scrollPanel(tester, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 200));

      // Find the SwitchListTile (used only for tool toggles)
      final toolTile = find.byType(SwitchListTile);
      expect(toolTile, findsOneWidget);

      // Tap the SwitchListTile to toggle ON
      await tester.tap(toolTile);
      await tester.pump();

      // Verify the callback was fired with correct values
      expect(toggledToolName, equals('web_search'));
      expect(toggledValue, isTrue);
    });

    testWidgets('toggling a tool OFF fires onToolToggle callback',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tools = [
        ToolDefinition(
          name: 'web_search',
          description: 'Search tool',
          parameters: {},
        ),
      ];

      String? toggledToolName;
      bool? toggledValue;

      await showPanelForTest(
        tester,
        tools: tools,
        enabledTools: {'web_search'}, // Start with ON
        onToolToggle: (name, enabled) {
          toggledToolName = name;
          toggledValue = enabled;
        },
      );

      // Scroll down to the tools section
      await scrollPanel(tester, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 200));

      // Find the SwitchListTile (used only for tool toggles)
      final toolTile = find.byType(SwitchListTile);
      expect(toolTile, findsOneWidget);

      // Tap the SwitchListTile to toggle OFF
      await tester.tap(toolTile);
      await tester.pump();

      // Verify the callback was fired with correct values
      expect(toggledToolName, equals('web_search'));
      expect(toggledValue, isFalse);
    });
  });
}
