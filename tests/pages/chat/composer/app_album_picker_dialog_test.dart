import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/gallery_choice_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/chat/composer/album_picker_shared.dart';
import 'package:stroom/pages/chat/composer/chat_album_picker_dialog.dart';
import 'package:stroom/pages/extended_image_editor_page.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/image_manifest.dart';
import 'package:stroom/providers/image_provider.dart';

class _FailOnceImageRecordsNotifier extends ImageRecordsNotifier {
  bool _failNext = true;

  @override
  Future<void> loadRecords() async {
    if (_failNext) {
      _failNext = false;
      throw StateError('simulated records load failure');
    }
    await super.loadRecords();
  }
}

class _FailOnceImageFolderListNotifier extends ImageFolderListNotifier {
  bool _failNext = true;

  @override
  Future<void> loadFolders() async {
    if (_failNext) {
      _failNext = false;
      throw StateError('simulated folders load failure');
    }
    await super.loadFolders();
  }
}

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
  testWidgets('gallery source choice uses localized labels', (tester) async {
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: const Locale('en', 'US'),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showGalleryChoiceDialog(context),
          child: const Text('Choose source'),
        ),
      ),
    ));
    await tester.tap(find.text('Choose source'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an image source'), findsOneWidget);
    expect(find.text('Device gallery'), findsOneWidget);
    expect(find.text('App gallery'), findsOneWidget);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    ImageManifest.invalidateCache();
    beforeAppAlbumPickerReadForTesting = null;
  });

  tearDown(() {
    beforeAppAlbumPickerReadForTesting = null;
  });

  Future<
      ({
        List<MapEntry<String, Uint8List>>? Function() result,
      })> openPickerWithLoadFailure(
    WidgetTester tester, {
    required bool failRecords,
  }) async {
    List<MapEntry<String, Uint8List>>? pickerResult;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageRecordsProvider.overrideWith(
            (ref) => failRecords
                ? _FailOnceImageRecordsNotifier()
                : ImageRecordsNotifier(),
          ),
          imageFolderListProvider.overrideWith(
            (ref) => failRecords
                ? ImageFolderListNotifier()
                : _FailOnceImageFolderListNotifier(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                pickerResult = await showAppAlbumPickerDialog(context);
              },
              child: const Text('Open Album'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Album'));
    await tester.pump();
    await _pumpUntil(
      tester,
      () =>
          find.byKey(const Key('album_picker_retry_btn')).evaluate().isNotEmpty,
    );
    return (result: () => pickerResult);
  }

  group('AppAlbumPickerDialog initial load failures', () {
    for (final failure in ['records', 'folders']) {
      testWidgets(
        '$failure load failure is distinct from an empty album and can retry',
        (tester) async {
          final picker = await openPickerWithLoadFailure(
            tester,
            failRecords: failure == 'records',
          );

          expect(find.text('加载应用内相册失败'), findsOneWidget);
          expect(find.text('暂无图片'), findsNothing);
          final confirm = tester.widget<FilledButton>(
            find.byKey(const Key('album_picker_confirm_btn')),
          );
          expect(confirm.onPressed, isNull);

          await tester.tap(find.byKey(const Key('album_picker_retry_btn')));
          await _pumpUntil(
            tester,
            () => find.text('暂无图片').evaluate().isNotEmpty,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const Key('album_picker_confirm_btn')),
                )
                .onPressed,
            isNotNull,
          );

          await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
          await _pumpUntil(tester, () => picker.result() != null);
          expect(picker.result(), isEmpty);
        },
      );
    }
  });

  Future<
      ({
        Completer<void> readStarted,
        Completer<void> releaseRead,
        Completer<void> replacementReadStarted,
        Completer<void> releaseReplacementRead,
        List<MapEntry<String, Uint8List>>? Function() result,
      })> openPickerWithBlockedRead(
    WidgetTester tester, {
    bool failRead = false,
    bool includeReplacement = false,
    bool blockReplacementRead = false,
    Locale locale = const Locale('zh', 'CN'),
  }) async {
    final png = await tester.runAsync(_createEnginePng);
    await tester.runAsync(() async {
      await ImageManifest.writeFile('pending-read.png', png!);
      await ImageManifest.addRecord(
        ImageRecord(
          id: 'pending-read',
          name: 'pending-read',
          hash: 'pending-read',
          format: 'png',
          createdAt: DateTime.now(),
          size: png.length,
          folder: '',
        ),
      );
      if (includeReplacement) {
        await ImageManifest.writeFile('replacement-read.png', png);
        await ImageManifest.addRecord(
          ImageRecord(
            id: 'replacement-read',
            name: 'replacement-read',
            hash: 'replacement-read',
            format: 'png',
            createdAt: DateTime.now(),
            size: png.length,
            folder: '',
          ),
        );
      }
    });

    List<MapEntry<String, Uint8List>>? pickerResult;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                pickerResult = await showAppAlbumPickerDialog(context);
              },
              child: const Text('Open Album'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Album'));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.text('pending-read.png').evaluate().isNotEmpty,
    );

    final readStarted = Completer<void>();
    final releaseRead = Completer<void>();
    final replacementReadStarted = Completer<void>();
    final releaseReplacementRead = Completer<void>();
    beforeAppAlbumPickerReadForTesting = (fileName) async {
      if (fileName == 'pending-read.png' && !readStarted.isCompleted) {
        readStarted.complete();
        await releaseRead.future;
        if (failRead) throw StateError('simulated image read failure');
      } else if (fileName == 'replacement-read.png') {
        replacementReadStarted.complete();
        if (blockReplacementRead) await releaseReplacementRead.future;
      }
    };
    await tester.tap(find.text('pending-read.png'));
    await tester.pump();
    expect(
      readStarted.isCompleted,
      isTrue,
      reason: 'the selection read should be paused deterministically',
    );

    return (
      readStarted: readStarted,
      releaseRead: releaseRead,
      replacementReadStarted: replacementReadStarted,
      releaseReplacementRead: releaseReplacementRead,
      result: () => pickerResult,
    );
  }

  group('AppAlbumPickerDialog pending-read lifecycle', () {
    testWidgets(
      'preview and confirmation preserve tap order when reads complete '
      'in reverse',
      (tester) async {
        final png = await tester.runAsync(_createEnginePng);
        await tester.runAsync(() async {
          for (final name in ['tap-first', 'tap-second']) {
            await ImageManifest.writeFile('$name-hash.png', png!);
            await ImageManifest.addRecord(
              ImageRecord(
                id: name,
                name: name,
                hash: '$name-hash',
                format: 'png',
                createdAt: DateTime.now(),
                size: png.length,
                folder: '',
              ),
            );
          }
        });

        List<MapEntry<String, Uint8List>>? pickerResult;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('zh', 'CN'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    pickerResult = await showAppAlbumPickerDialog(context);
                  },
                  child: const Text('Open Album'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open Album'));
        await tester.pump();
        await _pumpUntil(
          tester,
          () =>
              find.text('tap-first.png').evaluate().isNotEmpty &&
              find.text('tap-second.png').evaluate().isNotEmpty,
        );

        final readStarted = {
          'tap-first-hash.png': Completer<void>(),
          'tap-second-hash.png': Completer<void>(),
        };
        final releaseRead = {
          'tap-first-hash.png': Completer<void>(),
          'tap-second-hash.png': Completer<void>(),
        };
        beforeAppAlbumPickerReadForTesting = (fileName) async {
          readStarted[fileName]!.complete();
          await releaseRead[fileName]!.future;
        };

        await tester.tap(find.text('tap-first.png'));
        await tester.pump();
        await tester.tap(find.text('tap-second.png'));
        await tester.pump();
        expect(
          readStarted.values.every((started) => started.isCompleted),
          isTrue,
        );

        releaseRead['tap-second-hash.png']!.complete();
        await _pumpUntil(
          tester,
          () => find.byType(AlbumPreviewChip).evaluate().length == 1,
        );
        expect(
          tester
              .widget<AlbumPreviewChip>(find.byType(AlbumPreviewChip))
              .fileName,
          'tap-second.png',
        );

        releaseRead['tap-first-hash.png']!.complete();
        await _pumpUntil(
          tester,
          () => find.byType(AlbumPreviewChip).evaluate().length == 2,
        );
        expect(
          tester
              .widgetList<AlbumPreviewChip>(find.byType(AlbumPreviewChip))
              .map((chip) => chip.fileName),
          ['tap-first.png', 'tap-second.png'],
        );

        await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
        await _pumpUntil(tester, () => pickerResult != null);
        expect(
          pickerResult!.map((entry) => entry.key),
          ['tap-first.png', 'tap-second.png'],
        );
      },
    );

    testWidgets('confirm waits for a pending selection and returns its image', (
      tester,
    ) async {
      final picker = await openPickerWithBlockedRead(tester);

      expect(find.text('已选择 1 张图片'), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
      await tester.pump();
      expect(
        find.text('应用内相册'),
        findsOneWidget,
        reason: 'confirm must not close while the selected file is unread',
      );
      expect(picker.result(), isNull);

      picker.releaseRead.complete();
      await _pumpUntil(tester, () => picker.result() != null);
      expect(picker.result()!.single.key, 'pending-read.png');
      expect(picker.result()!.single.value, isNotEmpty);
    });

    testWidgets(
      'clearing cancels confirmation while a selection read is pending',
      (tester) async {
        final picker = await openPickerWithBlockedRead(tester);

        await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
        await tester.pump();
        expect(picker.result(), isNull);

        await tester.tap(find.byKey(const Key('album_picker_clear_btn')));
        await tester.pump();
        expect(
          find.text('应用内相册'),
          findsOneWidget,
          reason:
              'clearing the pending selection must cancel its confirmation',
        );
        expect(picker.result(), isNull);

        picker.releaseRead.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(picker.result(), isNull);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'failed read during confirmation keeps picker open for replacement',
      (tester) async {
        final picker = await openPickerWithBlockedRead(
          tester,
          failRead: true,
          includeReplacement: true,
        );

        await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
        await tester.pump();
        expect(picker.result(), isNull);

        picker.releaseRead.complete();
        await _pumpUntil(
          tester,
          () => find.text('无法读取文件').evaluate().isNotEmpty,
        );
        expect(
          find.text('应用内相册'),
          findsOneWidget,
          reason:
              'a failed pending read must cancel confirmation, not return an empty list',
        );
        expect(picker.result(), isNull);

        await tester.tap(find.text('replacement-read.png'));
        await _pumpUntil(
          tester,
          () => find.byType(AlbumPreviewChip).evaluate().isNotEmpty,
        );
        await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
        await _pumpUntil(tester, () => picker.result() != null);

        expect(picker.result()!.single.key, 'replacement-read.png');
        expect(picker.result()!.single.value, isNotEmpty);
      },
    );

    testWidgets(
      'clearing after a failed read still confirms an empty selection',
      (tester) async {
        final picker = await openPickerWithBlockedRead(
          tester,
          failRead: true,
          includeReplacement: true,
          blockReplacementRead: true,
        );

        await tester.tap(find.text('replacement-read.png'));
        await tester.pump();
        expect(picker.replacementReadStarted.isCompleted, isTrue);
        await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
        await tester.pump();

        picker.releaseRead.complete();
        await _pumpUntil(
          tester,
          () => find.text('无法读取文件').evaluate().isNotEmpty,
        );
        expect(picker.result(), isNull);

        await tester.tap(find.byKey(const Key('album_picker_clear_btn')));
        await _pumpUntil(tester, () => picker.result() != null);
        expect(picker.result(), isEmpty);

        picker.releaseReplacementRead.complete();
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('confirm resumes when its pending selection is toggled off', (
      tester,
    ) async {
      final picker = await openPickerWithBlockedRead(tester);

      await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
      await tester.pump();
      expect(picker.result(), isNull);

      await tester.tap(find.text('pending-read.png'));
      await tester.pump();
      await _pumpUntil(tester, () => picker.result() != null);
      expect(picker.result(), isEmpty);

      picker.releaseRead.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('clearing while a read is pending ignores its late result', (
      tester,
    ) async {
      final picker = await openPickerWithBlockedRead(tester);

      await tester.tap(find.byKey(const Key('album_picker_clear_btn')));
      await tester.pump();
      picker.releaseRead.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('album_picker_preview_bar')), findsNothing);
      expect(find.byKey(const Key('album_picker_clear_btn')), findsNothing);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isFalse,
      );
    });

    testWidgets(
      'toggling off a pending read stays deselected after completion',
      (tester) async {
        final picker = await openPickerWithBlockedRead(tester);

        await tester.tap(find.text('pending-read.png'));
        await tester.pump();
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox).first).value,
          isFalse,
        );
        picker.releaseRead.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byKey(const Key('album_picker_preview_bar')), findsNothing);
        expect(
          tester.widget<Checkbox>(find.byType(Checkbox).first).value,
          isFalse,
        );
      },
    );

    testWidgets('closing during a read does not update disposed state', (
      tester,
    ) async {
      final picker = await openPickerWithBlockedRead(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      picker.releaseRead.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(picker.result(), isNull);
    });
  });

  group('AppAlbumPickerDialog localization', () {
    for (final (locale, title, confirm, unreadable) in [
      (
        const Locale('en', 'US'),
        'App album',
        'Done',
        'Could not read file',
      ),
      (
        const Locale('zh', 'CN'),
        '应用内相册',
        '确定',
        '无法读取文件',
      ),
    ]) {
      testWidgets('$locale localizes picker chrome and read errors', (
        tester,
      ) async {
        final picker = await openPickerWithBlockedRead(
          tester,
          failRead: true,
          locale: locale,
        );

        expect(find.text(title), findsOneWidget);
        expect(find.textContaining(confirm), findsOneWidget);

        picker.releaseRead.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text(unreadable), findsOneWidget);
        expect(find.text('pending-read.png'), findsOneWidget,
            reason: 'the picker must keep the original filename visible');
      });
    }
  });

  // ====================================================================
  // Quick-edit flow: the editor processes the image in place (the page
  // stays open while processing) and the selection is updated with the
  // edited bytes once it pops.
  // ====================================================================
  group('AppAlbumPickerDialog quick-edit flow', () {
    testWidgets(
        'the quick editor processes in place, then the selection holds '
        'the edited bytes', (tester) async {
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

      List<MapEntry<String, Uint8List>>? pickerResult;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    pickerResult = await showAppAlbumPickerDialog(context);
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
      final originalChipBytes =
          tester.widget<AlbumPreviewChip>(find.byType(AlbumPreviewChip)).bytes;

      // Preview chip → preview dialog → quick editor.
      await tester.tap(find.byType(AlbumPreviewChip));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.crop));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Wait for the editor image to decode (engine work — real async).
      await _pumpUntil(
        tester,
        () => find.byType(ExtendedImageEditor).evaluate().isNotEmpty,
      );

      // Confirm the edit — the editor must NOT close immediately: it
      // processes the image in place with a spinner until the pipeline
      // finishes.
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ExtendedImageEditorPage), findsOneWidget,
          reason: 'the editor must stay on screen while processing');
      expect(
        find.descendant(
          of: find.byType(ExtendedImageEditorPage),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
        reason: 'a processing spinner must be visible',
      );

      // Only after the pipeline finishes does the editor pop back to the
      // picker.
      await _pumpUntil(
        tester,
        () => find.byType(ExtendedImageEditorPage).evaluate().isEmpty,
      );

      // The selection now holds the edited bytes — the preview chip
      // shows a NEW bytes instance.
      await _pumpUntil(
        tester,
        () =>
            tester
                .widget<AlbumPreviewChip>(find.byType(AlbumPreviewChip))
                .bytes !=
            originalChipBytes,
      );

      // Confirming returns the edited bytes.
      await tester.tap(find.byKey(const Key('album_picker_confirm_btn')));
      await tester.pump();
      expect(pickerResult, isNotNull);
      expect(pickerResult!.single.value, isNot(same(originalChipBytes)),
          reason: 'the confirmed selection must hold the edited bytes');
    });
  });
}
