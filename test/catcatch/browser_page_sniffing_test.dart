import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Note: These tests verify the integration architecture (JS hook + panel).
// Full browser page tests require platform-native WebView which cannot
// run in unit test mode. Integration tests with flutter_driver or
// integration_test are needed for the full InAppWebView page rendering.
// Panel-behavior tests (rendering, selection, minimize, drag) live in
// test/catcatch/draggable_floating_panel_test.dart.

import 'package:stroom/catcatch/engine/js_hook_script.dart';
import 'package:stroom/catcatch/widgets/draggable_floating_panel.dart';

/// Helper that pumps a test environment with the panel stacked above a tap
/// target behind it.
///
/// Uses a [SizedBox.expand()] as a non-positioned child so the [Stack]
/// fills the screen even when the panel is hidden (visible: false).
/// Without a non-positioned child, a Stack with only [Positioned] children
/// and a zero-sized panel (visible: false) would itself be zero-sized.
class _TapTestHelper {
  int backgroundTapCount = 0;

  Widget buildStack(
      {required bool panelVisible, List<String> urls = const []}) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            // Full-screen non-positioned child ensures the Stack fills the
            // available space regardless of other children's sizes.
            const SizedBox.expand(),
            // A tappable background (simulating a WebView button area)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  backgroundTapCount++;
                },
                child: Container(color: Colors.white),
              ),
            ),
            // The panel overlay
            DraggableFloatingPanel(
              visible: panelVisible,
              detectedUrls: urls,
              onConfirmCapture: (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('BrowserPage sniffing architecture', () {
    test('hook script references the CatCatchChannel contract', () {
      // Regression: BrowserPage registers a JavaScript handler named
      // 'CatCatchChannel' and the hook must post to exactly that channel
      // through flutter_inappwebview's callHandler.
      expect(JsHookScript.script, isNotEmpty);
      expect(JsHookScript.script, contains('CatCatchChannel'));
      expect(JsHookScript.script, contains('flutter_inappwebview'));
    });
  });

  // ===========================================================================
  // Click interaction behavior tests
  // ===========================================================================

  group('DraggableFloatingPanel hit testing', () {
    testWidgets(
        'taps on WebView area behind panel (outside panel bounds) reach the WebView',
        (tester) async {
      // Regression: The panel must not create a full-screen compositing layer
      // that blocks pointer events from reaching the WebView below.
      // Taps outside the small panel bounds must reach the background.
      final helper = _TapTestHelper();

      await tester.pumpWidget(
        helper.buildStack(panelVisible: true),
      );

      // Tap in the center of the screen (far from default panel position at
      // top-left corner (8, 8). Panel is 280w x ~120h (minimized) / 320h max)
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();

      // The background tap handler should have been called, proving the tap
      // passed through the panel's Stack without being intercepted.
      expect(helper.backgroundTapCount, greaterThan(0));
    });

    testWidgets(
        'taps inside panel bounds are absorbed by the panel (not passed to WebView)',
        (tester) async {
      // Regression: Taps on the panel itself (e.g., close, minimize, URL list)
      // should be handled by the panel, not passed through to the WebView.
      final helper = _TapTestHelper();

      await tester.pumpWidget(
        helper.buildStack(
            panelVisible: true, urls: ['https://example.com/v.mp4']),
      );

      // The close button is inside the panel bounds at default position (8, 8)
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // The close callback fired, and the background should NOT have received
      // this tap because the panel absorbed it.
      expect(helper.backgroundTapCount, 0);
    });

    testWidgets('panel does not intercept hits when visible=false',
        (tester) async {
      // Regression: When the panel is hidden (visible: false), it must not
      // participate in hit testing at all.
      final helper = _TapTestHelper();

      await tester.pumpWidget(
        helper.buildStack(panelVisible: false),
      );

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // All taps should reach the background since the panel is hidden
      expect(helper.backgroundTapCount, greaterThan(0));
    });
  });
}
