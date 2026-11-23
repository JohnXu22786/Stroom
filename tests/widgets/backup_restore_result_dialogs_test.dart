import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/backup_restore_result_dialogs.dart';

Future<void> _pumpDialog(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('de', 'DE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showDialog<void>(context: context, builder: (_) => dialog),
              child: const Text('Open fixture'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open fixture'));
  await tester.pumpAndSettle();
}

Finder _dialogContent(Finder dialog) =>
    find.descendant(of: dialog, matching: find.byType(SingleChildScrollView));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Unit owner: vertical_result_dialog_scroll.
  // Functional suite mapping: files-data; the CI test owner is feature-ui.
  testWidgets(
    'restart result scrolls long restore details and keeps both actions reachable',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      final message = List.filled(
        32,
        'Wiederherstellung abgeschlossen. Starte die App neu, damit die '
        'wiederhergestellten Daten verfügbar sind.',
      ).join('\n\n');
      await _pumpDialog(
        tester,
        BackupRestoreRestartDialog(
          title: 'Wiederherstellung abgeschlossen',
          message: message,
          exitLabel: 'App beenden',
          restartLabel: 'Jetzt neu starten',
          onExit: () {},
          onRestart: () {},
        ),
      );

      final dialog = find.byType(AlertDialog);
      final content = _dialogContent(dialog);
      expect(tester.widget<AlertDialog>(dialog).scrollable, isTrue);
      expect(content, findsOneWidget);
      expect(
        tester
            .state<ScrollableState>(
              find
                  .descendant(of: content, matching: find.byType(Scrollable))
                  .first,
            )
            .position
            .maxScrollExtent,
        greaterThan(0),
      );
      await tester.drag(content, const Offset(0, -900));
      await tester.pump();
      expect(
        find.textContaining('Wiederherstellung abgeschlossen.'),
        findsOneWidget,
      );
      expect(find.text('App beenden'), findsOneWidget);
      expect(find.text('Jetzt neu starten'), findsOneWidget);
      expect(
        tester.getRect(find.text('Jetzt neu starten')).bottom,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    },
  );

  // Unit owner: vertical_result_dialog_scroll.
  // Functional suite mapping: files-data; the CI test owner is feature-ui.
  testWidgets(
    'skipped categories scroll while acknowledgement remains reachable',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      final message = List.filled(
        48,
        'Wiederherstellung übersprungen: Die ausgewählte Kategorie war nicht '
        'in der Sicherung enthalten.',
      ).join('\n\n');

      await _pumpDialog(
        tester,
        BackupRestoreSkippedDialog(
          title: 'Nichts wiederhergestellt',
          message: message,
          acknowledgeLabel: 'Verstanden',
          onAcknowledge: () {},
        ),
      );

      final dialog = find.byType(AlertDialog);
      final content = _dialogContent(dialog);
      expect(tester.widget<AlertDialog>(dialog).scrollable, isTrue);
      expect(content, findsOneWidget);
      expect(
        tester
            .state<ScrollableState>(
              find
                  .descendant(of: content, matching: find.byType(Scrollable))
                  .first,
            )
            .position
            .maxScrollExtent,
        greaterThan(0),
      );
      await tester.drag(content, const Offset(0, -900));
      await tester.pump();
      expect(find.text('Verstanden'), findsOneWidget);
      expect(
        tester.getRect(find.text('Verstanden')).bottom,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
