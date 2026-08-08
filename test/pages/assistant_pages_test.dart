import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/built_in_prompts.dart';
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
    Finder findEmojiGrid() {
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
        final gridFinder = findEmojiGrid();
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
      final gridFinder = findEmojiGrid();
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

  group('BuiltInPromptSelector', () {
    testWidgets('shows market icon button in AppBar next to + button', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(name: '助手1', prompt: 'P1', emoji: '🤖'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The market entry should use a store-like icon (conveying it picks
      // from a "market"), not the sparkles icon
      expect(find.byIcon(Icons.storefront), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      // The + button should still be there
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('tapping market button opens selector dialog', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(name: '助手1', prompt: 'P1', emoji: '🤖'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap the market button
      await tester.tap(find.byIcon(Icons.storefront));
      await tester.pumpAndSettle();

      // Dialog should be visible with the market title
      expect(find.text('助手市场'), findsOneWidget);
    });

    testWidgets('market dialog shows prompt cards', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(name: '助手1', prompt: 'P1', emoji: '🤖'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open the dialog
      await tester.tap(find.byIcon(Icons.storefront));
      await tester.pumpAndSettle();

      // Should show the first built-in prompt's name
      final firstPrompt = builtInPrompts.first;
      expect(find.text(firstPrompt.name), findsOneWidget);
    });

    testWidgets('market cards have no text editing fields', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(name: '助手1', prompt: 'P1', emoji: '🤖'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open the dialog
      await tester.tap(find.byIcon(Icons.storefront));
      await tester.pumpAndSettle();

      // No text editing fields should be present for the prompts
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('prompt text is hidden on cards, shown only via info icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(name: '助手1', prompt: 'P1', emoji: '🤖'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open the dialog
      await tester.tap(find.byIcon(Icons.storefront));
      await tester.pumpAndSettle();

      // The prompt code must NOT be visible on the card; only the
      // description is shown by default
      final firstPrompt = builtInPrompts.first;
      expect(find.text(firstPrompt.prompt), findsNothing);
      expect(find.text(firstPrompt.description), findsOneWidget);

      // Tap the info icon next to the add button
      await tester.tap(find.byIcon(Icons.info_outline).first);
      await tester.pumpAndSettle();

      // The full prompt is now visible in the viewer
      expect(find.text(firstPrompt.prompt), findsOneWidget);
      expect(find.textContaining('提示词'), findsOneWidget);

      // Close the viewer again
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.text(firstPrompt.prompt), findsNothing);
    });

    testWidgets('tapping a card opens detail panel instead of adding', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(name: '助手1', prompt: 'P1', emoji: '🤖'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open the dialog
      await tester.tap(find.byIcon(Icons.storefront));
      await tester.pumpAndSettle();

      // Tap the first card — this must NOT import directly
      final firstPrompt = builtInPrompts.first;
      await tester.tap(find.text(firstPrompt.name).first);
      await tester.pumpAndSettle();

      // The detail panel is shown (with its import button), and the
      // market dialog is still open underneath — nothing imported yet
      expect(find.text('添加助手'), findsOneWidget);
      expect(find.text('助手市场'), findsOneWidget);
      // The detail panel lets the user review the prompt text
      expect(find.text(firstPrompt.prompt), findsOneWidget);

      // Close the detail panel without importing
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(find.text('添加助手'), findsNothing);

      // Close the market dialog and verify nothing was added to the grid
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('助手1'), findsOneWidget);
      expect(find.text(firstPrompt.name), findsNothing);
    });

    testWidgets(
        'importing from the detail panel creates assistant and closes dialogs',
        (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        createTestApp(
          // The override starts with an empty notifier; no default assistant
          // is auto-created, so the grid shows the empty state.
          assistants: [],
        ),
      );
      await tester.pumpAndSettle();

      // Open the dialog
      await tester.tap(find.byIcon(Icons.storefront));
      await tester.pumpAndSettle();

      // Open the detail panel of the first prompt
      final firstPrompt = builtInPrompts.first;
      await tester.tap(find.text(firstPrompt.name).first);
      await tester.pumpAndSettle();

      // Import from the detail panel
      await tester.tap(find.text('添加助手'));
      await tester.pumpAndSettle();

      // Both dialogs should be closed and the new assistant appears
      expect(find.text('助手市场'), findsNothing);
      expect(find.text(firstPrompt.name), findsOneWidget);
    });

    testWidgets('card 添加 button imports the prompt directly', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(name: '助手1', prompt: 'P1', emoji: '🤖'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open the dialog
      await tester.tap(find.byIcon(Icons.storefront));
      await tester.pumpAndSettle();

      // Tap the 添加 button on the first card (not the card itself)
      final firstPrompt = builtInPrompts.first;
      await tester.tap(find.widgetWithText(FilledButton, '添加').first);
      await tester.pumpAndSettle();

      // Dialog should be closed and the new assistant should appear
      expect(find.text('助手市场'), findsNothing);
      expect(find.text(firstPrompt.name), findsOneWidget);
    });

    testWidgets('rapid double tap on 添加助手 does not import twice', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(name: '助手1', prompt: 'P1', emoji: '🤖'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open the market dialog and the detail panel of the first prompt
      await tester.tap(find.byIcon(Icons.storefront));
      await tester.pumpAndSettle();
      final firstPrompt = builtInPrompts.first;
      await tester.tap(find.text(firstPrompt.name).first);
      await tester.pumpAndSettle();

      // Invoke the import action twice in a row (as a rapid double-tap
      // would). The second invocation must be a no-op — without the
      // re-entrancy guard it would import twice and pop the page beneath
      // the dialogs.
      final importButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '添加助手'),
      );
      importButton.onPressed!();
      await tester.pump(const Duration(milliseconds: 100));
      importButton.onPressed!();
      await tester.pumpAndSettle();

      // Exactly one assistant was created and both dialogs closed once
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AssistantSelectionPage)),
      );
      final imported = container
          .read(assistantProvider)
          .where((a) => a.name == firstPrompt.name);
      expect(imported.length, 1);
      expect(find.text('助手市场'), findsNothing);
      expect(find.text('添加助手'), findsNothing);
      // The selection page is still on screen
      expect(find.text('选择助手'), findsOneWidget);
    });

    testWidgets('market button also works in empty state', (tester) async {
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

      // The empty state appbar should have the market icon button
      expect(find.byIcon(Icons.storefront), findsAtLeast(1));
      // The + button should also be present
      expect(find.byIcon(Icons.add), findsAtLeast(1));
    });

    testWidgets('closing dialog via X button does not create any assistant', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        createTestApp(
          assistants: [
            Assistant(name: '现有助手', prompt: 'P1', emoji: '🤖'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.byIcon(Icons.storefront));
      await tester.pumpAndSettle();

      // Close using the X (close) icon button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('助手市场'), findsNothing);
      // Original assistant should still be there
      expect(find.text('现有助手'), findsOneWidget);
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

    testWidgets(
        'edit dialog shows three centered tabs with label-sized indicator',
        (tester) async {
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

      // All three tab labels are visible
      expect(find.text('基本设置'), findsOneWidget);
      expect(find.text('参数设置'), findsOneWidget);
      expect(find.text('默认设置'), findsOneWidget);

      // The dialog's TabBar (first in tree; the emoji picker's scrollable
      // category TabBar is a descendant) must be scrollable and centered so
      // the tab group is centered — not left-aligned — with the highlight
      // (label-sized indicator) aligned to the selected tab label.
      final dialogTabBar = tester.widget<TabBar>(find.byType(TabBar).first);
      expect(dialogTabBar.isScrollable, isTrue,
          reason: 'scrollable TabBar is required for TabAlignment.center');
      expect(dialogTabBar.tabAlignment, TabAlignment.center);
      expect(dialogTabBar.indicatorSize, TabBarIndicatorSize.label,
          reason: 'indicator hugs the label so the highlight stays aligned');
      expect(dialogTabBar.tabs.length, 3);

      // Geometry: the tab group must actually be CENTERED in the dialog
      // (the regression was the shrink-wrapped group pinned to the left).
      final firstLabel = tester.getCenter(find.text('基本设置'));
      final lastLabel = tester.getCenter(find.text('默认设置'));
      final groupCenterX = (firstLabel.dx + lastLabel.dx) / 2;
      final dialogCenterX = tester.getCenter(find.byType(AlertDialog)).dx;
      expect(
        (groupCenterX - dialogCenterX).abs(),
        lessThan(5),
        reason: 'Tab group should be centered in the dialog, not left-aligned',
      );
    });

    testWidgets('默认设置 tab shows default model selector and tool switches',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '助手编辑', prompt: 'P1', emoji: '🤖')],
        ),
      );
      await tester.pumpAndSettle();

      // Open edit dialog
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Switch to 默认设置 tab
      await tester.tap(find.text('默认设置'));
      await tester.pumpAndSettle();

      // Model section + empty state (no LLM config in test env) — the
      // follow-global option is still shown and is the effective selection
      expect(find.text('默认模型'), findsOneWidget);
      expect(find.textContaining('暂无可用模型'), findsOneWidget);
      expect(find.text('跟随全局设置'), findsOneWidget);

      // Tool section lists the built-in tools with switches
      expect(find.text('默认启用工具'), findsOneWidget);
      expect(find.text('web_search'), findsOneWidget);
      expect(find.text('todowrite'), findsOneWidget);
      expect(find.text('brave_web_search'), findsOneWidget);

      // Hint that un-added tools stay off in new topics
      expect(find.textContaining('未添加'), findsOneWidget);
    });

    testWidgets('默认设置 tab saves default model and default tools', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'provider_entries': jsonEncode([
          {
            'id': 'test_llm',
            'type': 'llm',
            'name': 'LLM供应商',
            'configs': [
              {
                'providerName': 'OpenAI',
                'host': 'https://api.openai.com/v1',
                'key': 'test-key',
                'models': [
                  {'name': 'gpt-4o', 'modelId': 'gpt-4o'},
                  {'name': 'claude-3.5-sonnet', 'modelId': 'claude-3.5-sonnet'},
                ],
              },
            ],
          },
        ]),
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) {
              final notifier = AssistantsNotifier();
              notifier.createAssistant(name: '助手编辑', prompt: 'P1');
              return notifier;
            }),
          ],
          child: const MaterialApp(home: AssistantSelectionPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Open edit dialog
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Switch to 默认设置 tab
      await tester.tap(find.text('默认设置'));
      await tester.pumpAndSettle();

      // Model selector lists the available models
      expect(find.text('跟随全局设置'), findsOneWidget);
      expect(find.text('gpt-4o | OpenAI'), findsOneWidget);
      expect(find.text('claude-3.5-sonnet | OpenAI'), findsOneWidget);

      // Select a default model and enable one tool
      await tester.tap(find.text('gpt-4o | OpenAI'));
      await tester.pumpAndSettle();
      final webSearchSwitch = find.widgetWithText(SwitchListTile, 'web_search');
      await tester.ensureVisible(webSearchSwitch);
      await tester.pumpAndSettle();
      await tester.tap(webSearchSwitch);
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // The assistant now carries the defaults
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AssistantSelectionPage)),
      );
      final assistant = container.read(assistantProvider).single;
      expect(assistant.defaultModelName, 'gpt-4o | OpenAI');
      expect(assistant.defaultToolNames, contains('web_search'));
    });

    testWidgets(
        'saving the dialog without touching 默认设置 keeps defaults '
        'unconfigured', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) {
              final notifier = AssistantsNotifier();
              notifier.createAssistant(name: '助手编辑', prompt: 'P1');
              return notifier;
            }),
          ],
          child: const MaterialApp(home: AssistantSelectionPage()),
        ),
      );
      await tester.pumpAndSettle();

      // Open edit dialog and change ONLY the name (默认设置 tab untouched)
      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '新名称');
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AssistantSelectionPage)),
      );
      final assistant = container.read(assistantProvider).single;
      expect(assistant.name, '新名称');
      expect(assistant.defaultModelName, isNull);
      expect(assistant.defaultToolNames, isNull,
          reason: '未触碰默认设置 tab 的保存（如仅改名）不得把助手标记为'
              '"已配置默认工具"——否则新话题会从自动启用全部工具变成全部关闭');
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
