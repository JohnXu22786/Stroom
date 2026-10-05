import 'package:flutter/material.dart';

/// The single visual style used by the Stroom startup screen.
enum StartupVisualStyle {
  mintGlass(
    palette: [Color(0xFF102326), Color(0xFF17453F), Color(0xFF44624F)],
    foreground: Color(0xFFF3FFF6),
    secondaryForeground: Color(0xFFBDD9C6),
    accent: Color(0xFFB8F28B),
    secondaryAccent: Color(0xFF6CE2C8),
    cardSurface: Color(0x24DDF8E8),
    cardBorder: Color(0x66D4F8DC),
    icon: Icons.bubble_chart_rounded,
  );

  const StartupVisualStyle({
    required this.palette,
    required this.foreground,
    required this.secondaryForeground,
    required this.accent,
    required this.secondaryAccent,
    required this.cardSurface,
    required this.cardBorder,
    required this.icon,
  });

  final List<Color> palette;
  final Color foreground;
  final Color secondaryForeground;
  final Color accent;
  final Color secondaryAccent;
  final Color cardSurface;
  final Color cardBorder;
  final IconData icon;
}
