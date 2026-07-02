import 'dart:async';
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
Widget createComposerTestApp({
  required bool reasoningEnabled,
  required String reasoningEffort,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      reasoningEnabledProvider.overrideWith((ref) => reasoningEnabled),
      reasoningEffortProvider.overrideWith((ref) => reasoningEffort),
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
            ReasoningParam(paramName: 'reasoning_effort', options: ['low', 'medium', 'high']),
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
        reasoningEffort: 'medium',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Should show the effort level when reasoning is enabled
      // The label shows the actual effort value ('medium')
      expect(find.text('medium'), findsOneWidget);
      expect(find.text('推理'), findsNothing);
    });

    testWidgets('shows 推理 when reasoning enabled but effort is empty',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffort: '',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      expect(find.text('推理'), findsOneWidget);
    });

    testWidgets('shows 推理 in gray when reasoning disabled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: false,
        reasoningEffort: 'medium',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      expect(find.text('推理'), findsOneWidget);
    });

    testWidgets('chip color is purple when reasoning enabled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: true,
        reasoningEffort: 'medium',
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

    testWidgets('chip color is grey when reasoning disabled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      await tester.pumpWidget(createComposerTestApp(
        reasoningEnabled: false,
        reasoningEffort: 'medium',
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
  });
}
