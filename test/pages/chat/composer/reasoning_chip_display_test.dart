import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/tool_call.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/pages/chat/composer/composer_shared.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

/// Helper that creates a widget with all providers needed to test
/// the composer widget in isolation, with reasoning state overrides.
///
/// [reasoningParamValues] controls what the reasoning chip label shows:
///   - When reasoning is enabled and effort toggle is on and 'reasoning_effort'
///     key is present: shows that value (the 推理力度 from model config).
///   - When reasoning is enabled but effort toggle is off: shows '推理' (purple).
///   - When reasoning is enabled but 'reasoning_effort' is absent: shows '推理'.
///   - When reasoning is disabled: shows '推理' (grey).
///
/// [mcpTools] is the composer's selectable tool list; the tool chip badge
/// only counts enabled tools that appear in it (hidden tools don't count).
Widget createComposerTestApp({
  required bool reasoningEnabled,
  required bool reasoningEffortEnabled,
  Map<String, String> reasoningParamValues = const {},
  Set<String> enabledTools = const {},
  List<ReasoningParam> extraReasoningParams = const [],
  List<ToolDefinition> mcpTools = const [],
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      reasoningEnabledProvider.overrideWith((ref) => reasoningEnabled),
      reasoningEffortEnabledProvider
          .overrideWith((ref) => reasoningEffortEnabled),
      reasoningParamValuesProvider.overrideWith((ref) => reasoningParamValues),
      conversationsProvider.overrideWith((ref) {
        return ConversationsNotifier(ref);
      }),
      activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
      providerEntriesProvider.overrideWith((ref) {
        return ProviderEntriesNotifier();
      }),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: ChatComposerWidget(
          onSend: (text, attachments) {},
          onStop: () {},
          modelNames: ['test-model'],
          selectedModelIndex: 0,
          onModelSelected: (idx) {},
          onEnabledToolsChanged: (tools) {},
          enabledTools: enabledTools,
          mcpTools: mcpTools,
          reasoningParams: [
            ReasoningParam(
                paramName: 'reasoning_effort',
                isEffortParam: true,
                options: ['low', 'medium', 'high']),
            ...extraReasoningParams,
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('Composer reasoning chip label', () {
    testWidgets('shows effort value when reasoning ON + effort ON + value set',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        reasoningParamValues: {'reasoning_effort': 'medium'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Should show the effort level when reasoning AND effort are enabled
      expect(find.text('medium'), findsOneWidget);
      expect(find.text('推理'), findsNothing);
    });

    testWidgets('shows 推理 when effort toggle is OFF', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: false,
        reasoningParamValues: {'reasoning_effort': 'medium'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // When effort toggle is off, show "推理" even if value is in map
      expect(find.text('推理'), findsOneWidget);
      expect(find.text('medium'), findsNothing);
    });

    testWidgets('shows 推理 when reasoning enabled but no param values set',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        reasoningParamValues: {},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // When no param values are set, show "推理" in purple
      expect(find.text('推理'), findsOneWidget);
    });

    testWidgets('shows 推理 in gray when reasoning disabled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: false,
        reasoningEffortEnabled: false,
        reasoningParamValues: {'reasoning_effort': 'medium'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      expect(find.text('推理'), findsOneWidget);
    });

    testWidgets(
        'chip color is purple when reasoning enabled with params and effort',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        reasoningParamValues: {'reasoning_effort': 'medium'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Find the chip by its label "medium"
      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == 'medium',
      );
      expect(chip, findsOneWidget);
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.color, Colors.purple);
    });

    testWidgets('chip color is purple when reasoning enabled without effort',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: false,
        reasoningParamValues: {},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Find the chip by its label "推理"
      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '推理',
      );
      expect(chip, findsOneWidget);
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.color, Colors.purple);
    });

    testWidgets('chip color is grey when reasoning disabled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: false,
        reasoningEffortEnabled: false,
        reasoningParamValues: {'reasoning_effort': 'medium'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '推理',
      );
      expect(chip, findsOneWidget);
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.color, Colors.grey);
    });

    testWidgets('shows non-default effort value (high) when enabled',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        reasoningParamValues: {'reasoning_effort': 'high'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Should show 'high' (the actual effort value), not 'medium'
      expect(find.text('high'), findsOneWidget);
      expect(find.text('medium'), findsNothing);
      expect(find.text('推理'), findsNothing);
    });

    testWidgets('shows low effort value when set', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        reasoningParamValues: {'reasoning_effort': 'low'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      expect(find.text('low'), findsOneWidget);
      expect(find.text('medium'), findsNothing);
    });

    testWidgets('shows reasoning_effort value specifically, not other params',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        reasoningParamValues: {
          'thinking.type': 'enabled',
          'reasoning_effort': 'high',
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Should show 'reasoning_effort' value ('high'), not 'thinking.type'
      expect(find.text('high'), findsOneWidget);
      expect(find.text('enabled'), findsNothing);
      expect(find.text('推理'), findsNothing);
    });

    testWidgets(
        'shows 推理 when reasoning enabled but reasoning_effort not in map',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        reasoningParamValues: {'thinking.type': 'enabled'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // When reasoning_effort is not in the map, show "推理" in purple
      expect(find.text('推理'), findsOneWidget);
      expect(find.text('enabled'), findsNothing);
    });

    // ═══════════════════════════════════════════════════════════
    // Tool chip accent color & zero-tools grey-state tests
    // ═══════════════════════════════════════════════════════════

    testWidgets('tool chip uses accent color when tools are enabled',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: false,
        reasoningEffortEnabled: false,
        enabledTools: {'some_tool'},
        mcpTools: const [
          ToolDefinition(
            name: 'some_tool',
            description: '',
            parameters: {},
          ),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      expect(find.byIcon(Icons.build_outlined), findsOneWidget);
      final toolChip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '工具',
      );
      expect(toolChip, findsOneWidget);
      final chip = tester.widget<SettingsChip>(toolChip);
      expect(chip.color, const Color(0xFF6366F1));
      expect(chip.badgeCount, 1);
    });

    testWidgets('tool chip shows badge count for multiple enabled tools',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: false,
        reasoningEffortEnabled: false,
        enabledTools: {'brave_web_search', 'bocha_web_search'},
        mcpTools: const [
          ToolDefinition(
            name: 'brave_web_search',
            description: '',
            parameters: {},
          ),
          ToolDefinition(
            name: 'bocha_web_search',
            description: '',
            parameters: {},
          ),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      final toolChip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '工具',
      );
      expect(toolChip, findsOneWidget);
      final chip = tester.widget<SettingsChip>(toolChip);
      expect(chip.color, const Color(0xFF6366F1));
      expect(chip.badgeCount, 2);
    });

    testWidgets(
        'tool chip turns grey and hides badge when no tools are enabled',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: false,
        reasoningEffortEnabled: false,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      expect(find.byIcon(Icons.build_outlined), findsOneWidget);
      final toolChip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '工具',
      );
      expect(toolChip, findsOneWidget);
      final chip = tester.widget<SettingsChip>(toolChip);
      expect(chip.color, Colors.grey);
      expect(chip.badgeCount, isNull);
    });

    testWidgets(
        'tool chip ignores enabled tools that are not in the selectable list '
        '(hidden MCP tools)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: false,
        reasoningEffortEnabled: false,
        // 已启用但不在可选择列表中的工具（被显示开关/总开关隐藏的 MCP
        // 工具）不计入徽标，chip 保持灰色。
        enabledTools: {'hidden_mcp'},
        mcpTools: const [
          ToolDefinition(
            name: 'visible_tool',
            description: '',
            parameters: {},
          ),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      final toolChip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '工具',
      );
      expect(toolChip, findsOneWidget);
      final chip = tester.widget<SettingsChip>(toolChip);
      expect(chip.color, Colors.grey);
      expect(chip.badgeCount, isNull);
    });

    // ═══════════════════════════════════════════════════════════
    // Custom params chip accent color & badge tests
    // ═══════════════════════════════════════════════════════════

    testWidgets(
        'custom params chip uses accent color and shows badge when a custom '
        'param is enabled with a selected value', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        enabledTools: {}, // no tools enabled — custom params are independent
        extraReasoningParams: [
          ReasoningParam(
            paramName: 'budget_tokens',
            enabled: true,
            options: ['5000', '10000'],
          ),
        ],
        reasoningParamValues: {
          'reasoning_effort': 'medium',
          'budget_tokens': '5000',
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      final customChip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      expect(customChip, findsOneWidget);
      final chip = tester.widget<SettingsChip>(customChip);
      expect(chip.color, const Color(0xFF6366F1));
      expect(chip.badgeCount, 1);
    });

    testWidgets(
        'custom params chip shows no badge when no custom param is active '
        'even with tools enabled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        enabledTools: {'some_tool'},
        extraReasoningParams: [
          ReasoningParam(
            paramName: 'budget_tokens',
            enabled: true,
            options: ['5000', '10000'],
          ),
        ],
        reasoningParamValues: {
          'reasoning_effort': 'medium',
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      final customChip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      expect(customChip, findsOneWidget);
      final chip = tester.widget<SettingsChip>(customChip);
      // No custom param has a selected value → grey chip, no badge
      expect(chip.badgeCount, isNull);
    });

    testWidgets(
        'custom params chip turns grey when no custom params are active',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        enabledTools: {
          'some_tool'
        }, // tools enabled but still grey (no active custom params)
        reasoningParamValues: {
          'reasoning_effort': 'medium',
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      final customChip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      expect(customChip, findsOneWidget);
      final chip = tester.widget<SettingsChip>(customChip);
      // No active custom params → grey chip, no badge
      expect(chip.color, Colors.grey);
      expect(chip.badgeCount, isNull);
    });

    testWidgets(
        'custom params chip lights up when a value is selected even if the '
        'param was created disabled', (tester) async {
      // 已选值即运行时开关状态（面板切换通过写入/移除参数值生效），
      // 配置里的 enabled 只是新建参数的默认状态。
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        extraReasoningParams: [
          ReasoningParam(
            paramName: 'budget_tokens',
            enabled: false, // created disabled — runtime state is the value
            options: ['5000', '10000'],
          ),
        ],
        reasoningParamValues: {
          'reasoning_effort': 'medium',
          'budget_tokens': '5000',
        },
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      final customChip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      final chip = tester.widget<SettingsChip>(customChip);
      expect(chip.color, const Color(0xFF6366F1));
      expect(chip.badgeCount, 1);
    });

    testWidgets('shows 推理 when no effort param exists (isEffortParam=false)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reasoningEnabledProvider.overrideWith((ref) => true),
            reasoningEffortEnabledProvider.overrideWith((ref) => false),
            reasoningParamValuesProvider.overrideWith(
              (ref) => {'reasoning_effort': 'medium'},
            ),
            conversationsProvider.overrideWith((ref) {
              return ConversationsNotifier(ref);
            }),
            activeConversationIdProvider.overrideWith(
              (ref) => 'test-conv-id',
            ),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatComposerWidget(
                onSend: (text, attachments) {},
                onStop: () {},
                modelNames: ['test-model'],
                selectedModelIndex: 0,
                onModelSelected: (idx) {},
                onEnabledToolsChanged: (tools) {},
                reasoningParams: [
                  ReasoningParam(
                    paramName: 'reasoning_effort',
                    isEffortParam: false,
                    options: ['low', 'medium', 'high'],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // When no param has isEffortParam=true, show "推理"
      expect(find.text('推理'), findsOneWidget);
      expect(find.text('medium'), findsNothing);
    });

    testWidgets(
        'shows the effort value when a value is selected even if the param '
        'was created disabled', (tester) async {
      // 已选值即运行时开关状态（与附加参数一致），配置里的 enabled 只是
      // 新建参数的默认状态。
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reasoningEnabledProvider.overrideWith((ref) => true),
            reasoningEffortEnabledProvider.overrideWith((ref) => true),
            reasoningParamValuesProvider.overrideWith(
              (ref) => {'reasoning_effort': 'medium'},
            ),
            conversationsProvider.overrideWith((ref) {
              return ConversationsNotifier(ref);
            }),
            activeConversationIdProvider.overrideWith(
              (ref) => 'test-conv-id',
            ),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatComposerWidget(
                onSend: (text, attachments) {},
                onStop: () {},
                modelNames: ['test-model'],
                selectedModelIndex: 0,
                onModelSelected: (idx) {},
                onEnabledToolsChanged: (tools) {},
                reasoningParams: [
                  ReasoningParam(
                    paramName: 'reasoning_effort',
                    isEffortParam: true,
                    enabled: false,
                    options: ['low', 'medium', 'high'],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // 有已选值即视为运行时激活：chip 显示该值
      expect(find.text('medium'), findsOneWidget);
      expect(find.text('推理'), findsNothing);
    });

    testWidgets(
        'shows effort value for legacy models without the isEffortParam flag',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reasoningEnabledProvider.overrideWith((ref) => true),
            reasoningEffortEnabledProvider.overrideWith((ref) => true),
            reasoningParamValuesProvider.overrideWith(
              (ref) => {'reasoning_effort': 'high'},
            ),
            conversationsProvider.overrideWith((ref) {
              return ConversationsNotifier(ref);
            }),
            activeConversationIdProvider.overrideWith(
              (ref) => 'test-conv-id',
            ),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatComposerWidget(
                onSend: (text, attachments) {},
                onStop: () {},
                modelNames: ['test-model'],
                selectedModelIndex: 0,
                onModelSelected: (idx) {},
                onEnabledToolsChanged: (tools) {},
                // Legacy data: reasoning params saved before the
                // isEffortParam flag existed (no key in the map).
                reasoningParams: [
                  ReasoningParam.fromMap({
                    'paramName': 'thinking.type',
                    'options': <String>[],
                    'enabled': true,
                    'isReasoningToggle': true,
                    'onValue': 'enabled',
                    'offValue': 'disabled',
                    'type': 'string',
                  }),
                  ReasoningParam.fromMap({
                    'paramName': 'reasoning_effort',
                    'options': ['low', 'medium', 'high'],
                    'enabled': true,
                    'isReasoningToggle': false,
                    'type': 'string',
                  }),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Pre-flag semantics: the first non-toggle param IS the effort param,
      // so its selected value shows on the chip.
      expect(find.text('high'), findsOneWidget);
      expect(find.text('推理'), findsNothing);
    });

    testWidgets(
        'chip shows 推理 (not stale value) when effort param has no options',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reasoningEnabledProvider.overrideWith((ref) => true),
            reasoningEffortEnabledProvider.overrideWith((ref) => true),
            reasoningParamValuesProvider.overrideWith(
              (ref) => {'reasoning_effort': 'high'},
            ),
            conversationsProvider.overrideWith((ref) {
              return ConversationsNotifier(ref);
            }),
            activeConversationIdProvider.overrideWith(
              (ref) => 'test-conv-id',
            ),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatComposerWidget(
                onSend: (text, attachments) {},
                onStop: () {},
                modelNames: ['test-model'],
                selectedModelIndex: 0,
                onModelSelected: (idx) {},
                onEnabledToolsChanged: (tools) {},
                // 力度参数仅声明参数名（无选项值）：即使 map 残留旧值，
                // 面板开关灰色不可用，chip 同样不得显示该旧值。
                reasoningParams: [
                  ReasoningParam(
                    paramName: 'reasoning_effort',
                    isEffortParam: true,
                    options: [],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // 无选项值 → 不可用：显示「推理」（灰色），不显示残留的 'high'
      expect(find.text('推理'), findsOneWidget);
      expect(find.text('high'), findsNothing);
      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '推理',
      );
      expect(chip, findsOneWidget);
      expect(tester.widget<SettingsChip>(chip).color, Colors.grey);
    });

    testWidgets(
        'chip shows 推理 (grey) when no usable reasoning params even if '
        'reasoning flag is on', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reasoningEnabledProvider.overrideWith((ref) => true),
            reasoningEffortEnabledProvider.overrideWith((ref) => false),
            reasoningParamValuesProvider.overrideWith(
              (ref) => {'reasoning_effort': 'high'},
            ),
            conversationsProvider.overrideWith((ref) {
              return ConversationsNotifier(ref);
            }),
            activeConversationIdProvider.overrideWith(
              (ref) => 'test-conv-id',
            ),
            providerEntriesProvider.overrideWith((ref) {
              return ProviderEntriesNotifier();
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatComposerWidget(
                onSend: (text, attachments) {},
                onStop: () {},
                modelNames: ['test-model'],
                selectedModelIndex: 0,
                onModelSelected: (idx) {},
                onEnabledToolsChanged: (tools) {},
                // 唯一参数是仅声明参数名（无选项值、非布尔）的力度参数：
                // 没有可用设置 → chip 灰色不可用（推理开启标记不生效）。
                reasoningParams: [
                  ReasoningParam(
                    paramName: 'reasoning_effort',
                    isEffortParam: true,
                    options: [],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      expect(find.text('推理'), findsOneWidget);
      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '推理',
      );
      expect(chip, findsOneWidget);
      expect(tester.widget<SettingsChip>(chip).color, Colors.grey);
    });
  });
}
