import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/album_picker_shared.dart';
import 'package:stroom/pages/chat/composer/chat_album_picker_dialog.dart';
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
/// real-async windows (engine image work) with pumps (fake-zone
/// continuations).
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

  group('AppAlbumPickerDialog tests', () {
    testWidgets('dialog opens and shows title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppAlbumPickerDialog(context);
                  },
                  child: const Text('Open Album'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Album'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      // Should show the picker title
      expect(find.text('应用内相册'), findsOneWidget);
    });

    testWidgets('dialog has close/dismiss button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppAlbumPickerDialog(context);
                  },
                  child: const Text('Open Album'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Album'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      // Find close button
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap close to dismiss
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('应用内相册'), findsNothing);
    });

    testWidgets('dialog dismisses on background tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppAlbumPickerDialog(context);
                  },
                  child: const Text('Open Album'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Album'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('应用内相册'), findsOneWidget);

      // Tap on background barrier
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('应用内相册'), findsNothing);
    });
  });

  // ====================================================================
  // Quick-edit background processing: confirm-button gating
  // ====================================================================
  group('AppAlbumPickerDialog quick-edit gating', () {
    testWidgets('confirm button is disabled while an edit processes',
        (tester) async {
      final png = await tester.runAsync(_createEnginePng);
      // Seed the test-mode image library with one real image.
      await tester.runAsync(() async {
        await ImageManifest.writeFile('gate-hash.png', png!);
        await ImageManifest.addRecord(
          ImageRecord(
            name: 'gate-image',
            hash: 'gate-hash',
            format: 'png',
            createdAt: DateTime.now(),
            size: png.length,
            folder: '',
          ),
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppAlbumPickerDialog(context);
                  },
                  child: const Text('Open Album'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Album'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));

      // The record list loads via real manifest IO in the fake zone —
      // wait for the image tile to appear.
      await _pumpUntil(
        tester,
        () => find.text('gate-image.png').evaluate().isNotEmpty,
      );

      // Select the image — the file is read asynchronously (real IO).
      await tester.tap(find.text('gate-image.png'));
      await tester.pump();
      await _pumpUntil(
        tester,
        () => find.byType(AlbumPreviewChip).evaluate().isNotEmpty,
      );

      // Preview chip → preview dialog → quick editor.
      await tester.tap(find.byType(AlbumPreviewChip));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit));
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
        find.byKey(const Key('album_picker_confirm_btn')),
      );
      expect(confirmBtn.onPressed, isNull);

      // Once the pipeline finishes, the button re-enables.
      await _pumpUntil(
        tester,
        () => find.text('处理中...').evaluate().isEmpty,
      );
      final confirmBtn2 = tester.widget<FilledButton>(
        find.byKey(const Key('album_picker_confirm_btn')),
      );
      expect(confirmBtn2.onPressed, isNotNull);
    });
  });
}
