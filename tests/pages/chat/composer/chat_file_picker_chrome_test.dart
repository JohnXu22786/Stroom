import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/chat/composer/chat_file_picker_dialog.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';
import 'package:stroom/widgets/constrained_text.dart';

const _captureKey = ValueKey('chat-file-picker-chrome-capture');

Future<void> _loadCaptureFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final fontDirectory = '$flutterRoot/bin/cache/artifacts/material_fonts';
  for (final (family, fileName) in [
    ('Roboto', 'Roboto-Regular.ttf'),
    ('MaterialIcons', 'MaterialIcons-Regular.otf'),
  ]) {
    final bytes = File('$fontDirectory/$fileName').readAsBytesSync();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
  }
}

Future<void> _openPicker(
  WidgetTester tester, {
  required ThemeData theme,
  required ValueNotifier<double> textScale,
  required Locale locale,
  String fixtureName = 'picker-chrome-note.txt',
  bool disableAnimations = false,
  Duration tabDataWait = const Duration(milliseconds: 500),
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      theme: theme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => ValueListenableBuilder<double>(
        valueListenable: textScale,
        builder: (context, scale, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: disableAnimations,
          ),
          child: RepaintBoundary(key: _captureKey, child: child!),
        ),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAppFilePickerDialog(context),
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open picker'));
  await tester.pump();
  await tester.pump(tabDataWait);
  await tester.tap(find.text(fixtureName));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _expectScreenshot(WidgetTester tester, String path) async {
  await expectLater(find.byKey(_captureKey), matchesGoldenFile(path));
}

TextPainter _measureConstrainedText(WidgetTester tester, Finder finder) {
  final widget = tester.widget<ConstrainedText>(finder);
  final context = tester.element(finder);
  final style = DefaultTextStyle.of(context).style.merge(widget.style);
  return TextPainter(
    text: TextSpan(text: widget.data, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    locale: Localizations.maybeLocaleOf(context),
  )..layout();
}

void main() {
  setUpAll(_loadCaptureFonts);

  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  testWidgets('large text reflows the picker chrome and keeps tabs usable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.runAsync(() async {
      await TextManifest.writeText('picker-chrome-note.txt', 'safe fixture');
      await TextManifest.addRecord(
        TextRecord(
          name: 'picker-chrome-note',
          hash: 'picker-chrome-note',
          size: 12,
          createdAt: DateTime(2026, 11, 27),
        ),
      );
    });

    for (final (theme, name) in [
      (ThemeData.light(useMaterial3: true), 'light'),
      (ThemeData.dark(useMaterial3: true), 'dark'),
    ]) {
      final textScale = ValueNotifier(1.0);
      await _openPicker(
        tester,
        theme: theme,
        textScale: textScale,
        locale: const Locale('en', 'US'),
      );
      if (name == 'light') {
        await _expectScreenshot(
          tester,
          '../../../../docs/ui-constrained-text-qa/chat-file-picker-chrome/chat-file-picker-en-430x932-scale1-light.png',
        );
      }

      tester.view.physicalSize = const Size(320, 640);
      textScale.value = 3;
      await tester.pumpAndSettle();
      await _expectScreenshot(
        tester,
        '../../../../docs/ui-constrained-text-qa/chat-file-picker-chrome/chat-file-picker-en-320x640-scale3-$name.png',
      );

      for (final (type, label) in [
        ('image', 'Images'),
        ('text', 'Text'),
        ('video', 'Videos'),
        ('audio', 'Audio'),
      ]) {
        final tab = find.byKey(Key('file_picker_tab_$type'));
        expect(find.bySemanticsLabel(label), findsOneWidget);
        final labelFinder = find.descendant(
          of: tab,
          matching: find.byType(ConstrainedText),
        );
        expect(labelFinder, findsOneWidget);
        final labelPainter = _measureConstrainedText(tester, labelFinder);
        expect(
          labelPainter.width,
          lessThanOrEqualTo(tester.getSize(labelFinder).width),
        );
        final rect = tester.getRect(tab);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(640));
        await tester.tap(tab);
        await tester.pumpAndSettle();
        final semanticsTab = find.bySemanticsLabel(label);
        expect(
          tester
              .getSemantics(semanticsTab)
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        expect(
          find.byKey(Key('file_picker_tab_content_$type')),
          findsOneWidget,
        );
      }

      await tester.tap(find.byKey(const Key('file_picker_clear_btn')));
      await tester.pump();
      expect(find.byKey(const Key('file_picker_clear_btn')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      textScale.dispose();
    }

    final landscapeTextScale = ValueNotifier(3.0);
    await _openPicker(
      tester,
      theme: ThemeData.light(useMaterial3: true),
      textScale: landscapeTextScale,
      locale: const Locale('en', 'US'),
    );
    tester.view.physicalSize = const Size(568, 320);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('file_picker_short_viewport_scroll')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('file_picker_preview_bar')), findsOneWidget);
    final landscapeClear = find.byKey(const Key('file_picker_clear_btn'));
    final landscapeConfirm = find.byKey(const Key('file_picker_confirm_btn'));
    final landscapePreview = find.byKey(const Key('file_picker_preview_bar'));
    final landscapeFile = find.text('picker-chrome-note.txt').first;
    final landscapeScroll =
        find.byKey(const Key('file_picker_short_viewport_scroll'));
    final landscapeViewport = const Rect.fromLTWH(0, 0, 568, 320);
    expect(tester.getRect(landscapeFile).overlaps(landscapeViewport), isTrue);
    final previewTopBeforeDrag = tester.getTopLeft(landscapePreview).dy;
    await tester.drag(landscapeScroll, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(landscapePreview).dy,
      lessThan(previewTopBeforeDrag),
    );
    expect(
      tester.getRect(landscapePreview).overlaps(landscapeViewport),
      isTrue,
    );
    tester.view.physicalSize = const Size(568, 401);
    await tester.pumpAndSettle();
    expect(landscapeScroll, findsOneWidget);
    await tester.drag(landscapeScroll, const Offset(0, -300));
    await tester.pumpAndSettle();
    const thresholdViewport = Rect.fromLTWH(0, 0, 568, 401);
    expect(
      tester.getRect(landscapePreview).overlaps(thresholdViewport),
      isTrue,
    );
    expect(
      tester.getRect(landscapeConfirm).overlaps(thresholdViewport),
      isTrue,
    );
    expect(tester.getRect(landscapeClear).overlaps(thresholdViewport), isTrue);
    expect(tester.takeException(), isNull);
    await tester.tap(landscapeConfirm);
    await tester.pumpAndSettle();
    expect(find.text('Open picker'), findsOneWidget);
    landscapeTextScale.dispose();

    final germanTextScale = ValueNotifier(1.0);
    await _openPicker(
      tester,
      theme: ThemeData.light(useMaterial3: true),
      textScale: germanTextScale,
      locale: const Locale('de', 'DE'),
    );
    tester.view.physicalSize = const Size(320, 640);
    germanTextScale.value = 3;
    await tester.pumpAndSettle();
    await _expectScreenshot(
      tester,
      '../../../../docs/ui-constrained-text-qa/chat-file-picker-chrome/chat-file-picker-de-DE-320x640-scale3-light.png',
    );

    expect(find.bySemanticsLabel('Dateien auswählen'), findsOneWidget);
    const germanClearLabel = 'Auswahl aufheben (1)';
    expect(find.bySemanticsLabel(germanClearLabel), findsOneWidget);
    final clearButton = find.byKey(const Key('file_picker_clear_btn'));
    final clearText = find.descendant(
      of: clearButton,
      matching: find.text(germanClearLabel),
    );
    final clearConstrainedText = find.descendant(
      of: clearButton,
      matching: find.byType(ConstrainedText),
    );
    expect(clearConstrainedText, findsOneWidget);
    final clearTextX = tester.getTopLeft(clearText).dx;
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getTopLeft(clearText).dx, closeTo(clearTextX, 0.01));
    final clearPainter = _measureConstrainedText(tester, clearConstrainedText);
    final clearSlotWidth = tester.getSize(clearConstrainedText).width;
    final clearTravel = Duration(
      milliseconds: ((clearPainter.width - clearSlotWidth) / 24 * 1000).round(),
    );
    expect(clearPainter.width, greaterThan(clearSlotWidth));
    await tester.pump(clearTravel + const Duration(milliseconds: 20));
    final clearClip =
        find.ancestor(of: clearText, matching: find.byType(ClipRect)).first;
    final clearClipRect = tester.getRect(clearClip);
    final clearEndRect = tester.getRect(clearText);
    expect(clearEndRect.right, closeTo(clearClipRect.right, 2));
    await _expectScreenshot(
      tester,
      '../../../../docs/ui-constrained-text-qa/chat-file-picker-chrome/chat-file-picker-de-DE-320x640-scale3-clear-end.png',
    );
    await tester.pump(const Duration(milliseconds: 1999));
    expect(tester.getTopLeft(clearText).dx, closeTo(clearEndRect.left, 0.01));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(clearText).dx, greaterThan(clearEndRect.left));

    for (final (type, label) in [
      ('image', 'Bilder'),
      ('text', 'Text'),
      ('video', 'Videos'),
      ('audio', 'Audio'),
    ]) {
      final tab = find.byKey(Key('file_picker_tab_$type'));
      expect(find.bySemanticsLabel(label), findsOneWidget);
      final labelFinder = find.descendant(
        of: tab,
        matching: find.byType(ConstrainedText),
      );
      expect(labelFinder, findsOneWidget);
      final labelPainter = _measureConstrainedText(tester, labelFinder);
      expect(
        labelPainter.width,
        lessThanOrEqualTo(tester.getSize(labelFinder).width),
      );
      await tester.tap(tab);
      await tester.pumpAndSettle();
      final semanticsTab = find.bySemanticsLabel(label);
      expect(
        tester
            .getSemantics(semanticsTab)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        find.byKey(Key('file_picker_tab_content_$type')),
        findsOneWidget,
      );
    }
    await tester.tap(clearButton);
    await tester.pump();
    expect(find.byKey(const Key('file_picker_clear_btn')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    germanTextScale.dispose();

    final reducedMotionScale = ValueNotifier(3.0);
    await _openPicker(
      tester,
      theme: ThemeData.light(useMaterial3: true),
      textScale: reducedMotionScale,
      locale: const Locale('de', 'DE'),
      disableAnimations: true,
    );
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();
    final reducedMotionText = find.descendant(
      of: find.byKey(const Key('file_picker_clear_btn')),
      matching: find.text(germanClearLabel),
    );
    final reducedMotionX = tester.getTopLeft(reducedMotionText).dx;
    await tester.pump(const Duration(seconds: 30));
    expect(
      tester.getTopLeft(reducedMotionText).dx,
      closeTo(reducedMotionX, 0.01),
    );
    expect(find.bySemanticsLabel(germanClearLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    reducedMotionScale.dispose();

    semantics.dispose();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('short landscape scroll extent follows the active tab', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.runAsync(() async {
      await TextManifest.writeText('picker-chrome-anchor.txt', 'safe fixture');
      await TextManifest.addRecord(
        TextRecord(
          name: 'picker-chrome-anchor',
          hash: 'picker-chrome-anchor',
          size: 12,
          createdAt: DateTime(2026, 11, 27),
        ),
      );
      for (var index = 0; index < 20; index++) {
        final name = 'picker-chrome-long-$index';
        await TextManifest.writeText('$name.txt', 'safe fixture');
        await TextManifest.addRecord(
          TextRecord(
            name: name,
            hash: name,
            size: 12,
            createdAt: DateTime(2026, 11, 27),
          ),
        );
      }
      TextManifest.invalidateCache();
    });

    final textScale = ValueNotifier(3.0);
    await _openPicker(
      tester,
      theme: ThemeData.light(useMaterial3: true),
      textScale: textScale,
      locale: const Locale('en', 'US'),
      fixtureName: 'picker-chrome-anchor.txt',
      tabDataWait: const Duration(seconds: 2),
    );
    tester.view.physicalSize = const Size(568, 320);
    await tester.pumpAndSettle();

    final scroll = find.byKey(const Key('file_picker_short_viewport_scroll'));
    final scrollable = find
        .descendant(
          of: scroll,
          matching: find.byType(Scrollable),
        )
        .first;
    expect(scrollable, findsOneWidget);
    final scrollState = tester.state<ScrollableState>(scrollable);
    final longFolderExtent = scrollState.position.maxScrollExtent;
    expect(longFolderExtent, greaterThan(1000));
    final lastLongFile = find.text('picker-chrome-long-9.txt');
    expect(lastLongFile, findsOneWidget);
    await tester.drag(scroll, const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(
      tester
          .getRect(lastLongFile)
          .overlaps(const Rect.fromLTWH(0, 0, 568, 320)),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('file_picker_tab_image')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('file_picker_tab_content_image')),
      findsOneWidget,
    );
    final sparseTabExtent = scrollState.position.maxScrollExtent;
    expect(sparseTabExtent, lessThan(longFolderExtent / 2));
    await tester.drag(scroll, const Offset(0, -1000));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('file_picker_confirm_btn'));
    expect(
      tester.getRect(confirm).overlaps(const Rect.fromLTWH(0, 0, 568, 320)),
      isTrue,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
    textScale.dispose();
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
