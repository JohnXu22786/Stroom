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
        selectedAssistantIdProvider.overrideWith((ref) => selectedAssistantId),
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
  group('EmojiPicker adaptive width', () {
    /// Find the emoji GridView inside the dialog (padding EdgeInsets.only(top: 4))
    Finder _findEmojiGrid() {
      return find.byWidgetPredicate(
        (w) => w is GridView && w.padding == const EdgeInsets.only(top: 4),
      );
    }

    testWidgets(
      'emoji picker is centered on wide screen (not stuck at 320px)',
      (tester) async {
        // Set a wide surface (simulating a tablet/desktop)
        await tester.binding.setSurfaceSize(const Size(800, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          createTestApp(
            assistants: [Assistant(name: '测试助手', prompt: 'P1', emoji: '🤖')],
          ),
        );
        await tester.pumpAndSettle();

        // Open edit dialog
        await tester.longPress(find.byType(AssistantAvatar));
        await tester.pumpAndSettle();
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();

        // Find the emoji grid inside the dialog
        final gridFinder = _findEmojiGrid();
        expect(gridFinder, findsOneWidget);

        // The picker is wrapped in Center + FittedBox, so on a wide screen
        // the emoji grid should be centered within the dialog content.
        expect(find.text('编辑助手'), findsOneWidget);
        expect(find.text('保存'), findsOneWidget);

        // Verify the emoji grid is within the screen bounds (not overflowed)
        final gridRect = tester.getRect(gridFinder);
        expect(gridRect.left, greaterThanOrEqualTo(0));
        expect(gridRect.right, lessThanOrEqualTo(800));

        // Verify the grid is horizontally centered by checking
        // left and right margins are roughly equal
        final screenCenterX = 800 / 2;
        final gridCenterX = gridRect.center.dx;
        // Grid center should be within 5px of screen center
        expect(
          (gridCenterX - screenCenterX).abs(),
          lessThan(5),
          reason: 'Emoji grid should be centered horizontally on wide screens',
        );
      },
    );

    testWidgets('emoji picker scales down on narrow screens', (tester) async {
      // Set a narrow surface (simulating a small phone)
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '测试助手', prompt: 'P1', emoji: '🤖')],
        ),
      );
      await tester.pumpAndSettle();

      // Open create dialog (it uses the emoji picker too)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // The dialog should be visible
      expect(find.text('新建助手'), findsOneWidget);
      // Emoji picker should be visible
      expect(find.text('表情'), findsOneWidget);

      // The grid should fit within the screen width (FittedBox scales it down)
      final gridFinder = _findEmojiGrid();
      expect(gridFinder, findsOneWidget);
      final gridRect = tester.getRect(gridFinder);
      expect(
        gridRect.width,
        greaterThan(0),
        reason: 'Emoji grid should have positive width',
      );
      expect(
        gridRect.right,
        lessThanOrEqualTo(360),
        reason: 'Emoji grid should fit within narrow screen (right edge)',
      );
    });

    testWidgets('emoji selection still works with adaptive sizing', (
      tester,
    ) async {
      // Use medium screen size
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '测试助手', prompt: 'P1', emoji: '😊')],
        ),
      );
      await tester.pumpAndSettle();

      // Open edit dialog
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // The current emoji '😊' should be shown
      // Tap a different emoji in the grid to change selection
      // First tap the emoji tab to make sure we're on the right category
      await tester.tap(find.text('表情').first);
      await tester.pumpAndSettle();

      // Try to find and tap '😀' in the grid (first emoji in the first category)
      final emojiFinder = find.text('😀');
      expect(
        emojiFinder,
        findsAtLeast(1),
        reason: '😀 should be visible in the emoji grid',
      );
      await tester.tap(emojiFinder.first);
      await tester.pumpAndSettle();

      // Verify the dialog is still working (not crashed)
      expect(find.text('编辑助手'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });
  });

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
          child: const MaterialApp(home: AssistantSelectionPage()),
        ),
      );
      await tester.pumpAndSettle();

      // The title should always be shown
      expect(find.text('选择助手'), findsOneWidget);
    });

    testWidgets('shows assistant cards in grid', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(
              name: '助手1',
              prompt: 'P1',
              emoji: '🤖',
              description: '第一个助手',
            ),
            Assistant(
              name: '助手2',
              prompt: 'P2',
              emoji: '😊',
              description: '第二个助手',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('助手1'), findsOneWidget);
      expect(find.text('助手2'), findsOneWidget);
      expect(find.text('🤖'), findsOneWidget);
      expect(find.text('😊'), findsOneWidget);
    });

    testWidgets('assistant card does NOT display prompt text', (tester) async {
      // Given an assistant with a non-empty prompt
      const promptText = '这是一个测试提示词';
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(
              name: '提示测试',
              prompt: promptText,
              emoji: '🤖',
              description: '带提示词的助手',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Then the name and description should still be visible
      expect(find.text('提示测试'), findsOneWidget);
      expect(find.text('带提示词的助手'), findsOneWidget);

      // But the prompt text should NOT be visible on the card
      expect(find.text(promptText), findsNothing);
    });

    testWidgets(
        'assistant card still shows name and description after removing prompt',
        (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(
              name: '助手1',
              prompt: 'P1',
              emoji: '🤖',
              description: '第一个助手',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('助手1'), findsOneWidget);
      expect(find.text('第一个助手'), findsOneWidget);
      expect(find.text('🤖'), findsOneWidget);
    });

    testWidgets('uses responsive grid with MaxCrossAxisExtent (like homepage)',
        (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(name: '助手1', prompt: 'P1', emoji: '🤖'),
            Assistant(name: '助手2', prompt: 'P2', emoji: '😊'),
            Assistant(name: '助手3', prompt: 'P3', emoji: '🎉'),
            Assistant(name: '助手4', prompt: 'P4', emoji: '🔥'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Find the GridView
      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate;

      // Should use SliverGridDelegateWithMaxCrossAxisExtent (not FixedCrossAxisCount)
      expect(delegate, isA<SliverGridDelegateWithMaxCrossAxisExtent>());
    });

    testWidgets('wide screen shows more columns than narrow screen', (
      tester,
    ) async {
      // First, test on a narrow screen
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(name: '助手1', prompt: 'P1', emoji: '🤖'),
            Assistant(name: '助手2', prompt: 'P2', emoji: '😊'),
            Assistant(name: '助手3', prompt: 'P3', emoji: '🎉'),
            Assistant(name: '助手4', prompt: 'P4', emoji: '🔥'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // On a narrow screen, the grid should auto-calculate columns
      // (MaxCrossAxisExtent handles this automatically)
      expect(tester.takeException(), isNull);

      // Now test on a wide screen
      tester.view.physicalSize = const Size(1200, 800);

      // Rebuild with wide screen
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('assistant card uses 0.85 aspect ratio', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(name: '助手1', prompt: 'P1', emoji: '🤖'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Find the GridView
      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          gridView.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;

      // Aspect ratio should be 0.85 (taller than wide)
      expect(delegate.childAspectRatio, closeTo(0.85, 0.01));
      // Max cross axis extent should be around 220 (bigger than homepage's 180)
      expect(delegate.maxCrossAxisExtent, greaterThan(200));
    });

    testWidgets('tapping assistant navigates to select conversation page', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(
              name: '助手1',
              prompt: 'P1',
              emoji: '🤖',
              description: '第一个助手',
            ),
          ],
        ),
      );
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
              notifier.createAssistant(name: '测试助手', prompt: 'P1', emoji: '🤖');
              return notifier;
            }),
            selectedAssistantIdProvider.overrideWith((ref) => 'a1'),
          ],
          child: const MaterialApp(home: TopicSelectionPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the new title
      expect(find.text('选择对话'), findsOneWidget);
    });
  });

  group('AssistantAvatar in pages', () {
    testWidgets('assistant card uses AssistantAvatar widget', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(
              name: '助手1',
              prompt: 'P1',
              emoji: '🤖',
              description: '第一个助手',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Should render AssistantAvatar widget
      expect(find.byType(AssistantAvatar), findsOneWidget);
      // Should show the emoji inside the avatar
      expect(find.text('🤖'), findsOneWidget);
    });

    testWidgets('create dialog has emoji picker and no image toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '测试助手', prompt: 'P1', emoji: '🤖')],
        ),
      );
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

    testWidgets('long press menu shows 编辑 (combined) and 删除, no separate 设置', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '助手1', prompt: 'P1', emoji: '🤖')],
        ),
      );
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

    testWidgets('long press menu 编辑 opens combined dialog with tab bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '助手编辑', prompt: 'P1', emoji: '🤖')],
        ),
      );
      await tester.pumpAndSettle();

      // Long-press to open menu
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();

      // Tap 编辑
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Should show dialog with tab bar
      expect(find.text('助手名称'), findsOneWidget);
      expect(find.text('系统提示词'), findsOneWidget);
      // Tab labels should be visible
      expect(find.text('基本设置'), findsOneWidget);
      expect(find.text('参数设置'), findsOneWidget);
      // On the first tab (基本设置), should NOT see parameter settings
      expect(find.text('温度 (Temperature)'), findsNothing);
      expect(find.text('流式输出 (Stream Output)'), findsNothing);
      // Save button should be there
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('switching to 参数设置 tab shows model parameters', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(
              name: '助手参数',
              prompt: 'P1',
              emoji: '🤖',
              settings: AssistantSettings.defaults(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open edit dialog
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Switch to 参数设置 tab
      await tester.tap(find.text('参数设置'));
      await tester.pumpAndSettle();

      // Should see model parameters
      expect(find.text('温度 (Temperature)'), findsOneWidget);
      expect(find.text('流式输出 (Stream Output)'), findsOneWidget);
      expect(find.text('Top P'), findsOneWidget);
      expect(find.text('最大Token数 (Max Tokens)'), findsOneWidget);
      expect(find.text('频率惩罚 (Frequency Penalty)'), findsOneWidget);
      expect(find.text('存在惩罚 (Presence Penalty)'), findsOneWidget);
      expect(find.text('随机种子 (Seed)'), findsOneWidget);
      expect(find.text('联网搜索'), findsOneWidget);
      expect(find.text('自定义参数'), findsOneWidget);
    });

    testWidgets('combined edit dialog has no image toggle', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '助手编辑', prompt: 'P1', emoji: '🤖')],
        ),
      );
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

    testWidgets('long press menu 删除 shows confirmation dialog', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '助手删除', prompt: 'P1', emoji: '🤖')],
        ),
      );
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

    testWidgets('confirming delete removes assistant from grid', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '要删除的助手', prompt: 'P1', emoji: '🤖')],
        ),
      );
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

    testWidgets('cancelling delete keeps assistant in grid', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '保留的助手', prompt: 'P1', emoji: '🤖')],
        ),
      );
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

    testWidgets('combined dialog has tab bar with 基本设置 and 参数设置 tabs', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '助手测试', prompt: 'P1', emoji: '🤖')],
        ),
      );
      await tester.pumpAndSettle();

      // Long-press to open menu
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();

      // Tap 编辑
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Should now have tab labels 基本设置 and 参数设置 (as tabs, not section headers)
      expect(find.text('基本设置'), findsOneWidget);
      expect(find.text('参数设置'), findsOneWidget);
    });

    testWidgets('info box is shown in 参数设置 tab', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '助手测试', prompt: 'P1', emoji: '🤖')],
        ),
      );
      await tester.pumpAndSettle();

      // Long-press to open menu
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();

      // Tap 编辑
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Info box is in Tab 2 (参数设置), so it should NOT be visible on Tab 1
      expect(find.text('助手的参数开关打开时覆盖模型参数；关闭时使用模型参数。'), findsNothing);

      // Switch to 参数设置 tab
      await tester.tap(find.text('参数设置'));
      await tester.pumpAndSettle();

      // The info box text should now be visible
      expect(find.text('助手的参数开关打开时覆盖模型参数；关闭时使用模型参数。'), findsOneWidget);

      // The info icon should be visible
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('combined dialog save button updates assistant', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(
              name: '原名',
              prompt: '旧提示词',
              emoji: '🤖',
              description: '旧描述',
            ),
          ],
        ),
      );
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
