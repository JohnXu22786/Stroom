import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/catcatch_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/video_manifest.dart';
import 'package:stroom/widgets/constrained_text.dart';

Widget _testApp({
  Locale locale = const Locale('de', 'DE'),
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.light,
}) =>
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeMode,
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
  testWidgets(
    'Spanish duration labels stay readable while numeric fields retain editing',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      ManifestDatabase.enableTestMode();
      VideoManifest.invalidateCache();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _testApp(locale: const Locale('es', 'ES'), textScale: 1.6),
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      final fields = find.byType(TextFormField);
      TextField textField(int index) => tester.widget<TextField>(
            find.descendant(
                of: fields.at(index), matching: find.byType(TextField)),
          );
      expect(fields, findsNWidgets(4));
      final durationLabels = ['Horas', 'Minutos', 'Artículos de segunda clase'];
      for (final label in durationLabels) {
        final constrainedLabel = find.byWidgetPredicate(
          (widget) => widget is ConstrainedText && widget.data == label,
        );
        expect(constrainedLabel, findsOneWidget);
        expect(
          tester.widget<ConstrainedText>(constrainedLabel).maxLines,
          1,
          reason: 'Duration labels must measure and reveal clipped text.',
        );
      }

      await tester.ensureVisible(fields.at(1));
      await tester.enterText(fields.at(1), '12');
      await tester.enterText(fields.at(2), '3x4');
      await tester.enterText(fields.at(3), '56');
      await tester.pump();
      await tester.showKeyboard(find.byType(EditableText).at(2));
      await tester.pump();

      expect(textField(1).controller!.text, '12');
      expect(textField(2).controller!.text, '34');
      expect(textField(3).controller!.text, '56');
      expect(textField(1).keyboardType, TextInputType.number);
      expect(textField(1).textInputAction, TextInputAction.next);
      expect(textField(3).textInputAction, TextInputAction.done);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'narrow German folder and duration rows keep complete clipped labels',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      ManifestDatabase.enableTestMode();
      VideoManifest.invalidateCache();
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const folder =
          'quarterly-review-with-a-very-long-folder-name-for-narrow-mobile-screens';
      await VideoManifest.addFolder(folder);
      await tester.pumpWidget(_testApp());
      await tester.pump();

      expect(find.text('Hauptordner'), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.videocam));
      await tester.pumpAndSettle();

      await tester.tap(find.text(folder));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(
        find.ancestor(
          of: find.text('Fertig'),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(folder), findsOneWidget);
      final folderPath = find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == folder,
      );
      final videoLabel = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText && widget.data == 'Video speichern unter',
      );
      expect(
        tester.getSize(folderPath).width,
        greaterThan(tester.getSize(videoLabel).width),
        reason:
            'The selected path should have room after its fixed affordances.',
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Vorschau: '), findsOneWidget);
      expect(find.text('Std.:Min.:Sek.'), findsOneWidget);
      expect(find.text('1 Aufgabe hinzugefügt'), findsOneWidget);
      expect(find.text(folder), findsOneWidget);
    },
  );

  testWidgets('large German task count stays within its dark narrow row', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    VideoManifest.invalidateCache();
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _testApp(textScale: 1.6, themeMode: ThemeMode.dark),
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('1 Aufgabe hinzugefügt'), findsOneWidget);
  });
}
