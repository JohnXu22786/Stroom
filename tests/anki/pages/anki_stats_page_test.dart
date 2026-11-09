import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/database/card_dao.dart';
import 'package:stroom/anki/database/revlog_dao.dart';
import 'package:stroom/anki/pages/anki_stats_page.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';

class _StubAnkiDatabase extends AnkiDatabase {
  _StubAnkiDatabase();

  @override
  late final CardDao cards = _StubCardDao();

  @override
  late final RevlogDao revlog = _StubRevlogDao();
}

class _StubCardDao implements CardDao {
  @override
  Future<int> totalCountAll() async => 10;

  @override
  Future<int> countByQueueAll(int queueValue) async => queueValue == 1 ? 2 : 3;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubRevlogDao implements RevlogDao {
  @override
  Future<int> count() async => 5;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'localizes statistics labels and progress in English and Chinese',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      for (final locale in const [Locale('en'), Locale('zh')]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ankiDatabaseProvider.overrideWith(
                (_) async => _StubAnkiDatabase(),
              ),
            ],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AnkiStatsPage(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final expected = locale.languageCode == 'en'
            ? [
                'Study statistics',
                'Total cards',
                'New cards',
                'Learning',
                'Due for review',
                'Review history',
                'Study progress',
                'Review rate',
              ]
            : ['学习统计', '总卡片数', '待学习', '学习中', '待复习', '历史复习次数', '学习进度', '复习率'];
        for (final label in expected) {
          expect(find.text(label), findsOneWidget);
        }
      }
    },
  );

  testWidgets('uses compact radius for the statistics icon plate', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiDatabaseProvider.overrideWith((_) async => _StubAnkiDatabase()),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiStatsPage(),
        ),
      ),
    );
    // The loading state uses an indeterminate progress indicator, so settle
    // bounded frames instead of waiting for all animations to stop.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('总卡片数'), findsOneWidget);
    final plate = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.auto_stories),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = plate.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(8));
  });
}
