import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Pure-Dart visual concepts for the Stroom startup screen.
enum StartupVisualStyle {
  violetCurrent(
    title: '紫雾流光',
    palette: [Color(0xFF201A39), Color(0xFF58366F), Color(0xFF8E4B73)],
    foreground: Color(0xFFFFF8FF),
    secondaryForeground: Color(0xFFE1D2EB),
    accent: Color(0xFFFFB28E),
    secondaryAccent: Color(0xFFDCA9F2),
    cardSurface: Color(0x2AFFFFFF),
    cardBorder: Color(0x66FFFFFF),
    icon: Icons.auto_awesome_rounded,
  ),
  paperDawn(
    title: '晨光书页',
    palette: [Color(0xFFF8EBD6), Color(0xFFF0D0B3), Color(0xFFDFA99B)],
    foreground: Color(0xFF43313D),
    secondaryForeground: Color(0xFF806673),
    accent: Color(0xFFA75E56),
    secondaryAccent: Color(0xFFC18056),
    cardSurface: Color(0xFFFDF8EF),
    cardBorder: Color(0x66805254),
    icon: Icons.menu_book_rounded,
  ),
  oceanSignal(
    title: '星海电台',
    palette: [Color(0xFF09182D), Color(0xFF17365E), Color(0xFF462F58)],
    foreground: Color(0xFFF3F7FF),
    secondaryForeground: Color(0xFFB8C9DF),
    accent: Color(0xFF7DE7D4),
    secondaryAccent: Color(0xFFFF83A7),
    cardSurface: Color(0x1AFFFFFF),
    cardBorder: Color(0x557DE7D4),
    icon: Icons.graphic_eq_rounded,
  ),
  mintGlass(
    title: '薄荷玻璃',
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
    required this.title,
    required this.palette,
    required this.foreground,
    required this.secondaryForeground,
    required this.accent,
    required this.secondaryAccent,
    required this.cardSurface,
    required this.cardBorder,
    required this.icon,
  });

  final String title;
  final List<Color> palette;
  final Color foreground;
  final Color secondaryForeground;
  final Color accent;
  final Color secondaryAccent;
  final Color cardSurface;
  final Color cardBorder;
  final IconData icon;

  /// Selects a launch appearance without consulting migration or startup state.
  static StartupVisualStyle random({math.Random? random}) {
    final source = random ?? math.Random();
    return values[source.nextInt(values.length)];
  }
}
