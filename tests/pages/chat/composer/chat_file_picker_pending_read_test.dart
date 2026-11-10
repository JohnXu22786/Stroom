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

Widget _buildTestApp(
  ValueChanged<List<MapEntry<String, Uint8List>>?> onPickerResult,
) {
  return MaterialApp(
    locale: const Locale('en', 'US'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
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
