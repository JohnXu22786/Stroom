import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/chat_composer_widget.dart';
import 'package:stroom/pages/chat/composer/composer_shared.dart';
import 'package:stroom/pages/chat/chat_types.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/pages/chat_page.dart';

/// Helper that creates a MaterialApp wrapped in ProviderScope with
/// all providers needed to render ChatPage, with overrides for reasoning state.
Widget createReasoningTestApp({
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
    child: const MaterialApp(home: ChatPage()),
  );
}

void main() {
  group('Reasoning chip display label', () {
    Future<void> setupSurface(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
    }

    testWidgets('shows effort value when reasoning enabled with effort param',
        (tester) async {
      await setupSurface(tester);
      await tester.pumpWidget(createReasoningTestApp(
        reasoningEnabled: true,
        reasoningEffort: 'medium',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Should show just "medium" (not "推理 medium")
      expect(find.text('medium'), findsOneWidget);
    });

    testWidgets('shows 推理 when reasoning enabled without effort param',
        (tester) async {
      await setupSurface(tester);
      await tester.pumpWidget(createReasoningTestApp(
        reasoningEnabled: true,
        reasoningEffort: '',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Should show "推理" when no effort param
      expect(find.text('推理'), findsOneWidget);
    });

    testWidgets('shows 推理 when reasoning disabled', (tester) async {
      await setupSurface(tester);
      await tester.pumpWidget(createReasoningTestApp(
        reasoningEnabled: false,
        reasoningEffort: 'medium',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Should show "推理" when reasoning is disabled
      expect(find.text('推理'), findsOneWidget);
    });

    testWidgets('chip passes purple color when reasoning enabled',
        (tester) async {
      await setupSurface(tester);
      await tester.pumpWidget(createReasoningTestApp(
        reasoningEnabled: true,
        reasoningEffort: 'medium',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Find the SettingsChip with label "medium"
      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == 'medium',
      );
      expect(chip, findsOneWidget);

      // Verify the chip uses purple color
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.color, Colors.purple);
    });

    testWidgets('chip passes grey color when reasoning disabled',
        (tester) async {
      await setupSurface(tester);
      await tester.pumpWidget(createReasoningTestApp(
        reasoningEnabled: false,
        reasoningEffort: 'medium',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      tester.takeException();

      // Find the SettingsChip with label "推理"
      final chip = find.byWidgetPredicate(
        (w) => w is SettingsChip && w.label == '推理',
      );
      expect(chip, findsOneWidget);

      // Verify the chip uses grey color
      final settingsChip = tester.widget<SettingsChip>(chip);
      expect(settingsChip.color, Colors.grey);
    });
  });
}
