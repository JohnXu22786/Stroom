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
