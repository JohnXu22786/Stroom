import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/mermaid_chart_page.dart';
import 'package:stroom/pages/text_storage_page.dart';
import 'package:stroom/providers/text_provider.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

class _GatedTextRecordsNotifier extends TextRecordsNotifier {
  final returnReloadStarted = Completer<void>();
  final finishReturnReload = Completer<void>();
  var loadCount = 0;

  @override
  Future<void> loadRecords() async {
    loadCount++;
    if (loadCount == 2) {
      returnReloadStarted.complete();
      await finishReturnReload.future;
    }
    await super.loadRecords();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.beforeFolderLoadForTesting = null;
    TextManifest.invalidateCache();
  });

  testWidgets(
    'returning from Mermaid save refreshes the newly created storage folder',
    (tester) async {
      const folderName = 'new-chart-folder';
      const originalContent = 'graph TD\n  A-->Before';
      final bytes = Uint8List.fromList(utf8.encode(originalContent));
      final hash = computeTextHash(bytes);
      final chart = TextRecord(
        id: 'existing-mermaid-chart',
        name: 'chart',
        hash: hash,
        format: 'mmd',
        createdAt: DateTime.utc(2024),
        size: bytes.length,
        textLength: originalContent.length,
      );
      await TextManifest.writeText(chart.storagePath, originalContent);
      await TextManifest.addRecord(chart);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TextStoragePage(),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(textFolderListProvider), isEmpty);
      await tester.tap(find.byKey(const Key('fm_file_existing-mermaid-chart')));
      // TextStoragePage opens Mermaid in split mode; its preview has a loading
      // animation, so advance the route transition without waiting for every
      // scheduled frame to stop.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(
        find.byType(TextField).first,
        'graph TD\n  A-->After',
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.save));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const Key('folder_picker_start_create_btn')));
      await tester.pump();
      final folderNameField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == '输入文件夹名称',
      );
      await tester.enterText(folderNameField, folderName);
      await tester.tap(
        find.byKey(const Key('folder_picker_create_confirm_btn')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(folderName), findsOneWidget);
      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      final savedChart = (await TextManifest.loadRecords()).singleWhere(
        (record) => record.id == chart.id,
      );
      expect(savedChart.folder, folderName);
      expect(await TextManifest.getAllFolders(), contains(folderName));
      expect(find.byType(MermaidChartPage), findsNothing);
      expect(container.read(textFolderListProvider), contains(folderName));
      expect(
        find.byKey(const Key('fm_folder_new-chart-folder')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('fm_folder_new-chart-folder')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const Key('fm_file_existing-mermaid-chart')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'does not read providers if Text Storage is disposed during return reload',
    (tester) async {
      const originalContent = 'graph TD\n  A-->Before';
      final bytes = Uint8List.fromList(utf8.encode(originalContent));
      final hash = computeTextHash(bytes);
      final chart = TextRecord(
        id: 'disposing-mermaid-chart',
        name: 'chart',
        hash: hash,
        format: 'mmd',
        createdAt: DateTime.utc(2024),
        size: bytes.length,
        textLength: originalContent.length,
      );
      await TextManifest.writeText(chart.storagePath, originalContent);
      await TextManifest.addRecord(chart);

      final recordsNotifier = _GatedTextRecordsNotifier();
      final container = ProviderContainer(
        overrides: [textRecordsProvider.overrideWith((ref) => recordsNotifier)],
      );
      addTearDown(() {
        if (!recordsNotifier.finishReturnReload.isCompleted) {
          recordsNotifier.finishReturnReload.complete();
        }
        container.dispose();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TextStoragePage(),
            localizationsDelegates: [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(recordsNotifier.loadCount, 1);

      await tester.tap(
        find.byKey(const Key('fm_file_disposing-mermaid-chart')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await recordsNotifier.returnReloadStarted.future;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SizedBox.shrink()),
        ),
      );
      recordsNotifier.finishReturnReload.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    },
  );
}
