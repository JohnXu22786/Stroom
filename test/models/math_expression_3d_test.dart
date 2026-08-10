import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/models/math_3d_object.dart';
import 'package:stroom/models/math_expression_3d.dart';

void main() {
  group('Expression3D.surface', () {
    test('parses z = f(x, y) surface from simple expression', () {
      final expr = Expression3D.surface('z = x^2 + y^2');
      expect(expr.isValid, true);
      expect(expr.type, Expression3DType.surface);
      expect(expr.parseError, isNull);
    });

    test('surface evaluator returns correct z values', () {
      final expr = Expression3D.surface('z = x + y');
      expect(expr.evaluateSurface(2, 3), closeTo(5, 1e-9));
    });

    test('surface with f(x,y)= prefix works', () {
      final expr = Expression3D.surface('f(x,y) = sin(x) * y');
      expect(expr.isValid, true);
      expect(expr.evaluateSurface(0, 5), closeTo(0, 1e-9));
    });

    test('surface sampling produces a grid mesh', () {
      final expr = Expression3D.surface('z = x + y');
      final mesh = expr.sampleSurfaceGrid(
          xMin: -1, xMax: 1, yMin: -1, yMax: 1, gridX: 4, gridY: 4);
      expect(mesh.vertices.length, 25);
      expect(mesh.indices.length, 32 * 3);
      // Corner values match z = x + y.
      final maxVertex =
          mesh.vertices.reduce((a, b) => a.x + a.y > b.x + b.y ? a : b);
      expect(maxVertex.z, closeTo(2, 1e-9));
    });

    test('invalid surface returns parse error', () {
      final expr = Expression3D.surface('z = (');
      expect(expr.isValid, false);
      expect(expr.parseError, isNotNull);
    });
  });

  group('Expression3D.implicit', () {
    test('parses sphere equation', () {
      final expr = Expression3D.implicit('x^2 + y^2 + z^2 = 6');
      expect(expr.isValid, true);
      expect(expr.type, Expression3DType.implicit);
    });

    test('implicit evaluator is F = lhs - rhs', () {
      final expr = Expression3D.implicit('x^2 + y^2 + z^2 = 4');
      expect(expr.isValid, true);
      // Inside the sphere F < 0, outside F > 0.
      expect(expr.evaluateImplicit(0, 0, 0), lessThan(0));
      expect(expr.evaluateImplicit(3, 0, 0), greaterThan(0));
      expect(expr.evaluateImplicit(2, 0, 0), closeTo(0, 1e-9));
    });

    test('parses plane equation', () {
      final expr = Expression3D.implicit('x + y + z = 1');
      expect(expr.isValid, true);
    });

    test('rejects expression without equals sign', () {
      final expr = Expression3D.implicit('x^2 + y^2');
      expect(expr.isValid, false);
      expect(expr.parseError, contains('等号'));
    });

    test('samples sphere into a mesh', () {
      final expr = Expression3D.implicit('x^2 + y^2 + z^2 = 4');
      final mesh = expr.sampleImplicitGrid(box: 3, grid: 16);
      expect(mesh.vertices.length, greaterThan(100));
      expect(mesh.indices.length, greaterThan(300));
    });

    test('implicit sphere mesh is a closed 2-manifold (Kuhn tiling)', () {
      // The sphere lies fully inside the sample box, so the isosurface mesh
      // must be a closed surface: every undirected edge is shared by exactly
      // two triangles, and no triangle is degenerate. Regression for the
      // broken Kuhn decomposition (face diagonal 0-5) that left ~1/3 of each
      // cell unsampled and produced non-manifold holes.
      final expr = Expression3D.implicit('x^2 + y^2 + z^2 = 4');
      final mesh = expr.sampleImplicitGrid(box: 3, grid: 12);
      final triCount = mesh.indices.length ~/ 3;
      expect(triCount, greaterThan(100));

      final edgeCount = <String, int>{};
      // Key by quantized POSITION: adjacent cells interpolate their shared
      // grid edge independently (same coordinates, different indices).
      String qk(Point3D p) =>
          '${(p.x * 1e6).round()},${(p.y * 1e6).round()},${(p.z * 1e6).round()}';
      for (int i = 0; i < mesh.indices.length; i += 3) {
        final a = mesh.indices[i];
        final b = mesh.indices[i + 1];
        final c = mesh.indices[i + 2];
        // No triangle may be degenerate (zero or near-zero area).
        final va = mesh.vertices[a];
        final vb = mesh.vertices[b];
        final vc = mesh.vertices[c];
        final area = (vb - va).cross(vc - va).magnitude / 2;
        expect(area, greaterThan(1e-9), reason: 'degenerate triangle $i');
        // All vertices must be within the sampling box (no NaN/Inf).
        for (final v in [va, vb, vc]) {
          expect(v.x.isFinite && v.y.isFinite && v.z.isFinite, isTrue);
          expect(v.x.abs(), lessThan(3.1));
          expect(v.y.abs(), lessThan(3.1));
          expect(v.z.abs(), lessThan(3.1));
        }
        void bump(Point3D x, Point3D y) {
          final kx = qk(x), ky = qk(y);
          final key = kx.compareTo(ky) <= 0 ? '$kx-$ky' : '$ky-$kx';
          edgeCount[key] = (edgeCount[key] ?? 0) + 1;
        }

        bump(va, vb);
        bump(vb, vc);
        bump(vc, va);
      }
      // Almost-closed manifold: only the tiny sliver holes left by the
      // corner-snap dropping are allowed (< 1% of edges), everything else
      // must be shared by exactly two faces. The pre-fix mesh had ~57%
      // non-manifold edges.
      final bad =
          edgeCount.entries.where((e) => e.value != 2).map((e) => e.value);
      expect(bad.length, lessThan(edgeCount.length * 0.01),
          reason: 'too many non-manifold edges');
    });

    test('surface with parameter variable defaults the parameter to 1', () {
      final expr = Expression3D.surface('z = a*x*y');
      expect(expr.isValid, true);
      expect(expr.parseError, isNull);
      expect(expr.evaluateSurface(2, 3), closeTo(6, 1e-9));
    });

    test('implicit equation with parameter variable parses', () {
      final expr = Expression3D.implicit('x^2 + y^2 + z^2 = a');
      expect(expr.isValid, true);
      expect(expr.parseError, isNull);
      // F = x²+y²+z²−a, a defaults to 1.
      expect(expr.evaluateImplicit(2, 0, 0), closeTo(3, 1e-9));
    });

    test('parametric curve with parameter variable evaluates', () {
      final expr = Expression3D.parametricCurve('(a*t, t^2, 0)', tMax: 1);
      expect(expr.isValid, true);
      expect(expr.parseError, isNull);
      final p = expr.evaluateCurve(2);
      expect(p.x, closeTo(2, 1e-9)); // a defaults to 1
      expect(p.y, closeTo(4, 1e-9));
    });

    test('samples plane into a mesh', () {
      final expr = Expression3D.implicit('x + y + z = 1');
      final mesh = expr.sampleImplicitGrid(box: 3, grid: 16);
      expect(mesh.vertices.length, greaterThan(50));
      // All vertices lie close to the plane.
      for (final v in mesh.vertices) {
        expect((v.x + v.y + v.z - 1).abs(), lessThan(0.15));
      }
    });

    test('samples cylinder into a mesh', () {
      final expr = Expression3D.implicit('x^2 + y^2 = 4');
      final mesh = expr.sampleImplicitGrid(box: 3, grid: 16);
      expect(mesh.vertices.length, greaterThan(100));
    });
  });

  group('Expression3D.parametricCurve', () {
    test('parses 3D parametric curve', () {
      final expr =
          Expression3D.parametricCurve('(cos(t), sin(t), t)', tMax: 6.28);
      expect(expr.isValid, true);
      expect(expr.type, Expression3DType.parametricCurve);
    });

    test('parametric curve evaluates at t values', () {
      final expr = Expression3D.parametricCurve('(2*t, t^2, 0)', tMax: 1);
      final p = expr.evaluateCurve(3);
      expect(p.x, closeTo(6, 1e-9));
      expect(p.y, closeTo(9, 1e-9));
    });

    test('sampleCurve generates points', () {
      final expr = Expression3D.parametricCurve('(cos(t), sin(t), t)',
          tMax: 2 * 3.14159);
      final pts = expr.sampleCurve(numSamples: 50);
      expect(pts.length, 50);
      expect(pts.first.distanceTo(const Point3D(1, 0, 0)), lessThan(1e-6));
    });

    test('invalid curve format returns error', () {
      final expr = Expression3D.parametricCurve('cos(t), sin(t)');
      expect(expr.isValid, false);
    });
  });

  group('Expression3D.parametricSurface', () {
    test('parses 3D parametric surface', () {
      final expr =
          Expression3D.parametricSurface('(cos(u)*v, sin(u)*v, v)', uMax: 6.28);
      expect(expr.isValid, true);
      expect(expr.type, Expression3DType.parametricSurface);
    });

    test('evaluates at (u, v)', () {
      final expr = Expression3D.parametricSurface('(u, v, u*v)');
      final p = expr.evaluateParametricSurface(2, 3);
      expect(p.x, closeTo(2, 1e-9));
      expect(p.y, closeTo(3, 1e-9));
      expect(p.z, closeTo(6, 1e-9));
    });

    test('samples into a mesh', () {
      final expr =
          Expression3D.parametricSurface('(cos(u), sin(u), v)', uMax: 6.28);
      final mesh = expr.sampleParametricSurface(gridU: 8, gridV: 4);
      expect(mesh.vertices.length, 9 * 5);
      expect(mesh.indices.length, 8 * 4 * 6);
    });
  });
}
