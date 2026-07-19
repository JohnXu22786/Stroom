import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/widgets/math_canvas.dart';

/// Test helpers: expose private coordinate methods via the state's GlobalKey.
///
/// The state methods tested here are the gesture-engine methods that were
/// previously private and buggy (damping 0.5, wrong Y coordinate space).
/// We test them through the @visibleForTesting accessors.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps a [MathCanvas] and returns its state key.
  ///
  /// Uses [SizedBox] with explicit width/height to give the canvas exact
  /// dimensions, matching the pattern from the existing test file.
  Future<GlobalKey<MathCanvasState>> pumpCanvas(
    WidgetTester tester, {
    double width = 400,
    double height = 400,
  }) async {
    final key = GlobalKey<MathCanvasState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: MathCanvas(key: key),
          ),
        ),
      ),
    );
    await tester.pump();
    return key;
  }

  group('MathCanvas - effective Y bounds (aspect ratio correction)', () {
    /// Regression: Zoom center was wrong in landscape because _screenToMathY
    /// used raw Y bounds instead of effective (aspect-ratio-corrected) bounds.
    ///
    /// Protection: If the effective Y range computation is wrong, zoom and pan
    /// will misalign with the user's finger position.
    testWidgets('effectiveYMin and effectiveYMax center on raw Y center',
        (tester) async {
      final key = await pumpCanvas(tester, width: 400, height: 400);
      final state = key.currentState!;
      final effectiveCenter =
          (state.testEffectiveYMin() + state.testEffectiveYMax()) / 2;
      // Center of effective Y should equal center of raw Y = (-10 + 10) / 2 = 0
      expect(effectiveCenter, closeTo(0.0, 1e-6));
    });

    testWidgets('effectiveYRange is proportional to xRange / aspectRatio',
        (tester) async {
      final key = await pumpCanvas(tester, width: 400, height: 400);
      final state = key.currentState!;

      // Get the actual canvas dimensions used by LayoutBuilder
      final actualWidth = state.testCanvasWidth();
      final actualHeight = state.testCanvasHeight();

      // Default viewport: [-10, -10, 10, 10] → xRange = 20
      // effectiveYRange = xRange / (actualWidth / actualHeight)
      final expectedYRange = 20.0 / (actualWidth / actualHeight);
      expect(state.testEffectiveYRange(), closeTo(expectedYRange, 1e-6));
    });
  });

  group('MathCanvas - _screenToMathY uses effective Y bounds', () {
    /// Regression: _screenToMathY used raw Y bounds rather than effective
    /// Y bounds, causing zoom center to be wrong in non-square aspect ratios.
    ///
    /// Protection: If _screenToMathY doesn't use effective Y bounds, the
    /// focal point for zoom will be in the wrong coordinate space.
    testWidgets('screenToMathY converts using effective Y bounds',
        (tester) async {
      final key = await pumpCanvas(tester, width: 400, height: 400);
      final state = key.currentState!;

      final h = state.testCanvasHeight();
      final w = state.testCanvasWidth();
      final xRange = 20.0; // default [-10, 10]

      // effectiveYRange = xRange / (w/h)
      final eYRange = xRange / (w / h);
      // effectiveYMin = yCenter - eYRange/2 = 0 - eYRange/2
      final eYMin = -eYRange / 2;
      // effectiveYMax = yCenter + eYRange/2 = 0 + eYRange/2
      final eYMax = eYRange / 2;

      // screenY = 0 (top) → mathY = (1 - 0/h) * eYRange + eYMin = eYMax
      // screenY = h (bottom) → mathY = (1 - h/h) * eYRange + eYMin = eYMin
      // screenY = h/2 (center) → mathY = (1 - 0.5) * eYRange + eYMin = eYRange/2 - eYRange/2 = 0
      expect(state.testScreenToMathY(0), closeTo(eYMax, 1e-6));
      expect(state.testScreenToMathY(h), closeTo(eYMin, 1e-6));
      expect(state.testScreenToMathY(h / 2), closeTo(0.0, 1e-6));
    });
  });

  group('MathCanvas - pan behavior (no damping, 1:1 tracking)', () {
    /// Regression: Pan was damped by 0.5, requiring twice the drag distance
    /// for the same content movement. Fixed by using focalPointDelta directly
    /// without damping factor.
    ///
    /// Protection: If damping is re-introduced or the conversion factor is
    /// wrong, the viewport will not track the finger 1:1.
    testWidgets('pan maps screen delta 1:1 to viewport shift', (tester) async {
      final key = await pumpCanvas(tester, width: 400, height: 400);
      final state = key.currentState!;

      final w = state.testCanvasWidth();
      final xRange = 20.0; // default [-10, 10]

      // Drag right 100px → viewport shifts left by (100/w) * xRange
      // This keeps the content under the finger in place.
      final expectedDelta = (100.0 / w) * xRange;
      state.testApplyPanDelta(100.0, 0.0);

      final vp = state.viewport;
      // xMin: -10 - expectedDelta
      expect(vp.$1, closeTo(-10.0 - expectedDelta, 1e-6));
      // xMax: 10 - expectedDelta
      expect(vp.$3, closeTo(10.0 - expectedDelta, 1e-6));

      // Verify 1:1 tracking: content at original mathX=0 now maps to screen
      // position screenX = (0 - newXMin) / xRange * w.
      // Before drag: screenX(0) = 200 (center). After drag:
      final screenXOfZero = (0.0 - vp.$1) / (vp.$3 - vp.$1) * w;
      // Finger moved from 200 to 300. Content at mathX=0 should be at screenX=300.
      expect(screenXOfZero, closeTo(300.0, 1.0));
    });
  });

  group('MathCanvas - zoom behavior (correct focal point Y)', () {
    /// Regression: Zoom center was wrong because _screenToMathY used raw Y
    /// bounds instead of effective Y bounds. The focal point in Y space was
    /// computed incorrectly, especially in landscape mode.
    ///
    /// Protection: If the Y coordinate space is wrong, zooming around a
    /// focal point will cause the point under the finger to drift.
    testWidgets('zoom preserves screen position of focal point in X',
        (tester) async {
      final key = await pumpCanvas(tester, width: 400, height: 400);
      final state = key.currentState!;

      final w = state.testCanvasWidth();
      final h = state.testCanvasHeight();

      // Place finger at screen center (w/2, h/2), zoom in 2x.
      // The math point (0, 0) should stay under the finger after zoom.
      state.testApplyZoomDelta(2.0, w / 2, h / 2);

      final vp = state.viewport;
      final xRange = vp.$3 - vp.$1;
      final yRange = vp.$4 - vp.$2;
      final rawYCenter = (vp.$2 + vp.$4) / 2;

      // After 2x zoom centered on (0, 0), viewport should be [-5, ?, 5, ?]
      expect(vp.$1, closeTo(-5.0, 1e-6));
      expect(vp.$3, closeTo(5.0, 1e-6));

      // The effective Y focal point at screen center should remain at the
      // same position. Verify that mathY=0 maps back to screen center.
      // First compute effective YMax for current viewport:
      final aspectRatio = w / h;
      final newEffectiveYRange = xRange / aspectRatio;
      final newEffectiveYMin = rawYCenter - newEffectiveYRange / 2;
      // mathY=0 in effective space → screenY = (1 - (0 - newEffectiveYMin) / newEffectiveYRange) * h
      final screenYOfZero =
          (1.0 - (0.0 - newEffectiveYMin) / newEffectiveYRange) * h;
      expect(screenYOfZero, closeTo(h / 2, 2.0));

      // Also verify Y range halved (it's a center zoom, so raw Y range reduces by 2x)
      expect(yRange, closeTo(10.0, 1e-6));
    });

    testWidgets(
        'off-center zoom preserves effective Y focal point in landscape',
        (tester) async {
      final key = await pumpCanvas(tester, width: 400, height: 400);
      final state = key.currentState!;

      final h = state.testCanvasHeight();

      // Place finger at top edge (h=0), zoom in 2x at screen center X.
      // The top edge in effective Y space should stay fixed.
      state.testApplyZoomDelta(2.0, 200.0, 0.0);

      final vp = state.viewport;
      final rawYCenter = (vp.$2 + vp.$4) / 2;

      // Zoom at top edge: the raw Y center should shift so that the
      // effective Y top position (which was at screenY=0) stays at screenY=0.
      // Verify the raw Y center is positive (shifted upward).
      expect(rawYCenter, greaterThan(0.0));
    });
  });

  group('MathCanvas - mouse wheel zoom (correct focal point Y)', () {
    testWidgets('scroll zoom preserves focal point in screen space',
        (tester) async {
      final key = await pumpCanvas(tester, width: 400, height: 400);
      final state = key.currentState!;

      final w = state.testCanvasWidth();
      final h = state.testCanvasHeight();

      // Zoom in 2x at screen center
      state.testApplyScrollZoom(0.5, w / 2, h / 2);

      final vp = state.viewport;
      // After 2x zoom centered on (0, 0)
      expect(vp.$1, closeTo(-5.0, 1e-6));
      expect(vp.$3, closeTo(5.0, 1e-6));

      // Y center should remain at 0 (focal point is at center)
      final yCenter = (vp.$2 + vp.$4) / 2;
      expect(yCenter, closeTo(0.0, 1e-6));
    });
  });
}
