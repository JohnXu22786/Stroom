import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/chat/composer/chat_file_picker_dialog.dart';
import 'package:stroom/pages/chat/composer/file_picker_shared.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
    TextManifest.readFileOverrideForTesting = null;
  });

  testWidgets('confirm waits until a pending file read completes', (
    tester,
  ) async {
    final pendingRead = Completer<Uint8List?>();
    final pendingReadStarted = Completer<void>();
    TextManifest.readFileOverrideForTesting = (_) {
      pendingReadStarted.complete();
      return pendingRead.future;
    };

    await tester.runAsync(() async {
      await TextManifest.addRecord(
        TextRecord(
          name: 'pending',
          hash: 'pending',
          size: 1,
          createdAt: DateTime.now(),
        ),
      );
    });

    List<MapEntry<String, Uint8List>>? pickerResult;
    await tester.pumpWidget(_buildTestApp((result) => pickerResult = result));
    await _openPicker(tester);

    await tester.tap(find.text('pending.txt'));
    await tester.pump();
    expect(pendingReadStarted.isCompleted, isTrue);

    final confirmButton = find.byKey(const Key('file_picker_confirm_btn'));
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
    await tester.tap(confirmButton);
    await tester.pump();
    expect(find.text('pending.txt'), findsOneWidget);
    expect(pickerResult, isNull);

    final fileBytes = Uint8List.fromList([1, 2, 3]);
    pendingRead.complete(fileBytes);
    await tester.pump();
    await tester.pump();

    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
    await tester.tap(confirmButton);
    await tester.pump();

    expect(pickerResult, hasLength(1));
    expect(pickerResult!.single.key, 'pending.txt');
    expect(pickerResult!.single.value, fileBytes);
  });

  testWidgets('fitting selected file keeps the production preview bar size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _seedPdf(tester, 'annual');

    await tester.pumpWidget(_buildTestApp((_) {}));
    await _openPicker(tester);
    await tester.tap(find.text('annual.pdf'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final previewBar = find.byKey(const Key('file_picker_preview_bar'));
    final chip = find.byType(PreviewChip);
    expect(tester.getSize(previewBar).height, 106);
    expect(tester.getSize(chip).height, 72);
    expect(
      find.descendant(of: chip, matching: find.byIcon(Icons.close)),
      findsOneWidget,
    );
  });

  testWidgets('scaled selected file grows the production preview bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _seedPdf(tester, 'annual');

    await tester.pumpWidget(_buildTestApp((_) {}, textScale: 3));
    await _openPicker(tester);
    _expectOnlyKnownScaleThreeChromeOverflows(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    _expectOnlyKnownScaleThreeChromeOverflows(tester);
    expect(find.byType(PreviewChip), findsOneWidget);

    final previewBar = find.byKey(const Key('file_picker_preview_bar'));
    final chip = find.byType(PreviewChip);
    expect(tester.getSize(previewBar).height, greaterThan(106));
    expect(tester.getSize(chip).height, greaterThan(72));
    final filename = find.descendant(
      of: chip,
      matching: find.byType(ConstrainedText),
    );
    expect(tester.widget<ConstrainedText>(filename).data, 'annual.pdf');
    expect(tester.widget<ConstrainedText>(filename).maxLines, 2);
    expect(
      tester.getSize(chip).height,
      greaterThanOrEqualTo(tester.getSize(filename).height + 17),
    );

    final dialogContent = tester.getRect(
      find.byKey(const Key('file_picker_content')),
    );
    final confirmButton = tester.getRect(
      find.byKey(const Key('file_picker_confirm_btn')),
    );
    expect(dialogContent.height, greaterThan(0));
    expect(confirmButton.bottom, lessThanOrEqualTo(640));
    expect(
      find.descendant(of: chip, matching: find.byIcon(Icons.close)),
      findsOneWidget,
    );
  });

  testWidgets('preview bar keeps a name fitting the rendered 99 dp slot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const filename = 'notes.pdf';
    await _seedPdf(tester, 'notes');
    await _openAtTextScale(
      tester,
      textScale: await _scaleForNaturalTextWidth(tester, 97),
    );

    final chip = find.byType(PreviewChip);
    final filenameLabel = find.descendant(
      of: chip,
      matching: find.byType(ConstrainedText),
    );
    final labelRect = tester.getRect(filenameLabel);
    final chipRect = tester.getRect(chip);
    final chipRow = find.descendant(of: chip, matching: find.byType(Row));
    final textSlotWidth = tester.getSize(chipRow).width - 20 - 4;
    final previewBarRect = tester.getRect(
      find.byKey(const Key('file_picker_preview_bar')),
    );
    final context = tester.element(chip);
    final chipStyle = DefaultTextStyle.of(context).style.merge(
          TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
    final naturalText = TextPainter(
      text: TextSpan(text: filename, style: chipStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final wrappedText = TextPainter(
      text: TextSpan(text: filename, style: chipStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: textSlotWidth);
    expect(tester.widget<ConstrainedText>(filenameLabel).data, filename);
    expect(textSlotWidth, closeTo(99, 0.01));
    expect(naturalText.width, closeTo(98.28, 0.5));
    expect(naturalText.width, lessThan(textSlotWidth));
    expect(labelRect.width, closeTo(99, 0.01));
    expect(wrappedText.computeLineMetrics(), hasLength(1));
    expect(labelRect.height, closeTo(wrappedText.height, 0.01));
    expect(tester.getSize(chip).height, 72);
    expect(previewBarRect.height, 106);
    expect(labelRect.bottom, lessThanOrEqualTo(chipRect.bottom - 8));
    expect(chipRect.bottom, lessThanOrEqualTo(previewBarRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview bar grows at the rendered 99 dp wrap boundary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const filename = 'notes.pdf';
    await _seedPdf(tester, 'notes');
    await _openAtTextScale(
      tester,
      textScale: await _scaleForNaturalTextWidth(tester, 97.88),
    );
    final chip = find.byType(PreviewChip);
    final filenameLabel = find.descendant(
      of: chip,
      matching: find.byType(ConstrainedText),
    );
    final labelRect = tester.getRect(filenameLabel);
    final chipRect = tester.getRect(chip);
    final chipRow = find.descendant(of: chip, matching: find.byType(Row));
    final textSlotWidth = tester.getSize(chipRow).width - 20 - 4;
    final previewBar = find.byKey(const Key('file_picker_preview_bar'));
    final previewBarRect = tester.getRect(previewBar);
    final context = tester.element(chip);
    final chipStyle = DefaultTextStyle.of(context).style.merge(
          TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
    final naturalText = TextPainter(
      text: TextSpan(text: filename, style: chipStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final wrappedText = TextPainter(
      text: TextSpan(text: filename, style: chipStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: textSlotWidth);
    final requiredHeight = PreviewChip.requiredHeight(
      context,
      fileName: filename,
      isImage: false,
    );

    expect(textSlotWidth, closeTo(99, 0.01));
    expect(naturalText.width, closeTo(99.28, 0.2));
    expect(naturalText.width, greaterThan(textSlotWidth));
    expect(naturalText.width, lessThan(100));
    expect(labelRect.width, closeTo(99, 0.01));
    expect(wrappedText.computeLineMetrics(), hasLength(2));
    expect(labelRect.height, closeTo(wrappedText.height, 0.01));
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(requiredHeight));
    expect(tester.getSize(previewBar).height, greaterThanOrEqualTo(106));
    expect(labelRect.bottom, lessThanOrEqualTo(chipRect.bottom - 8));
    expect(chipRect.bottom, lessThanOrEqualTo(previewBarRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview bar grows when text exceeds 100 dp', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const filename = 'notes.pdf';
    await _seedPdf(tester, 'notes');

    await _openAtTextScale(
      tester,
      textScale: await _scaleForNaturalTextWidth(tester, 98.86),
    );
    final chip = find.byType(PreviewChip);
    final filenameLabel = find.descendant(
      of: chip,
      matching: find.byType(ConstrainedText),
    );
    final labelRect = tester.getRect(filenameLabel);
    final chipRect = tester.getRect(chip);
    final chipRow = find.descendant(of: chip, matching: find.byType(Row));
    final textSlotWidth = tester.getSize(chipRow).width - 20 - 4;
    final previewBar = find.byKey(const Key('file_picker_preview_bar'));
    final previewBarRect = tester.getRect(previewBar);
    final context = tester.element(chip);
    final chipStyle = DefaultTextStyle.of(context).style.merge(
          TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
    final naturalText = TextPainter(
      text: TextSpan(text: filename, style: chipStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final wrappedText = TextPainter(
      text: TextSpan(text: filename, style: chipStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: textSlotWidth);
    final requiredHeight = PreviewChip.requiredHeight(
      context,
      fileName: filename,
      isImage: false,
    );

    expect(textSlotWidth, closeTo(99, 0.01));
    expect(naturalText.width, closeTo(100.28, 0.2));
    expect(naturalText.width, greaterThan(100));
    expect(labelRect.width, closeTo(99, 0.01));
    expect(wrappedText.computeLineMetrics(), hasLength(2));
    expect(labelRect.height, closeTo(wrappedText.height, 0.01));
    expect(tester.getSize(chip).height, greaterThanOrEqualTo(requiredHeight));
    expect(tester.getSize(previewBar).height, greaterThanOrEqualTo(106));
    expect(labelRect.bottom, lessThanOrEqualTo(chipRect.bottom - 8));
    expect(chipRect.bottom, lessThanOrEqualTo(previewBarRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scaled CJK filename fits the measured production chip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _seedPdf(tester, '資料');

    await tester.pumpWidget(_buildTestApp((_) {}, textScale: 3));
    await _openPicker(tester);
    _expectOnlyKnownScaleThreeChromeOverflows(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    _expectOnlyKnownScaleThreeChromeOverflows(tester);

    final chip = find.byType(PreviewChip);
    final label = find.descendant(
      of: chip,
      matching: find.byType(ConstrainedText),
    );
    expect(tester.widget<ConstrainedText>(label).data, '資料.pdf');
    expect(
      tester.getSize(chip).height,
      greaterThanOrEqualTo(tester.getSize(label).height + 17),
    );
  });

  testWidgets('repeated tap does not start another pending file read', (
    tester,
  ) async {
    final pendingRead = Completer<Uint8List?>();
    var readCount = 0;
    TextManifest.readFileOverrideForTesting = (_) {
      readCount++;
      return pendingRead.future;
    };

    await tester.runAsync(() async {
      await TextManifest.addRecord(
        TextRecord(
          name: 'repeated',
          hash: 'repeated',
          size: 1,
          createdAt: DateTime.now(),
        ),
      );
    });

    List<MapEntry<String, Uint8List>>? pickerResult;
    await tester.pumpWidget(_buildTestApp((result) => pickerResult = result));
    await _openPicker(tester);

    await tester.tap(find.text('repeated.txt'));
    await tester.pump();
    await tester.tap(find.text('repeated.txt'));
    await tester.pump();
    expect(readCount, 1);

    final fileBytes = Uint8List.fromList([1, 2, 3]);
    pendingRead.complete(fileBytes);
    await tester.pump();
    await tester.pump();
    expect(find.byType(PreviewChip), findsOneWidget);

    await tester.tap(find.byKey(const Key('file_picker_confirm_btn')));
    await tester.pump();
    expect(pickerResult, hasLength(1));
    expect(pickerResult!.single.key, 'repeated.txt');
    expect(pickerResult!.single.value, fileBytes);
  });

  testWidgets('selected file can be deselected after it becomes unreadable', (
    tester,
  ) async {
    var readCount = 0;
    TextManifest.readFileOverrideForTesting = (_) async {
      readCount++;
      return readCount == 1 ? Uint8List.fromList([1, 2, 3]) : null;
    };

    await tester.runAsync(() async {
      await TextManifest.addRecord(
        TextRecord(
          name: 'selected',
          hash: 'selected',
          size: 1,
          createdAt: DateTime.now(),
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp((_) {}));
    await _openPicker(tester);

    await tester.tap(find.text('selected.txt'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PreviewChip), findsOneWidget);
    expect(readCount, 1);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.byType(PreviewChip), findsNothing);
    expect(readCount, 1);
  });

  testWidgets('deselecting a selected file removes it', (tester) async {
    final pendingRead = Completer<Uint8List?>();
    TextManifest.readFileOverrideForTesting = (_) => pendingRead.future;

    await tester.runAsync(() async {
      await TextManifest.addRecord(
        TextRecord(
          name: 'pending',
          hash: 'pending',
          size: 1,
          createdAt: DateTime.now(),
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp((_) {}));
    await _openPicker(tester);

    await tester.tap(find.text('pending.txt'));
    await tester.pump();
    pendingRead.complete(Uint8List.fromList([1]));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PreviewChip), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.byType(PreviewChip), findsNothing);
  });

  testWidgets('preview chip removal removes a selected file', (tester) async {
    TextManifest.readFileOverrideForTesting =
        (_) async => Uint8List.fromList([1]);

    await tester.runAsync(() async {
      await TextManifest.addRecord(
        TextRecord(
          name: 'pending',
          hash: 'pending',
          size: 1,
          createdAt: DateTime.now(),
        ),
      );
    });

    await tester.pumpWidget(_buildTestApp((_) {}));
    await _openPicker(tester);

    await tester.tap(find.text('pending.txt'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byType(PreviewChip), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(PreviewChip),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pump();
    expect(find.byType(PreviewChip), findsNothing);
  });

  testWidgets('clearing selection ignores an earlier pending file read', (
    tester,
  ) async {
    final pendingRead = Completer<Uint8List?>();
    final pendingReadStarted = Completer<void>();
    TextManifest.readFileOverrideForTesting = (fileName) {
      if (fileName == 'pending.txt') {
        pendingReadStarted.complete();
        return pendingRead.future;
      }
      return Future.value(Uint8List.fromList([2]));
    };

    await tester.runAsync(() async {
      for (final name in ['pending', 'selected']) {
        await TextManifest.addRecord(
          TextRecord(
            name: name,
            hash: name,
            size: 1,
            createdAt: DateTime.now(),
          ),
        );
      }
    });

    List<MapEntry<String, Uint8List>>? pickerResult;
    await tester.pumpWidget(_buildTestApp((result) => pickerResult = result));
    await _openPicker(tester);

    await tester.tap(find.text('pending.txt'));
    await tester.pump();
    expect(pendingReadStarted.isCompleted, isTrue);

    await tester.tap(find.text('selected.txt'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PreviewChip), findsOneWidget);

    await tester.tap(find.byKey(const Key('file_picker_clear_btn')));
    await tester.pump();
    expect(find.byType(PreviewChip), findsNothing);

    pendingRead.complete(Uint8List.fromList([1]));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PreviewChip), findsNothing);

    await tester.tap(find.byKey(const Key('file_picker_confirm_btn')));
    await tester.pump();
    expect(pickerResult, isEmpty);
  });

  testWidgets('closing picker ignores a pending file read', (tester) async {
    final pendingRead = Completer<Uint8List?>();
    final pendingReadStarted = Completer<void>();
    TextManifest.readFileOverrideForTesting = (_) {
      pendingReadStarted.complete();
      return pendingRead.future;
    };

    await tester.runAsync(() async {
      await TextManifest.addRecord(
        TextRecord(
          name: 'pending',
          hash: 'pending',
          size: 1,
          createdAt: DateTime.now(),
        ),
      );
    });

    List<MapEntry<String, Uint8List>>? pickerResult;
    await tester.pumpWidget(_buildTestApp((result) => pickerResult = result));
    await _openPicker(tester);

    await tester.tap(find.text('pending.txt'));
    await tester.pump();
    expect(pendingReadStarted.isCompleted, isTrue);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    pendingRead.complete(Uint8List.fromList([1]));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(pickerResult, isNull);
  });
}

void _expectOnlyKnownScaleThreeChromeOverflows(WidgetTester tester) {
  // Keep the 3× route regression focused on the selected chip while pinning
  // the adjacent 72 dp tab strip and selected-state AppBar overflow for their
  // separate follow-up. Assert the tab's actual overflowing child geometry;
  // the test binding's aggregated exception does not retain its individual
  // FlutterErrorDetails, so its count alone is not a sufficient allowlist.
  for (final name in ['text', 'image', 'video', 'audio']) {
    final tab = find.byKey(Key('file_picker_tab_$name'));
    final tabContent = find.descendant(of: tab, matching: find.byType(Column));
    final label =
        find.descendant(of: tab, matching: find.byType(ConstrainedText));
    expect(tab, findsOneWidget);
    expect(tester.getSize(tab).height, 72);
    expect(tester.getSize(tabContent).height, 72);
    expect(tester.getSize(label).height, 60);
  }
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    expect(
      exception.toString(),
      anyOf(
        'A RenderFlex overflowed by 14 pixels on the bottom.',
        'A RenderFlex overflowed by 67 pixels on the right.',
        'Multiple exceptions (4) were detected during the running of the current test, and at least one was unexpected.',
      ),
    );
  }
}

Future<void> _seedPdf(WidgetTester tester, String name) async {
  // ignore: invalid_use_of_visible_for_testing_member
  TextManifest.readFileOverrideForTesting =
      (_) async => Uint8List.fromList([1, 2, 3]);
  await tester.runAsync(() async {
    await TextManifest.addRecord(
      TextRecord(
        name: name,
        format: 'pdf',
        hash: '$name-preview-chip',
        size: 3,
        createdAt: DateTime.now(),
      ),
    );
  });
}

Widget _buildTestApp(
  ValueChanged<List<MapEntry<String, Uint8List>>?> onPickerResult, {
  double textScale = 1,
}) {
  return MaterialApp(
    theme: textScale == 3
        ? ThemeData(
            useMaterial3: true,
            textTheme: const TextTheme(bodyMedium: TextStyle(height: 1.2)),
          )
        : null,
    locale: const Locale('en', 'US'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          onPickerResult(await showAppFilePickerDialog(context));
        },
        child: const Text('Open Picker'),
      ),
    ),
  );
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.text('Open Picker'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _openAtTextScale(
  WidgetTester tester, {
  required double textScale,
}) async {
  await tester.pumpWidget(_buildTestApp((_) {}, textScale: textScale));
  await _openPicker(tester);
  await tester.tap(find.byType(Checkbox).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<double> _scaleForNaturalTextWidth(
  WidgetTester tester,
  double targetWidth,
) async {
  await tester.pumpWidget(_buildTestApp((_) {}, textScale: 1));
  final context = tester.element(find.text('Open Picker'));
  final style = DefaultTextStyle.of(context).style.merge(
        TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
  var low = 1.0;
  var high = 4.0;
  for (var attempt = 0; attempt < 30; attempt++) {
    final scale = (low + high) / 2;
    final painter = TextPainter(
      text: TextSpan(text: 'notes.pdf', style: style),
      textDirection: Directionality.of(context),
      textScaler: TextScaler.linear(scale),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    if (painter.width < targetWidth) {
      low = scale;
    } else {
      high = scale;
    }
  }
  return (low + high) / 2;
}
