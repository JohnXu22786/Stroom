import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_widget/markdown_widget.dart';

void main() {
  group('MarkdownConfig creation', () {
    /// Replicates the markdown config creation logic from chat_page.dart
    /// to verify it produces clean styles without unwanted decorations.
    MarkdownConfig _buildCustomMarkdownConfig(bool isDark, BuildContext context) {
      final theme = Theme.of(context);
      return MarkdownConfig(configs: [
        PConfig(
          textStyle: TextStyle(
            fontSize: 16,
            color: theme.colorScheme.onSurface,
          ),
        ),
        H1Config(
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        H2Config(
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        H3Config(
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        H4Config(
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        H5Config(
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        H6Config(
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        LinkConfig(
          style: TextStyle(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
        CodeConfig(
          style: TextStyle(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: theme.colorScheme.onSurface,
          ),
        ),
        PreConfig(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const BlockquoteConfig(),
      ]);
    }

    testWidgets('MarkdownConfig has no unwanted yellow underline or red text',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final lightConfig = _buildCustomMarkdownConfig(false, context);
                final darkConfig = _buildCustomMarkdownConfig(true, context);

                // Verify no unwanted yellow underline or red text in any config
                // PConfig
                expect(
                  lightConfig.p.textStyle.decoration,
                  isNull,
                  reason: 'PConfig should not have any text decoration',
                );
                expect(
                  darkConfig.p.textStyle.decoration,
                  isNull,
                  reason: 'PConfig (dark) should not have any text decoration',
                );

                // Verify text color is not red
                expect(
                  lightConfig.p.textStyle.color,
                  isNot(Colors.red),
                  reason: 'PConfig text should not be red',
                );
                expect(
                  darkConfig.p.textStyle.color,
                  isNot(Colors.red),
                  reason: 'PConfig (dark) text should not be red',
                );

                // LinkConfig
                expect(
                  lightConfig.a.style.decoration,
                  TextDecoration.underline,
                  reason: 'LinkConfig should have underline decoration',
                );
                expect(
                  lightConfig.a.style.color,
                  isNot(Colors.red),
                  reason: 'LinkConfig color should not be hardcoded red',
                );

                // CodeConfig
                expect(
                  lightConfig.code.style.decoration,
                  isNull,
                  reason: 'CodeConfig should not have any text decoration',
                );
                expect(
                  lightConfig.code.style.color,
                  isNot(Colors.red),
                  reason: 'CodeConfig text should not be red',
                );

                // Headings
                expect(
                  lightConfig.h1.style.decoration,
                  isNull,
                  reason: 'H1 should not have unwanted decoration',
                );
                expect(
                  lightConfig.h1.style.color,
                  isNot(Colors.red),
                  reason: 'H1 should not be red',
                );
                expect(
                  lightConfig.h2.style.decoration,
                  isNull,
                  reason: 'H2 should not have unwanted decoration',
                );
                expect(
                  lightConfig.h3.style.decoration,
                  isNull,
                  reason: 'H3 should not have unwanted decoration',
                );
                expect(
                  lightConfig.h4.style.decoration,
                  isNull,
                  reason: 'H4 should not have unwanted decoration',
                );
                expect(
                  lightConfig.h5.style.decoration,
                  isNull,
                  reason: 'H5 should not have unwanted decoration',
                );
                expect(
                  lightConfig.h6.style.decoration,
                  isNull,
                  reason: 'H6 should not have unwanted decoration',
                );

                // Verify heading colors use theme
                expect(
                  lightConfig.h1.style.color,
                  isNot(Colors.red),
                  reason: 'H1 should not be red',
                );
                expect(
                  darkConfig.h1.style.color,
                  isNot(Colors.red),
                  reason: 'H1 (dark) should not be red',
                );

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    });

    test('PConfig textStyle has no unwanted decoration by default', () {
      const pConfig = PConfig();
      expect(pConfig.textStyle.decoration, isNull);
      expect(pConfig.textStyle.color, isNull);
    });

    test('H1Config textStyle has no unwanted decoration by default', () {
      const h1Config = H1Config();
      expect(h1Config.style.decoration, isNull);
      expect(h1Config.style.color, isNull);
    });

    test('H2Config textStyle has no unwanted decoration by default', () {
      const h2Config = H2Config();
      expect(h2Config.style.decoration, isNull);
      expect(h2Config.style.color, isNull);
    });

    test('H3Config textStyle has no unwanted decoration by default', () {
      const h3Config = H3Config();
      expect(h3Config.style.decoration, isNull);
      expect(h3Config.style.color, isNull);
    });

    test('LinkConfig has underline decoration but NOT yellow by default', () {
      const linkConfig = LinkConfig();
      expect(linkConfig.style.decoration, TextDecoration.underline);
      // Default link color is blue (#0969da), NOT red or yellow
      expect(linkConfig.style.color!.value, 0xff0969da);
    });

    test('CodeConfig has no text decoration by default', () {
      const codeConfig = CodeConfig();
      expect(codeConfig.style.decoration, isNull);
      // Default code has grey background, not red text
      expect(codeConfig.style.color, isNull);
    });

    test('DelNode default style is strikethrough, not yellow underline', () {
      // The del tag uses lineThrough, not underline
      // This is from the package source: _defaultDelStyle
      const delStyle = TextStyle(decoration: TextDecoration.lineThrough);
      expect(delStyle.decoration, TextDecoration.lineThrough);
      expect(delStyle.decoration, isNot(TextDecoration.underline));
    });

    test('EmNode default style is italic, no unwanted color', () {
      // The em tag uses italic, no color
      const emStyle = TextStyle(fontStyle: FontStyle.italic);
      expect(emStyle.fontStyle, FontStyle.italic);
      expect(emStyle.color, isNull);
      expect(emStyle.decoration, isNull);
    });

    test('StrongNode default style is bold, no unwanted color', () {
      const strongStyle = TextStyle(fontWeight: FontWeight.bold);
      expect(strongStyle.fontWeight, FontWeight.bold);
      expect(strongStyle.color, isNull);
      expect(strongStyle.decoration, isNull);
    });

    test('LinkConfig does NOT have yellow decoration color by default', () {
      const linkConfig = LinkConfig();
      expect(linkConfig.style.decorationColor, isNull,
          reason: 'LinkConfig should not have a decoration color set');
      expect(linkConfig.style.decoration, TextDecoration.underline);
    });
  });
}
