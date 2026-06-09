import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/pages/assistant_selection_page.dart';
import 'package:stroom/pages/topic_selection_page.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/widgets/llm/assistant_avatar.dart';

/// Creates a test app wrapped in ProviderScope with optional overrides.
Widget createTestApp({
  List<Assistant>? assistants,
  String? selectedAssistantId,
  Widget? home,
  Map<String, WidgetBuilder>? extraRoutes,
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
        selectedAssistantIdProvider
            .overrideWith((ref) => selectedAssistantId),
    ],
    child: MaterialApp(
      home: home ?? const AssistantSelectionPage(),
      routes: {
        '/topic-selection': (_) => const TopicSelectionPage(),
        if (extraRoutes != null) ...extraRoutes,
      },
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
          Assistant(
              name: '助手1',
              prompt: 'P1',
              emoji: '🤖',
              description: '第一个助手'),
          Assistant(
              name: '助手2',
              prompt: 'P2',
              emoji: '😊',
              description: '第二个助手'),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('助手1'), findsOneWidget);
      expect(find.text('助手2'), findsOneWidget);
      expect(find.text('🤖'), findsOneWidget);
      expect(find.text('😊'), findsOneWidget);
    });

    testWidgets('tapping assistant navigates to topic selection',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(
              name: '助手1',
              prompt: 'P1',
              emoji: '🤖',
              description: '第一个助手'),
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
              notifier.createAssistant(
                  name: '测试助手', prompt: 'P1', emoji: '🤖');
              return notifier;
            }),
            selectedAssistantIdProvider
                .overrideWith((ref) => 'a1'),
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
  });

  group('AssistantAvatar in pages', () {
    testWidgets('assistant card uses AssistantAvatar widget', (tester) async {
      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(
            name: '助手1',
            prompt: 'P1',
            emoji: '🤖',
            description: '第一个助手',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Should render AssistantAvatar widget
      expect(find.byType(AssistantAvatar), findsOneWidget);
      // Should show the emoji inside the avatar
      expect(find.text('🤖'), findsOneWidget);
    });

    testWidgets('create dialog has avatar type toggle and image URL input',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(
            name: '测试助手',
            prompt: 'P1',
            emoji: '🤖',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Tap the add button in the app bar to open create dialog
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Should have the SegmentedButton for avatar type selection
      expect(find.text('表情'), findsAtLeastNWidgets(1));
      expect(find.text('图片'), findsOneWidget);

      // Switch to image mode
      await tester.tap(find.text('图片'));
      await tester.pumpAndSettle();

      // Now the image URL field should be visible
      expect(find.text('头像图片URL（可选）'), findsOneWidget);
    });

    testWidgets('settings dialog has extended params sections',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(
            name: '助手1',
            prompt: 'P1',
            emoji: '🤖',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Long-press to open menu
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();

      // Tap 设置
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      // Should see the extended param labels
      expect(find.text('频率惩罚 (Frequency Penalty)'), findsOneWidget);
      expect(find.text('存在惩罚 (Presence Penalty)'), findsOneWidget);
    });
  });
}
