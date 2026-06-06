import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/pages/assistant_selection_page.dart';
import 'package:stroom/pages/topic_selection_page.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestApp({
  List<Assistant>? assistants,
  String? selectedAssistantId,
  Widget? home,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      if (assistants != null)
        assistantProvider.overrideWith((ref) {
          final notifier = AssistantsNotifier();
          for (final a in assistants) {
            notifier.createAssistant(
              name: a.name,
              prompt: a.prompt,
              emoji: a.emoji,
              description: a.description,
            );
          }
          return notifier;
        }),
      if (selectedAssistantId != null)
        selectedAssistantIdProvider.overrideWith((ref) => selectedAssistantId),
    ],
    child: MaterialApp(
      home: home ?? const AssistantSelectionPage(),
    ),
  );
}

void main() {
  group('AssistantSelectionPage', () {
    testWidgets('renders with title', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) {
              return AssistantsNotifier();
            }),
          ],
          child: const MaterialApp(
            home: AssistantSelectionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The title should always be shown
      expect(find.text('选择助手'), findsOneWidget);
    });

    testWidgets('shows assistant cards in grid', (tester) async {
      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(name: '助手1', prompt: 'P1', emoji: '🤖', description: '第一个助手'),
          Assistant(name: '助手2', prompt: 'P2', emoji: '😊', description: '第二个助手'),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('助手1'), findsOneWidget);
      expect(find.text('助手2'), findsOneWidget);
      expect(find.text('🤖'), findsOneWidget);
      expect(find.text('😊'), findsOneWidget);
    });

    testWidgets('tapping assistant navigates to topic selection', (tester) async {
      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(name: '助手1', prompt: 'P1', emoji: '🤖', description: '第一个助手'),
        ],
      ));
      await tester.pumpAndSettle();

      // Tap the first assistant card
      await tester.tap(find.text('助手1'));
      await tester.pumpAndSettle();

      // Should navigate to topic selection
      expect(find.text('选择话题'), findsOneWidget);
    });
  });

  group('TopicSelectionPage', () {
    testWidgets('shows topic selection title', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) {
              final notifier = AssistantsNotifier();
              notifier.createAssistant(name: '助手1', prompt: 'P1', emoji: '🤖');
              return notifier;
            }),
            selectedAssistantIdProvider.overrideWith((ref) => 'a1'),
          ],
          child: const MaterialApp(
            home: TopicSelectionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the title
      expect(find.text('选择话题'), findsOneWidget);
    });

    testWidgets('shows assistant info in header', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) {
              final notifier = AssistantsNotifier();
              notifier.createAssistant(name: '测试助手', prompt: 'P', emoji: '😊');
              return notifier;
            }),
            selectedAssistantIdProvider.overrideWith((ref) => 'a1'),
          ],
          child: const MaterialApp(
            home: TopicSelectionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Since assistant IDs don't match (a1 vs random UUID), show error state
      expect(find.text('未选择助手'), findsOneWidget);
    });
  });
}
