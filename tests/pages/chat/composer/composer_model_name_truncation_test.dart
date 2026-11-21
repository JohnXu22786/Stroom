import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/chat/composer/composer_shared.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
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

    testWidgets('reveals a clipped label while keeping its badge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const label = 'reasoning_effort_with_a_long_custom_option_value';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: 140,
              child: SettingsChip(
                icon: Icons.psychology_outlined,
                label: label,
                color: Colors.purple,
                badgeCount: 3,
                onTap: () {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text(label), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ConstrainedText)).label,
        contains(label),
      );
      final text = find.text(label);
      final start = tester.getTopLeft(text);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.getTopLeft(text).dx, lessThan(start.dx));
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps fitting label still and tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SettingsChip(
              icon: Icons.build_outlined,
              label: 'Tools',
              color: Colors.teal,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ));
      await tester.pump();

      final label = find.text('Tools');
      final start = tester.getTopLeft(label);
      await tester.pump(const Duration(seconds: 4));
      expect(tester.getTopLeft(label), start);

      await tester.tap(label);
      expect(tapped, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Widget tests for ModelNameChip
  // ═══════════════════════════════════════════════════════════════
  group('ModelNameChip widget', () {
    testWidgets('preserves full label and scrolls when clipped at 320x640', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      const full =
          'Very-Long-Model-Name-That-Should-Truncate | SomeExtremelyLongProviderName';
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: false),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 292,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ModelNameChip(
                    displayName: full,
                    color: Colors.teal,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(full), findsOneWidget);
      expect(tester.getSemantics(find.byType(ConstrainedText)).label, full);
      final text = find.text(full);
      final start = tester.getTopLeft(text);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getTopLeft(text).dx, lessThan(start.dx));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    for (final (locale, expectedLabel) in [
      (const Locale('en'), 'Model'),
      (const Locale('zh', 'CN'), '模型'),
    ]) {
      testWidgets('shows localized fallback "$expectedLabel" for $locale',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

        expect(find.text(expectedLabel), findsOneWidget);
      });
    }

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

    testWidgets('preserves a fitting label without moving it', (tester) async {
      const full = 'GPT-4o | OpenAI';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: AlignmentDirectional.centerStart,
            child: ModelNameChip(
              displayName: full,
              color: Colors.teal,
              onTap: () {},
            ),
          ),
        ),
      ));
      await tester.pump();

      final label = find.text(full);
      final start = tester.getTopLeft(label);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.getTopLeft(label), start);
    });

    testWidgets('preserves full text inside a ConstrainedBox', (tester) async {
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

      expect(
        find.text(
          'Very-Long-Model-Name-That-Should-Truncate-Properly | OpenAI',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders short text unchanged inside ConstrainedBox',
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
