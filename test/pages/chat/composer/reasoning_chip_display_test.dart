import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
Widget createComposerTestApp({
  required bool reasoningEnabled,
  required bool reasoningEffortEnabled,
  Map<String, String> reasoningParamValues = const {},
  Set<String> enabledTools = const {},
  List<ReasoningParam> extraReasoningParams = const [],
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

    // ═══════════════════════════════════════════════════════════
    // Custom params chip accent color & badge tests
    // ═══════════════════════════════════════════════════════════

    testWidgets(
        'custom params chip uses accent color and shows badge when params active and tools enabled',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        enabledTools: {'some_tool'},
        reasoningParamValues: {
          'reasoning_effort': 'medium',
          'custom_param_1': 'value1',
        },
        extraReasoningParams: [
          ReasoningParam(
            paramName: 'custom_param_1',
            isEffortParam: false,
            isReasoningToggle: false,
            options: ['value1', 'value2'],
          ),
        ],
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
        'custom params chip with no active params shows no badge when tools enabled',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        enabledTools: {'some_tool'},
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
      // No non-effort/non-toggle params have values, so badgeCount should be null
      expect(chip.badgeCount, isNull);
    });

    testWidgets('custom params chip turns grey when no tools are enabled',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffortEnabled: true,
        reasoningParamValues: {
          'reasoning_effort': 'medium',
          'custom_param_1': 'value1',
        },
        extraReasoningParams: [
          ReasoningParam(
            paramName: 'custom_param_1',
            isEffortParam: false,
            isReasoningToggle: false,
            options: ['value1', 'value2'],
          ),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      final customChip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      expect(customChip, findsOneWidget);
      final chip = tester.widget<SettingsChip>(customChip);
      expect(chip.color, Colors.grey);
      expect(chip.badgeCount, isNull);
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
  });
}
