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

    testWidgets('tapping assistant navigates to select conversation page',
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

      // Should navigate to topic selection page (now titled "选择对话")
      expect(find.text('选择对话'), findsOneWidget);
    });
  });

  group('SelectConversationPage', () {
    testWidgets('shows select conversation title', (tester) async {
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

      // Should show the new title
      expect(find.text('选择对话'), findsOneWidget);
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

    testWidgets('create dialog has emoji picker and no image toggle',
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

      // Should still show "表情" in the dialog (emoji picker is shown by default)
      // But should NOT have any "图片" segment button or image URL field
      expect(find.text('图片'), findsNothing);
      expect(find.text('头像图片URL（可选）'), findsNothing);

      // The dialog should still have basic fields
      expect(find.text('助手名称'), findsOneWidget);
    });

    testWidgets('long press menu shows 编辑 (combined) and 删除, no separate 设置',
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

      // Should show 编辑 (combined)
      expect(find.text('编辑'), findsOneWidget);
      // Should show 删除
      expect(find.text('删除'), findsOneWidget);
      // Should NOT show separate 设置 menu item
      expect(find.text('设置'), findsNothing);
    });

    testWidgets('long press menu 编辑 opens combined dialog with both basics and settings',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(
            name: '助手编辑',
            prompt: 'P1',
            emoji: '🤖',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Long-press to open menu
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();

      // Tap 编辑
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Should show combined dialog with basics
      expect(find.text('助手名称'), findsOneWidget);
      expect(find.text('系统提示词'), findsOneWidget);
      // Should show settings sections
      expect(find.text('温度 (Temperature)'), findsOneWidget);
      expect(find.text('流式输出 (Stream Output)'), findsOneWidget);
      // Save button should be there
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('combined edit dialog has no image toggle', (tester) async {
      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(
            name: '助手编辑',
            prompt: 'P1',
            emoji: '🤖',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Long-press to open menu
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();

      // Tap 编辑
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Should NOT have '图片' segment button or image URL field
      expect(find.text('图片'), findsNothing);
      expect(find.text('头像图片URL'), findsNothing);
    });

    testWidgets('long press menu 删除 shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(
            name: '助手删除',
            prompt: 'P1',
            emoji: '🤖',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Verify assistant exists
      expect(find.text('助手删除'), findsOneWidget);

      // Long-press to open menu
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();

      // Tap 删除
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.text('删除助手'), findsOneWidget);
      expect(find.text('确定要删除助手「助手删除」吗？此操作无法撤销。'), findsOneWidget);
      // Should have cancel and delete buttons
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('confirming delete removes assistant from grid',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(
            name: '要删除的助手',
            prompt: 'P1',
            emoji: '🤖',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Verify assistant exists before deletion
      expect(find.text('要删除的助手'), findsOneWidget);

      // Long-press to open menu
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();

      // Tap 删除
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Confirm delete
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      // Assistant should be removed
      expect(find.text('要删除的助手'), findsNothing);
      // Should show empty state
      expect(find.text('暂无助手，请先创建'), findsOneWidget);
    });

    testWidgets('cancelling delete keeps assistant in grid',
        (tester) async {
      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(
            name: '保留的助手',
            prompt: 'P1',
            emoji: '🤖',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Verify assistant exists
      expect(find.text('保留的助手'), findsOneWidget);

      // Long-press to open menu
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();

      // Tap 删除
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Cancel delete
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Assistant should still exist
      expect(find.text('保留的助手'), findsOneWidget);
    });

    testWidgets('combined dialog save button updates assistant', (tester) async {
      await tester.pumpWidget(createTestApp(
        assistants: [
          Assistant(
            name: '原名',
            prompt: '旧提示词',
            emoji: '🤖',
            description: '旧描述',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      // Long-press to open menu
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();

      // Tap 编辑 to open combined dialog
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Find name field and change it - use the first TextField
      final nameField = find.widgetWithText(TextField, '原名');
      await tester.tap(nameField);
      await tester.enterText(nameField, '新名');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // The assistant card should show the new name
      expect(find.text('新名'), findsOneWidget);
      expect(find.text('原名'), findsNothing);
    });
  });
}
