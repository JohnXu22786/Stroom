import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/files_page.dart';
import 'package:stroom/pages/files_page_shared.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: FilesPage(),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

TextRecord _record(String name, String hash, {String folder = ''}) {
  return TextRecord(
    name: name,
    hash: hash,
    createdAt: DateTime(2026, 1, 1),
    size: 10,
    folder: folder,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('files refresh signal', () {
    testWidgets(
        're-entering files page (refresh signal) keeps the open folder level',
        (tester) async {
      // Seed a record inside a folder so the folder tile shows at root.
      await TextManifest.addRecord(_record('note_in_folder', 'hash1',
          folder: 'subfolder'));

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TabBar)),
      );

      // Open the folder from the root.
      await tester.tap(find.text('subfolder'));
      await tester.pumpAndSettle();
      expect(container.read(filesPageCurrentFolderProvider), 'subfolder');

      // Simulate what the bottom navigation does when re-entering the
      // files page: increment the auto-refresh signal.
      container.read(filesRefreshSignalProvider.notifier).state++;
      await tester.pumpAndSettle();

      // The open folder must be preserved — this is the regression:
      // previously the signal changed the sub-page ValueKeys, recreating
      // the pages and resetting the folder to root.
      expect(
        container.read(filesPageCurrentFolderProvider),
        'subfolder',
        reason: 'refresh signal must not reset the open folder to root',
      );
      expect(find.text('note_in_folder.txt'), findsOneWidget,
          reason: 'folder contents should still be shown after refresh');
    });

    testWidgets('refresh signal still reloads newly added files',
        (tester) async {
      await TextManifest.addRecord(_record('old_doc', 'hash2'));

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('old_doc.txt'), findsOneWidget);

      // A file is added from another page while the files page is mounted.
      await TextManifest.addRecord(_record('new_doc', 'hash3'));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TabBar)),
      );
      container.read(filesRefreshSignalProvider.notifier).state++;
      await tester.pumpAndSettle();

      expect(find.text('new_doc.txt'), findsOneWidget,
          reason: 'refresh signal must still reload file data');
    });
  });
}
