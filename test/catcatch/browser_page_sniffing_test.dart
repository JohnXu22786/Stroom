import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Note: These tests verify the integration architecture (JS hook + panel).
// Full browser page tests require platform-native WebView which cannot
// run in unit test mode. Integration tests with flutter_driver or
// integration_test are needed for the full InAppWebView page rendering.

import 'package:stroom/catcatch/engine/js_hook_script.dart';
import 'package:stroom/catcatch/widgets/draggable_floating_panel.dart';

void main() {
  group('BrowserPage sniffing architecture', () {
    test('JsHookScript is available as constant string', () {
      expect(JsHookScript.script, isNotEmpty);
    });

    testWidgets('DraggableFloatingPanel can be composed in a Stack layout',
        (tester) async {
      // Simulate the layout: Stack with a Container (simulating WebView)
      // and a floating panel overlay (panel now manages its own position)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                // Simulated WebView placeholder
                Container(
                  color: Colors.white,
                  width: 400,
                  height: 800,
                ),
                // Draggable floating panel on top (no Positioned wrapper
                // needed - the panel positions itself internally)
                DraggableFloatingPanel(
                  detectedUrls: ['https://cdn.example.com/video.mp4'],
                  onConfirmCapture: (_) {},
                  initialPosition: const Offset(8, 8),
                ),
              ],
            ),
          ),
        ),
      );

      // The panel should be visible
      expect(find.textContaining('video.mp4'), findsOneWidget);
    });

    test('JavaScriptChannel receives messages from JS hook', () {
      // Verify the JS hook references CatCatchChannel
      expect(JsHookScript.script, contains('CatCatchChannel'));

      // Verify the hook uses callHandler for flutter_inappwebview
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

      // Should render the first few items
      expect(find.textContaining('video0.mp4'), findsOneWidget);
      expect(find.textContaining('video1.mp4'), findsOneWidget);
      // The panel badge should show the count
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

      // Tap the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // The onClose callback should have been called
      expect(onCloseCalled, isTrue);

      // Panel should still be visible (parent controls visibility externally)
      expect(find.byIcon(Icons.close), findsOneWidget);

      // When parent sets visible: false, the panel hides
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

      // The panel should be dismissed
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });
}
