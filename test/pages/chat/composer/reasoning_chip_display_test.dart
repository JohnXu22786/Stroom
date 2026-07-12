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
///   - When reasoning is enabled and 'reasoning_effort' key is present:
///     shows that value (the 推理力度 from model config).
///   - When reasoning is enabled but 'reasoning_effort' is absent:
///     shows '推理' (purple, on state).
///   - When reasoning is disabled: shows '推理' (grey).
Widget createComposerTestApp({
  required bool reasoningEnabled,
  Map<String, String> reasoningParamValues = const {},
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      reasoningEnabledProvider.overrideWith((ref) => reasoningEnabled),
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
          reasoningParams: [
            ReasoningParam(
                paramName: 'reasoning_effort',
                options: ['low', 'medium', 'high']),
          ],
          hasReasoningParams: true,
        ),
      ),
    ),
  );
}

void main() {
  group('Composer reasoning chip label', () {
    testWidgets('shows effort value when reasoning enabled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningParamValues: {'reasoning_effort': 'medium'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Should show the effort level when reasoning is enabled
      // The label shows the actual effort value ('medium')
      expect(find.text('medium'), findsOneWidget);
      expect(find.text('推理'), findsNothing);
    });

    testWidgets('shows 推理 when reasoning enabled but no param values set',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
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
        reasoningParamValues: {'reasoning_effort': 'medium'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      expect(find.text('推理'), findsOneWidget);
    });

    testWidgets('chip color is purple when reasoning enabled with params',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
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

    testWidgets('chip color is purple when reasoning enabled without params',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
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

    testWidgets('shows non-default effort value (high) when reasoning enabled',
        (tester) async {
      // This test validates that the chip label reflects the actual
      // reasoningParamValues provider value (not hard-coded 'medium').
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
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
      // When multiple reasoning params exist, the chip should specifically
      // show the 'reasoning_effort' value (the "推理力度" from model config),
      // not any other param's value.
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
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
        reasoningParamValues: {'thinking.type': 'enabled'},
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // When reasoning_effort is not in the map, show "推理" in purple
      expect(find.text('推理'), findsOneWidget);
      expect(find.text('enabled'), findsNothing);
    });
  });
}
