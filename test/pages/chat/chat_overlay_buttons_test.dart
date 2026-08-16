// Widget tests for the ChatOverlayButtons widget in isolation: the
// keyboard-dismiss button must fade/scales in and out (never pop in/out
// abruptly), the scroll-to-bottom button must follow the CURRENT list
// metrics, and the keyboard state must come from the VIEW (the enclosing
// Scaffold strips viewInsets from MediaQuery, exactly like production's
// HomePage).
//
// The page-level interplay (no chat-list rebuild on keyboard transitions,
// corner slide, tap-to-unfocus) is covered by
// chat_page_keyboard_scroll_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/chat/chat_overlay_buttons.dart';

/// A scrollable list + the overlay buttons, wrapped in a Scaffold like
/// production (the Scaffold strips viewInsets from the body's MediaQuery,
/// so an overlay that read MediaQuery instead of the View would fail the
/// keyboard tests below).
Future<void> pumpOverlay(
  WidgetTester tester, {
  required ScrollController scrollController,
  required ValueNotifier<int> metricsTick,
  required VoidCallback onScrollToBottomTap,
  required VoidCallback onKeyboardDismissTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListView.builder(
              controller: scrollController,
              itemCount: 80,
              itemBuilder: (context, i) =>
                  SizedBox(height: 60, child: Text('item $i')),
            ),
            Positioned.fill(
              child: ChatOverlayButtons(
                scrollController: scrollController,
                metricsTick: metricsTick,
                isDark: false,
                onScrollToBottomTap: onScrollToBottomTap,
                onKeyboardDismissTap: onKeyboardDismissTap,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

/// Jumps the list and pumps one frame so the overlay's scroll listener
/// fires.
Future<void> jumpTo(WidgetTester tester, ScrollPosition pos, double value) {
  pos.jumpTo(value);
  return tester.pump();
}

/// Sets the view insets (soft keyboard) and dispatches the metrics change
/// the same way the page-level keyboard tests do. Setting
/// `tester.view.viewInsets` already triggers a synchronous metrics-changed
/// dispatch; the manual dispatch makes sure observers that read the
/// inherited MediaQuery (one frame behind the view) also see the change.
Future<void> setKeyboardInset(WidgetTester tester, double inset) async {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.viewInsets = FakeViewPadding(bottom: inset * dpr);
  await tester.pump(const Duration(milliseconds: 16));
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  tester.binding.handleMetricsChanged();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

/// Restores the view insets to zero (keyboard gone).
Future<void> closeKeyboard(WidgetTester tester) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.viewInsets = FakeViewPadding.zero;
  await tester.pump(const Duration(milliseconds: 16));
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  tester.binding.handleMetricsChanged();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 16));
}

/// The nearest FadeTransition ancestor of [icon] — the AnimatedSwitcher
/// transition of the button itself (not any ancestor app transition).
FadeTransition _fadeOf(WidgetTester tester, IconData icon) {
  return tester.widget<FadeTransition>(
    find
        .ancestor(
          of: find.byIcon(icon),
          matching: find.byType(FadeTransition),
        )
        .first,
  );
}

/// Pumps past the overlay switch animation (250ms) plus one extra frame,
/// so an in-flight enter/exit animation has fully completed.
Future<void> pumpPastSwitch(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 260));
  await tester.pump();
}

void main() {
  late ScrollController scrollController;
  late ValueNotifier<int> metricsTick;
  var scrollTapCount = 0;
  var keyboardTapCount = 0;

  setUp(() {
    scrollController = ScrollController();
    metricsTick = ValueNotifier(0);
    scrollTapCount = 0;
    keyboardTapCount = 0;
  });

  tearDown(() {
    scrollController.dispose();
    metricsTick.dispose();
  });

  Future<void> pumpDefault(WidgetTester tester) {
    return pumpOverlay(
      tester,
      scrollController: scrollController,
      metricsTick: metricsTick,
      onScrollToBottomTap: () => scrollTapCount++,
      onKeyboardDismissTap: () => keyboardTapCount++,
    );
  }

  group('ChatOverlayButtons', () {
    testWidgets(
        'the keyboard-dismiss button fades and scales IN on keyboard open '
        'and fades/scales OUT on close — never a sudden pop',
        (tester) async {
      await pumpDefault(tester);
      addTearDown(tester.view.reset);
      final pos = scrollController.position;
      await jumpTo(tester, pos, pos.maxScrollExtent);
      await jumpTo(tester, pos, pos.maxScrollExtent - 200);
      expect(
        find.byIcon(Icons.keyboard_hide),
        findsNothing,
        reason: 'precondition: no dismiss button while the keyboard is '
            'closed',
      );

      // Keyboard opens: one frame in, the button is already in the tree
      // (the enter animation just started) and is visibly mid-fade.
      await setKeyboardInset(tester, 300);
      expect(find.byIcon(Icons.keyboard_hide), findsOneWidget);
      final fadingIn = _fadeOf(tester, Icons.keyboard_hide);
      expect(
        fadingIn.opacity.value,
        greaterThan(0.0),
        reason: 'mid fade-in the button is already visible',
      );
      expect(
        fadingIn.opacity.value,
        lessThan(1.0),
        reason: 'mid fade-in the button has not fully appeared — it '
            'fades in instead of popping in',
      );

      // The animation completes: fully opaque.
      await pumpPastSwitch(tester);
      expect(
        _fadeOf(tester, Icons.keyboard_hide).opacity.value,
        1.0,
        reason: 'after the enter animation the button is fully visible',
      );

      // Keyboard closes: mid-exit the button is still in the tree, fading.
      await closeKeyboard(tester);
      expect(find.byIcon(Icons.keyboard_hide), findsOneWidget);
      final fadingOut = _fadeOf(tester, Icons.keyboard_hide);
      expect(
        fadingOut.opacity.value,
        lessThan(1.0),
        reason: 'mid fade-out the button has already started fading',
      );
      expect(
        fadingOut.opacity.value,
        greaterThan(0.0),
        reason: 'mid fade-out the button is still visible — it fades out '
            'instead of popping out',
      );

      // After the exit animation the button leaves the tree.
      await pumpPastSwitch(tester);
      expect(find.byIcon(Icons.keyboard_hide), findsNothing);
    });

    testWidgets('the keyboard state comes from the VIEW, not MediaQuery '
        '(the Scaffold strips viewInsets from the body)', (tester) async {
      await pumpDefault(tester);
      addTearDown(tester.view.reset);
      final pos = scrollController.position;
      await jumpTo(tester, pos, pos.maxScrollExtent);
      await jumpTo(tester, pos, pos.maxScrollExtent - 200);

      // If the overlay read the inherited MediaQuery it would always see
      // viewInsets == 0 inside the Scaffold and the button would never
      // appear (the regression the production HomePage Scaffold would
      // have hit).
      await setKeyboardInset(tester, 300);
      expect(find.byIcon(Icons.keyboard_hide), findsOneWidget);
      await closeKeyboard(tester);
      await pumpPastSwitch(tester);
      expect(find.byIcon(Icons.keyboard_hide), findsNothing);
    });

    testWidgets(
        'the scroll-to-bottom button follows the CURRENT metrics: shown '
        'when scrolled up, hidden at the bottom, and recomputed after a '
        'viewport-only change that fires no scroll event', (tester) async {
      await pumpDefault(tester);
      addTearDown(tester.view.reset);
      final pos = scrollController.position;
      await jumpTo(tester, pos, pos.maxScrollExtent);
      expect(find.byIcon(Icons.arrow_downward), findsNothing,
          reason: 'precondition: at the bottom the button is hidden');

      // Scroll up: the button fades in (it is in the tree immediately).
      await jumpTo(tester, pos, pos.maxScrollExtent - 200);
      expect(
        find.byIcon(Icons.arrow_downward),
        findsOneWidget,
        reason: 'scrolled up the button appears',
      );
      await pumpPastSwitch(tester);

      // Back to the bottom: the button fades out and leaves the tree.
      await jumpTo(tester, pos, pos.maxScrollExtent);
      await pumpPastSwitch(tester);
      expect(
        find.byIcon(Icons.arrow_downward),
        findsNothing,
        reason: 'at the bottom the button hides after its exit animation',
      );

      // A viewport-only change (window resize). Growing the window by
      // 400px clamps the 200px-above-bottom position to the new (smaller)
      // max — the clamp DOES notify the controller listeners, so this
      // path exercises the scroll-listener recompute. The genuinely
      // event-free recompute paths (content growth with no scroll event;
      // keyboard viewport changes) are covered by the metrics-tick test
      // below and the page-level keyboard tests.
      await jumpTo(tester, pos, pos.maxScrollExtent - 200);
      await pumpPastSwitch(tester);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      tester.view.physicalSize = const Size(2400, 3000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await pumpPastSwitch(tester);
      expect(
        find.byIcon(Icons.arrow_downward),
        findsNothing,
        reason: 'after the viewport change the button reflects the new '
            '(bottom-clamped) metrics and hides',
      );
    });

    testWidgets(
        'a metrics tick after a content growth (no scroll event, no view '
        'metrics change) surfaces the scroll-to-bottom button — the '
        'viewport-only recompute path', (tester) async {
      await pumpDefault(tester);
      final pos = scrollController.position;
      await jumpTo(tester, pos, pos.maxScrollExtent);
      expect(find.byIcon(Icons.arrow_downward), findsNothing,
          reason: 'precondition: at the bottom the button is hidden');

      // Grow the content (80 → 100 items): maxScrollExtent grows but the
      // position stays — an idle scroll position does not follow content
      // growth and does not notify its controller listeners, so NO scroll
      // event fires. The page's ScrollMetricsNotification handler bumps
      // metricsTick for exactly this case (composer growth, sliver
      // corrections).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ListView.builder(
                  controller: scrollController,
                  itemCount: 100,
                  itemBuilder: (context, i) =>
                      SizedBox(height: 60, child: Text('item $i')),
                ),
                Positioned.fill(
                  child: ChatOverlayButtons(
                    scrollController: scrollController,
                    metricsTick: metricsTick,
                    isDark: false,
                    onScrollToBottomTap: () => scrollTapCount++,
                    onKeyboardDismissTap: () => keyboardTapCount++,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byIcon(Icons.arrow_downward),
        findsNothing,
        reason: 'the content growth alone does not move the button — the '
            'overlay only recomputes when its metrics triggers fire',
      );

      // The page's metrics-notification handler would bump the tick here.
      metricsTick.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byIcon(Icons.arrow_downward),
        findsOneWidget,
        reason: 'after the metrics tick the button reflects the current '
            'metrics and appears — without any scroll event',
      );
      await pumpPastSwitch(tester);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('tapping the buttons fires the page callbacks', (tester) async {
      await pumpDefault(tester);
      final pos = scrollController.position;
      await jumpTo(tester, pos, pos.maxScrollExtent);
      await jumpTo(tester, pos, pos.maxScrollExtent - 200);
      await pumpPastSwitch(tester);

      await tester.tap(find.byIcon(Icons.arrow_downward));
      await tester.pump();
      expect(
        scrollTapCount,
        1,
        reason: 'the scroll-to-bottom tap reaches the page callback',
      );

      await setKeyboardInset(tester, 300);
      await pumpPastSwitch(tester);
      await tester.tap(find.byIcon(Icons.keyboard_hide));
      await tester.pump();
      expect(
        keyboardTapCount,
        1,
        reason: 'the keyboard-dismiss tap reaches the page callback',
      );

      await closeKeyboard(tester);
      await pumpPastSwitch(tester);
    });
  });
}

