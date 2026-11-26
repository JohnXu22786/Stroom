import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/tts_models.dart';
import 'package:stroom/pages/voice_batch_add_page.dart';
import 'package:stroom/pages/voice_editor_page.dart';

void main() {
  testWidgets('remaining ID focus callbacks survive deleting an earlier row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VoiceEditorPage(
          initialVoices: [
            VoiceEntry(name: 'First', id: 'first'),
            VoiceEntry(name: 'Second', id: 'second'),
            VoiceEntry(name: 'Third', id: 'third'),
          ],
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete).first);
    await tester.pump();

    final thirdIdField = find.byType(TextField).at(3);
    await tester.tap(thirdIdField);
    await tester.enterText(thirdIdField, 'second');
    FocusScope.of(tester.element(thirdIdField)).unfocus();
    await tester.pump();

    expect(find.byIcon(Icons.warning_amber), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide voice editor keeps actions inline and batch action works', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const VoiceEditorPage(initialVoices: []),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final addRow = tester.getRect(find.text('Zeile hinzufügen'));
    final batchAdd = tester.getRect(find.text('Gesammelt hinzufügen'));
    expect(addRow.center.dy, batchAdd.center.dy);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Gesammelt hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceBatchAddPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'voice editor actions stay inside a narrow viewport with expanded labels',
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
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const VoiceEditorPage(initialVoices: []),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      final buttons = tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(buttons, hasLength(2));
      for (final button in buttons) {
        final rect = tester.getRect(find.byWidget(button));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }

      await tester.tap(find.text('Zeile hinzufügen'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
