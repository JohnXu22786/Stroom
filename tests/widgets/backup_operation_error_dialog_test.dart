import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/backup_operation_error_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Unit owner: vertical_backup_error.
  // Functional suite mapping: files-data; this widget test runs in feature-ui.
  testWidgets(
    'long localized diagnostic remains selectable and actions stay reachable at 320x640',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final diagnostic =
          'fake provider failure: ${List.filled(160, 'diagnostic detail').join(' ')}';
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
            builder: (context) {
              final strings = AppLocalizations.of(context)!;
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      unawaited(
                        showBackupOperationErrorDialog(
                          context: context,
                          title: strings.backupServiceRestoreFailed(''),
                          diagnostic: diagnostic,
                          additionalMessage:
                              strings.backupRestoreIncompleteMessage,
                          actionsBuilder: (dialogContext) => [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: Text(strings.backupRestoreExitApp),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: Text(strings.backupRestoreRestartNow),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Show fake error'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      final strings = AppLocalizations.of(
        tester.element(find.text('Show fake error')),
      )!;

      await tester.tap(find.text('Show fake error'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(tester.widget<AlertDialog>(dialog).scrollable, isTrue);
      expect(find.text(strings.backupServiceRestoreFailed('')), findsOneWidget);
      final diagnosticWidget = tester.widget<SelectableText>(
        find.descendant(of: dialog, matching: find.byType(SelectableText)),
      );
      expect(diagnosticWidget.data, diagnostic);

      final exit = find.descendant(
        of: dialog,
        matching: find.text(strings.backupRestoreExitApp),
      );
      final restart = find.descendant(
        of: dialog,
        matching: find.text(strings.backupRestoreRestartNow),
      );
      expect(exit, findsOneWidget);
      expect(restart, findsOneWidget);
      expect(tester.getRect(exit).bottom, lessThanOrEqualTo(640));
      expect(tester.getRect(restart).bottom, lessThanOrEqualTo(640));
      expect(tester.takeException(), isNull);
    },
  );
}
