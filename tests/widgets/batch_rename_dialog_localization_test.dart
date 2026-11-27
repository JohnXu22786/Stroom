import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/utils/batch_rename.dart';
import 'package:stroom/widgets/batch_rename_dialog.dart';

import '../utils/batch_rename_test.dart' show bridge, file;

void _expectNoHorizontalFlexOverflow(WidgetTester tester) {
  for (final element in find.byType(Row).evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is! RenderFlex ||
        renderObject.direction != Axis.horizontal) {
      continue;
    }

    var child = renderObject.firstChild;
    while (child != null) {
      final parentData = child.parentData! as FlexParentData;
      final childLeft = parentData.offset.dx;
      final childRight = childLeft + child.size.width;
      expect(
        childLeft,
        greaterThanOrEqualTo(-0.01),
        reason: 'A Row child extends past its left edge.',
      );
      expect(
        childRight,
        lessThanOrEqualTo(renderObject.size.width + 0.01),
        reason: 'A Row child extends past its right edge.',
      );
      child = renderObject.childAfter(child);
    }
  }
}

void main() {
  // ignore: invalid_use_of_visible_for_testing_member
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('German save-preset helper is fully visible at phone size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final items = [file('one', 'long original filename')];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => BatchRenameDialog(
                  items: items,
                  allFiles: items,
                  allFolders: const {},
                  bridge: bridge,
                  initialConfig: const BatchRenameConfig(),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final dialogContext = tester.element(
      find.byKey(const Key('batch_rename_dialog')),
    );
    final l10n = AppLocalizations.of(dialogContext)!;
    await tester.tap(find.text(l10n.batchDlgSavePresetFallback));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(l10n.batchDlgPresetHint), findsOneWidget);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
    );
    expect(field.decoration!.helper, isA<Text>());
    expect(field.decoration!.helperText, isNull);
    final helperContext = tester.element(find.text(l10n.batchDlgPresetHint));
    final helperText = TextPainter(
      text: TextSpan(
        text: l10n.batchDlgPresetHint,
        style: DefaultTextStyle.of(helperContext).style,
      ),
      textDirection: Directionality.of(helperContext),
      textScaler: MediaQuery.textScalerOf(helperContext),
    )..layout(
        maxWidth: tester.getSize(find.text(l10n.batchDlgPresetHint)).width,
      );
    expect(
      tester.getSize(find.text(l10n.batchDlgPresetHint)).height,
      greaterThanOrEqualTo(helperText.height - 0.5),
    );
    expect(helperText.computeLineMetrics(), hasLength(greaterThan(1)));
    expect(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (const Locale('de'), Brightness.light, const Size(900, 720), 1.0),
    (const Locale('de'), Brightness.dark, const Size(360, 720), 1.0),
    (const Locale('pt', 'BR'), Brightness.light, const Size(360, 720), 2.0),
    (const Locale('pt', 'BR'), Brightness.dark, const Size(900, 720), 2.0),
  ]) {
    testWidgets(
      'dialog lays out ${scenario.$1} ${scenario.$2} ${scenario.$3} scale ${scenario.$4}',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = scenario.$3;
        final items = [
          file(
            'one',
            'Ein sehr langer ursprünglicher Dateiname für die Prüfung des Vorschaubereichs',
          ),
          file(
            'two',
            'Um nome original extremamente comprido para verificar a linha da pré-visualização',
          ),
        ];
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: scenario.$3,
              textScaler: TextScaler.linear(scenario.$4),
            ),
            child: MaterialApp(
              locale: scenario.$1,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: scenario.$2 == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scenario.$4)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => BatchRenameDialog(
                        items: items,
                        allFiles: items,
                        allFolders: const {},
                        bridge: bridge,
                        initialConfig: const BatchRenameConfig(),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        if (scenario.$3.width < 720) {
          await tester.tap(find.byKey(const Key('batch_preview_tab')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }
        final dialogContext = tester.element(
          find.byKey(const Key('batch_rename_dialog')),
        );
        expect(MediaQuery.textScalerOf(dialogContext).scale(1), scenario.$4);
        _expectNoHorizontalFlexOverflow(tester);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('batch_rename_dialog')), findsOneWidget);
        expect(
          find.byKey(const Key('batch_rename_preview_list')),
          findsOneWidget,
        );
      },
    );
  }
}
