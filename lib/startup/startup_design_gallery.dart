import 'package:flutter/material.dart';

import 'startup_page.dart';
import 'startup_visual_style.dart';

/// A swipeable preview of the startup concepts, built entirely with Flutter UI.
class StartupDesignGallery extends StatelessWidget {
  const StartupDesignGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return PageView(
      children: [
        for (var index = 0; index < StartupVisualStyle.values.length; index++)
          _ConceptPage(
            style: StartupVisualStyle.values[index],
            index: index,
          ),
      ],
    );
  }
}

class _ConceptPage extends StatelessWidget {
  const _ConceptPage({required this.style, required this.index});

  final StartupVisualStyle style;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isPaper = style == StartupVisualStyle.paperDawn;
    return Stack(
      children: [
        Positioned.fill(
          child: StartupPage(
            isWorking: true,
            statusMessage: '正在准备你的学习空间',
            progressDetail:
                'CONCEPT  0${index + 1}  /  0${StartupVisualStyle.values.length}',
            visualStyle: style,
          ),
        ),
        Positioned(
          top: 12,
          right: 16,
          child: SafeArea(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isPaper
                    ? style.cardSurface.withValues(alpha: 0.92)
                    : style.palette.first.withValues(alpha: 0.88),
                border: Border.all(color: style.cardBorder),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  '${style.title}  ·  0${index + 1}',
                  style: TextStyle(
                    color: isPaper ? style.foreground : style.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
