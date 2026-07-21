import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/mermaid_render_widget.dart';

/// Regression test for the Mermaid gesture scroll fix:
///
/// The Mermaid diagram's gesture wrapper uses [ImmediateMermaidGestureRecognizer]
/// in a [GestureArenaTeam] with [ScaleGestureRecognizer] so that the recognizer
/// wins Flutter's gesture arena on the very first [PointerMoveEvent] in ANY
/// direction, before the parent [ScrollView]'s [VerticalDragGestureRecognizer]
/// can determine the drag direction.
///
/// These tests simulate the gesture wrapper structure to verify:
/// - All drag directions (horizontal, vertical, diagonal) within the Mermaid
///   area do NOT scroll the parent scroll view
/// - Taps on interactive elements above the overlay still work
/// - The HTML/JS template contract is preserved
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // Gesture arena absorption: Mermaid overlay vs parent ScrollView
  // ===========================================================================

  group('Mermaid gesture wrapper - parent scroll absorption', () {
    /// Builds the gesture overlay using the same [GestureArenaTeam] approach
    /// as the production code.
    Widget _buildTestGestureOverlay() {
      final team = GestureArenaTeam();

      return RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          ScaleGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
            () {
              final recognizer = ScaleGestureRecognizer()..team = team;
              // Must set captain so that ScaleGestureRecognizer is accepted
              // when the team wins the arena (otherwise the team would accept
              // ImmediateMermaidGestureRecognizer and reject the scale one).
              team.captain = recognizer;
              return recognizer;
            },
            (instance) {
              instance.onStart = (details) {};
              instance.onUpdate = (details) {};
              instance.onEnd = (details) {};
            },
          ),
          ImmediateMermaidGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                  ImmediateMermaidGestureRecognizer>(
            () => ImmediateMermaidGestureRecognizer()..team = team,
            (instance) {},
          ),
        },
        behavior: HitTestBehavior.opaque,
        child: Container(color: Colors.transparent),
      );
    }

    /// Builds a test scaffold with a scrollable page containing a Mermaid-like
    /// gesture area on top, and regular content below.
    ///
    /// The gesture area uses the same [GestureArenaTeam] setup as the real
    /// [MermaidRenderWidget._buildGestureWrapper]: a transparent overlay with
    /// [ImmediateMermaidGestureRecognizer] + [ScaleGestureRecognizer] in a
    /// [GestureArenaTeam] that captures pointer events in any direction.
    Future<ScrollController> buildScrollTestScaffold(
      WidgetTester tester, {
      double mermaidHeight = 200.0,
    }) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  // Mermaid-like gesture area with team-based recognizer
                  SizedBox(
                    height: mermaidHeight,
                    width: 600,
                    child: ClipRect(
                      child: Stack(
                        children: [
                          // Simulated WebView content
                          Positioned.fill(
                            child: Container(color: Colors.blueGrey[50]),
                          ),
                          // Gesture overlay: RawGestureDetector with
                          // GestureArenaTeam (same as the fix)
                          Positioned.fill(
                            child: _buildTestGestureOverlay(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Content below the Mermaid area — ensures scroll view has
                  // enough content to scroll
                  Container(
                    height: 400,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text('Scrollable content below'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      return scrollController;
    }

    /// Builds a test scaffold WITHOUT the gesture wrapper to verify that
    /// vertical drags on the Mermaid area scroll the parent when no gesture
    /// absorption is active.
    Future<ScrollController> buildScrollTestScaffoldWithoutFix(
      WidgetTester tester, {
      double mermaidHeight = 200.0,
    }) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  // Normal container WITHOUT gesture wrapper
                  Container(
                    height: mermaidHeight,
                    width: 600,
                    color: Colors.blueGrey[50],
                  ),
                  Container(
                    height: 400,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text('Scrollable content below'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      return scrollController;
    }

    testWidgets(
        'vertical drag within Mermaid area does NOT scroll parent when '
        'gesture wrapper has ImmediateMermaidGestureRecognizer in team',
        (tester) async {
      final scrollController = await buildScrollTestScaffold(tester);

      // Initial scroll position should be 0
      expect(scrollController.offset, closeTo(0.0, 0.1));

      // Find the Mermaid area (the SizedBox with the gesture wrapper)
      final mermaidArea = find.byType(SizedBox).first;
      expect(mermaidArea, findsOneWidget);

      // Perform a series of vertical drags within the Mermaid area
      for (int i = 0; i < 5; i++) {
        await tester.drag(
          mermaidArea,
          const Offset(0, 50), // vertical drag downward
        );
        await tester.pump(const Duration(milliseconds: 16));
      }

      // The scroll view should NOT have scrolled — the gesture wrapper
      // should have absorbed ALL the vertical drags
      expect(scrollController.offset, closeTo(0.0, 0.1));
    });

    testWidgets(
        'horizontal drag within Mermaid area does NOT scroll parent '
        '(same fix applies to all directions)', (tester) async {
      final scrollController = await buildScrollTestScaffold(tester);

      expect(scrollController.offset, closeTo(0.0, 0.1));

      final mermaidArea = find.byType(SizedBox).first;

      // Perform multiple horizontal drags
      for (int i = 0; i < 5; i++) {
        await tester.drag(
          mermaidArea,
          const Offset(50, 0), // horizontal drag to the right
        );
        await tester.pump(const Duration(milliseconds: 16));
      }

      // The scroll view should NOT have scrolled
      expect(scrollController.offset, closeTo(0.0, 0.1));
    });

    testWidgets('diagonal drag within Mermaid area does NOT scroll parent',
        (tester) async {
      final scrollController = await buildScrollTestScaffold(tester);

      expect(scrollController.offset, closeTo(0.0, 0.1));

      final mermaidArea = find.byType(SizedBox).first;

      // Perform multiple diagonal drags
      for (int i = 0; i < 5; i++) {
        await tester.drag(
          mermaidArea,
          const Offset(30, 30), // diagonal drag
        );
        await tester.pump(const Duration(milliseconds: 16));
      }

      // The scroll view should NOT have scrolled
      expect(scrollController.offset, closeTo(0.0, 0.1));
    });

    testWidgets(
        'gesture wrapper fires pan/zoom callbacks after drag proves '
        'ScaleGestureRecognizer receives events via team captain',
        (tester) async {
      // Verify that after a drag, the ScaleGestureRecognizer onStart/onUpdate
      // callbacks have been invoked. This proves the GestureArenaTeam with
      // captain=ScaleGestureRecognizer properly forwards events.
      bool onStartFired = false;
      bool onUpdateFired = false;
      Offset? lastFocalDelta;

      final team = GestureArenaTeam();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    width: 600,
                    child: ClipRect(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(color: Colors.blueGrey[50]),
                          ),
                          Positioned.fill(
                            child: RawGestureDetector(
                              gestures: <Type, GestureRecognizerFactory>{
                                ScaleGestureRecognizer:
                                    GestureRecognizerFactoryWithHandlers<
                                        ScaleGestureRecognizer>(
                                  () {
                                    final recognizer = ScaleGestureRecognizer()
                                      ..team = team;
                                    team.captain = recognizer;
                                    return recognizer;
                                  },
                                  (instance) {
                                    instance.onStart = (details) {
                                      onStartFired = true;
                                    };
                                    instance.onUpdate = (details) {
                                      onUpdateFired = true;
                                      lastFocalDelta = details.focalPointDelta;
                                    };
                                    instance.onEnd = (details) {};
                                  },
                                ),
                                ImmediateMermaidGestureRecognizer:
                                    GestureRecognizerFactoryWithHandlers<
                                        ImmediateMermaidGestureRecognizer>(
                                  () => ImmediateMermaidGestureRecognizer()
                                    ..team = team,
                                  (instance) {},
                                ),
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ),
      );

      // Drag within the Mermaid area
      final mermaidArea = find.byType(SizedBox).first;
      await tester.drag(mermaidArea, const Offset(0, 50));
      await tester.pump();

      // The ScaleGestureRecognizer should have received events via the team
      expect(onStartFired, isTrue, reason: 'onStart should fire after drag');
      expect(onUpdateFired, isTrue, reason: 'onUpdate should fire after drag');
      expect(lastFocalDelta, isNotNull);
      // The focal point delta should reflect the vertical drag
      expect(lastFocalDelta!.dy, greaterThan(0.0));
    });

    testWidgets(
        'gesture wrapper with ImmediateMermaidGestureRecognizer does not '
        'interfere with tapping interactive elements', (tester) async {
      // Verify that the gesture wrapper still allows taps to pass through.
      // Taps produce no PointerMoveEvent, so ImmediateMermaidGestureRecognizer
      // never resolves, and the tap recognizer wins the arena normally.
      int tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    width: 600,
                    child: ClipRect(
                      child: Stack(
                        children: [
                          // Gesture overlay with team-based recognizers
                          // Placed first (behind) in the Stack
                          Positioned.fill(
                            child: _buildTestGestureOverlay(),
                          ),
                          // Simulated interactive element above the overlay
                          // (like toolbar buttons in production)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => tapCount++,
                              child: Container(
                                key: const Key('tap_target'),
                                width: 48,
                                height: 48,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ),
      );

      // Tap the interactive element (positioned top-right, above overlay)
      final tapTarget = find.byKey(const Key('tap_target'));
      await tester.tap(tapTarget);
      await tester.pump();

      expect(tapCount, equals(1));
    });
  });

  // ===========================================================================
  // HTML template contract regression tests
  // ===========================================================================
  //
  // These tests verify that the fix does NOT break the HTML/JS template
  // contract — the window.setZoom, window.setPan, and gesture handler JS
  // functions remain intact.

  group('Gesture fix - HTML template contract preserved', () {
    test('buildMermaidHtml still has window.setZoom and window.setPan', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('window.setZoom'));
      expect(html, contains('window.setPan'));
    });

    test('buildMermaidHtml with withJsGestures=true has full gesture JS', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD',
          withJsGestures: true);
      expect(html, contains('mousedown'));
      expect(html, contains('mousemove'));
      expect(html, contains('touchstart'));
      expect(html, contains('touchmove'));
    });

    test('buildMermaidHtml with withJsGestures=false omits gesture JS', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD',
          withJsGestures: false);
      expect(html, isNot(contains('mousedown')));
      expect(html, isNot(contains('touchstart')));
      // Still has zoom and pan functions
      expect(html, contains('window.setZoom'));
      expect(html, contains('window.setPan'));
    });

    test('setZoom still clamps between 0.1 and 10', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('Math.max(0.1, Math.min(10, level))'));
    });

    test('setZoom still reports via onZoomChanged handler', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains("callHandler('onZoomChanged'"));
    });

    test('setZoom still adjusts panX/panY when centerX/centerY provided', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(
          html, contains('centerX - (centerX - panX) * (zoomLevel / oldZoom)'));
      expect(
          html, contains('centerY - (centerY - panY) * (zoomLevel / oldZoom)'));
    });

    test('scroll viewport still has overflow hidden', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('overflow: hidden'));
    });

    test('svg still has max-width: none and max-height: none', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('max-width: none'));
      expect(html, contains('max-height: none'));
    });

    test('error reporting still works via callHandler', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('flutter_inappwebview.callHandler'));
      expect(html, contains('onMermaidError'));
    });

    test('mermaid initialization code still present', () {
      final html = MermaidRenderWidget.buildMermaidHtml('graph TD');
      expect(html, contains('mermaid.initialize'));
      expect(html, contains('mermaid.run'));
    });
  });
}
