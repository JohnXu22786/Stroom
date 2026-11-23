import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/database/card_dao.dart';
import 'package:stroom/anki/database/revlog_dao.dart';
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

Widget _statsPageWithQueryError(Object error) => ProviderScope(
      overrides: [
        ankiDatabaseProvider.overrideWith(
          (_) async => _QueryFailingAnkiDatabase(error),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AnkiStatsPage(),
      ),
    );

class _QueryFailingAnkiDatabase extends AnkiDatabase {
  _QueryFailingAnkiDatabase(this.error);

  final Object error;
  late final CardDao _cards = _QueryFailingCardDao(error);
  late final RevlogDao _revlog = _StubRevlogDao();

  @override
  CardDao get cards => _cards;

  @override
  RevlogDao get revlog => _revlog;
}

class _QueryFailingCardDao implements CardDao {
  _QueryFailingCardDao(this.error);

  final Object error;

  @override
  Future<int> totalCountAll() => Future.error(error);

  @override
  Future<int> countByQueueAll(int queueValue) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubRevlogDao implements RevlogDao {
  @override
  Future<int> count() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('shows a database query failure instead of loading forever', (
    tester,
  ) async {
    await tester.pumpWidget(
      _statsPageWithQueryError(StateError('stats query failed')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('stats query failed'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'long stats query diagnostics remain reachable on a narrow scaled screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final diagnostic =
          'Anki database failure: ${'detail with context ' * 110}END OF DIAGNOSTIC';

      await tester.pumpWidget(_statsPageWithQueryError(StateError(diagnostic)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

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
