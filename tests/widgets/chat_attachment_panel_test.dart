import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/chat_attachment_panel.dart';
import 'package:stroom/widgets/constrained_text.dart';

const _captureKey = ValueKey('chat-attachment-panel-capture');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
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
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  testWidgets('all four attachment actions fit a 320 dp viewport', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 640));
    final picked = <String>[];
    await _openPanel(tester, picked);

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile(
        '../../docs/ui-constrained-text-qa/r13_chat_attachment_panel/chat-attachment-panel-en-US-320x640-scale1-light.png',
      ),
    );
    for (final label in [
      'Take photo',
      'Device gallery',
      'Device files',
      'App files',
    ]) {
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(16));
      expect(rect.right, lessThanOrEqualTo(304));
      final constrainedLabel = find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == label,
      );
      expect(tester.getSize(constrainedLabel).width, greaterThanOrEqualTo(120));
      expect(rect.bottom, lessThanOrEqualTo(640));
    }

    await tester.tap(find.text('App files'));
    await tester.pumpAndSettle();
    expect(picked, ['app-files']);
  });

  testWidgets('all four attachment actions remain on one row when wide', (
    tester,
  ) async {
    await _setViewport(tester, const Size(800, 640));
    await _openPanel(tester, <String>[]);

    expect(tester.takeException(), isNull);
    final centers = [
      for (final label in [
        'Take photo',
        'Device gallery',
        'Device files',
        'App files',
      ])
        tester.getCenter(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        ),
    ];
    expect(centers.map((point) => point.dy).toSet(), hasLength(1));
  });

  testWidgets('keeps one row at the 352 dp viewport boundary', (tester) async {
    await _setViewport(tester, const Size(352, 640));
    await _openPanel(tester, <String>[]);

    expect(tester.takeException(), isNull);
    final centers = [
      for (final label in [
        'Take photo',
        'Device gallery',
        'Device files',
        'App files',
      ])
        tester.getCenter(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        ),
    ];
    expect(centers.map((point) => point.dy).toSet(), hasLength(1));
  });

  testWidgets('German action labels fit the two-column narrow panel', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 640));
    final picked = <String>[];
    await _openPanel(tester, picked, locale: const Locale('de'));

    const labels = [
      'Foto aufnehmen',
      'Gerätegalerie',
      'Gerätedateien',
      'App-Dateien',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
      final rect = tester.getRect(find.text(label));
      expect(rect.left, greaterThanOrEqualTo(16));
      expect(rect.right, lessThanOrEqualTo(304));
      final constrainedLabel = find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == label,
      );
      expect(tester.getSize(constrainedLabel).width, greaterThanOrEqualTo(120));
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('App-Dateien'));
    await tester.pumpAndSettle();
    expect(picked, ['app-files']);
  });

  testWidgets(
    'short German panel scrolls to every action at large text scale',
    (tester) async {
      await _setViewport(tester, const Size(320, 320));
      final picked = <String>[];
      await _openPanel(
        tester,
        picked,
        locale: const Locale('de'),
        textScaler: const TextScaler.linear(2.5),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(SingleChildScrollView).first,
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      await expectLater(
        find.byKey(_captureKey),
        matchesGoldenFile(
          '../../docs/ui-constrained-text-qa/r13_chat_attachment_panel/chat-attachment-panel-de-DE-320x320-scale2_5-light-top.png',
        ),
      );
      final appFiles = find.text('App-Dateien');
      await tester.ensureVisible(appFiles);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(0));
      await expectLater(
        find.byKey(_captureKey),
        matchesGoldenFile(
          '../../docs/ui-constrained-text-qa/r13_chat_attachment_panel/chat-attachment-panel-de-DE-320x320-scale2_5-light-scrolled.png',
        ),
      );
      expect(tester.getRect(appFiles).bottom, lessThanOrEqualTo(320));
      await tester.tap(appFiles);
      await tester.pumpAndSettle();
      expect(picked, ['app-files']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('attachment title stays within the sheet at large text scale', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 640));
    await _openPanel(
      tester,
      <String>[],
      textScaler: const TextScaler.linear(4),
    );

    final title = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == 'Attach file',
    );
    expect(title, findsOneWidget);
    final titleRect = tester.getRect(title);
    expect(titleRect.left, greaterThanOrEqualTo(54));
    expect(titleRect.right, lessThanOrEqualTo(304));
    expect(find.bySemanticsLabel('Attach file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _openPanel(
  WidgetTester tester,
  List<String> picked, {
  Locale? locale,
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showChatAttachmentPanel(
                  context: context,
                  onPickFromCamera: () => picked.add('camera'),
                  onPickFromGallery: () => picked.add('gallery'),
                  onPickFromFilePicker: () => picked.add('device-files'),
                  onPickFromAppFiles: () => picked.add('app-files'),
                ),
                child: const Text('Open attachments'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open attachments'));
  await tester.pumpAndSettle();
}
