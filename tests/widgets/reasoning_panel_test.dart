import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/chat_setting_panels.dart';
import 'package:stroom/providers/provider_config.dart';

/// Helper function to show the reasoning panel in tests.
Future<void> showReasoningPanelForTest(
  WidgetTester tester, {
  bool reasoningEnabled = false,
  bool reasoningEffortEnabled = false,
  Map<String, String> reasoningParamSelections = const {},
  List<ReasoningParam> reasoningParams = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              showReasoningPanel(
                context: context,
                reasoningEnabled: reasoningEnabled,
                reasoningEffortEnabled: reasoningEffortEnabled,
                reasoningParamSelections: reasoningParamSelections,
                reasoningParams: reasoningParams,
                onReasoningToggle: (_) {},
                onReasoningEffortToggle: (_) {},
                onReasoningParamChanged: (_, __) {},
              );
            },
            child: const Text('Open'),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('ReasoningPanel - disabled switch when no params', () {
    testWidgets(
        'reasoning switch is disabled with onChanged=null when no params',
        (tester) async {
      await showReasoningPanelForTest(
        tester,
        reasoningParams: [],
      );

      final switches = tester.widgetList<Switch>(find.byType(Switch));
      var hasDisabledSwitch = false;
      for (final sw in switches) {
        if (sw.onChanged == null) {
          hasDisabledSwitch = true;
          break;
        }
      }
      expect(hasDisabledSwitch, isTrue,
          reason:
              'At least one switch should be disabled when reasoningParams is empty');
    });
  });

  group('ReasoningPanel - additional params with switch + options', () {
    testWidgets('shows non-effort params with switch row like effort section',
        (tester) async {
      // Note: The reasoning panel (showReasoningPanel) no longer shows
      // non-effort, non-toggle params — they are now in showCustomReasoningParamsPanel.
      // This test verifies they are NOT in the reasoning panel.
      await showReasoningPanelForTest(
        tester,
        reasoningEnabled: true,
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'budget_tokens',
            options: ['5000', '10000'],
          ),
        ],
      );

      // Wait for the panel to settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Non-effort params are NOT shown in the reasoning panel
      // (they are in the separate custom params panel instead)
      expect(find.text('budget_tokens'), findsNothing);
      expect(find.text('5000'), findsNothing);
      expect(find.text('10000'), findsNothing);
    });
  });

  group('Model settings - switch removed from additional params', () {
    test('ReasoningParam enabled field still exists for panel control', () {
      // The enabled flag should still exist on ReasoningParam
      final param = ReasoningParam(
        paramName: 'test_param',
        options: ['a', 'b'],
        enabled: true,
      );
      expect(param.enabled, isTrue);

      // It can be toggled
      param.enabled = false;
      expect(param.enabled, isFalse);

      // Test serialization
      final map = param.toMap();
      expect(map['enabled'], false);

      // Test deserialization
      final restored = ReasoningParam.fromMap(map);
      expect(restored.enabled, isFalse);
    });
  });

  group('ReasoningPanel - disabled switch when no options/no settings', () {
    testWidgets(
        'effort switch is disabled and off when effort param has no option '
        'values', (tester) async {
      await showReasoningPanelForTest(
        tester,
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: [],
          ),
        ],
      );

      // The effort switch (second switch) must be disabled AND off even
      // though reasoningEffortEnabled was passed as true — with no option
      // values there is nothing to select, so the switch is unavailable.
      final effortSwitch = tester.widget<Switch>(find.byType(Switch).at(1));
      expect(effortSwitch.onChanged, isNull);
      expect(effortSwitch.value, isFalse);

      // The hint explains why the effort section is unavailable.
      expect(find.textContaining('该参数暂无选项值'), findsOneWidget);
    });

    testWidgets(
        'reasoning toggle is disabled and off when no params exist even if '
        'reasoning was enabled before', (tester) async {
      // Simulate a stale state: reasoning was enabled for a previous model
      // that had params, but the current model has no reasoning params.
      await showReasoningPanelForTest(
        tester,
        reasoningEnabled: true,
        reasoningParams: [],
      );

      // The reasoning toggle (first switch) must be disabled AND off.
      final reasoningSwitch = tester.widget<Switch>(find.byType(Switch).at(0));
      expect(reasoningSwitch.onChanged, isNull);
      expect(reasoningSwitch.value, isFalse);
    });
  });

  group('ReasoningPanel - effort disabled state and edge cases', () {
    testWidgets('shows effort section disabled when no effort param exists',
        (tester) async {
      await showReasoningPanelForTest(
        tester,
        reasoningEnabled: true,
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
        ],
      );

      // The effort section should be visible with a disabled switch
      expect(find.text('推理力度'), findsOneWidget);

      // The hint text should show
      expect(
        find.textContaining('当前模型未配置推理力度参数'),
        findsOneWidget,
      );
    });

    testWidgets('shows hint when reasoning is enabled but no additional params',
        (tester) async {
      await showReasoningPanelForTest(
        tester,
        reasoningEnabled: true,
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
        ],
      );

      // Should show hint about no additional params
      expect(
        find.textContaining('当前模型未配置其他推理参数'),
        findsOneWidget,
      );
    });

    testWidgets('effort switch is enabled when effort param exists',
        (tester) async {
      await showReasoningPanelForTest(
        tester,
        reasoningEnabled: true,
        reasoningEffortEnabled: false,
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'medium', 'high'],
          ),
        ],
      );

      // The effort section should be visible
      expect(find.text('推理力度'), findsOneWidget);

      // The effort options should appear when effort toggle is turned on
      // (since localEffortEnabled starts false, options are hidden)
      expect(find.text('low'), findsNothing);
      expect(find.text('medium'), findsNothing);
      expect(find.text('high'), findsNothing);
    });
  });

  group('ReasoningPanel - effort section independent of reasoning toggle', () {
    testWidgets('shows effort section even when reasoning is OFF',
        (tester) async {
      await showReasoningPanelForTest(
        tester,
        reasoningEnabled: false,
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'medium', 'high'],
          ),
        ],
      );

      // The effort section is always visible, independent of the
      // reasoning toggle state.
      expect(find.text('推理力度'), findsOneWidget);
    });

    testWidgets('turning reasoning on keeps the effort section visible',
        (tester) async {
      await showReasoningPanelForTest(
        tester,
        reasoningEnabled: false,
        reasoningParams: [
          ReasoningParam(
            paramName: 'thinking.type',
            isReasoningToggle: true,
            onValue: 'enabled',
            offValue: 'disabled',
          ),
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'medium', 'high'],
          ),
        ],
      );

      // Effort section visible while reasoning is off
      expect(find.text('推理力度'), findsOneWidget);

      // Toggle the reasoning switch ON
      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      // The effort section must remain visible immediately (no stale
      // hidden state from the panel-opening value).
      expect(find.text('推理力度'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    });

    testWidgets(
        'effort switch is enabled and reveals options while reasoning '
        'is OFF', (tester) async {
      await showReasoningPanelForTest(
        tester,
        reasoningEnabled: false,
        reasoningEffortEnabled: false,
        reasoningParams: [
          ReasoningParam(
            paramName: 'reasoning_effort',
            isEffortParam: true,
            options: ['low', 'medium', 'high'],
          ),
        ],
      );

      // The effort switch (second switch) is tappable even when the
      // reasoning toggle is off.
      final effortSwitch = tester.widget<Switch>(find.byType(Switch).at(1));
      expect(effortSwitch.onChanged, isNotNull);
      expect(effortSwitch.value, isFalse);

      await tester.tap(find.byType(Switch).at(1));
      await tester.pump();

      // Enabling the effort toggle reveals its options.
      expect(find.text('low'), findsOneWidget);
      expect(find.text('medium'), findsOneWidget);
      expect(find.text('high'), findsOneWidget);
    });
  });

  group('CustomReasoningParamsPanel', () {
    testWidgets('shows custom reasoning params with switch and options',
        (tester) async {
      // Use a larger screen to accommodate the bottom sheet
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showCustomReasoningParamsPanel(
                    context: context,
                    reasoningEnabled: true,
                    reasoningParamSelections: {},
                    reasoningParams: [
                      ReasoningParam(
                        paramName: 'budget_tokens',
                        options: ['5000', '10000', '20000'],
                      ),
                    ],
                    onReasoningParamChanged: (_, __) {},
                    onCustomParamToggle: (_, __) {},
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Title should be visible (matches the 自定义参数 button label —
      // regression: the panel used to say 自定义推理参数)
      expect(find.text('自定义参数'), findsOneWidget);

      // Param name should be visible
      expect(find.text('budget_tokens'), findsOneWidget);

      // 无已选值 → 开关关闭、选项隐藏（运行时状态以已选值为准）
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);
      expect(find.text('5000'), findsNothing);

      // 开启开关 → 写入默认选项值，选项显示
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(find.text('5000'), findsOneWidget);
      expect(find.text('10000'), findsOneWidget);
      expect(find.text('20000'), findsOneWidget);
    });

    testWidgets('shows empty state when no custom params', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showCustomReasoningParamsPanel(
                    context: context,
                    reasoningEnabled: true,
                    reasoningParamSelections: {},
                    reasoningParams: [],
                    onReasoningParamChanged: (_, __) {},
                    onCustomParamToggle: (_, __) {},
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Title should be visible (matches the 自定义参数 button label)
      expect(find.text('自定义参数'), findsOneWidget);

      // Empty state text should show
      expect(
        find.textContaining('当前模型未配置自定义参数'),
        findsOneWidget,
      );
    });
  });
}
