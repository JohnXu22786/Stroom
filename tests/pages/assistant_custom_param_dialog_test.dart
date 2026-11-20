import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/models/assistant.dart';
import 'package:stroom/pages/assistant_selection_page.dart';
import 'package:stroom/widgets/constrained_text.dart';

Widget _dialogHost({required Locale locale, required VoidCallback open}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(onPressed: open, child: const Text('Open')),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('assistant custom parameter dialogs', () {
    testWidgets(
      'add dialog stays usable at narrow size with long labels and keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        tester.view.platformDispatcher.textScaleFactorTestValue = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(
          tester.view.platformDispatcher.clearTextScaleFactorTestValue,
        );
        String? savedName;
        dynamic savedValue;

        await tester.pumpWidget(
          _dialogHost(locale: const Locale('de'), open: () {}),
        );
        // Open through the live Navigator context so this exercises the
        // production dialog rather than a replica.
        final context = tester.element(find.byType(ElevatedButton));
        showAddCustomParameterDialog(context, (name, type, value) {
          savedName = name;
          savedValue = value;
        });
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollable), findsWidgets);
        expect(find.byType(ConstrainedText), findsAtLeastNWidgets(5));
        await tester.enterText(
          find.byType(TextField).first,
          'reasoning_effort',
        );
        await tester.pump();
        await tester.enterText(find.byType(TextField).last, 'enabled');
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byType(FilledButton).last);
        await tester.pump(const Duration(milliseconds: 300));
        expect(savedName, 'reasoning_effort');
        expect(savedValue, 'enabled');
      },
    );

    testWidgets('edit dialog preserves JSON and prevents invalid save', (
      tester,
    ) async {
      String? savedName;
      dynamic savedValue;
      await tester.pumpWidget(
        _dialogHost(locale: const Locale('en'), open: () {}),
      );
      showEditCustomParameterDialog(
        tester.element(find.byType(ElevatedButton)),
        CustomParameter(
          name: 'options',
          type: 'json',
          value: {'enabled': true},
        ),
        (name, type, value) {
          savedName = name;
          savedValue = value;
        },
      );
      await tester.pump(const Duration(milliseconds: 300));

      final valueField = find.byType(TextField).last;
      expect(
        tester.widget<TextField>(valueField).controller!.text,
        '{"enabled":true}',
      );
      await tester.enterText(valueField, '{ invalid');
      await tester.pump();
      expect(
        tester.widget<TextField>(valueField).decoration!.errorText,
        isNotNull,
      );
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump();
      expect(savedName, isNull);
      expect(
        tester.widget<TextField>(valueField).controller!.text,
        '{ invalid',
      );

      await tester.enterText(valueField, '{"enabled":false}');
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(savedName, 'options');
      expect(savedValue, {'enabled': false});
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'scaled add dialog keeps validation, type selection, and cancel',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.platformDispatcher.textScaleFactorTestValue = 1.8;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(
          tester.view.platformDispatcher.clearTextScaleFactorTestValue,
        );
        String? savedName;
        dynamic savedValue;

        await tester.pumpWidget(
          _dialogHost(locale: const Locale('de'), open: () {}),
        );
        showAddCustomParameterDialog(
          tester.element(find.byType(ElevatedButton)),
          (name, type, value) {
            savedName = name;
            savedValue = value;
          },
        );
        await tester.pump(const Duration(milliseconds: 300));

        final typeField = find.byType(DropdownButtonFormField<String>);
        await tester.ensureVisible(typeField);
        await tester.pump();
        await tester.tap(typeField);
        await tester.pump();
        final context = tester.element(find.byType(FilledButton));
        await tester.tap(
          find.text(
            AppLocalizations.of(context)!.assistantParamValueTypeBoolean,
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump();
        expect(savedName, isNull, reason: 'empty parameter name is rejected');

        await tester.enterText(find.byType(TextField).first, 'stream');
        await tester.pump();
        await tester.enterText(find.byType(TextField).last, 'true');
        await tester.pump();
        await tester.tap(find.byType(FilledButton).last);
        await tester.pump(const Duration(milliseconds: 300));
        expect(savedName, 'stream');
        expect(savedValue, true);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('cancel closes add dialog without saving', (tester) async {
      String? savedName;
      await tester.pumpWidget(
        _dialogHost(locale: const Locale('en'), open: () {}),
      );
      showAddCustomParameterDialog(
        tester.element(find.byType(ElevatedButton)),
        (name, type, value) => savedName = name,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(TextButton).last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(savedName, isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
