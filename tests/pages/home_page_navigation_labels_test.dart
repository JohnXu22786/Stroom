import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/home_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('narrow bottom navigation reveals the complete German label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1100));

    final settingsLabel = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == 'Einstellungen',
    );
    expect(settingsLabel, findsOneWidget);
    expect(
      tester.getSemantics(settingsLabel).label,
      'Einstellungen\nTab 4 von 4',
    );
    expect(tester.getSize(settingsLabel).width, 80);
    expect(
      find.descendant(of: settingsLabel, matching: find.byType(ClipRect)),
      findsOneWidget,
      reason: 'the narrow destination must use the clipped-label reveal path',
    );

    await tester.tap(find.text('Dateien'));
    await tester.pump();
    expect(container.read(selectedPageProvider), AppPage.files);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1100));

    final portugueseSettingsLabel = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == 'Configurações',
    );
    expect(portugueseSettingsLabel, findsOneWidget);
    expect(
      find.descendant(
        of: portugueseSettingsLabel,
        matching: find.byType(ClipRect),
      ),
      findsOneWidget,
      reason: 'the Brazilian Portuguese preview label must actually overflow',
    );
    expect(
      tester.getSemantics(portugueseSettingsLabel).label,
      contains('Configurações'),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(3)),
            child: child!,
          ),
          home: const HomePage(),
        ),
      ),
    );
    await tester.pump();

    final scaledSettingsLabel = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == 'Configurações',
    );
    final navigationBar = find
        .ancestor(of: scaledSettingsLabel, matching: find.byType(Material))
        .first;
    expect(tester.getSize(navigationBar).height, greaterThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide navigation rail keeps labels centered and complete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomePage(),
        ),
      ),
    );

    final settingsLabel = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == 'Einstellungen',
    );
    expect(settingsLabel, findsOneWidget);
    final label = tester.widget<ConstrainedText>(settingsLabel);
    expect(label.textAlign, TextAlign.center);
    expect(label.maxLines, 1);
    expect(
      find.descendant(of: settingsLabel, matching: find.byType(ClipRect)),
      findsNothing,
      reason: 'the rail expands to fit this label, so it must stay stationary',
    );
    expect(
      tester.getSemantics(settingsLabel).label,
      'Einstellungen\nTab 4 von 4',
    );
  });
}
