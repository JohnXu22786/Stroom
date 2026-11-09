import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/database/card_dao.dart';
import 'package:stroom/anki/database/revlog_dao.dart';
import 'package:stroom/anki/pages/anki_stats_page.dart';
import 'package:stroom/anki/providers/anki_provider.dart';

class _StubAnkiDatabase extends AnkiDatabase {
  _StubAnkiDatabase();

  @override
  late final CardDao cards = _StubCardDao();

  @override
  late final RevlogDao revlog = _StubRevlogDao();
}

class _StubCardDao implements CardDao {
  @override
  Future<int> totalCountAll() async => 0;

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
  testWidgets('uses compact radius for the statistics icon plate', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiDatabaseProvider.overrideWith((_) async => _StubAnkiDatabase()),
        ],
        child: const MaterialApp(home: AnkiStatsPage()),
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
