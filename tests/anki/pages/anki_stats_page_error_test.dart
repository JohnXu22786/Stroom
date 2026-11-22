import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/pages/anki_stats_page.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';

Widget _statsPageWithError(Object error) => ProviderScope(
      overrides: [ankiDatabaseProvider.overrideWith((_) async => throw error)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AnkiStatsPage(),
      ),
    );

void main() {
  testWidgets(
    'long database diagnostics wrap and remain reachable when narrow and scaled',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final diagnostic =
          'Anki database failure: ${'detail with context ' * 110}END OF DIAGNOSTIC';

      await tester.pumpWidget(_statsPageWithError(StateError(diagnostic)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Anki database failure:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final scrollable = find
          .descendant(
            of: find.byType(Scaffold),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.drag(scrollable, const Offset(0, -10000));
      await tester.pumpAndSettle();

      expect(find.textContaining('END OF DIAGNOSTIC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unsupported platform error remains the localized centered state',
    (tester) async {
      await tester.pumpWidget(
        _statsPageWithError(const AnkiStatsUnsupportedException()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Anki statistics are unavailable on this platform.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.byType(Center),
        ),
        findsWidgets,
      );
    },
  );
}
