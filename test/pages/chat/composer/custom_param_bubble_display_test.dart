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
/// the composer widget in isolation.
///
/// The '自定义参数' chip reflects the session state of the model's custom
/// reasoning params (non-toggle, non-effort): a param counts as ACTIVE
/// when it has a name, its switch is on (enabled), and a value was
/// selected for it in [reasoningParamValues]. The chip shows the accent
/// color and a badge with the active count; otherwise it is grey with no
/// badge. This is independent of the tool enabled state.
Widget createComposerTestApp({
  Set<String> enabledTools = const {},
  Map<String, String> reasoningParamValues = const {},
  List<ReasoningParam> reasoningParams = const [],
  bool reasoningEnabled = true,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      reasoningEnabledProvider.overrideWith((ref) => reasoningEnabled),
      reasoningEffortEnabledProvider.overrideWith((ref) => true),
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
              options: ['low', 'medium', 'high'],
            ),
            ...reasoningParams,
          ],
        ),
      ),
    ),
  );
}

ReasoningParam customParam(
  String name, {
  bool enabled = true,
  List<String> options = const ['a', 'b'],
}) {
  return ReasoningParam(
    paramName: name,
    enabled: enabled,
    options: options,
  );
}

Future<void> pumpComposer(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2000));
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  tester.takeException();
}

void main() {
  group('Custom params chip reflects active custom params', () {
    testWidgets(
        'accent color + badge when a custom param is enabled with a value',
        (tester) async {
      await pumpComposer(
        tester,
        createComposerTestApp(
          reasoningParams: [customParam('budget_tokens')],
          reasoningParamValues: {'budget_tokens': 'a'},
        ),
      );

      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      expect(chip, findsOneWidget);
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.color, const Color(0xFF6366F1));
      expect(settingsChip.badgeCount, 1);
    });

    testWidgets('badge counts multiple active custom params', (tester) async {
      await pumpComposer(
        tester,
        createComposerTestApp(
          reasoningParams: [
            customParam('budget_tokens'),
            customParam('thinking.type'),
          ],
          reasoningParamValues: {
            'budget_tokens': 'a',
            'thinking.type': 'b',
          },
        ),
      );

      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.color, const Color(0xFF6366F1));
      expect(settingsChip.badgeCount, 2);
    });

    testWidgets('grey + no badge when no custom params are active',
        (tester) async {
      await pumpComposer(
        tester,
        createComposerTestApp(
          reasoningParams: [customParam('budget_tokens')],
          reasoningParamValues: {},
        ),
      );

      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.color, Colors.grey);
      expect(settingsChip.badgeCount, isNull);
    });

    testWidgets('active + badge when a value is selected even if the param '
        'was created disabled', (tester) async {
      // 已选值即运行时开关状态（面板切换通过写入/移除参数值生效），
      // 配置里的 enabled 只是新建参数的默认状态。
      await pumpComposer(
        tester,
        createComposerTestApp(
          reasoningParams: [
            customParam('budget_tokens', enabled: false),
          ],
          reasoningParamValues: {'budget_tokens': 'a'},
        ),
      );

      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.color, const Color(0xFF6366F1));
      expect(settingsChip.badgeCount, 1);
    });

    testWidgets('effort param value does not count toward the custom badge',
        (tester) async {
      await pumpComposer(
        tester,
        createComposerTestApp(
          reasoningParams: [customParam('budget_tokens')],
          reasoningParamValues: {
            'reasoning_effort': 'high',
            'budget_tokens': 'a',
          },
        ),
      );

      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.badgeCount, 1,
          reason: 'only the custom param counts, not the effort value');
    });

    testWidgets('empty-named custom params are excluded', (tester) async {
      await pumpComposer(
        tester,
        createComposerTestApp(
          reasoningParams: [
            customParam(''),
            customParam('budget_tokens'),
          ],
          reasoningParamValues: {'budget_tokens': 'a'},
        ),
      );

      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.badgeCount, 1);
    });

    testWidgets('chip state is independent of the tool enabled state',
        (tester) async {
      await pumpComposer(
        tester,
        createComposerTestApp(
          enabledTools: {'web_search'},
          reasoningParams: [customParam('budget_tokens')],
          reasoningParamValues: {'budget_tokens': 'a'},
        ),
      );

      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.color, const Color(0xFF6366F1));
      expect(settingsChip.badgeCount, 1);
    });

    testWidgets(
        'chip is grey when reasoning is off even with active custom params '
        '(nothing is sent)', (tester) async {
      await pumpComposer(
        tester,
        createComposerTestApp(
          reasoningEnabled: false,
          reasoningParams: [customParam('budget_tokens')],
          reasoningParamValues: {'budget_tokens': 'a'},
        ),
      );

      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.color, Colors.grey);
      expect(settingsChip.badgeCount, isNull);
    });
  });
}
