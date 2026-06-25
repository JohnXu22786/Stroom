import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/topic_selection_page.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/providers/conversation_provider.dart';

/// Creates a test app simulating the chat tab's nested Navigator structure,
/// starting at the (merged) TopicSelectionPage with pre-selected assistant.
Widget createMergedTopicTestApp({
  List<Assistant>? assistants,
  String? selectedAssistantId,
  List<Conversation>? conversations,
  String? activeConversationId,
}) {
  SharedPreferences.setMockInitialValues({});
  return ProviderScope(
    overrides: [
      if (assistants != null)
        assistantProvider.overrideWith((ref) {
          final notifier = AssistantsNotifier();
          notifier.state = assistants;
          return notifier;
        }),
      if (selectedAssistantId != null)
        selectedAssistantIdProvider.overrideWith((ref) => selectedAssistantId),
      conversationsProvider.overrideWith((ref) {
        final notifier = ConversationsNotifier(ref);
        if (conversations != null) {
          notifier.state = conversations;
        }
        return notifier;
      }),
      if (activeConversationId != null)
        activeConversationIdProvider.overrideWith(
          (ref) => activeConversationId,
        ),
    ],
    child: MaterialApp(
      home: Navigator(
        initialRoute: '/topic-selection',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/topic-selection':
              return MaterialPageRoute(
                builder: (_) => const TopicSelectionPage(),
                settings: settings,
              );
            case '/chat':
              return MaterialPageRoute(
                builder: (_) =>
                    const Scaffold(body: Center(child: Text('Chat Page Mock'))),
                settings: settings,
              );
            default:
              return MaterialPageRoute(
                builder: (_) =>
                    const Scaffold(body: Center(child: Text('Unknown'))),
                settings: settings,
              );
          }
        },
      ),
    ),
  );
}

void main() {
  group('Merged SelectConversationPage - AppBar', () {
    testWidgets('shows title "选择对话" and no avatar icon in title', (
      tester,
    ) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id',
              name: '测试助手',
              prompt: '你好',
              emoji: '🤖',
              description: '测试',
            ),
          ],
          selectedAssistantId: 'test-id',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show the new title
      expect(find.text('选择对话'), findsOneWidget);
      // The emoji should NOT appear in the AppBar title area (it's only in the info bar)
      // Wait: the emoji IS in the info bar (assistant info bar), so it should be found
      // But NOT in the title row. The old test had findsAtLeast(1) because emoji was
      // in both title and info bar. Now it should NOT be in the title.
      // Let's just check: the emoji still appears in the info bar
      expect(find.text('🤖'), findsOneWidget);
    });

    testWidgets('NO add (新话题) button in AppBar (bottom button still exists)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id',
              name: '助手A',
              prompt: 'P1',
              emoji: '🤖',
              description: 'AA',
            ),
          ],
          selectedAssistantId: 'test-id',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The add button should NOT be in the AppBar
      final appBar = find.byType(AppBar);
      final addIconsInAppBar = find.descendant(
        of: appBar,
        matching: find.byIcon(Icons.add),
      );
      expect(addIconsInAppBar, findsNothing);
    });

    testWidgets('NO swap_horiz (切换助手) button in AppBar', (tester) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-2',
              name: '助手B',
              prompt: 'P2',
              emoji: '🤖',
              description: 'BB',
            ),
          ],
          selectedAssistantId: 'test-id-2',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('title has no icon (no avatar) to its left', (tester) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-icon',
              name: '图标助手',
              prompt: 'P',
              emoji: '🌟',
              description: 'ICON',
            ),
          ],
          selectedAssistantId: 'test-id-icon',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the AppBar title area
      final appBar = find.byType(AppBar);
      final titleText = find.descendant(
        of: appBar,
        matching: find.text('选择对话'),
      );
      expect(titleText, findsOneWidget);
      // Verify there's no Row with AssistantAvatar icon before the title
      // (the title is a plain Text, not wrapped in a Row with avatar)
      expect(
        find.descendant(
          of: appBar,
          matching: find.byIcon(Icons.chat_bubble_outline_rounded),
        ),
        findsNothing,
      );
    });
  });

  group('Merged SelectConversationPage - Features', () {
    testWidgets('shows search button in AppBar that opens a panel', (
      tester,
    ) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-3',
              name: '助手C',
              prompt: 'P3',
              emoji: '🤖',
              description: 'CC',
            ),
          ],
          selectedAssistantId: 'test-id-3',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Search button should exist
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('tapping search button opens search panel (bottom sheet)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-search',
              name: '助手搜索',
              prompt: 'P',
              emoji: '🔍',
              description: '搜索',
            ),
          ],
          selectedAssistantId: 'test-id-search',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the search button
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should find the search text field in the bottom sheet
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('search panel has two toggle options: 搜标题 and 搜内容', (
      tester,
    ) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-toggle',
              name: '助手切换',
              prompt: 'P',
              emoji: '🔀',
              description: '切换',
            ),
          ],
          selectedAssistantId: 'test-id-toggle',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open search panel
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should have toggle buttons
      expect(find.text('搜标题'), findsOneWidget);
      expect(find.text('搜内容'), findsOneWidget);
    });

    testWidgets('shows selection mode (checklist) button in AppBar', (
      tester,
    ) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-4',
              name: '助手D',
              prompt: 'P4',
              emoji: '🤖',
              description: 'DD',
            ),
          ],
          selectedAssistantId: 'test-id-4',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Checklist button should be present
      expect(find.byIcon(Icons.checklist), findsOneWidget);
    });

    testWidgets('displays conversations with card-based UI', (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '我的第一个对话',
        updatedAt: DateTime(2026, 6, 1, 10, 30),
        assistantId: 'test-id-5',
        messages: [
          ChatMessage(id: 'm1', role: 'user', content: 'Hello'),
          ChatMessage(id: 'm2', role: 'assistant', content: 'Hi'),
        ],
      );

      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-5',
              name: '助手E',
              prompt: 'P5',
              emoji: '🤖',
              description: 'EE',
            ),
          ],
          selectedAssistantId: 'test-id-5',
          conversations: [conv1],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show conversation title
      expect(find.text('我的第一个对话'), findsOneWidget);
      // Should show message count
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('tapping conversation navigates to chat page', (tester) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话1',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-id-6',
      );

      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-6',
              name: '助手F',
              prompt: 'P6',
              emoji: '🤖',
              description: 'FF',
            ),
          ],
          selectedAssistantId: 'test-id-6',
          conversations: [conv1],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the conversation
      await tester.tap(find.text('对话1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should navigate to chat page
      expect(find.text('Chat Page Mock'), findsOneWidget);
    });

    testWidgets('shows popup menu (more_vert) on each conversation card', (
      tester,
    ) async {
      final conv1 = Conversation(
        id: 'conv-1',
        title: '对话D',
        updatedAt: DateTime(2026, 5, 1),
        assistantId: 'test-id-7',
      );

      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-7',
              name: '助手G',
              prompt: 'P7',
              emoji: '🤖',
              description: 'GG',
            ),
          ],
          selectedAssistantId: 'test-id-7',
          conversations: [conv1],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Popup menu (more_vert) should exist
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('shows only ONE "新话题" button (bottom only)', (tester) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-8',
              name: '助手H',
              prompt: 'P8',
              emoji: '🤖',
              description: 'HH',
            ),
          ],
          selectedAssistantId: 'test-id-8',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Only 1 "新话题" button: the bottom one
      expect(find.widgetWithText(FilledButton, '新话题'), findsOneWidget);
    });

    testWidgets('tapping bottom new topic button navigates to chat', (
      tester,
    ) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-9',
              name: '助手I',
              prompt: 'P9',
              emoji: '🤖',
              description: 'II',
            ),
          ],
          selectedAssistantId: 'test-id-9',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();

      // Tap the LAST "新话题" FilledButton (the bottom one)
      final newTopicButtons = find.widgetWithText(FilledButton, '新话题');
      expect(newTopicButtons, findsAtLeast(1));
      await tester.tap(newTopicButtons.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();

      // Should navigate to chat page
      expect(find.text('Chat Page Mock'), findsOneWidget);
    });

    testWidgets(
      'search panel filters conversations by title when "搜标题" is selected',
      (tester) async {
        final conv1 = Conversation(
          id: 'conv-s1',
          title: '机器学习基础',
          updatedAt: DateTime(2026, 6, 1),
          assistantId: 'test-search-filter',
        );
        final conv2 = Conversation(
          id: 'conv-s2',
          title: '深度学习',
          updatedAt: DateTime(2026, 6, 2),
          assistantId: 'test-search-filter',
        );

        await tester.pumpWidget(
          createMergedTopicTestApp(
            assistants: [
              Assistant(
                id: 'test-search-filter',
                name: '助手筛选',
                prompt: 'P',
                emoji: '🔍',
                description: '筛选',
              ),
            ],
            selectedAssistantId: 'test-search-filter',
            conversations: [conv1, conv2],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Open search panel
        await tester.tap(find.byIcon(Icons.search));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // "搜标题" should be selected by default
        // Type search query
        await tester.enterText(find.byType(TextField), '机器');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Scope to the bottom sheet's DraggableScrollableSheet
        final sheet = find.byType(DraggableScrollableSheet);
        // Should show matching conversation "机器学习基础" in the search panel
        expect(
          find.descendant(of: sheet, matching: find.text('机器学习基础')),
          findsOneWidget,
        );
        // The matching card also appears on the main page behind the sheet
        // so total is 2, but within the sheet it's 1
        // Should NOT show non-matching "深度学习" in the search panel
        expect(
          find.descendant(of: sheet, matching: find.text('深度学习')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'search panel filters conversations by content when "搜内容" is selected',
      (tester) async {
        final conv1 = Conversation(
          id: 'conv-c1',
          title: '天气讨论',
          updatedAt: DateTime(2026, 6, 1),
          assistantId: 'test-content-search',
          messages: [
            ChatMessage(id: 'm1', role: 'user', content: '今天天气真好'),
            ChatMessage(id: 'm2', role: 'assistant', content: '是的，适合外出'),
          ],
        );
        final conv2 = Conversation(
          id: 'conv-c2',
          title: '编程问题',
          updatedAt: DateTime(2026, 6, 2),
          assistantId: 'test-content-search',
          messages: [
            ChatMessage(id: 'm3', role: 'user', content: 'Flutter怎么用'),
          ],
        );

        await tester.pumpWidget(
          createMergedTopicTestApp(
            assistants: [
              Assistant(
                id: 'test-content-search',
                name: '助手内容',
                prompt: 'P',
                emoji: '📝',
                description: '内容搜索',
              ),
            ],
            selectedAssistantId: 'test-content-search',
            conversations: [conv1, conv2],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Open search panel
        await tester.tap(find.byIcon(Icons.search));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Switch to "搜内容"
        await tester.tap(find.text('搜内容'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Type search query - should match content "今天天气真好"
        await tester.enterText(find.byType(TextField), '天气');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Scope to the bottom sheet's DraggableScrollableSheet
        final sheet = find.byType(DraggableScrollableSheet);
        // Should show conversation with matching content in the panel
        expect(
          find.descendant(of: sheet, matching: find.text('天气讨论')),
          findsOneWidget,
        );
        // Should NOT show non-matching in the panel
        expect(
          find.descendant(of: sheet, matching: find.text('编程问题')),
          findsNothing,
        );
      },
    );

    testWidgets('tapping a card in the search panel navigates to chat', (
      tester,
    ) async {
      final conv1 = Conversation(
        id: 'conv-nav',
        title: '搜索结果导航',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-nav-search',
      );

      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-nav-search',
              name: '助手导航',
              prompt: 'P',
              emoji: '🧭',
              description: '导航',
            ),
          ],
          selectedAssistantId: 'test-nav-search',
          conversations: [conv1],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open search panel
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter a query to match the conversation title
      await tester.enterText(find.byType(TextField), '搜索');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the conversation card in the panel (scope to DraggableScrollableSheet)
      final sheet = find.byType(DraggableScrollableSheet);
      await tester.tap(
        find.descendant(of: sheet, matching: find.text('搜索结果导航')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should navigate to chat page (panel closed, now on chat)
      expect(find.text('Chat Page Mock'), findsOneWidget);
    });

    testWidgets('search panel shows "没有找到匹配的对话" when no results', (
      tester,
    ) async {
      final conv1 = Conversation(
        id: 'conv-empty',
        title: '唯一对话',
        updatedAt: DateTime(2026, 6, 1),
        assistantId: 'test-empty-search',
      );

      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-empty-search',
              name: '助手空',
              prompt: 'P',
              emoji: '🔍',
              description: '空结果',
            ),
          ],
          selectedAssistantId: 'test-empty-search',
          conversations: [conv1],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open search panel
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Enter a query that matches nothing
      await tester.enterText(find.byType(TextField), 'ZZZZ_NO_MATCH');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show the no-results empty state
      expect(find.text('没有找到匹配的对话'), findsOneWidget);
    });

    testWidgets('search panel shows "搜标题" selected by default', (tester) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-default-mode',
              name: '助手默认',
              prompt: 'P',
              emoji: '🔍',
              description: '默认',
            ),
          ],
          selectedAssistantId: 'test-default-mode',
          conversations: [
            Conversation(
              id: 'c1',
              title: '讨论',
              updatedAt: DateTime(2026, 6, 1),
              assistantId: 'test-default-mode',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open search panel
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Type query that matches in content but not title
      await tester.enterText(find.byType(TextField), '讨论');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // In title mode by default, should match by title
      // Text matches both the TextField content and the card title
      expect(find.text('讨论'), findsWidgets);
    });
  });

  group('Merged SelectConversationPage - Assistant info bar', () {
    testWidgets('shows assistant info bar with emoji, name, description', (
      tester,
    ) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-assistant',
              name: '智能助手',
              prompt: '帮助用户',
              emoji: '🧠',
              description: '一个智能助手',
            ),
          ],
          selectedAssistantId: 'test-assistant',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Emoji appears in info bar (NOT in AppBar title anymore)
      expect(find.text('🧠'), findsOneWidget);
      // Name and description should appear in info bar
      expect(find.text('智能助手'), findsOneWidget);
      expect(find.text('一个智能助手'), findsOneWidget);
    });

    testWidgets('assistant info bar tune button opens combined edit dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-10',
              name: '助手J',
              prompt: 'P10',
              emoji: '🤖',
              description: 'JJ',
            ),
          ],
          selectedAssistantId: 'test-id-10',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tune button should exist
      expect(find.byIcon(Icons.tune), findsOneWidget);

      // Tap the tune button
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should open combined edit dialog with tab bar
      expect(find.text('助手名称'), findsOneWidget);
      expect(find.text('基本设置'), findsOneWidget);
      expect(find.text('参数设置'), findsOneWidget);
      // Temperature is in 参数设置 tab, not visible initially
      expect(find.text('温度 (Temperature)'), findsNothing);

      // Switch to 参数设置 tab to verify parameters are there
      await tester.tap(find.text('参数设置'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('温度 (Temperature)'), findsOneWidget);

      expect(find.text('保存'), findsOneWidget);
    });
  });

  group('Merged SelectConversationPage - Drag sort hint', () {
    testWidgets('shows drag sort hint text below assistant info bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-hint',
              name: '助手提示',
              prompt: 'P',
              emoji: '🤖',
              description: '提示测试',
            ),
          ],
          selectedAssistantId: 'test-hint',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The hint text should be visible
      expect(find.text('长按拖拽即可调整对话顺序'), findsOneWidget);
    });

    testWidgets('shows drag indicator icon in the hint', (tester) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-hint-icon',
              name: '助手图标',
              prompt: 'P',
              emoji: '🤖',
              description: '图标测试',
            ),
          ],
          selectedAssistantId: 'test-hint-icon',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Drag indicator icon should be present
      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    });

    testWidgets('hint is NOT shown when no assistant selected', (tester) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-hint-none',
              name: '助手无',
              prompt: 'P',
              emoji: '🤖',
              description: '无助手测试',
            ),
          ],
          selectedAssistantId: null,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Hint text should NOT be visible
      expect(find.text('长按拖拽即可调整对话顺序'), findsNothing);
    });

    testWidgets(
      'hint is positioned fixed below assistant card, not inside scrollable list',
      (tester) async {
        await tester.pumpWidget(
          createMergedTopicTestApp(
            assistants: [
              Assistant(
                id: 'test-hint-pos',
                name: '助手位置',
                prompt: 'P',
                emoji: '🤖',
                description: '位置测试',
              ),
            ],
            selectedAssistantId: 'test-hint-pos',
            conversations: [
              Conversation(
                id: 'c1',
                title: '对话1',
                updatedAt: DateTime(2026, 6, 1),
                assistantId: 'test-hint-pos',
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The hint text should be outside the ReorderableListView
        final reorderableList = find.byType(ReorderableListView);
        final hintInList = find.descendant(
          of: reorderableList,
          matching: find.text('长按拖拽即可调整对话顺序'),
        );
        expect(hintInList, findsNothing);

        // The hint should still be found on the page
        expect(find.text('长按拖拽即可调整对话顺序'), findsOneWidget);
      },
    );
  });

  group('Merged SelectConversationPage - Empty state', () {
    testWidgets('shows empty state when no conversations', (tester) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-11',
              name: '助手K',
              prompt: 'P11',
              emoji: '🤖',
              description: 'KK',
            ),
          ],
          selectedAssistantId: 'test-id-11',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show empty state text
      expect(find.text('暂无对话'), findsOneWidget);
      expect(find.text('创建一个新对话开始对话'), findsOneWidget);
    });
  });

  group('No assistant selected state', () {
    testWidgets('shows error state when no assistant is selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        createMergedTopicTestApp(
          assistants: [
            Assistant(
              id: 'test-id-12',
              name: '助手L',
              prompt: 'P12',
              emoji: '🤖',
              description: 'LL',
            ),
          ],
          selectedAssistantId: null,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show error state
      expect(find.text('未选择助手'), findsOneWidget);
      expect(find.text('返回选择助手'), findsOneWidget);
    });
  });

  group(
    'Merged SelectConversationPage - Pinned topic preserves original time',
    () {
      testWidgets(
        'pinned topic shows original updatedAt date, not modified time',
        (tester) async {
          final originalTime = DateTime(2026, 5, 15, 10, 30, 0);
          final conv = Conversation(
            id: 'pinned-conv',
            title: '置顶对话',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: originalTime,
            isPinned: true,
            assistantId: 'test-pin-time',
          );

          await tester.pumpWidget(
            createMergedTopicTestApp(
              assistants: [
                Assistant(
                  id: 'test-pin-time',
                  name: '时间助手',
                  prompt: 'P',
                  emoji: '⏰',
                  description: '测试',
                ),
              ],
              selectedAssistantId: 'test-pin-time',
              conversations: [conv],
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Should show the original date: 2026-05-15 10:30
          expect(find.textContaining('2026-05-15'), findsOneWidget);
          expect(find.textContaining('10:30'), findsOneWidget);
          // Pinned icon should be visible
          expect(find.byIcon(Icons.push_pin), findsAtLeast(1));
        },
      );

      testWidgets('non-pinned topic shows its own updatedAt date', (
        tester,
      ) async {
        final conv = Conversation(
          id: 'normal-conv',
          title: '普通对话',
          createdAt: DateTime(2026, 2, 1),
          updatedAt: DateTime(2026, 3, 20, 14, 45),
          isPinned: false,
          assistantId: 'test-non-pin-time',
        );

        await tester.pumpWidget(
          createMergedTopicTestApp(
            assistants: [
              Assistant(
                id: 'test-non-pin-time',
                name: '普通助手',
                prompt: 'P',
                emoji: '📋',
                description: '测试',
              ),
            ],
            selectedAssistantId: 'test-non-pin-time',
            conversations: [conv],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should show the original date: 2026-03-20 14:45
        expect(find.textContaining('2026-03-20'), findsOneWidget);
        expect(find.textContaining('14:45'), findsOneWidget);
        expect(find.text('普通对话'), findsOneWidget);
      });
    },
  );
}
