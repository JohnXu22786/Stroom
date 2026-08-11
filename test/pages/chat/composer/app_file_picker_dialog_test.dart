import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/chat_file_picker_dialog.dart';
import 'package:stroom/pages/chat/composer/file_picker_shared.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';
import 'package:stroom/pages/image_editor_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/image_manifest.dart';

/// Creates a small valid PNG (8x8 green) via the real engine.
///
/// Must be called from `tester.runAsync` — engine image work never
/// completes inside the widget-test FakeAsync zone.
Future<Uint8List> _createEnginePng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = const Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

/// Pumps until [condition] is true or [timeout] elapses, alternating
/// real-async windows (engine image work / file IO) with pumps
/// (fake-zone continuations).
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for condition');
    }
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ImageManifest.invalidateCache();
  });
  // ====================================================================
  // Quick-edit background processing: confirm-button gating
  // ====================================================================
  group('AppFilePickerDialog quick-edit gating', () {
    testWidgets('confirm button is disabled while an edit processes',
        (tester) async {
      // Room for the tab content + preview bar + confirm button.
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final png = await tester.runAsync(_createEnginePng);
      // Seed the test-mode image library with one real image.
      await tester.runAsync(() async {
        await ImageManifest.writeFile('gate-hash.png', png!);
        await ImageManifest.addRecord(
          ImageRecord(
            name: 'gate-file',
            hash: 'gate-hash',
            format: 'png',
            createdAt: DateTime.now(),
            size: png.length,
            folder: '',
          ),
        );
      });

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppFilePickerDialog(context),
            child: const Text('Open Picker'),
          ),
        ),
      ));
      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Switch to the image tab and let the tab transition settle, then
      // wait for its records (real manifest IO in the fake zone).
      await tester.tap(find.byKey(const Key('file_picker_tab_image')));
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () => find.text('gate-file.png').evaluate().isNotEmpty,
      );

      // Select the image — the file is read asynchronously (real IO).
      await tester.tap(find.byType(Checkbox), warnIfMissed: false);
      await tester.pump();
      await _pumpUntil(
        tester,
        () => find.byType(PreviewChip).evaluate().isNotEmpty,
      );

      // Preview chip → preview dialog → quick editor (crop button —
      // the edit button opens the full editor instead).
      await tester.tap(find.byType(PreviewChip));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Wait for the editor image to decode (engine work — real async).
      await _pumpUntil(
        tester,
        () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
      );

      // Confirm the edit — the editor pops immediately and the image
      // processing continues in the background.
      await tester.tap(find.text('完成'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Gating: while processing, confirm is disabled with a processing
      // label — confirming now would return the unedited bytes.
      expect(find.text('处理中...'), findsOneWidget);
      final confirmBtn = tester.widget<FilledButton>(
        find.byKey(const Key('file_picker_confirm_btn')),
      );
      expect(confirmBtn.onPressed, isNull);

      // Once the pipeline finishes, the button re-enables.
      await _pumpUntil(
        tester,
        () => find.text('处理中...').evaluate().isEmpty,
      );
      final confirmBtn2 = tester.widget<FilledButton>(
        find.byKey(const Key('file_picker_confirm_btn')),
      );
      expect(confirmBtn2.onPressed, isNotNull);
    });

    testWidgets(
        'edit button opens the full editor (ImageEditorPage), not the '
        'quick editor', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final png = await tester.runAsync(_createEnginePng);
      await tester.runAsync(() async {
        await ImageManifest.writeFile('full-edit-hash.png', png!);
        await ImageManifest.addRecord(
          ImageRecord(
            name: 'full-edit-file',
            hash: 'full-edit-hash',
            format: 'png',
            createdAt: DateTime.now(),
            size: png.length,
            folder: '',
          ),
        );
      });

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppFilePickerDialog(context),
            child: const Text('Open Picker'),
          ),
        ),
      ));
      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Switch to the image tab and wait for its records.
      await tester.tap(find.byKey(const Key('file_picker_tab_image')));
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () => find.text('full-edit-file.png').evaluate().isNotEmpty,
      );

      // Select the image — the file is read asynchronously (real IO).
      await tester.tap(find.byType(Checkbox), warnIfMissed: false);
      await tester.pump();
      await _pumpUntil(
        tester,
        () => find.byType(PreviewChip).evaluate().isNotEmpty,
      );

      // Preview chip → preview dialog → full editor (edit button).
      await tester.tap(find.byType(PreviewChip));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The full editor page must be pushed (ProImageEditor), not the
      // quick editor.
      await _pumpUntil(
        tester,
        () => find.byType(ImageEditorPage).evaluate().isNotEmpty,
      );
      expect(find.byType(ExtendedImageEditorPage), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════
  // Preview bar tests
  // ═══════════════════════════════════════════════════════════════
  group('AppFilePickerDialog preview bar', () {
    testWidgets('preview bar is not shown when no files are selected',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppFilePickerDialog(context),
            child: const Text('Open Picker'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Picker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Preview bar should not appear when no selection
      expect(find.byKey(const Key('file_picker_preview_bar')), findsNothing);
    });
  });
}
