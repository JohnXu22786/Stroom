import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'startup_visual_style.dart';

class StartupBackdropPainter extends CustomPainter {
  const StartupBackdropPainter({required this.style, required this.phase});

  final StartupVisualStyle style;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final angle = phase * 2 * math.pi;

    switch (style) {
      case StartupVisualStyle.violetCurrent:
        _drawGlow(canvas, Offset(width * 0.82, height * 0.2), width * 0.72,
            style.secondaryAccent);
        _drawGlow(canvas, Offset(width * 0.15, height * 0.84), width * 0.6,
            style.accent);
        _drawOrbit(canvas, Offset(width * 0.85, height * 0.2), width * 0.43,
            style.foreground.withValues(alpha: 0.12), angle);
        break;
      case StartupVisualStyle.paperDawn:
        final rulePaint = Paint()
          ..color = style.accent.withValues(alpha: 0.09)
          ..strokeWidth = 1;
        for (var index = 0; index < 12; index++) {
          final y = height * 0.08 + (index * 28);
          canvas.drawLine(Offset(0, y), Offset(width, y), rulePaint);
        }
        final marginPaint = Paint()
          ..color = style.secondaryAccent.withValues(alpha: 0.16)
          ..strokeWidth = 1;
        canvas.drawLine(Offset(28, 0), Offset(28, height), marginPaint);
        _drawGlow(canvas, Offset(width * 0.84, height * 0.18), width * 0.58,
            style.secondaryAccent);
        canvas.drawCircle(
          Offset(width * 0.84, height * 0.18),
          width * 0.24,
          Paint()..color = style.accent.withValues(alpha: 0.08),
        );
        break;
      case StartupVisualStyle.oceanSignal:
        for (var index = 0; index < 38; index++) {
          final x = ((index * 197) % 997) / 997 * width;
          final y = ((index * 389) % 991) / 991 * height;
          final drift = math.sin(angle + index) * 4;
          final radius = index % 7 == 0 ? 1.7 : 0.9;
          canvas.drawCircle(
            Offset(x + drift, y),
            radius,
            Paint()
              ..color = (index % 3 == 0 ? style.accent : style.foreground)
                  .withValues(alpha: index % 7 == 0 ? 0.54 : 0.24),
          );
        }
        _drawGlow(canvas, Offset(width * 0.15, height * 0.8), width * 0.52,
            style.secondaryAccent);
        break;
      case StartupVisualStyle.mintGlass:
        final gridPaint = Paint()
          ..color = style.foreground.withValues(alpha: 0.045)
          ..strokeWidth = 1;
        for (var x = 24.0; x < width; x += 38) {
          canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
        }
        for (var y = 22.0; y < height; y += 38) {
          canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
        }
        _drawGlow(canvas, Offset(width * 0.8, height * 0.22), width * 0.6,
            style.accent);
        _drawGlow(canvas, Offset(width * 0.16, height * 0.82), width * 0.58,
            style.secondaryAccent);
        for (final point in [
          Offset(width * 0.1, height * 0.18),
          Offset(width * 0.91, height * 0.72),
          Offset(width * 0.18, height * 0.76),
        ]) {
          canvas.drawCircle(
            point,
            3,
            Paint()..color = style.accent.withValues(alpha: 0.62),
          );
        }
        break;
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

  void _drawOrbit(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double angle,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      angle,
      math.pi * 1.24,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.76),
      -angle * 0.7,
      math.pi * 0.8,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant StartupBackdropPainter oldDelegate) =>
      style != oldDelegate.style || phase != oldDelegate.phase;
}

class StartupSignalOrbitPainter extends CustomPainter {
  const StartupSignalOrbitPainter({required this.style, required this.phase});

  final StartupVisualStyle style;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final angle = phase * 2 * math.pi;
    for (var index = 0; index < 3; index++) {
      final radius = 62.0 + index * 19;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle * (index.isEven ? 1 : -0.72) + index,
        math.pi * (1.12 - index * 0.16),
        false,
        Paint()
          ..color = (index == 1 ? style.secondaryAccent : style.accent)
              .withValues(alpha: 0.38 - index * 0.07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = index == 0 ? 1.5 : 1,
      );
    }
    final beacon = Offset(
      center.dx + math.cos(angle) * 88,
      center.dy + math.sin(angle) * 88,
    );
    canvas.drawCircle(
      beacon,
      4,
      Paint()..color = style.secondaryAccent.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant StartupSignalOrbitPainter oldDelegate) =>
      style != oldDelegate.style || phase != oldDelegate.phase;
}
