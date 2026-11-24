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
  _StubAnkiDatabase({
    this.reviewDueTimes = const [],
    this.dayLearningCount = 0,
  });

  final List<int> reviewDueTimes;
  final int dayLearningCount;

  @override
  late final CardDao cards = _StubCardDao(
    reviewDueTimes: reviewDueTimes,
    dayLearningCount: dayLearningCount,
  );

  @override
  late final RevlogDao revlog = _StubRevlogDao();
}

class _StubCardDao implements CardDao {
  final List<int> reviewDueTimes;
  final int dayLearningCount;

  _StubCardDao({this.reviewDueTimes = const [], this.dayLearningCount = 0});

  @override
  Future<int> totalCountAll() async => 10;

  @override
  Future<int> countByQueueAll(int queueValue) async {
    if (queueValue == 1) return 2;
    if (queueValue == 2) return reviewDueTimes.length;
    if (queueValue == 3) return dayLearningCount;
    return 3;
  }

  @override
  Future<int> countDueReviewAll(int nowSec) async =>
      reviewDueTimes.where((due) => due <= nowSec).length;

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

  testWidgets('shows only review cards due now or earlier in due statistics', (
    tester,
  ) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final database = _StubAnkiDatabase(
      reviewDueTimes: [nowSec - 60, nowSec + 3600],
    );
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ankiDatabaseProvider.overrideWith((_) async => database)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiStatsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final dueCard = find.ancestor(
      of: find.text('Due for review'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: dueCard, matching: find.text('1')),
      findsOneWidget,
    );
    final progressCard = find.ancestor(
      of: find.text('Study progress'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: progressCard, matching: find.text('40%')),
      findsOneWidget,
    );
  });

  testWidgets('includes day-learning cards in learning total and progress', (
    tester,
  ) async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final database = _StubAnkiDatabase(
      reviewDueTimes: [nowSec - 60, nowSec + 3600],
      dayLearningCount: 3,
    );
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [ankiDatabaseProvider.overrideWith((_) async => database)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiStatsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final newCard = find.ancestor(
      of: find.text('New cards'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: newCard, matching: find.text('3')),
      findsOneWidget,
    );

    final learningCard = find.ancestor(
      of: find.text('Learning'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: learningCard, matching: find.text('5')),
      findsOneWidget,
    );

    final dueCard = find.ancestor(
      of: find.text('Due for review'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: dueCard, matching: find.text('1')),
      findsOneWidget,
    );

    final progressCard = find.ancestor(
      of: find.text('Study progress'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: progressCard, matching: find.text('70%')),
      findsOneWidget,
    );
  });

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
