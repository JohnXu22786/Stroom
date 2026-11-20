import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/error_detail_dialog_header.dart';

void main() {
  testWidgets(
    'localized OCR and ASR headings preserve close action when clipped',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de', 'DE'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => Dialog(
                        insetPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: ErrorDetailDialogHeader(
                          title: AppLocalizations.of(dialogContext)!
                              .ocrErrorDetails,
                          onClose: () => Navigator.pop(dialogContext),
                        ),
                      ),
                    ),
                    child: const Text('OCR'),
                  ),
                  TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => Dialog(
                        insetPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: ErrorDetailDialogHeader(
                          title: AppLocalizations.of(dialogContext)!
                              .asrErrorDetails,
                          onClose: () => Navigator.pop(dialogContext),
                        ),
                      ),
                    ),
                    child: const Text('ASR'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      for (final button in ['OCR', 'ASR']) {
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
        expect(find.byType(ConstrainedText), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
      }
    },
  );
}
