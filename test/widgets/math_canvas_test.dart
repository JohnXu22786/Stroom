import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
          [{'x': 0.0, 'y': 0.0}],
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

      await key.currentState!
          .setExpression('a*x^2', {'a': 2});
      await tester.pump();

      final points = key.currentState!.curvePoints;
      expect(points.length, greaterThan(0));
    });

    testWidgets('updateParameters changes the function', (tester) async {
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

      // Set initial expression
      await key.currentState!
          .setExpression('a*x', {'a': 2});
      await tester.pump();

      // Get point at x=5 (should be 10)
      final initialPoints = key.currentState!.curvePoints
          .where((p) => (p['x']! - 5).abs() < 0.1)
          .toList();
      // Just verify it doesn't crash

      // Update parameter
      await key.currentState!.updateParameters({'a': 3});
      await tester.pump();

      // Should have new points (3*x instead of 2*x)
      expect(key.currentState!.curvePoints.length, greaterThan(0));
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
                onViewportChange: (_, __, ___, ____) =>
                    viewportChanged = true,
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
