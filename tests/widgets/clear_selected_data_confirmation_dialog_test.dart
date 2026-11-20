import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/clear_selected_data_confirmation_dialog.dart';

const _labels = [
  'Gesprächsverlauf und Anhänge',
  'Einstellungen',
  'Bilder',
  'Audiodateien',
  'Videos',
  'Texte',
  'Aufgaben',
  'Anki-Daten',
  'Browser-Cookies',
];

const _warning =
    'Dieser Vorgang kann nicht rückgängig gemacht werden. Starte die App nach dem Löschen neu, damit die Änderungen wirksam werden.';

Widget _testApp({
  required ValueChanged<Future<bool?>?> onDialogResult,
  double textScaleFactor = 1,
}) {
  return MaterialApp(
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
          .copyWith(textScaler: TextScaler.linear(textScaleFactor)),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () {
            onDialogResult(
              showDialog<bool>(
                context: context,
                builder: (_) => ClearSelectedDataConfirmationDialog(
                  labels: _labels,
                  browserWebsiteDataUnsupported: true,
                ),
              ),
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'compact enlarged dialog scrolls full content and keeps both actions visible',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);

      Future<bool?>? result;
      await tester.pumpWidget(
        _testApp(
          onDialogResult: (value) => result = value,
          textScaleFactor: 1.3,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 500));

      final dialog = find.byType(AlertDialog);
      final scroll = find.descendant(
        of: dialog,
        matching: find.byType(SingleChildScrollView),
      );
      final cancel = find.descendant(
        of: dialog,
        matching: find.text('Abbrechen'),
      );
      final confirm = find.descendant(
        of: dialog,
        matching: find.text('Löschen (10)'),
      );
      expect(scroll, findsOneWidget);
      expect(cancel, findsOneWidget);
      expect(confirm, findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(cancel).overlaps(tester.getRect(confirm)), isFalse);
      expect(tester.getRect(cancel).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(640));

      await tester.scrollUntilVisible(
        find.text(_warning),
        200,
        scrollable: find.descendant(
          of: dialog,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.drag(scroll, const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      final viewport = tester.getRect(scroll);
      final warningRect = tester.getRect(find.text(_warning));
      expect(warningRect.top, greaterThanOrEqualTo(viewport.top));
      expect(warningRect.bottom, lessThanOrEqualTo(viewport.bottom));
      for (final label in _labels) {
        expect(
          find.descendant(of: dialog, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(640));
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(640));

      await tester.tap(cancel);
      await tester.pump(const Duration(milliseconds: 500));
      expect(await result, isFalse);
    },
  );

  testWidgets(
    'enabled confirm returns true without running a clear operation',
    (tester) async {
      Future<bool?>? result;
      await tester.pumpWidget(
        _testApp(onDialogResult: (value) => result = value),
      );
      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 500));

      final confirmBeforeCountdown = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Löschen (10)'),
      );
      expect(confirmBeforeCountdown.onPressed, isNull);

      await tester.pump(const Duration(seconds: 10));
      final confirm = find.widgetWithText(
        FilledButton,
        'Ausgewählte Daten löschen',
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      expect(await result, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
