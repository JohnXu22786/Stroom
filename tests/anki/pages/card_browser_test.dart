import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/anki/database/card_dao.dart';
import 'package:stroom/anki/models/card.dart' as anki;
import 'package:stroom/anki/pages/card_browser.dart';
import 'package:stroom/anki/providers/anki_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';

class _EmptyCardDao implements CardDao {
  @override
  Future<List<anki.Card>> all() async => [];

  @override
  Future<List<anki.Card>> listByDeck(int deckId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'localizes browser title, search hint, and empty state in English and Chinese',
    (tester) async {
      for (final locale in const [Locale('en'), Locale('zh')]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ankiCardDaoProvider.overrideWithValue(AsyncData(_EmptyCardDao())),
            ],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AnkiCardBrowser(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final expected = locale.languageCode == 'en'
            ? ['Browse cards', 'Search cards...', 'No cards']
            : ['浏览卡片', '搜索卡片...', '无卡片'];
        for (final label in expected) {
          expect(find.text(label), findsOneWidget);
        }
      }
    },
  );

  testWidgets('uses compact radius for the search field', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ankiCardDaoProvider.overrideWith((_) async {
            throw StateError('Card loading is not needed to inspect the field');
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AnkiCardBrowser(),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    final border = field.decoration!.border! as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(8));
  });
}
