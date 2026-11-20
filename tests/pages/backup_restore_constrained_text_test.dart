import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/backup_restore_page.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/manifest_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    AppLogService.disableFileLogging();
  });

  for (final scenario in [
    (const Locale('de'), 320.0, Brightness.light),
    (const Locale('de'), 320.0, Brightness.dark),
    (const Locale('de'), 360.0, Brightness.light),
    (const Locale('de'), 360.0, Brightness.dark),
    (const Locale('pt', 'BR'), 320.0, Brightness.light),
    (const Locale('pt', 'BR'), 320.0, Brightness.dark),
    (const Locale('pt', 'BR'), 360.0, Brightness.light),
    (const Locale('pt', 'BR'), 360.0, Brightness.dark),
  ]) {
    testWidgets(
      'category labels fit ${scenario.$1} ${scenario.$2} ${scenario.$3} at 1.7x',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(scenario.$2, 800);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: scenario.$1,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: scenario.$3 == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.7)),
                child: child!,
              ),
              home: const BackupRestorePage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (var i = 0;
            i < 8 && find.byType(CheckboxListTile).evaluate().isEmpty;
            i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -400),
          );
          await tester.pump(const Duration(milliseconds: 500));
        }

        expect(find.byType(CheckboxListTile), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'long German clear and restart titles stay inside their finite rows',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('de'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.7)),
              child: child!,
            ),
            home: const BackupRestorePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clearButton = find.widgetWithText(
        OutlinedButton,
        'Ausgewählte Daten löschen',
      );
      await tester.scrollUntilVisible(
        clearButton,
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      await tester.tap(clearButton);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
        find.widgetWithText(FilledButton, 'Ausgewählte Daten löschen'),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Einige Daten gelöscht'), findsOneWidget);
      final layoutErrors = <String>[];
      Object? error;
      while ((error = tester.takeException()) != null) {
        layoutErrors.add(error.toString());
      }
      expect(
        layoutErrors.where(
          (message) =>
              message.contains('overflowed') && message.contains('right'),
        ),
        isEmpty,
        reason: 'Icon/title rows must not overflow horizontally',
      );
    },
  );
}
