import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'startup_visual_style.dart';

class StartupBackdropPainter extends CustomPainter {
  const StartupBackdropPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final style = StartupVisualStyle.mintGlass;

    final gridPaint = Paint()
      ..color = style.foreground.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (var x = 24.0; x < width; x += 38) {
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
    }
    for (var y = 22.0; y < height; y += 38) {
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    _drawGlow(
        canvas, Offset(width * 0.8, height * 0.22), width * 0.6, style.accent);
    _drawGlow(canvas, Offset(width * 0.16, height * 0.82), width * 0.58,
        style.secondaryAccent);

    final angle = phase * 2 * math.pi;
    final drift = math.sin(angle) * 4;
    for (final point in [
      Offset(width * 0.1, height * 0.18),
      Offset(width * 0.91, height * 0.72),
      Offset(width * 0.18, height * 0.76),
    ]) {
      canvas.drawCircle(
        point.translate(drift, 0),
        3,
        Paint()..color = style.accent.withValues(alpha: 0.62),
      );
    }
  }

  void _drawGlow(Canvas canvas, Offset center, double radius, Color color) {
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.24), color.withValues(alpha: 0)],
      ).createShader(bounds);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant StartupBackdropPainter oldDelegate) =>
      phase != oldDelegate.phase;
}
