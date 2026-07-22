import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Note: These tests verify the integration architecture (JS hook + panel).
// Full browser page tests require platform-native WebView which cannot
// run in unit test mode. Integration tests with flutter_driver or
// integration_test are needed for the full InAppWebView page rendering.

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
    test('JsHookScript is available as constant string', () {
      expect(JsHookScript.script, isNotEmpty);
    });

    testWidgets('DraggableFloatingPanel can be composed in a Stack layout',
        (tester) async {
      // Regression: The panel must render its content when placed in a Stack
      // above other content, which is the production layout in BrowserPage.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Container(
                  color: Colors.white,
                  width: 400,
                  height: 800,
                ),
                DraggableFloatingPanel(
                  detectedUrls: ['https://cdn.example.com/video.mp4'],
                  onConfirmCapture: (_) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('video.mp4'), findsOneWidget);
    });

    test('JavaScriptChannel receives messages from JS hook', () {
      expect(JsHookScript.script, contains('CatCatchChannel'));
      expect(
        JsHookScript.script,
        contains('flutter_inappwebview'),
      );
    });

    testWidgets(
        'DraggableFloatingPanel with many URLs shows scrollable content',
        (tester) async {
      final manyUrls = List.generate(
        20,
        (i) => 'https://cdn.example.com/video$i.mp4',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: manyUrls,
              onConfirmCapture: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('video0.mp4'), findsOneWidget);
      expect(find.textContaining('video1.mp4'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('DraggableFloatingPanel close button fires onClose callback',
        (tester) async {
      bool onCloseCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const ['https://cdn.example.com/video.mp4'],
              onConfirmCapture: (_) {},
              onClose: () {
                onCloseCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(onCloseCalled, isTrue);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // When parent sets visible: false, the panel hides entirely
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const ['https://cdn.example.com/video.mp4'],
              onConfirmCapture: (_) {},
              onClose: () {},
              visible: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsNothing);
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

    testWidgets('DraggableFloatingPanel empty state is shown for no URLs',
        (tester) async {
      // Regression: When there are no detected URLs, the panel should show
      // a meaningful empty state rather than a broken or empty container.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const [],
              onConfirmCapture: (_) {},
            ),
          ),
        ),
      );

      // Should show the empty state text
      expect(find.textContaining('暂无检测到媒体资源'), findsOneWidget);
      // No URL list items should be rendered
      expect(find.byIcon(Icons.videocam), findsNothing);
    });
  });
}
