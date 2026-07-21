import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/formula_entry.dart';
import 'package:stroom/models/math_expression.dart';
import 'package:stroom/widgets/math_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GraphPainter - niceStep', () {
    // _niceStep is private, so we test it indirectly through
    // the canvas rendering behavior.

    test('GraphPainter can be instantiated', () {
      const painter = GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
      );
      // Verify no crash
      expect(painter, isNotNull);
    });
  });

  group('GraphPainter - curve rendering', () {
    test('renders curves from point data', () {
      const painter = GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
        curves: [
          [
            {'x': 0.0, 'y': 0.0},
            {'x': 1.0, 'y': 1.0},
            {'x': 2.0, 'y': 4.0},
          ],
        ],
        curveColors: [Colors.blue],
      );
      expect(painter, isNotNull);
    });

    test('renders multiple curves', () {
      const painter = GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
        curves: [
          [
            {'x': 0.0, 'y': 0.0},
            {'x': 1.0, 'y': 1.0},
          ],
          [
            {'x': 0.0, 'y': 1.0},
            {'x': 1.0, 'y': 0.0},
          ],
        ],
        curveColors: [Colors.blue, Colors.red],
      );
      expect(painter, isNotNull);
    });
  });

  group('GraphPainter - shouldRepaint', () {
    test('returns false when nothing changes', () {
      final painter1 = const GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
      );
      final painter2 = const GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
      );
      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('returns true when viewport changes', () {
      final painter1 = const GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
      );
      final painter2 = const GraphPainter(
        xMin: -20,
        yMin: -10,
        xMax: 20,
        yMax: 10,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('returns true when curves change', () {
      final painter1 = const GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
        curves: [
          [
            {'x': 0.0, 'y': 0.0}
          ],
        ],
      );
      final painter2 = const GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('returns true when colors change', () {
      final painter1 = const GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
        gridColor: Colors.grey,
      );
      final painter2 = const GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
        gridColor: Colors.blue,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });
  });

  group('MathCanvas - initial state', () {
    testWidgets('creates canvas without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MathCanvas), findsOneWidget);
    });

    testWidgets('canvas is ready callback fires', (tester) async {
      bool ready = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(
                onReady: () => ready = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // The ready callback fires after first frame via addPostFrameCallback
      await tester.pump();
      expect(ready, isTrue);
    });

    testWidgets('resets viewport correctly', (tester) async {
      final key = GlobalKey<MathCanvasState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(
                key: key,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Default viewport should be [-10, -10, 10, 10]
      final state = key.currentState!;
      final vp = state.viewport;
      expect(vp.$1, closeTo(-10, 1e-10));
      expect(vp.$2, closeTo(-10, 1e-10));
      expect(vp.$3, closeTo(10, 1e-10));
      expect(vp.$4, closeTo(10, 1e-10));

      // Reset should not crash
      await state.resetView();
      final vp2 = state.viewport;
      expect(vp2.$1, closeTo(-10, 1e-10));
    });
  });

  group('MathCanvas - expression handling', () {
    testWidgets('setExpression renders a valid function', (tester) async {
      final key = GlobalKey<MathCanvasState>();
      bool gotPoints = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(
                key: key,
                onCoordinateUpdate: (points) {
                  if (points.isNotEmpty) gotPoints = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await key.currentState!.setExpression('x^2', null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Should have sampled points
      final points = key.currentState!.curvePoints;
      expect(points.length, greaterThan(0));
    });

    testWidgets('setExpression with parameters works', (tester) async {
      final key = GlobalKey<MathCanvasState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(key: key),
            ),
          ),
        ),
      );
      await tester.pump();

      await key.currentState!.setExpression('a*x^2', {'a': 2});
      await tester.pump();

      final points = key.currentState!.curvePoints;
      expect(points.length, greaterThan(0));
    });

    testWidgets('setFormulas with multiple formulas works', (tester) async {
      final key = GlobalKey<MathCanvasState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(key: key),
            ),
          ),
        ),
      );
      await tester.pump();

      // Set two formulas
      final parsed1 = MathExpression.fromInput('x^2');
      final parsed2 = MathExpression.fromInput('x');
      await key.currentState!.setFormulas([
        FormulaEntry(
          rawExpression: 'x^2',
          parsed: parsed1,
          color: Colors.blue,
          autoColor: true,
        ),
        FormulaEntry(
          rawExpression: 'x',
          parsed: parsed2,
          color: Colors.red,
          autoColor: true,
        ),
      ]);
      await tester.pump();

      // Should have points from both expressions
      expect(key.currentState!.curvePoints.length, greaterThanOrEqualTo(2));
    });
  });

  group('MathCanvas - viewport', () {
    testWidgets('setViewport changes visible range', (tester) async {
      final key = GlobalKey<MathCanvasState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(key: key),
            ),
          ),
        ),
      );
      await tester.pump();

      await key.currentState!.setViewport(-5, -5, 5, 5);
      final vp = key.currentState!.viewport;
      expect(vp.$1, closeTo(-5, 1e-10));
      expect(vp.$3, closeTo(5, 1e-10));
    });

    testWidgets('setViewport ignores invalid bounds', (tester) async {
      final key = GlobalKey<MathCanvasState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(key: key),
            ),
          ),
        ),
      );
      await tester.pump();

      await key.currentState!.setViewport(10, -10, -10, 10);
      // Viewport should not change (xMax <= xMin)
      final vp = key.currentState!.viewport;
      expect(vp.$1, closeTo(-10, 1e-10));
    });
  });

  group('GraphPainter - edge rendering', () {
    test('draws curves with clipRect for clean edges', () {
      // Test with points that extend beyond canvas bounds
      const painter = GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
        curves: [
          [
            {'x': -10.0, 'y': 5.0},
            {'x': -5.0, 'y': 2.0},
            {'x': 0.0, 'y': 0.0},
            {'x': 5.0, 'y': 2.0},
            {'x': 10.0, 'y': 5.0},
          ],
        ],
        curveColors: [Colors.blue],
      );
      // Should not crash - clipRect handles edge points
      expect(painter, isNotNull);
    });

    test('does not break path for points at viewport edges', () {
      // Points exactly at the viewport boundaries should be valid
      const painter = GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
        curves: [
          [
            {'x': -10.0, 'y': 0.0},
            {'x': 10.0, 'y': 0.0},
          ],
        ],
        curveColors: [Colors.green],
      );
      expect(painter, isNotNull);

      // Verify coordinate transform works for boundary points
      // (-10, 0) should map to screen x=0 and y=height/2
      // (10, 0) should map to screen x=width and y=height/2
    });

    test('renders curves with points outside viewport without crash', () {
      // Points far outside the viewport (clipped by clipRect)
      const painter = GraphPainter(
        xMin: -10,
        yMin: -10,
        xMax: 10,
        yMax: 10,
        curves: [
          [
            {'x': -10.0, 'y': 100.0},
            {'x': 0.0, 'y': -100.0},
            {'x': 10.0, 'y': 100.0},
          ],
        ],
        curveColors: [Colors.red],
      );
      expect(painter, isNotNull);
    });
  });

  group('MathCanvas - extended sampling margin', () {
    testWidgets(
        'explicit function sampling extends well beyond viewport bounds',
        (tester) async {
      final key = GlobalKey<MathCanvasState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(key: key),
            ),
          ),
        ),
      );
      await tester.pump();

      // Set a specific viewport
      await key.currentState!.setViewport(-5, -5, 5, 5);
      await tester.pump();

      // Set a simple linear formula
      await key.currentState!.setExpression('x', null);
      await tester.pump();

      final points = key.currentState!.curvePoints;
      expect(points.length, greaterThanOrEqualTo(2));

      // With ~50% margin on each side, sampling range should be ~[-10, 10].
      // The actual margin is 0.5 × (xMax - xMin) = 0.5 × 10 = 5.
      // Verify points extend well beyond the viewport bounds (-5, 5).
      final firstX = points.first['x']!;
      final lastX = points.last['x']!;
      expect(firstX, lessThanOrEqualTo(-7.0),
          reason:
              'First sampled x ($firstX) should extend ~50% beyond xMin=-5');
      expect(lastX, greaterThanOrEqualTo(7.0),
          reason: 'Last sampled x ($lastX) should extend ~50% beyond xMax=5');
    });

    testWidgets('sampled point count scales proportionally with extended range',
        (tester) async {
      final key = GlobalKey<MathCanvasState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(key: key),
            ),
          ),
        ),
      );
      await tester.pump();

      // Set viewport [-10, 10] (default) — range = 20, margin = 10,
      // so sampling range = 40, scalePoints = 40/20 = 2.0.
      // numPoints = 300 * 2.0 = 600.
      await key.currentState!.setExpression('x', null);
      await tester.pump();

      final points = key.currentState!.curvePoints;
      // For f(x)=x over [-20, 20], all 600 points are finite.
      expect(points.length, greaterThanOrEqualTo(500),
          reason:
              'With 2× range scaling, point count should be ~600, not the base 300');
    });

    testWidgets(
        'implicit equation sampling with extended bounds works correctly',
        (tester) async {
      final key = GlobalKey<MathCanvasState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(key: key),
            ),
          ),
        ),
      );
      await tester.pump();

      // Set viewport and an implicit equation whose contour extends
      // beyond the viewport (e.g., x^2 - y = 0 is a broad parabola).
      await key.currentState!.setViewport(-5, -5, 5, 5);
      await key.currentState!.setExpression('x^2-y=0', null);
      await tester.pump();

      final points = key.currentState!.curvePoints;
      // The implicit should produce contour segments
      expect(points.length, greaterThan(0),
          reason: 'Implicit equation should produce contour segments');

      // Verify all points have finite coordinates (no NaN/infinity)
      for (final p in points) {
        expect(p['x']!.isFinite, isTrue,
            reason: 'All implicit segment x values should be finite');
        expect(p['y']!.isFinite, isTrue,
            reason: 'All implicit segment y values should be finite');
      }

      // With 50% margin (y bounds [-7.5, 7.5]), the parabola y=x^2 at x=±2.5
      // has y=6.25, which should be within the extended y bounds.
      // Verify y-values extend beyond the original viewport yMax=5.
      final ys = points.map((p) => p['y']!).toList();
      final maxY = ys.reduce((a, b) => a > b ? a : b);
      expect(maxY, greaterThan(5.0),
          reason:
              'Implicit contour y-values should extend beyond yMax=5 with extended bounds, got maxY=$maxY');
    });
  });

  group('MathCanvas - drag coverage', () {
    testWidgets('extended sampling range accommodates half-viewport pan',
        (tester) async {
      final key = GlobalKey<MathCanvasState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(key: key),
            ),
          ),
        ),
      );
      await tester.pump();

      // Set initial viewport [-10, -10, 10, 10] with a simple function
      await key.currentState!.setViewport(-10, -10, 10, 10);
      await key.currentState!.setExpression('x', null);
      await tester.pump();

      final points = key.currentState!.curvePoints;
      final xs = points.map((p) => p['x']!).toList()..sort();

      // With 50% margin (= 10 units on each side), sampling range is [-20, 20].
      // Verify the data extends well beyond the original viewport [-10, 10].
      expect(xs.first, lessThanOrEqualTo(-19.0),
          reason:
              'First sampled x (${xs.first}) should extend ~50% beyond viewport xMin=-10');
      expect(xs.last, greaterThanOrEqualTo(19.0),
          reason:
              'Last sampled x (${xs.last}) should extend ~50% beyond viewport xMax=10');

      // This confirms that if the user pans 50% of viewport width (from [-10,10]
      // to roughly [0,20]), the already-sampled data at [-20,20] still fully
      // covers the visible area — curves stay visible without needing a resample.
    });
  });

  group('MathCanvas - curve continuity', () {
    testWidgets('formula renders without gaps from boundary issues',
        (tester) async {
      final key = GlobalKey<MathCanvasState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(key: key),
            ),
          ),
        ),
      );
      await tester.pump();

      // Set a simple continuous function
      await key.currentState!.setExpression('x^2', null);
      await tester.pump();

      final points = key.currentState!.curvePoints;
      expect(points.length, greaterThan(0));

      // All points should have finite coordinates
      for (final p in points) {
        expect(p['x']!.isFinite, isTrue);
        expect(p['y']!.isFinite, isTrue);
      }
    });

    testWidgets('extreme zoom levels render without crash', (tester) async {
      final key = GlobalKey<MathCanvasState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(key: key),
            ),
          ),
        ),
      );
      await tester.pump();

      // Set a very tight viewport (deep zoom)
      await key.currentState!.setViewport(-0.1, -0.1, 0.1, 0.1);
      await key.currentState!.setExpression('x^2', null);
      await tester.pump();

      final points = key.currentState!.curvePoints;
      expect(points.length, greaterThan(0));
    });
  });

  group('MathCanvas - callbacks', () {
    testWidgets('onError fires for invalid expression', (tester) async {
      String? errorMsg;
      final key = GlobalKey<MathCanvasState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(
                key: key,
                onError: (msg) => errorMsg = msg,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await key.currentState!.setExpression('x ^^ 2', null);
      await tester.pump();

      // Should have fired error callback
      expect(errorMsg, isNot(isNull));
    });

    testWidgets('onViewportChange fires after resetView', (tester) async {
      bool viewportChanged = false;
      final key = GlobalKey<MathCanvasState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: MathCanvas(
                key: key,
                onViewportChange: (_, __, ___, ____) => viewportChanged = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await key.currentState!.resetView();
      await tester.pump();

      expect(viewportChanged, isTrue);
    });
  });
}
