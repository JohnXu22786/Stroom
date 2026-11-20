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
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.light,
}) =>
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('de', 'DE'),
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
