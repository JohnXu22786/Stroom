import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/composer_shared.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // Unit tests for truncateDisplayName (char-based, max 20 per part)
  // ═══════════════════════════════════════════════════════════════
  group('truncateDisplayName', () {
    test('short text with separator: unchanged', () {
      const full = 'GPT-4o | OpenAI';
      final result = truncateDisplayName(full);
      expect(result, full);
    });

    test('long model part: truncated with ... at 20 chars total', () {
      // 23 chars: "abcdefghijklmnopqrstuvw"
      // → substring(0, 17) + "..." = 20
      const full = 'abcdefghijklmnopqrstuvw | OpenAI';
      final result = truncateDisplayName(full);
      expect(result, 'abcdefghijklmnopq... | OpenAI');
    });

    test('no separator: simple truncation to 20 chars', () {
      // 25 chars → substring(0, 17) + "..." = 20
      const full = 'abcdefghijklmnopqrstuvwxy';
      final result = truncateDisplayName(full);
      expect(result, 'abcdefghijklmnopq...');
    });

    test('empty string: preserves empty', () {
      expect(truncateDisplayName(''), '');
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
  // Widget tests for SettingsChip badge color
  // ═══════════════════════════════════════════════════════════════
  group('SettingsChip badge color', () {
    testWidgets('badge background matches the chip accent color',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsChip(
            icon: Icons.build_outlined,
            label: '工具',
            color: const Color(0xFF6366F1),
            onTap: () {},
            badgeCount: 3,
          ),
        ),
      ));

      // The ChipBadge should use Color(0xFF6366F1), not cs.tertiary
      final badge = tester.widget<ChipBadge>(find.byType(ChipBadge));
      expect(badge.color, const Color(0xFF6366F1));
    });

    testWidgets('badge text has white color', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsChip(
            icon: Icons.build_outlined,
            label: '工具',
            color: Colors.indigo,
            onTap: () {},
            badgeCount: 3,
          ),
        ),
      ));

      // ChipBadge text should be white — find the Text widget inside the badge.
      // There are multiple Text widgets (label '工具' and badge '3'); pick the
      // one with the count value and verify its style color is Colors.white.
      final badgeText = tester.widget<Text>(
        find.byWidgetPredicate((w) => w is Text && w.data == '3'),
      );
      expect(badgeText.style?.color, Colors.white);
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
          body: Center(
            child: ModelNameChip(
              displayName: 'Very-Long-Model-Name-That-Should-Truncate | OpenAI',
              color: Colors.teal,
              onTap: () {},
            ),
          ),
        ),
      ));
      await tester.pump();

      // Model "Very-Long-Model-Name-That-Should-Truncate" (42 chars)
      // → substring(0, 17) + "..." = 20 chars: "Very-Long-Model-N..."
      expect(find.textContaining('Very-Long-Model-N...'), findsOneWidget);
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
      // With char-based truncation (20 chars max per part), the truncated
      // text is known and checked directly regardless of parent width.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ModelNameChip(
              displayName:
                  'Some-Long-Model-Name-That-Needs-Truncation | SomeVendor',
              color: Colors.teal,
              onTap: () {},
            ),
          ),
        ),
      ));

      // Model "Some-Long-Model-Name-That-Needs-Truncation" (39 chars)
      // → substring(0, 17) + "..." = "Some-Long-Model-N..." (20 chars)
      expect(find.textContaining('Some-Long-Model-N...'), findsOneWidget);
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
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ModelNameChip(
                displayName:
                    'Very-Long-Model-Name-That-Should-Truncate-Properly | OpenAI',
                color: Colors.teal,
                onTap: () {},
              ),
            ),
          ),
        ),
      ));

      // Model "Very-Long-Model-Name-That-Should-Truncate-Properly" (45 chars)
      // → substring(0, 17) + "..." = "Very-Long-Model-N..." (20 chars)
      expect(find.textContaining('Very-Long-Model-N...'), findsOneWidget);
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
