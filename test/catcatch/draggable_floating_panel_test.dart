import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/widgets/draggable_floating_panel.dart';

void main() {
  group('DraggableFloatingPanel', () {
    testWidgets('renders with empty state when no URLs provided',
        (tester) async {
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

      // Should show empty state
      expect(find.textContaining('暂无'), findsOneWidget);
      expect(find.textContaining('等待'), findsOneWidget);
    });

    testWidgets('displays detected URLs in a list', (tester) async {
      final urls = [
        'https://cdn.example.com/video1.mp4',
        'https://cdn.example.com/video2.m3u8',
        'https://cdn.example.com/audio.mp3',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: urls,
              onConfirmCapture: (_) {},
            ),
          ),
        ),
      );

      // Should show all URLs
      for (final url in urls) {
        expect(find.textContaining(url), findsOneWidget);
      }
    });

    testWidgets('calls onConfirmCapture when capture button tapped',
        (tester) async {
      String? capturedUrl;
      final urls = ['https://cdn.example.com/video.mp4'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: urls,
              onConfirmCapture: (url) {
                capturedUrl = url;
              },
            ),
          ),
        ),
      );

      // First, find and tap the first item to select it
      await tester.tap(find.textContaining('video.mp4'));
      await tester.pumpAndSettle();

      // Then tap the confirm button
      await tester.tap(find.text('确认捕获'));
      await tester.pumpAndSettle();

      expect(capturedUrl, equals('https://cdn.example.com/video.mp4'));
    });

    testWidgets('supports selecting different URL then confirming',
        (tester) async {
      String? capturedUrl;
      final urls = [
        'https://cdn.example.com/video1.mp4',
        'https://cdn.example.com/video2.mp4',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: urls,
              onConfirmCapture: (url) {
                capturedUrl = url;
              },
            ),
          ),
        ),
      );

      // Select the second URL
      await tester.tap(find.textContaining('video2.mp4'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('确认捕获'));
      await tester.pumpAndSettle();

      expect(capturedUrl, equals('https://cdn.example.com/video2.mp4'));
    });

    testWidgets('does not show confirm button or call callback on empty list',
        (tester) async {
      bool captureCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const [],
              onConfirmCapture: (_) {
                captureCalled = true;
              },
            ),
          ),
        ),
      );

      // The confirm button should NOT exist when list is empty
      expect(find.text('确认捕获'), findsNothing);
      expect(captureCalled, isFalse);
    });

    testWidgets('shows media type icon for each URL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const ['https://cdn.example.com/video.mp4'],
              onConfirmCapture: (_) {},
            ),
          ),
        ),
      );

      // Should show a video icon
      expect(find.byIcon(Icons.videocam), findsOneWidget);
    });

    testWidgets('shows audio icon for audio URLs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const ['https://cdn.example.com/audio.mp3'],
              onConfirmCapture: (_) {},
            ),
          ),
        ),
      );

      // Should show an audio icon
      expect(find.byIcon(Icons.audio_file), findsOneWidget);
    });

    // ====================================================================
    // Persistence & dragging tests
    // ====================================================================

    testWidgets('panel visibility is controlled by external visible parameter',
        (
      tester,
    ) async {
      // The panel should be visible or hidden based on the
      // externally-controlled [visible] parameter.
      bool onCloseCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const [],
              onConfirmCapture: (_) {},
              visible: true,
              onClose: () {
                onCloseCalled = true;
              },
            ),
          ),
        ),
      );

      // Panel should be visible
      expect(find.textContaining('暂无'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Close the panel explicitly
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // The onClose callback should be called
      expect(onCloseCalled, isTrue);

      // Rebuild with visible: false — panel should hide
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const [],
              onConfirmCapture: (_) {},
              visible: false,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Panel should be hidden now
      expect(find.textContaining('暂无'), findsNothing);
    });

    testWidgets('panel position changes when dragged (parent-managed)', (
      tester,
    ) async {
      // Simulates the parent (BrowserPage) managing position state.
      // The parent uses Positioned + onDragUpdate to reposition the panel.
      Offset panelOffset = const Offset(8, 8);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setLocalState) => Stack(
                children: [
                  const SizedBox.expand(),
                  Positioned(
                    left: panelOffset.dx,
                    top: panelOffset.dy,
                    child: DraggableFloatingPanel(
                      detectedUrls: const [],
                      onConfirmCapture: (_) {},
                      onDragUpdate: (delta) {
                        setLocalState(() {
                          panelOffset = Offset(
                            panelOffset.dx + delta.dx,
                            panelOffset.dy + delta.dy,
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Get initial position of the panel
      final panelFinder = find.text('猫抓嗅探');
      expect(panelFinder, findsOneWidget);

      final initialBox = tester.renderObject<RenderBox>(panelFinder);
      final initialPos = initialBox.localToGlobal(Offset.zero);

      // Drag the panel by some offset
      await tester.drag(panelFinder, const Offset(50, 30));
      await tester.pumpAndSettle();

      // Get new position
      final finalBox = tester.renderObject<RenderBox>(panelFinder);
      final finalPos = finalBox.localToGlobal(Offset.zero);

      // Position should have changed
      expect(finalPos.dx, greaterThan(initialPos.dx),
          reason: 'Panel should move right when dragged right');
      expect(finalPos.dy, greaterThan(initialPos.dy),
          reason: 'Panel should move down when dragged down');
    });

    testWidgets('minimize toggle works correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DraggableFloatingPanel(
              detectedUrls: const ['https://cdn.example.com/video.mp4'],
              onConfirmCapture: (_) {},
            ),
          ),
        ),
      );

      // Should show content (URL list)
      expect(find.textContaining('video.mp4'), findsOneWidget);

      // Tap minimize button
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Content should be hidden
      expect(find.textContaining('video.mp4'), findsNothing);

      // Tap expand button
      await tester.tap(find.byIcon(Icons.expand_less));
      await tester.pumpAndSettle();

      // Content should be visible again
      expect(find.textContaining('video.mp4'), findsOneWidget);
    });

    testWidgets('long URL list scrolls and the last item becomes reachable',
        (tester) async {
      // Regression: the URL list must scroll internally (the panel is
      // capped at 320px) instead of being clipped or overflowing.
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

      // Count badge reflects the full list
      expect(find.text('20'), findsOneWidget);
      // First items visible, last item not built yet (lazy ListView)
      expect(find.textContaining('video0.mp4'), findsOneWidget);
      expect(find.textContaining('video19.mp4'), findsNothing);

      // Scroll the list until the last item becomes visible
      await tester.scrollUntilVisible(
        find.textContaining('video19.mp4'),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.textContaining('video19.mp4'), findsOneWidget);
    });

    testWidgets('stale selection is cleared when the URL list shrinks',
        (tester) async {
      // Regression: BrowserPage mutates one list instance in place (clear +
      // add on navigation) while the panel previously compared list identity
      // in didUpdateWidget — so a selection made before a navigation
      // survived the list reset and crashed the action bar with a RangeError.
      // This test mutates the SAME list instance in place so the identity
      // check can never fire; the out-of-bounds guard prevents the crash.
      String? capturedUrl;

      // One shared list, mutated in place — exactly how BrowserPage feeds
      // the panel across navigations.
      final urls = <String>[
        'https://cdn.example.com/video1.mp4',
        'https://cdn.example.com/video2.mp4',
        'https://cdn.example.com/video3.mp4',
      ];

      Future<void> pump() {
        return tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DraggableFloatingPanel(
                detectedUrls: urls,
                onConfirmCapture: (url) => capturedUrl = url,
              ),
            ),
          ),
        );
      }

      await pump();

      // Select the last item
      await tester.tap(find.textContaining('video3.mp4'));
      await tester.pumpAndSettle();

      // Navigation: same list instance is cleared and refilled with one URL.
      urls.clear();
      urls.add('https://cdn.example.com/video4.mp4');
      await pump();
      await tester.pumpAndSettle();

      // No crash; the confirm button is disabled again.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '确认捕获'),
      );
      expect(button.onPressed, isNull);

      // Nothing can be captured with a stale selection.
      expect(capturedUrl, isNull);
    });

    testWidgets('selection is dropped when the detection epoch changes',
        (tester) async {
      // Regression: a new page can detect the SAME number of URLs as the
      // previous one — a selection kept by index would highlight and
      // capture the wrong URL. The parent bumps detectionEpoch on every
      // navigation; the panel must clear the selection then.
      String? capturedUrl;

      Future<void> pump({required int epoch, required List<String> urls}) {
        return tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DraggableFloatingPanel(
                detectionEpoch: epoch,
                detectedUrls: urls,
                onConfirmCapture: (url) => capturedUrl = url,
              ),
            ),
          ),
        );
      }

      await pump(
        epoch: 0,
        urls: const [
          'https://cdn.example.com/video1.mp4',
          'https://cdn.example.com/video2.mp4',
        ],
      );

      // Select the second URL.
      await tester.tap(find.textContaining('video2.mp4'));
      await tester.pumpAndSettle();

      // New page with the same number of URLs, epoch bumped.
      await pump(
        epoch: 1,
        urls: const [
          'https://cdn.example.com/audio1.mp3',
          'https://cdn.example.com/audio2.mp3',
        ],
      );
      await tester.pumpAndSettle();

      // The selection must be gone — confirming would otherwise capture
      // audio2.mp3 under the old selection.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '确认捕获'),
      );
      expect(button.onPressed, isNull);
      expect(capturedUrl, isNull);

      // Selecting the first new URL captures it correctly.
      await tester.tap(find.textContaining('audio1.mp3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认捕获'));
      await tester.pumpAndSettle();
      expect(capturedUrl, 'https://cdn.example.com/audio1.mp3');
    });

    testWidgets('hidden→shown transition resets minimized and selection',
        (tester) async {
      // Regression: when the panel is hidden and shown again, it must come
      // back expanded with a cleared selection (its default state).
      Future<void> pumpWith(bool visible) {
        return tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DraggableFloatingPanel(
                visible: visible,
                detectedUrls: const ['https://cdn.example.com/video.mp4'],
                onConfirmCapture: (_) {},
              ),
            ),
          ),
        );
      }

      await pumpWith(true);
      await tester.pumpAndSettle();

      // Select the URL and minimize the panel
      await tester.tap(find.textContaining('video.mp4'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      expect(find.textContaining('video.mp4'), findsNothing);

      // Hide then show again
      await pumpWith(false);
      await tester.pumpAndSettle();
      await pumpWith(true);
      await tester.pumpAndSettle();

      // Panel is expanded again and the selection was cleared.
      expect(find.textContaining('video.mp4'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '确认捕获'),
      );
      expect(button.onPressed, isNull);
    });
  });
}
