import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';

/// Creates a small valid PNG (8x8 green) via the real engine.
///
/// Must be called from `tester.runAsync` — engine image work never
/// completes inside the widget-test FakeAsync zone.
Future<Uint8List> createTestImage() async {
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

/// Pumps until [condition] is true or [timeout] elapses.
///
/// Background image processing alternates between engine calls (decode,
/// rasterize, encode — need real async) and fake-zone continuations
/// (need pumps), so each iteration runs a real-async window followed by
/// a pump.
Future<void> pumpUntil(
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

/// Pushes [ExtendedImageEditorPage] from a host button and waits for the
/// editor state to exist (the image must decode first — a real-async
/// process). Polls instead of sleeping a fixed time so a slow engine
/// decode on CI cannot race the test.
Future<void> _pushEditor(
  WidgetTester tester, {
  required Uint8List imageBytes,
  required FutureOr<void> Function(QuickEditProcessingResult result)
      onProcessed,
  bool waitForEditorReady = true,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExtendedImageEditorPage(
                imageBytes: imageBytes,
                fileName: 'test.png',
                onProcessed: onProcessed,
              ),
            ),
          );
        },
        child: const Text('Open'),
      ),
    ),
  ));

  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  if (waitForEditorReady) {
    // The editor widget is only built after the image finishes loading.
    await pumpUntil(
      tester,
      () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
    );
  } else {
    // Give the (failing) load a moment to settle either way.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  }
}

void main() {
  group('ExtendedImageEditorPage', () {
    testWidgets('renders without crash when image data is provided',
        (tester) async {
      final png = await tester.runAsync(createTestImage);
      await tester.pumpWidget(MaterialApp(
        home: ExtendedImageEditorPage(
          imageBytes: png!,
          fileName: 'test.jpg',
          onProcessed: (_) async {},
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The page should display the file name in the app bar
      expect(find.text('快速编辑 - test.jpg'), findsOneWidget);
    });

    testWidgets('shows rotate and flip tool buttons', (tester) async {
      final png = await tester.runAsync(createTestImage);
      await tester.pumpWidget(MaterialApp(
        home: ExtendedImageEditorPage(
          imageBytes: png!,
          fileName: 'test.jpg',
          onProcessed: (_) async {},
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check for tool buttons in the bottom bar
      expect(find.text('左旋'), findsOneWidget);
      expect(find.text('右旋'), findsOneWidget);
      expect(find.text('翻转'), findsOneWidget);
      expect(find.text('裁剪'), findsOneWidget);
    });

    testWidgets('close button pops with null', (tester) async {
      bool? result;
      final png = await tester.runAsync(createTestImage);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ExtendedImageEditorPage(
                    imageBytes: png!,
                    fileName: 'test.jpg',
                    onProcessed: (_) async {},
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump();

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(result, isNull);
    });

    testWidgets('save button is present', (tester) async {
      final png = await tester.runAsync(createTestImage);
      await tester.pumpWidget(MaterialApp(
        home: ExtendedImageEditorPage(
          imageBytes: png!,
          fileName: 'test.jpg',
          onProcessed: (_) async {},
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the save/complete button
      expect(find.text('完成'), findsOneWidget);
    });

    // ====================================================================
    // Immediate pop + background processing
    //
    // The editor must pop as soon as the user taps 完成 and process the
    // image in the background — the edit result must survive the widget
    // being disposed (delivered via [onProcessed] afterwards).
    // ====================================================================
    group('immediate pop + background processing', () {
      testWidgets(
          'tapping 完成 pops the editor before processing runs, then '
          'delivers the processed bytes', (tester) async {
        final png = await tester.runAsync(createTestImage);
        Uint8List? delivered;
        await _pushEditor(
          tester,
          imageBytes: png!,
          onProcessed: (result) {
            if (result is QuickEditProcessingSuccess) {
              delivered = result.editedBytes;
            }
          },
        );

        // Tap 完成 — the editor pops immediately.
        await tester.tap(find.text('完成'));
        await tester.pump();

        // Mid-transition sanity check: nothing can have been delivered
        // yet (the pipeline waits for the pop animation, and engine work
        // cannot complete without a real-async window anyway).
        await tester.pump(const Duration(milliseconds: 100));
        expect(delivered, isNull,
            reason: 'processing must not run during the pop transition');

        // The route completes its exit — the editor widget is disposed.
        await pumpUntil(
          tester,
          () => find.byType(ExtendedImageEditorPage).evaluate().isEmpty,
        );
        // REAL GATE: by the time the widget is gone the pipeline has had
        // real-async windows — if the pop-animation wait were dropped the
        // bytes would already be delivered here.
        expect(delivered, isNull,
            reason: 'processing must start only after the pop animation');

        // The edit result is NOT lost: background processing still
        // completes and delivers the bytes via onProcessed.
        await pumpUntil(tester, () => delivered != null);
        expect(delivered, isNotNull);
        expect(delivered!.isNotEmpty, isTrue);
      });

      testWidgets('delivered bytes decode to a valid image', (tester) async {
        final png = await tester.runAsync(createTestImage);
        Uint8List? delivered;
        await _pushEditor(
          tester,
          imageBytes: png!,
          onProcessed: (result) {
            if (result is QuickEditProcessingSuccess) {
              delivered = result.editedBytes;
            }
          },
        );

        await tester.tap(find.text('完成'));
        await tester.pump();
        await pumpUntil(tester, () => delivered != null);

        // The 8x8 input PNG should come back as a valid 8x8 image.
        final codec =
            await tester.runAsync(() => ui.instantiateImageCodec(delivered!));
        final frame = await tester.runAsync(() => codec!.getNextFrame());
        expect(frame!.image.width, 8);
        expect(frame.image.height, 8);
        frame.image.dispose();
        codec!.dispose();
      });

      testWidgets('closing with X does not deliver bytes', (tester) async {
        final png = await tester.runAsync(createTestImage);
        Uint8List? delivered;
        await _pushEditor(
          tester,
          imageBytes: png!,
          onProcessed: (result) {
            if (result is QuickEditProcessingSuccess) {
              delivered = result.editedBytes;
            }
          },
        );

        // Close the editor without confirming — no processing should run.
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(delivered, isNull);
        expect(find.byType(ExtendedImageEditorPage), findsNothing);
      });

      testWidgets(
          'invalid image data shows an error snackbar and delivers nothing',
          (tester) async {
        QuickEditProcessingResult? outcome;
        // Invalid image data — the editor image never loads, so the
        // editor state is never created and confirming reports an error
        // without starting the pipeline.
        await _pushEditor(
          tester,
          imageBytes: Uint8List.fromList([1, 2, 3]),
          onProcessed: (result) => outcome = result,
          // The image never loads — do not wait for an editor state.
          waitForEditorReady: false,
        );

        await tester.tap(find.text('完成'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(outcome, isNull,
            reason: 'no pipeline runs when the editor never initialized');
        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('pipeline always delivers an outcome, including failures',
          (tester) async {
        final messengerKey = GlobalKey<ScaffoldMessengerState>();
        await tester.pumpWidget(MaterialApp(
          home: ScaffoldMessenger(
            key: messengerKey,
            child: const Scaffold(body: SizedBox()),
          ),
        ));

        QuickEditProcessingResult? outcome;
        // Invalid image data — the background decode fails. The pipeline
        // must still deliver a failure outcome (callers rely on the
        // always-fires contract to release their guards).
        await tester.runAsync(
          () => runQuickEditProcessing(
            rawData: Uint8List.fromList([1, 2, 3]),
            cropRect: null,
            action: null,
            messenger: messengerKey.currentState!,
            onProcessed: (result) => outcome = result,
          ),
        );
        await tester.pump();

        expect(outcome, isA<QuickEditProcessingFailure>());
        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('pop result is true when confirming', (tester) async {
        final png = await tester.runAsync(createTestImage);
        bool? popResult;
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popResult = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExtendedImageEditorPage(
                      imageBytes: png!,
                      fileName: 'test.png',
                      onProcessed: (_) async {},
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ));
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntil(
          tester,
          () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
        );

        await tester.tap(find.text('完成'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(popResult, isTrue);
      });

      testWidgets('close button cannot pop the page below during exit',
          (tester) async {
        final png = await tester.runAsync(createTestImage);
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExtendedImageEditorPage(
                      imageBytes: png!,
                      fileName: 'test.png',
                      onProcessed: (_) async {},
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ));
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntil(
          tester,
          () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
        );

        // Confirm and immediately tap close mid-transition. While the
        // editor route is exiting it is no longer "present" — an
        // unguarded second pop would pop the page BELOW the editor.
        await tester.tap(find.text('完成'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The exiting route is not rebuilt, so the close handler is the
        // stale closure from the last build — invoke it directly to
        // prove the runtime guard makes it a no-op.
        final closeButton = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.close),
        );
        closeButton.onPressed!.call();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The host page must still be here.
        expect(find.text('Open'), findsOneWidget);
        expect(find.byType(ExtendedImageEditorPage), findsNothing);
      });
    });
  });
}
