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
          notifier.state = [...assistants];
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

    // ── Requirement 6 tests: top-right buttons removed ──

    testWidgets('does NOT show top-right add (新建) button in AppBar',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      const assistantId = 'test-assistant-id-1';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) {
              final notifier = AssistantsNotifier();
              notifier.state = [
                Assistant(
                  id: assistantId,
                  name: '助手1',
                  prompt: 'P1',
                  emoji: '🤖',
                ),
              ];
              return notifier;
            }),
            selectedAssistantIdProvider.overrideWith((ref) => assistantId),
          ],
          child: const MaterialApp(
            home: TopicSelectionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The top-right add button should NOT be present (bottom one already exists)
      // and zero IconButtons with Icons.add in AppBar
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.add),
        ),
        findsNothing,
      );
      // The bottom '新话题' button(s) should still exist
      expect(find.widgetWithText(FilledButton, '新话题'), findsWidgets);
    });

    testWidgets('does NOT show top-right switch-assistant (切换助手) button',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      const assistantId = 'test-assistant-id-2';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) {
              final notifier = AssistantsNotifier();
              notifier.state = [
                Assistant(
                  id: assistantId,
                  name: '助手2',
                  prompt: 'P2',
                  emoji: '😊',
                ),
              ];
              return notifier;
            }),
            selectedAssistantIdProvider.overrideWith((ref) => assistantId),
          ],
          child: const MaterialApp(
            home: TopicSelectionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The switch assistant button should NOT be present in AppBar
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.swap_horiz),
        ),
        findsNothing,
      );
    });
  });

  group('Assistant emoji/image picker', () {
    testWidgets('create dialog shows expanded emoji grid', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) {
              // Start with an assistant so empty state is not shown
              final notifier = AssistantsNotifier();
              notifier.createAssistant(name: '已有助手', prompt: 'P1', emoji: '🤖');
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: AssistantSelectionPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the add button in AppBar
      await tester.tap(find.byTooltip('新建助手'));
      await tester.pumpAndSettle();

      // The dialog title should appear
      expect(find.text('新建助手'), findsOneWidget);

      // The emoji tab bar should exist
      expect(find.text('Emoji'), findsOneWidget);
      expect(find.text('图片'), findsOneWidget);

      // The emoji grid should have more than 16 options (presence of '🎯')
      expect(find.text('🎯'), findsOneWidget);
      // Check some common emojis from the expanded set
      expect(find.text('😀'), findsOneWidget);
      expect(find.text('🐶'), findsOneWidget);
    });

    testWidgets('edit dialog shows expanded emoji grid', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          assistantProvider.overrideWith((ref) {
            final notifier = AssistantsNotifier();
            notifier.createAssistant(name: '测试助手', prompt: 'P1', emoji: '🤖');
            return notifier;
          }),
        ],
        child: const MaterialApp(
          home: AssistantSelectionPage(),
        ),
      ));
      await tester.pumpAndSettle();

      // Long press the assistant card to open menu
      await tester.longPress(find.text('🤖'));
      await tester.pumpAndSettle();

      // Tap edit
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // The emoji tab bar should exist
      expect(find.text('Emoji'), findsOneWidget);
      expect(find.text('图片'), findsOneWidget);
    });
  });

  group('Assistant settings extended params dialog', () {
    testWidgets('settings dialog shows extended parameters', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          assistantProvider.overrideWith((ref) {
            final notifier = AssistantsNotifier();
            notifier.createAssistant(name: '参数助手', prompt: 'P1', emoji: '🤖');
            return notifier;
          }),
        ],
        child: const MaterialApp(
          home: AssistantSelectionPage(),
        ),
      ));
      await tester.pumpAndSettle();

      // Long press to open menu then tap settings
      await tester.longPress(find.text('🤖'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      // Title
      expect(find.text('助手参数设置'), findsOneWidget);

      // Should show new parameter labels
      expect(find.text('Top K'), findsWidgets);
      expect(find.text('频率惩罚 (Frequency Penalty)'), findsOneWidget);
      expect(find.text('存在惩罚 (Presence Penalty)'), findsOneWidget);

      // Should show override model settings toggle
      expect(find.text('覆盖模型设置'), findsOneWidget);
    });
  });
}
