import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/pages/chat/composer/composer_shared.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';

/// Behavior tests for the panel ↔ reasoningParamValuesProvider sync:
/// - Enabling a custom param switch (or the effort toggle) writes the
///   default option (options.first) into the map, so the chip shows the
///   value and the request actually sends the param.
/// - Disabling the switch / toggle removes the value, so the chip goes
///   grey and the param stops being sent.
Widget createComposerTestApp({
  required List<ReasoningParam> reasoningParams,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      reasoningEnabledProvider.overrideWith((ref) => true),
      reasoningEffortEnabledProvider.overrideWith((ref) => false),
      reasoningParamValuesProvider.overrideWith((ref) => const {}),
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
          reasoningParams: reasoningParams,
        ),
      ),
    ),
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
  // Factories, not shared instances: the panel mutates the param's
  // `enabled` flag in place, so reusing one object across tests would
  // leak state between tests.
  ReasoningParam effortParam() => ReasoningParam(
        paramName: 'reasoning_effort',
        isEffortParam: true,
        options: ['low', 'medium', 'high'],
      );

  ReasoningParam customParam() => ReasoningParam(
        paramName: 'budget_tokens',
        enabled: false,
        options: ['5000', '10000'],
      );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
          tester.element(find.byType(ChatComposerWidget)));

  group('Custom params panel switch syncs the value map', () {
    testWidgets('switch ON writes the default option into the map',
        (tester) async {
      await pumpComposer(
        tester,
        createComposerTestApp(reasoningParams: [effortParam(), customParam()]),
      );

      // Open the custom params panel
      await tester.tap(find.text('自定义参数'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Custom param switch exists (off initially)
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isFalse);

      // Turn the switch on
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = containerOf(tester);
      expect(container.read(reasoningParamValuesProvider),
          {'budget_tokens': '5000'});
    });

    testWidgets('switch OFF removes the value from the map', (tester) async {
      await pumpComposer(
        tester,
        createComposerTestApp(reasoningParams: [effortParam(), customParam()]),
      );

      await tester.tap(find.text('自定义参数'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Turn on, then off
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final container = containerOf(tester);
      expect(container.read(reasoningParamValuesProvider),
          {'budget_tokens': '5000'});

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(reasoningParamValuesProvider), isEmpty);
    });

    testWidgets(
        'stale value keeps the chip active without config write-through',
        (tester) async {
      // 已选值即运行时开关状态：即使参数创建时 enabled=false（从未
      // 在配置页激活），存在已选值就视为激活，chip 点亮且请求发送
      // （激活状态可跨重启保留，无需写穿共享配置对象）。
      SharedPreferences.setMockInitialValues({});
      final staleApp = ProviderScope(
        overrides: [
          reasoningEnabledProvider.overrideWith((ref) => true),
          reasoningEffortEnabledProvider.overrideWith((ref) => false),
          reasoningParamValuesProvider.overrideWith(
            (ref) => const {'budget_tokens': '5000'},
          ),
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
              reasoningParams: [effortParam(), customParam()],
            ),
          ),
        ),
      );
      await pumpComposer(tester, staleApp);

      // Chip 已点亮（有已选值，参数视为运行时激活）
      final litChip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      expect(
        tester.widget<SettingsChip>(litChip).color,
        const Color(0xFF6366F1),
      );

      await tester.tap(find.text('自定义参数'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 开关显示为开（有已选值）
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 先关后开：关闭移除值，重新开启时写入默认选项值
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 值被重新写入，chip 保持点亮
      final container = containerOf(tester);
      expect(container.read(reasoningParamValuesProvider),
          {'budget_tokens': '5000'});
      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '自定义参数',
      );
      expect(tester.widget<SettingsChip>(chip).color, const Color(0xFF6366F1));
    });
  });

  group('Reasoning panel effort toggle syncs the value map', () {
    testWidgets('effort toggle ON writes the default option into the map',
        (tester) async {
      await pumpComposer(
        tester,
        createComposerTestApp(reasoningParams: [effortParam()]),
      );

      await tester.tap(find.text('推理'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Two switches: reasoning toggle (on) + effort toggle (off)
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.length, greaterThanOrEqualTo(2));
      expect(switches[0].value, isTrue);
      expect(switches[1].value, isFalse);

      await tester.tap(find.byWidget(switches[1]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = containerOf(tester);
      expect(container.read(reasoningParamValuesProvider),
          {'reasoning_effort': 'low'});
    });

    testWidgets('effort toggle OFF removes the value from the map',
        (tester) async {
      await pumpComposer(
        tester,
        createComposerTestApp(reasoningParams: [effortParam()]),
      );

      await tester.tap(find.text('推理'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      var switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      await tester.tap(find.byWidget(switches[1]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = containerOf(tester);
      expect(container.read(reasoningParamValuesProvider),
          {'reasoning_effort': 'low'});

      // Toggle off again
      switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      await tester.tap(find.byWidget(switches[1]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(reasoningParamValuesProvider), isEmpty);
    });

    testWidgets('effort toggle ON keeps an already-selected non-default value',
        (tester) async {
      // Seed the map with a non-default value, then toggle effort off and on.
      SharedPreferences.setMockInitialValues({});
      final seededApp = ProviderScope(
        overrides: [
          reasoningEnabledProvider.overrideWith((ref) => true),
          reasoningEffortEnabledProvider.overrideWith((ref) => false),
          reasoningParamValuesProvider.overrideWith(
            (ref) => const {'reasoning_effort': 'high'},
          ),
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
              reasoningParams: [effortParam()],
            ),
          ),
        ),
      );
      await pumpComposer(tester, seededApp);

      await tester.tap(find.text('推理'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Effort toggle on → the existing 'high' value is preserved
      var switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      await tester.tap(find.byWidget(switches[1]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = containerOf(tester);
      expect(container.read(reasoningParamValuesProvider),
          {'reasoning_effort': 'high'});
    });
  });
}
