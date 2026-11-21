import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/chat_attachment_panel.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('all four attachment actions fit a 320 dp viewport', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 640));
    final picked = <String>[];
    await _openPanel(tester, picked);

    expect(tester.takeException(), isNull);
    for (final label in [
      'Take photo',
      'Device gallery',
      'Device files',
      'App files'
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
          find.ancestor(
            of: find.text(label),
            matching: find.byType(InkWell),
          ),
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
          find.ancestor(
            of: find.text(label),
            matching: find.byType(InkWell),
          ),
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
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _openPanel(WidgetTester tester, List<String> picked,
    {Locale? locale}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
  );
  await tester.tap(find.text('Open attachments'));
  await tester.pumpAndSettle();
}
