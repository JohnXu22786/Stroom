import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/catcatch_page.dart';

Widget _testApp({required Locale locale, double textScale = 1}) =>
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const CatCatchPage(),
      ),
    );

void main() {
  testWidgets('French 3x empty-state guidance scrolls above the fixed bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(locale: const Locale('fr', 'FR'), textScale: 3),
    );
    await tester.pumpAndSettle();

    final title = find.text('Aucune tâche de téléchargement pour le moment');
    final hint = find.text(
      'Touchez + en haut à droite pour ajouter une tâche de téléchargement',
    );
    expect(title, findsOneWidget);
    expect(hint, findsOneWidget);
    final scroll = find.byKey(const Key('catcatch_empty_state_scroll'));
    expect(scroll, findsOneWidget);

    final scrollable = find.descendant(
      of: scroll,
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -800));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(scrollable, const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.getRect(hint).bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(const Key('catcatch_bottom_bar'))).top + 1,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fitting empty state remains centered in its viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(locale: const Locale('fr', 'FR')));
    await tester.pumpAndSettle();

    final viewport = tester.getRect(
      find.byKey(const Key('catcatch_empty_state_scroll')),
    );
    final content = tester.getRect(
      find.byKey(const Key('catcatch_empty_state_content')),
    );
    expect(content.center.dy, closeTo(viewport.center.dy, 1));
    expect(tester.takeException(), isNull);
  });
}
