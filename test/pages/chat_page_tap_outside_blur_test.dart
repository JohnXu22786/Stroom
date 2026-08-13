// Chat page tests for the app-wide tap-outside blur ([TapOutsideUnfocus]).
//
// The app root overrides `EditableTextTapOutsideIntent` so tapping outside a
// focused text field blurs it on every platform. The chat page deliberately
// keeps the keyboard while the user reads/scrolls the message list, so the
// list is grouped with the composer ([TextFieldTapRegion] + shared
// [chatComposerTapRegionGroupId]) — a tap on the list is treated as INSIDE
// the composer's tap region and must NOT blur it.
//
// Behaviors protected:
//  1. Tapping the message list while composing keeps the composer focused
//     (the grouping survives — without it the app-wide override would blur
//     the composer and close the keyboard on list touch).
//  2. Tapping the top bar (outside the group) blurs the composer — the
//     app-wide blur still applies outside the chat message area.
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' hide ChatMessage;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat_page.dart';
import 'package:stroom/providers/conversation_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/widgets/tap_outside_unfocus.dart';

List<ChatMessage> _testMessages(int count) {
  return List.generate(count, (i) {
    return ChatMessage(
      id: i.isEven ? 'user_$i' : 'assistant_$i',
      role: i.isEven ? 'user' : 'assistant',
      content: 'Message $i content',
      createdAt: DateTime(2025, 1, 1).add(Duration(hours: i)),
    );
  });
}

/// Runs [body] with [debugDefaultTargetPlatformOverride] forced to
/// [platform], guaranteeing the override is reset even on failure — the
/// test binding asserts all foundation debug variables are unset at the
/// end of the test body (before addTearDown runs).
Future<void> withPlatform(
  WidgetTester tester,
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// Pumps a ChatPage exactly like production: the app-level
/// [TapOutsideUnfocus] override is present (MaterialApp.builder), so a tap
/// outside the composer's tap region blurs the composer.
Future<void> pumpChat(WidgetTester tester) async {
  final messages = _testMessages(6);
  SharedPreferences.setMockInitialValues({
    'conversations': jsonEncode([
      {
        'id': 'test-conv-id',
        'title': 'Test Conversation',
        'createdAt': DateTime(2025, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2025, 1, 1).toIso8601String(),
        'messages': messages.map((m) => m.toMap()).toList(),
        'isPinned': false,
        'sortOrder': 0,
      }
    ]),
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeConversationIdProvider.overrideWith((ref) => 'test-conv-id'),
        providerEntriesProvider.overrideWith((ref) {
          return ProviderEntriesNotifier();
        }),
      ],
      child: MaterialApp(
        builder: (context, child) =>
            TapOutsideUnfocus(child: child ?? const SizedBox.shrink()),
        home: Scaffold(body: const ChatPage()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  // Let the chat list fully initialize (initial positioning pass, delayed
  // insert/scroll timers from flutter_chat_ui) so the list is interactive.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  tester.takeException();
  // Avoid pending visibility-detector re-check timers at test end.
  final oldUpdateInterval =
      VisibilityDetectorController.instance.updateInterval;
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  addTearDown(() {
    VisibilityDetectorController.instance.updateInterval = oldUpdateInterval;
  });
  addTearDown(tester.view.reset);
}

/// Whether the composer's TextField currently has focus.
bool composerFocused(WidgetTester tester) {
  return tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;
}

void main() {
  group('ChatPage tap-outside blur', () {
    testWidgets(
        'tapping the message list while composing keeps the composer '
        'focused (the list is grouped with the composer)', (tester) async {
      await withPlatform(tester, TargetPlatform.android, () async {
        await pumpChat(tester);

        // Focus the composer input.
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(composerFocused(tester), isTrue,
            reason: 'precondition: the composer input is focused');

        // Tap a message in the list — inside the composer's tap-region
        // group, so the app-wide tap-outside blur must NOT fire. The list
        // widget's center is used (message content renders via markdown,
        // so find.text cannot address a bubble).
        await tester.tap(find.byType(ChatAnimatedList));
        await tester.pump();
        expect(composerFocused(tester), isTrue,
            reason: 'tapping the message list while composing must not blur '
                'the composer (the keyboard stays while the user '
                'reads/scrolls the list)');
      });
    });

    testWidgets(
        'tapping the top bar (outside the group) blurs the composer '
        '(the app-wide override still applies)', (tester) async {
      await withPlatform(tester, TargetPlatform.android, () async {
        await pumpChat(tester);

        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(composerFocused(tester), isTrue);

        // Tap the conversation title in the top bar — outside the
        // composer's tap-region group, so the app-wide blur fires.
        await tester.tap(find.text('Test Conversation'));
        await tester.pump();
        expect(composerFocused(tester), isFalse,
            reason: 'tapping the top bar must blur the composer like any '
                'other outside-tap in the app');
      });
    });

    testWidgets(
        'in search mode, tapping the results list keeps the search field '
        'focused (the search field is in the same tap-region group)',
        (tester) async {
      await withPlatform(tester, TargetPlatform.android, () async {
        await pumpChat(tester);

        // Enter search mode via the top-bar toggle.
        await tester.tap(find.byTooltip('搜索消息'));
        await tester.pump();
        // Precondition: search mode is actually active (the search field's
        // hint is visible). Without this, a missed tooltip tap would
        // silently fall through to the composer and pass for the wrong
        // reason.
        expect(find.text('搜索当前对话...'), findsOneWidget,
            reason: 'precondition: search mode is active');
        // The search bar renders above the composer, so its TextField is
        // the FIRST in the tree once search mode is active.
        final searchField = find.byType(TextField).first;
        final searchEditable = find.descendant(
          of: searchField,
          matching: find.byType(EditableText),
        );
        bool searchFocused() => tester
            .state<EditableTextState>(searchEditable)
            .widget
            .focusNode
            .hasFocus;
        await tester.tap(searchField);
        await tester.pump();
        expect(searchFocused(), isTrue,
            reason: 'precondition: the search field is focused');

        // Tap the results list — the search field is grouped with the
        // message list, so the app-wide blur must NOT fire.
        await tester.tap(find.byType(ChatAnimatedList));
        await tester.pump();
        expect(searchFocused(), isTrue,
            reason: 'tapping the search results list must not blur the '
                'search field (the keyboard stays while browsing results)');
      });
    });
  });
}
