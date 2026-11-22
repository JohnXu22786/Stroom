import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/chat/dialogs/message_save_destination_dialog.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets(
    'reveals the clipped French device destination and keeps its action',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;

      Future<MessageSaveDestination?>? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr', 'FR'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    result = showMessageSaveDestinationDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      const label = 'Enregistrer sur l’appareil';
      final button = find.widgetWithText(FilledButton, label);
      expect(button, findsOneWidget);
      final constrainedLabel = find.descendant(
        of: button,
        matching: find.byType(ConstrainedText),
      );
      expect(constrainedLabel, findsOneWidget);
      expect(tester.getSemantics(constrainedLabel).label, label);

      final clippingViewport = find.descendant(
        of: constrainedLabel,
        matching: find.byType(ClipRect),
      );
      expect(clippingViewport, findsOneWidget);
      final fullText = find.descendant(
        of: clippingViewport,
        matching: find.text(label),
      );
      expect(
        tester.getSize(fullText).width,
        greaterThan(tester.getSize(clippingViewport).width),
      );

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(await result, MessageSaveDestination.device);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
