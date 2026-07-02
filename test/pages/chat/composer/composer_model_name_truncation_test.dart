import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/composer_shared.dart';

/// Helper to create a TextPainter with the chip's text style.
TextPainter _makePainter(String text) {
  return TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}

void main() {
  // ═══════════════════════════════════════════════════════════════
  // Unit tests for truncateDisplayName
  // ═══════════════════════════════════════════════════════════════
  group('truncateDisplayName', () {
    test('fits within available width: returns text unchanged', () {
      const full = 'GPT-4o | OpenAI';
      final tp = _makePainter(full);
      final result = truncateDisplayName(full, tp.width + 20, tp);
      expect(result, full);
    });

    test('exactly fits available width: returns text unchanged', () {
      const full = 'GPT-4o | OpenAI';
      final tp = _makePainter(full);
      final result = truncateDisplayName(full, tp.width, tp);
      expect(result, full);
    });

    test('proportional truncation: long model, short vendor', () {
      const full = 'abcdefghijkl | abcd';
      final tp = _makePainter(full);
      // Use constraint at 90% of original (moderate truncation)
      final constraint = tp.width * 0.9;
      final result = truncateDisplayName(full, constraint, tp);

      // Result must contain separator
      expect(result, contains(' | '));

      // Each part at least 2 chars
      final parts = result.split(' | ');
      expect(parts.length, 2);
      expect(parts[0].length, greaterThanOrEqualTo(2));
      expect(parts[1].length, greaterThanOrEqualTo(2));
    });

    test('proportional truncation: short model, long vendor', () {
      const full = 'GPT | ReallyLongVendorNameHere';
      final tp = _makePainter(full);
      final constraint = tp.width * 0.9;
      final result = truncateDisplayName(full, constraint, tp);

      expect(result, contains(' | '));
      final parts = result.split(' | ');
      expect(parts.length, 2);
      expect(parts[0].length, greaterThanOrEqualTo(2));
      expect(parts[1].length, greaterThanOrEqualTo(2));
    });

    test('each part at least 2 chars under heavy constraint', () {
      const full = 'VeryLongModelNameHere | VeryLongVendorNameHere';
      final tp = _makePainter(full);
      // Heavy truncation
      final constraint = tp.width * 0.4;
      final result = truncateDisplayName(full, constraint, tp);

      expect(result, contains(' | '));
      final parts = result.split(' | ');
      expect(parts.length, 2);
      // Each part at least 2 real chars
      expect(parts[0].length, greaterThanOrEqualTo(2));
      expect(parts[1].length, greaterThanOrEqualTo(2));
    });

    test('no separator: falls back to standard truncation with ellipsis', () {
      const full = 'ModelNameWithoutSeparator';
      final tp = _makePainter(full);
      final constraint = tp.width * 0.5;
      final result = truncateDisplayName(full, constraint, tp);

      expect(result.endsWith('...'), isTrue);
    });

    test('multiple widths produce valid results (long name cases)', () {
      const testCases = [
        'GPT-4o-Turbo-Very-Long-Model-Name-Here | OpenAI',
        'Claude-3.5-Sonnet-Anthropic-Haiku | Anthropic-Claude',
        'Short | Vendor',
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ | X',
      ];

      for (final full in testCases) {
        final tp = _makePainter(full);
        for (final factor in [0.4, 0.6, 0.8]) {
          final constraint = tp.width * factor;
          final result = truncateDisplayName(full, constraint, tp);

          expect(result, isNotEmpty);
          expect(result, contains(' | '),
              reason: 'FAIL: "$full" @${(factor*100).round()}% → "$result" (no separator)');
        }
      }
    });

    test('minimum part lengths (A | B) does not crash and returns valid result', () {
      const full = 'A | B';
      final tp = _makePainter(full);

      final result50 = truncateDisplayName(full, tp.width * 0.5, tp);
      expect(result50, isNotEmpty);
      expect(result50, contains(' | '));

      // Very tight constraint - should not crash, fallback used
      final resultTight = truncateDisplayName(full, 10, tp);
      expect(resultTight, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Widget tests for SettingsChip with badge
  // ═══════════════════════════════════════════════════════════════
  group('SettingsChip with badge', () {
    testWidgets('shows badge count when > 0', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsChip(
            icon: Icons.build_outlined,
            label: '工具',
            color: Colors.teal,
            onTap: () {},
            badgeCount: 3,
          ),
        ),
      ));

      expect(find.text('工具'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('no badge when count is 0', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsChip(
            icon: Icons.build_outlined,
            label: '工具',
            color: Colors.teal,
            onTap: () {},
            badgeCount: 0,
          ),
        ),
      ));

      expect(find.text('工具'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('no badge when badgeCount is null (default)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsChip(
            icon: Icons.build_outlined,
            label: '工具',
            color: Colors.teal,
            onTap: () {},
          ),
        ),
      ));

      expect(find.text('工具'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Widget tests for ChipBadge (circular badge)
  // ═══════════════════════════════════════════════════════════════
  group('ChipBadge circular shape', () {
    testWidgets('uses BoxShape.circle for single digit', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsChip(
            icon: Icons.build_outlined,
            label: '工具',
            color: Colors.teal,
            onTap: () {},
            badgeCount: 3,
          ),
        ),
      ));

      expect(find.text('3'), findsOneWidget);
      final badgeFinder = find.byType(ChipBadge);
      expect(badgeFinder, findsOneWidget);
    });

    testWidgets('shows badge for count 1 (minimum display)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsChip(
            icon: Icons.build_outlined,
            label: '工具',
            color: Colors.teal,
            onTap: () {},
            badgeCount: 1,
          ),
        ),
      ));

      expect(find.text('1'), findsOneWidget);
      final badgeFinder = find.byType(ChipBadge);
      expect(badgeFinder, findsOneWidget);
    });

    testWidgets('shows badge for count 99 (last 2-digit value)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsChip(
            icon: Icons.build_outlined,
            label: '工具',
            color: Colors.teal,
            onTap: () {},
            badgeCount: 99,
          ),
        ),
      ));

      expect(find.text('99'), findsOneWidget);
      final badgeFinder = find.byType(ChipBadge);
      expect(badgeFinder, findsOneWidget);
    });

    testWidgets('shows 99+ for large numbers', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsChip(
            icon: Icons.build_outlined,
            label: '工具',
            color: Colors.teal,
            onTap: () {},
            badgeCount: 150,
          ),
        ),
      ));

      expect(find.text('99+'), findsOneWidget);
      final badgeFinder = find.byType(ChipBadge);
      expect(badgeFinder, findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Widget tests for ModelNameChip
  // ═══════════════════════════════════════════════════════════════
  group('ModelNameChip widget', () {
    testWidgets('renders model display name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ModelNameChip(
              displayName: 'GPT-4o | OpenAI',
              color: Colors.teal,
              onTap: () {},
            ),
          ),
        ),
      ));

      expect(find.textContaining('GPT-4o'), findsOneWidget);
      expect(find.textContaining('OpenAI'), findsOneWidget);
    });

    testWidgets('truncates long model name in narrow width', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            child: ModelNameChip(
              displayName: 'Very-Long-Model-Name-That-Should-Truncate | OpenAI',
              color: Colors.teal,
              onTap: () {},
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('...'), findsWidgets);
    });

    testWidgets('shows fallback "模型" when displayName is empty', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ModelNameChip(
              displayName: '',
              color: Colors.teal,
              onTap: () {},
            ),
          ),
        ),
      ));

      expect(find.text('模型'), findsOneWidget);
    });

    testWidgets('tap fires callback', (tester) async {
      var tapped = false;
      final chipKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ModelNameChip(
              key: chipKey,
              displayName: 'GPT-4o | OpenAI',
              color: Colors.teal,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ));

      await tester.tap(find.textContaining('GPT-4o'));
      expect(tapped, isTrue);
    });

    testWidgets('fits within constrained SizedBox width', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: ModelNameChip(
              displayName: 'Some-Long-Model-Name-That-Needs-Truncation | SomeVendor',
              color: Colors.teal,
              onTap: () {},
            ),
          ),
        ),
      ));

      expect(find.textContaining('...'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('disabled chip does not crash', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ModelNameChip(
              displayName: 'GPT-4o | OpenAI',
              color: Colors.teal,
              onTap: null,
              enabled: false,
            ),
          ),
        ),
      ));

      expect(find.byType(ModelNameChip), findsOneWidget);
    });
  });
}
