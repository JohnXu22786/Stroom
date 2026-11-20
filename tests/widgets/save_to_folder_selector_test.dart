import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/save_to_folder_selector.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('keeps fitting save-to labels and folder values stationary', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: false),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 320,
              child: SaveToFolderSelector(
                label: 'Save output label',
                folder: 'X',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    const labelText = 'Save output label';
    const folderText = 'X';
    final label = find.text(labelText);
    final folder = find.text(folderText);
    expect(label, findsOneWidget);
    expect(folder, findsOneWidget);
    final context = tester.element(find.byType(SaveToFolderSelector));
    final labelPainter = TextPainter(
      text: const TextSpan(text: labelText, style: TextStyle(fontSize: 12)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final folderPainter = TextPainter(
      text: const TextSpan(
        text: folderText,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final textSlotsWidth =
        tester.getSize(find.byType(SaveToFolderSelector)).width - 68;
    expect(labelPainter.width + folderPainter.width, lessThan(textSlotsWidth));
    expect(
      tester.getSize(find.byType(ConstrainedText).first).width,
      greaterThanOrEqualTo(labelPainter.width),
    );
    final labelPosition = tester.getTopLeft(label);
    final folderPosition = tester.getTopLeft(folder);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(label), labelPosition);
    expect(tester.getTopLeft(folder), folderPosition);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bounds long labels and paths while preserving selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const label = 'Speichern unter einem sehr langen lokalisierten Ziel';
    const folder = 'Projects/2026/Quarterly Reports/Long Folder Name';
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 320,
              child: SaveToFolderSelector(
                label: label,
                folder: folder,
                onTap: () => selected = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text(label), findsOneWidget);
    expect(find.text(folder), findsOneWidget);
    expect(tester.getSemantics(find.text(label)), isNotNull);
    expect(tester.getSemantics(find.text(folder)), isNotNull);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(InkWell));
    expect(selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('handles actual localized labels at large scale in both themes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final locale in [
      const Locale('de'),
      const Locale('pt', 'BR'),
      const Locale('ar'),
    ]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.7)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: 320,
                    child: SaveToFolderSelector(
                      label: AppLocalizations.of(context)!.ocrSaveTo,
                      folder:
                          'Projects/2026/Quarterly Reports/Long Folder Name',
                      onTap: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text(
            AppLocalizations.of(
              tester.element(find.byType(SaveToFolderSelector)),
            )!.ocrSaveTo,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
