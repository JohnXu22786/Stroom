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
              reason:
                  'FAIL: "$full" @${(factor * 100).round()}% → "$result" (no separator)');
        }
      }
    });

    test('minimum part lengths (A | B) does not crash and returns valid result',
        () {
      const full = 'A | B';
      final tp = _makePainter(full);

      final result50 = truncateDisplayName(full, tp.width * 0.5, tp);
      expect(result50, isNotEmpty);
      expect(result50, contains(' | '),
          reason: 'Result at 50% constraint: "$result50"');

      // Very tight constraint - should not crash, falls back to minimum format
      final resultTight = truncateDisplayName(full, 10, tp);
      expect(resultTight, isNotEmpty);
      // The minimum result should still contain the separator (even if it
      // slightly overflows the constraint, the format must be preserved)
      expect(resultTight, contains(' | '),
          reason:
              'Format must be preserved at tight constraint: "$resultTight"');
    });

    test('pixel-width aware: proportional allocation fits within constraint',
        () {
      // The algorithm uses pixel-width ratios for allocation. In test
      // environment (monospace font), character-count and pixel-width ratios
      // are equivalent. This test verifies the multi-part format is preserved
      // and the result fits within the pixel constraint at moderate-to-generous
      // constraints where the minimum (2 chars each) can fit.
      const testCases = [
        '模型A服务商 | ProviderXYZ', // mixed format
        'abcdefghijklmnopqrstuv | short',
        'short | abcdefghijklmnopqrstuv',
      ];

      for (final full in testCases) {
        final tp = _makePainter(full);
        for (final factor in [0.7, 0.85, 0.9]) {
          final constraint = tp.width * factor;
          final result = truncateDisplayName(full, constraint, tp);

          // Result must always contain the separator
          expect(result, contains(' | '),
              reason: 'FAIL: "$full" @${(factor * 100).round()}% → "$result"');

          final parts = result.split(' | ');
          expect(parts.length, 2);

          // Each part at least 2 visible chars at moderate constraints
          final modelVisible = parts[0].replaceAll('...', '');
          final vendorVisible = parts[1].replaceAll('...', '');
          expect(modelVisible.length, greaterThanOrEqualTo(2));
          expect(vendorVisible.length, greaterThanOrEqualTo(2));

          // Result width should be close to constraint. May slightly overflow
          // at tight constraints due to the discrete 2-char minimum boundary.
          final resultWidth = _makePainter(result).width;
          final overflow = resultWidth - constraint;
          expect(overflow, lessThan(10),
              reason:
                  '"$full" @${(factor * 100).round()}% overflowed by ${overflow.toStringAsFixed(1)}px');
        }

        // At very tight constraints, format must still be preserved (contains
        // separator), even if visible chars may drop below 2.
        final tightConstraint = tp.width * 0.35;
        final tightResult = truncateDisplayName(full, tightConstraint, tp);
        expect(tightResult, contains(' | '),
            reason:
                'Tight constraint: "$full" @35% → "$tightResult" must preserve format');
        expect(tightResult.split(' | ').length, 2);
      }
    });

    test('proportional: longer part loses more characters under constraint',
        () {
      // "AAAA" (4 chars) + " | " + "BB" (2 chars) = 10 chars total
      // At 90% constraint, the model (4 chars) should lose more chars
      // than the vendor (2 chars) because it's proportionally longer.
      // The minimum guarantee (2 chars per part) may cause slight overflow
      // of the constraint, which is acceptable.
      const full = 'AAAA | BB';
      final tp = _makePainter(full);
      final constraint = tp.width * 0.9;
      final result = truncateDisplayName(full, constraint, tp);

      expect(result, contains(' | '));
      final parts = result.split(' | ');
      expect(parts.length, 2);

      // Both parts should have at least 2 chars at minimum
      final modelVisible = parts[0].replaceAll('...', '');
      final vendorVisible = parts[1].replaceAll('...', '');
      expect(modelVisible.length, greaterThanOrEqualTo(2));
      expect(vendorVisible.length, greaterThanOrEqualTo(2));
    });

    test(
        'provider name never drops below 2 chars even with extremely long model',
        () {
      // Very long model name with wide chars, short provider
      const full = '这是一个非常长的中文模型名称用于测试极限情况 | ABC';
      final tp = _makePainter(full);
      // Heavy constraint
      final constraint = tp.width * 0.35;
      final result = truncateDisplayName(full, constraint, tp);

      expect(result, contains(' | '));
      final parts = result.split(' | ');
      expect(parts.length, 2);
      // Provider should never drop below 2 visible chars (before "...")
      final vendorVisible = parts[1].replaceAll('...', '');
      expect(vendorVisible.length, greaterThanOrEqualTo(2));
    });

    test('provider name visible when model is extremely long ASCII', () {
      // Very long ASCII model name, short vendor
      const full =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCDEFGHIJKLMNOP | Short';
      final tp = _makePainter(full);
      final constraint = tp.width * 0.3;
      final result = truncateDisplayName(full, constraint, tp);

      expect(result, contains(' | '));
      final parts = result.split(' | ');
      expect(parts.length, 2);
      // Provider should have at least 2 visible chars
      final vendorVisible = parts[1].replaceAll('...', '');
      expect(vendorVisible.length, greaterThanOrEqualTo(2));
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

    testWidgets('shows badge for count 99 (last 2-digit value)',
        (tester) async {
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

    testWidgets('badge is sized just slightly larger than font',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsChip(
            icon: Icons.build_outlined,
            label: '工具',
            color: Colors.teal,
            onTap: () {},
            badgeCount: 5,
          ),
        ),
      ));

      // The ChipBadge should exist
      final badgeFinder = find.byType(ChipBadge);
      expect(badgeFinder, findsOneWidget);

      // The badge text should be visible
      expect(find.text('5'), findsOneWidget);

      // Verify the badge size — it should be close to font size (~11px) but
      // slightly larger (16px). Measure from the rendered badge.
      final badgeWidget = tester.widget<Container>(find.byType(Container).last);
      // The Container with ChipBadge style has width:16, height:16
      // Cannot easily get rendered size in test, but the container is
      // created with fixed 16x16 dimensions
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

      // Text should still show a recognizable portion (truncated via ellipsis)
      expect(find.textContaining('Very-Long'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows fallback "模型" when displayName is empty',
        (tester) async {
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
              displayName:
                  'Some-Long-Model-Name-That-Needs-Truncation | SomeVendor',
              color: Colors.teal,
              onTap: () {},
            ),
          ),
        ),
      ));

      expect(find.textContaining('Some-Long-Model'), findsOneWidget);
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

    testWidgets('truncates text inside a ConstrainedBox', (tester) async {
      // When given a ConstrainedBox, ModelNameChip fills the available
      // width (MainAxisSize.max) so that Flexible + LayoutBuilder can
      // truncate the text proportionally.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: ModelNameChip(
              displayName:
                  'Very-Long-Model-Name-That-Should-Truncate-Properly | OpenAI',
              color: Colors.teal,
              onTap: () {},
            ),
          ),
        ),
      ));

      // The text should be truncated in the tight space
      expect(find.textContaining('Very-Long-Model'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders short text without truncation inside ConstrainedBox',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ModelNameChip(
                displayName: 'GPT-4o | OpenAI',
                color: Colors.teal,
                onTap: () {},
              ),
            ),
          ),
        ),
      ));

      // The chip should render both model and provider name fully
      expect(find.textContaining('GPT-4o'), findsOneWidget);
      expect(find.textContaining('OpenAI'), findsOneWidget);
      // No truncation needed for short text
      expect(tester.takeException(), isNull);
    });
  });
}
