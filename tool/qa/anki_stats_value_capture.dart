import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/anki/database/anki_database.dart';
import 'package:stroom/anki/database/card_dao.dart';
import 'package:stroom/anki/database/col_dao.dart';
import 'package:stroom/anki/database/revlog_dao.dart';
import 'package:stroom/anki/pages/anki_stats_page.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';

class _CaptureAnkiDatabase extends AnkiDatabase {
  _CaptureAnkiDatabase();

  @override
  late final CardDao cards = _CaptureCardDao();

  @override
  late final ColDao col = _CaptureColDao();

  @override
  late final RevlogDao revlog = _CaptureRevlogDao();
}

class _CaptureCardDao implements CardDao {
  @override
  Future<int> totalCountAll() async => 9876543;

  @override
  Future<int> countByQueueAll(int queueValue) async => 123;

  @override
  Future<int> countDueReviewAll(int dayOrdinal) async => 456;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CaptureColDao implements ColDao {
  @override
  Future<void> load() async {}

  @override
  int dayOrdinalAt(int nowSec) => 6000;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CaptureRevlogDao implements RevlogDao {
  @override
  Future<int> count() async => 2540123;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 3;
  runApp(
    ProviderScope(
      overrides: [
        ankiDatabaseProvider.overrideWith((_) async => _CaptureAnkiDatabase()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        ),
        home: const AnkiStatsPage(),
      ),
    ),
  );
}
