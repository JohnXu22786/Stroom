import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/chat/composer/composer_shared.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════
  // Unit tests for truncateDisplayName (char-based: model 25, provider 10)
  // ═══════════════════════════════════════════════════════════════
  group('truncateDisplayName', () {
    test('short text with separator: unchanged', () {
      const full = 'GPT-4o | OpenAI';
      final result = truncateDisplayName(full);
      expect(result, full);
    });

    test('long model part: truncated with ... at 25 chars total', () {
      // 28 chars: "abcdefghijklmnopqrstuvwxyzab"
      // → substring(0, 22) + "..." = 25
      const full = 'abcdefghijklmnopqrstuvwxyzab | OpenAI';
      final result = truncateDisplayName(full);
      expect(result, 'abcdefghijklmnopqrstuv... | OpenAI');
    });

    test('long provider part: truncated with ... at 10 chars total', () {
      // Provider "OpenAIVeryLongProviderName" (26 chars)
      // → substring(0, 7) + "..." = 10
      const full = 'GPT-4o | OpenAIVeryLongProviderName';
      final result = truncateDisplayName(full);
      expect(result, 'GPT-4o | OpenAIV...');
    });

    test('model part exactly at limit: unchanged', () {
      // 25 chars exactly
      const full = 'abcdefghijklmnopqrstuvwxy | OpenAI';
      final result = truncateDisplayName(full);
      expect(result, full);
    });

    test('provider part exactly at limit: unchanged', () {
      // Provider exactly 10 chars
      const full = 'GPT-4o | OpenAI2024';
      final result = truncateDisplayName(full);
      expect(result, full);
    });

    test('provider part one over limit: truncated to 10 chars total', () {
      // 11 chars → substring(0, 7) + "..." = 10
      const full = 'GPT-4o | OpenAI20245';
      final result = truncateDisplayName(full);
      expect(result, 'GPT-4o | OpenAI2...');
    });

    test('no separator: simple truncation to 25 chars', () {
      // 28 chars → substring(0, 22) + "..." = 25
      const full = 'abcdefghijklmnopqrstuvwxyzab';
      final result = truncateDisplayName(full);
      expect(result, 'abcdefghijklmnopqrstuv...');
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
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Widget tests for ModelNameChip
  // ═══════════════════════════════════════════════════════════════
  group('ModelNameChip widget', () {
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

      // Model "Very-Long-Model-Name-That-Should-Truncate" (41 chars)
      // → substring(0, 22) + "..." = 25 chars: "Very-Long-Model-Name-T..."
      expect(find.textContaining('Very-Long-Model-Name-T...'), findsOneWidget);
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

    testWidgets('truncates long provider name in model chip', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ModelNameChip(
              displayName: 'GPT-4o | SomeVeryLongProviderName',
              color: Colors.teal,
              onTap: () {},
            ),
          ),
        ),
      ));
      await tester.pump();

      // Provider "SomeVeryLongProviderName" (24 chars)
      // → substring(0, 7) + "..." = 10 chars: "SomeVer..."
      expect(find.textContaining('SomeVer...'), findsOneWidget);
    });

    testWidgets('fits within constrained SizedBox width', (tester) async {
      // With char-based truncation (25 chars max for model, 10 for provider),
      // the truncated text is known and checked directly regardless of
      // parent width.
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

      // Model "Some-Long-Model-Name-That-Needs-Truncation" (42 chars)
      // → substring(0, 22) + "..." = "Some-Long-Model-Name-T..." (25 chars)
      expect(find.textContaining('Some-Long-Model-Name-T...'), findsOneWidget);
    });

    testWidgets('truncates text inside a ConstrainedBox', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
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

      // Model "Very-Long-Model-Name-That-Should-Truncate-Properly" (50 chars)
      // → substring(0, 22) + "..." = "Very-Long-Model-Name-T..." (25 chars)
      expect(find.textContaining('Very-Long-Model-Name-T...'), findsOneWidget);
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
