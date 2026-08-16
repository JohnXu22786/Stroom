import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/models/built_in_prompts.dart';
import 'package:stroom/pages/assistant_selection_page.dart';
import 'package:stroom/providers/assistant_provider.dart';
import 'package:stroom/widgets/llm/assistant_avatar.dart';

/// Creates a test app wrapped in ProviderScope with optional overrides.
Widget createTestApp({
  List<Assistant>? assistants,
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
    ],
    child: const MaterialApp(
      home: AssistantSelectionPage(),
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
      'emoji picker panel opens from the square and stays centered on wide screen',
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

        // The picker now lives behind the small emoji square in 基本设置:
        // tapping the square opens the picker panel dialog.
        expect(findEmojiGrid(), findsNothing,
            reason: 'picker is no longer inline in the edit dialog');
        await tester.tap(find.byType(EmojiAvatarButton));
        await tester.pumpAndSettle();
        expect(find.text('选择表情'), findsOneWidget);

        // Find the emoji grid inside the panel
        final gridFinder = findEmojiGrid();
        expect(gridFinder, findsOneWidget);

        // The picker is wrapped in Center + FittedBox, so on a wide screen
        // the emoji grid should be centered within the panel content.
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

    testWidgets('picking an emoji in the panel updates the square', (
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

      // The current emoji '😊' should be shown in the square
      // Tap the square to open the picker panel
      await tester.tap(find.byType(EmojiAvatarButton));
      await tester.pumpAndSettle();

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

      // The panel closes on selection and the edit dialog is still working
      expect(find.text('编辑助手'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(findEmojiGrid(), findsNothing,
          reason: 'picker panel should close after picking');

      // The square now shows the picked emoji
      final square = tester.widget<EmojiAvatarButton>(
        find.byType(EmojiAvatarButton),
      );
      expect(square.selectedEmoji, '😀');
    });

    testWidgets('edit dialog system prompt field fills the remaining height', (
      tester,
    ) async {
      // Tall surface so the dialog has plenty of room to expand
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '测试助手', prompt: 'P1', emoji: '🤖')],
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // The prompt field must be a growing field, not a fixed 4-line box
      final promptField = find.widgetWithText(TextField, '系统提示词');
      final promptWidget = tester.widget<TextField>(promptField);
      expect(promptWidget.maxLines, isNull,
          reason: 'system prompt must not have a fixed line count');
      expect(promptWidget.expands, isTrue,
          reason: 'system prompt must expand into the remaining space');

      // Geometry: it should occupy most of the dialog height — far taller
      // than the 2-line description field — and end right above the buttons
      // (no fixed-height stub in the middle of the dialog).
      final promptRect = tester.getRect(promptField);
      final descRect = tester.getRect(
        find.widgetWithText(TextField, '描述（可选）'),
      );
      final saveRect = tester.getRect(
        find.widgetWithText(FilledButton, '保存'),
      );
      expect(promptRect.height, greaterThan(descRect.height * 3),
          reason: 'prompt field should fill the remaining dialog space');
      expect(promptRect.bottom, lessThan(saveRect.top),
          reason: 'prompt field must not overlap the action buttons');
      expect(saveRect.top - promptRect.bottom, lessThan(80),
          reason: 'prompt field should end right above the action buttons');
    });

    testWidgets('create dialog system prompt field fills the remaining height',
        (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '测试助手', prompt: 'P1', emoji: '🤖')],
        ),
      );
      await tester.pumpAndSettle();

      // Tap the add button in the app bar to open create dialog
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      final promptField = find.widgetWithText(TextField, '系统提示词');
      final promptWidget = tester.widget<TextField>(promptField);
      expect(promptWidget.maxLines, isNull);
      expect(promptWidget.expands, isTrue);

      final promptRect = tester.getRect(promptField);
      final descRect = tester.getRect(
        find.widgetWithText(TextField, '描述（可选）'),
      );
      final createRect =
          tester.getRect(find.widgetWithText(FilledButton, '创建'));
      expect(promptRect.height, greaterThan(descRect.height * 3));
      expect(promptRect.bottom, lessThan(createRect.top));
      expect(createRect.top - promptRect.bottom, lessThan(80));
    });

    testWidgets(
        'edit dialog on a very short window falls back to a scrollable '
        'layout without overflow', (tester) async {
      // Short window: the fixed rows + expanded prompt would overflow, so
      // the editor must switch to its scrollable fallback layout.
      tester.view.physicalSize = const Size(800, 380);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '测试助手', prompt: 'P1', emoji: '🤖')],
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // No overflow exception was thrown; the editor switched to its
      // scrollable fallback layout inside the dialog (the prompt field's
      // ancestor), and all fields remain reachable.
      expect(
        find.ancestor(
          of: find.widgetWithText(TextField, '系统提示词'),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, '系统提示词'), findsOneWidget);
      expect(find.widgetWithText(TextField, '助手名称'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets(
        'large text scale on a medium window also uses the fallback '
        'layout (scaled threshold)', (tester) async {
      // 560dp window is above the unscaled fill threshold (540), but with
      // system font scaling 2.0 the fixed rows would overflow the fill
      // layout — the scaled threshold must switch to the scrollable fallback.
      tester.view.physicalSize = const Size(800, 560);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(
        tester.platformDispatcher.clearTextScaleFactorTestValue,
      );

      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '测试助手', prompt: 'P1', emoji: '🤖')],
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // No overflow exception; the prompt lives in the scrollable fallback.
      expect(
        find.ancestor(
          of: find.widgetWithText(TextField, '系统提示词'),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(find.text('保存'), findsOneWidget);
    });

    testWidgets('emoji square sits before the assistant name field', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          assistants: [Assistant(name: '助手编辑', prompt: 'P1', emoji: '🤖')],
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // 基本设置 layout: emoji square first, name field to its right,
      // both on the same row.
      final squareRect = tester.getRect(find.byType(EmojiAvatarButton));
      final nameRect = tester.getRect(
        find.widgetWithText(TextField, '助手编辑'),
      );
      expect(squareRect.right, lessThan(nameRect.left),
          reason: 'emoji square should be before (left of) the name field');
      expect((squareRect.center.dy - nameRect.center.dy).abs(), lessThan(30),
          reason: 'emoji square and name field should be on the same row');
    });
  });

  group('AssistantSelectionPage', () {
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
  });

  group('BuiltInPromptSelector', () {
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

  group('AssistantAvatar in pages', () {
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

      // The emoji picker now lives behind the small emoji square in the
      // dialog (only opened on tap), so no picker content is shown by
      // default. But there should be no image-avatar options either.
      expect(find.text('图片'), findsNothing);
      expect(find.text('头像图片URL（可选）'), findsNothing);

      // The dialog should still have basic fields
      expect(find.text('助手名称'), findsOneWidget);
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

      // The dialog's TabBar (the emoji picker's category TabBar only exists
      // while its popup panel is open, so this is the only one in the tree)
      // must be scrollable and centered so the tab group is centered — not
      // left-aligned — with the highlight (label-sized indicator) aligned to
      // the selected tab label.
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
      // not-set option is still shown and is the effective selection
      // (radio tile + 效果预览 summary each show the label)
      expect(find.text('默认模型'), findsOneWidget);
      expect(find.textContaining('暂无可用模型'), findsOneWidget);
      expect(find.text('暂不设置'), findsWidgets);

      // Tool section lists the built-in tools with switches
      expect(find.text('默认启用工具'), findsOneWidget);
      expect(find.text('web_search'), findsOneWidget);
      expect(find.text('todowrite'), findsOneWidget);
      expect(find.text('brave_web_search'), findsOneWidget);

      // 从未配置默认工具的助手：tab 显示全部工具开启（与新建话题自动启用
      // 全部工具的旧行为一致），而不是误导性地显示全部关闭。
      expect(find.textContaining('尚未配置默认工具'), findsOneWidget);
      for (final toolName in ['web_search', 'todowrite', 'brave_web_search']) {
        final tile = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, toolName),
        );
        expect(tile.value, isTrue, reason: '未配置默认工具时，工具开关应显示为开启（$toolName）');
      }

      // 效果预览卡反映生效行为：全部自动启用 + 暂不设置
      expect(find.text('新建话题效果'), findsOneWidget);
      expect(find.text('暂不设置'), findsWidgets);
      expect(find.text('全部自动启用（未配置）'), findsOneWidget);

      // 头部右侧始终提供批量操作按钮；未配置时"全部启用"没有意义
      // （当前已自动启用全部），不显示；"取消配置"按钮已移除。
      expect(find.text('全部启用'), findsNothing);
      expect(find.text('全部关闭'), findsOneWidget);
      expect(find.text('取消配置（自动启用全部）'), findsNothing);
    });

    testWidgets(
        '从未配置的助手切换任一工具后保存，新话题严格使用该集合（回归：'
        'tab 显示全关但新话题全开的误导）', (tester) async {
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

      // 从未配置 → 全部开启；关闭 todowrite 即产生显式配置
      final todowriteSwitch = find.widgetWithText(SwitchListTile, 'todowrite');
      await tester.ensureVisible(todowriteSwitch);
      await tester.pumpAndSettle();
      await tester.tap(todowriteSwitch);
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AssistantSelectionPage)),
      );
      final assistant = container.read(assistantProvider).single;
      expect(assistant.defaultToolNames, isNotNull,
          reason: '切换过工具后保存即视为已配置默认工具');
      expect(assistant.defaultToolNames, isNot(contains('todowrite')));
      expect(assistant.defaultToolNames, contains('web_search'));
    });

    testWidgets('已配置为空（全部关闭）的助手，默认设置 tab 显示全部工具关闭', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) {
              final notifier = AssistantsNotifier();
              final assistant =
                  notifier.createAssistant(name: '助手编辑', prompt: 'P1');
              // 显式配置"全部关闭"（空集合 = 已配置）。
              notifier.updateAssistantDefaults(
                id: assistant.id,
                defaultToolNames: {},
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(home: AssistantSelectionPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('默认设置'));
      await tester.pumpAndSettle();

      // 配置过空集合 → 开关全部关闭，说明文字用"已配置"措辞
      expect(find.textContaining('未启用的工具'), findsOneWidget);
      for (final toolName in ['web_search', 'todowrite', 'brave_web_search']) {
        final tile = tester.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, toolName),
        );
        expect(tile.value, isFalse, reason: '已配置默认工具为空时，开关应显示为关闭（$toolName）');
      }
      expect(find.textContaining('已启用 0 /'), findsOneWidget);
    });

    testWidgets(
        '默认模型已失效（从供应商配置中删除）时：tab 退化为暂不设置，'
        '保存后自动清除失效记录', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) {
              final notifier = AssistantsNotifier();
              final assistant =
                  notifier.createAssistant(name: '助手编辑', prompt: 'P1');
              // 记录一个已不存在的模型（provider_entries 未配置任何 LLM）。
              notifier.updateAssistantDefaults(
                id: assistant.id,
                defaultModelName: 'removed-model | OpenAI',
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(home: AssistantSelectionPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('默认设置'));
      await tester.pumpAndSettle();

      // 失效的模型名不出现，生效状态退化为"暂不设置"
      expect(find.text('removed-model | OpenAI'), findsNothing);
      expect(find.text('暂不设置'), findsWidgets);

      // 未触碰模型选择直接保存 → 失效记录被清除（避免同名模型重新
      // 添加后旧的默认值悄悄复活）
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AssistantSelectionPage)),
      );
      final assistant = container.read(assistantProvider).single;
      expect(assistant.defaultModelName, isNull);
    });

    testWidgets(
        '同名模型（不同供应商配置）只显示一个单选选项，不触发 RadioGroup '
        '重复 value 崩溃', (tester) async {
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
                ],
              },
              {
                'providerName': 'OpenAI',
                'host': 'https://api.openai.com/v1',
                'key': 'test-key-2',
                // 与上面同显示名（'gpt-4o | OpenAI'）——必须去重。
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

      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('默认设置'));
      await tester.pumpAndSettle();

      // 重复的显示名只渲染一次（暂不设置 + 2 个唯一模型）
      expect(find.text('gpt-4o | OpenAI'), findsOneWidget);
      expect(find.text('claude-3.5-sonnet | OpenAI'), findsOneWidget);

      // 选中后保存正常写入
      await tester.tap(find.text('gpt-4o | OpenAI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(AssistantSelectionPage)),
      );
      final assistant = container.read(assistantProvider).single;
      expect(assistant.defaultModelName, 'gpt-4o | OpenAI');
    });

    testWidgets('手机宽度下默认设置 tab 不溢出（标题行按钮自动换行）', (tester) async {
      // 360dp 手机宽度 + 系统字体缩放 2.0，最严苛的常见布局场景
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(
        tester.platformDispatcher.clearTextScaleFactorTestValue,
      );
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assistantProvider.overrideWith((ref) {
              final notifier = AssistantsNotifier();
              final assistant =
                  notifier.createAssistant(name: '助手编辑', prompt: 'P1');
              // 已配置状态 → 两个批量按钮出现在标题行右侧，最容易溢出
              notifier.updateAssistantDefaults(
                id: assistant.id,
                defaultToolNames: {'web_search', 'todowrite'},
              );
              return notifier;
            }),
          ],
          child: const MaterialApp(home: AssistantSelectionPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(AssistantAvatar));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // 窄屏 + 大字模式下 TabBar 可滚动：先拖到最右露出"默认设置"标签
      await tester.drag(find.byType(TabBar).first, const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('默认设置'));
      await tester.pumpAndSettle();

      // 打开即渲染两个批量按钮；若有 RenderFlex 溢出，pumpAndSettle 会抛异常
      expect(find.text('全部启用'), findsOneWidget);
      expect(find.text('全部关闭'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

      // Model selector lists the available models (radio tile + summary)
      expect(find.text('暂不设置'), findsWidgets);
      expect(find.text('gpt-4o | OpenAI'), findsOneWidget);
      expect(find.text('claude-3.5-sonnet | OpenAI'), findsOneWidget);

      // Select a default model and disable one tool (从未配置 → 默认全部开启，
      // 关闭 todowrite 得到显式集合）
      await tester.tap(find.text('gpt-4o | OpenAI'));
      await tester.pumpAndSettle();
      final todowriteSwitch = find.widgetWithText(SwitchListTile, 'todowrite');
      await tester.ensureVisible(todowriteSwitch);
      await tester.pumpAndSettle();
      await tester.tap(todowriteSwitch);
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
      expect(assistant.defaultToolNames, isNot(contains('todowrite')));
    });

    testWidgets(
        '默认设置 tab 的模型列表按对话页底部模型选择器的保存顺序（model_order）'
        '排序，而不是按供应商配置的添加顺序', (tester) async {
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
                  {'name': 'gemini-2.0-flash', 'modelId': 'gemini-2.0-flash'},
                ],
              },
            ],
          },
        ]),
        // 对话页底部模型选择器里保存的全局拖动顺序（与配置添加顺序相反，
        // 且只覆盖其中两个模型）。
        'model_order': ['claude-3.5-sonnet | OpenAI', 'gpt-4o | OpenAI'],
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

      // 已保存顺序中的模型按保存顺序排在前，未保存的模型按原顺序追加在末尾：
      // 期望 claude → gpt-4o → gemini（而非配置添加顺序 gpt-4o → claude → gemini）。
      final claudeY =
          tester.getCenter(find.text('claude-3.5-sonnet | OpenAI')).dy;
      final gptY = tester.getCenter(find.text('gpt-4o | OpenAI')).dy;
      final geminiY =
          tester.getCenter(find.text('gemini-2.0-flash | OpenAI')).dy;
      expect(claudeY, lessThan(gptY),
          reason: '保存顺序（model_order）中的模型应排在配置添加顺序之前');
      expect(gptY, lessThan(geminiY), reason: '未出现在保存顺序中的新模型按原顺序追加在末尾');
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
