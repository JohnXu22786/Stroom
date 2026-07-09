import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/file_record.dart';
import 'package:stroom/utils/manifest_bridge.dart';
import 'package:stroom/utils/sort_config.dart';
import 'package:stroom/widgets/file_manager_view.dart';

/// Minimal test record for widget tests
class _TestFileRecord
    with Hashable, Storable, Renamable<_TestFileRecord>, Movable<_TestFileRecord>
    implements FileRecord {
  @override
  final String id;
  @override
  final String name;
  @override
  final String hash;
  @override
  final String format;
  @override
  final DateTime createdAt;
  @override
  final int size;
  @override
  final String folder;

  _TestFileRecord({
    String? id,
    this.name = 'test',
    this.hash = 'test_hash',
    this.format = 'mp4',
    DateTime? createdAt,
    this.size = 1024,
    this.folder = '',
  })  : id = id ?? 'file_${DateTime.now().millisecondsSinceEpoch}',
        createdAt = createdAt ?? DateTime.now();

  @override
  String get storagePath => '$hash.$format';

  @override
  _TestFileRecord copyWithName(String name) => _TestFileRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        size: size,
        folder: folder,
      );

  @override
  _TestFileRecord copyWithFolder(String folder) => _TestFileRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        size: size,
        folder: folder,
      );
}

Widget _buildTestApp(Widget body, {double screenWidth = 800}) {
  return MediaQuery(
    data: MediaQueryData(size: Size(screenWidth, 600)),
    child: MaterialApp(
      home: Scaffold(body: body),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

final testFiles = [
  _TestFileRecord(id: 'file_1', name: 'test1', hash: 'h1', format: 'mp4'),
  _TestFileRecord(id: 'file_2', name: 'test2', hash: 'h2', format: 'mov'),
];

final sortConfig = SortConfig(
  field: SortField.name,
  order: SortOrder.ascending,
);

ManifestBridge get testManifestBridge => ManifestBridge(
      getFolderBaseName: (path) => path.split('/').last,
      getParentFolderPath: (path) {
        final parts = path.split('/');
        return parts.length > 1
            ? parts.sublist(0, parts.length - 1).join('/')
            : '';
      },
      getChildFolderPaths: (parent, allPaths) => [],
      validateFolderName: (_) => null,
      getAllDescendantFolderPaths: (parentPath, allPaths) => [],
    );

/// Helper to create a FileManagerView for widget tests.
FileManagerView<_TestFileRecord> _buildFileManagerView({
  int tabResetSignal = 0,
  Set<String> folders = const {},
}) {
  final config = FileManagerConfig<_TestFileRecord>(
    title: 'Test',
    fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
    onFileTap: (_) {},
  );

  return FileManagerView<_TestFileRecord>(
    tabResetSignal: tabResetSignal,
    sortedRecords: testFiles,
    folders: folders,
    sortConfig: sortConfig,
    config: config,
    onRefresh: () async {},
    onRenameFile: (_, __) async {},
    onMoveFile: (_, __) async {},
    onCopyFile: (_, __) async {},
    onDeleteFile: (_) async {},
    onDeleteFiles: (_) async {},
    onDeleteFolders: (_) async {},
    onMoveFiles: (_, __) async {},
    onMoveFolders: (_, __) async {},
    onExportFile: (_) async {},
    onRenameFolder: (_, __) async {},
    onMoveFolder: (_, __) async {},
    onCopyFolder: (_, __) async {},
    onDeleteFolder: (_) async {},
    onCreateFolder: (_) async {},
    onToggleSort: (_) {},
    manifestBridge: testManifestBridge,
  );
}

void main() {
  group('Selection bottom bar label visibility', () {
    testWidgets('hides labels on small screens (<400dp)', (tester) async {
      // Set screen width to 360dp (small phone)
      await tester.pumpWidget(
        _buildTestApp(
          _buildFileManagerView(),
          screenWidth: 360,
        ),
      );

      // Enter selection mode by long-pressing a file
      final fileItem = find.byKey(const Key('fm_file_file_1'));
      await tester.longPress(fileItem);
      await tester.pumpAndSettle();

      // The selection action bar should be visible
      expect(find.byKey(const Key('fm_selection_copy_btn')), findsOneWidget);
      expect(find.byKey(const Key('fm_selection_move_btn')), findsOneWidget);
      expect(find.byKey(const Key('fm_selection_export_btn')), findsOneWidget);
      expect(find.byKey(const Key('fm_selection_delete_btn')), findsOneWidget);

      // On small screen, the labels should NOT be visible
      expect(find.text('复制'), findsNothing);
      expect(find.text('移动'), findsNothing);
      expect(find.text('导出'), findsNothing);
      expect(find.text('删除'), findsNothing);
    });

    testWidgets('shows labels on large screens (>=400dp)', (tester) async {
      // Set screen width to 800dp (large screen)
      await tester.pumpWidget(
        _buildTestApp(
          _buildFileManagerView(),
          screenWidth: 800,
        ),
      );

      // Enter selection mode by long-pressing a file
      final fileItem = find.byKey(const Key('fm_file_file_1'));
      await tester.longPress(fileItem);
      await tester.pumpAndSettle();

      // On large screen, the labels should be visible
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('移动'), findsOneWidget);
      expect(find.text('导出'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('buttons still work when labels are hidden on small screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          _buildFileManagerView(),
          screenWidth: 360,
        ),
      );

      // Enter selection mode
      final fileItem = find.byKey(const Key('fm_file_file_1'));
      await tester.longPress(fileItem);
      await tester.pumpAndSettle();

      // Verify buttons are tappable (just checking they exist)
      expect(find.byKey(const Key('fm_selection_copy_btn')), findsOneWidget);
      expect(find.byKey(const Key('fm_selection_move_btn')), findsOneWidget);
      expect(find.byKey(const Key('fm_selection_export_btn')), findsOneWidget);
      expect(find.byKey(const Key('fm_selection_delete_btn')), findsOneWidget);
    });
  });

  group('tabResetSignal feature', () {
    /// Create a [FileManagerView] with a file inside a subfolder so that
    /// entering the folder shows content (and the back-item is rendered).
    FileManagerView<_TestFileRecord> _buildWithFilesAndFolders({
      required int signal,
      required Set<String> folders,
      required List<_TestFileRecord> records,
    }) {
      final config = FileManagerConfig<_TestFileRecord>(
        title: 'Test',
        fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
        onFileTap: (_) {},
      );
      return FileManagerView<_TestFileRecord>(
        tabResetSignal: signal,
        sortedRecords: records,
        folders: folders,
        sortConfig: sortConfig,
        config: config,
        onRefresh: () async {},
        onRenameFile: (_, __) async {},
        onMoveFile: (_, __) async {},
        onCopyFile: (_, __) async {},
        onDeleteFile: (_) async {},
        onDeleteFiles: (_) async {},
        onDeleteFolders: (_) async {},
        onMoveFiles: (_, __) async {},
        onMoveFolders: (_, __) async {},
        onExportFile: (_) async {},
        onRenameFolder: (_, __) async {},
        onMoveFolder: (_, __) async {},
        onCopyFolder: (_, __) async {},
        onDeleteFolder: (_) async {},
        onCreateFolder: (_) async {},
        onToggleSort: (_) {},
        manifestBridge: testManifestBridge,
      );
    }

    Widget _buildWithSignal(int signal, Set<String> folders,
        [List<_TestFileRecord>? records]) {
      return _buildTestApp(
        _buildWithFilesAndFolders(
          signal: signal,
          folders: folders,
          records: records ?? <_TestFileRecord>[],
        ),
      );
    }

    testWidgets('tabResetSignal resets folder to root when changed', (
      tester,
    ) async {
      const folders = {'MyFolder'};
      // Add a file inside MyFolder so the folder is NOT empty
      final recordsWithFolder = [
        _TestFileRecord(
          id: 'file_in_folder',
          name: 'inner_file',
          hash: 'h3',
          format: 'txt',
          folder: 'MyFolder',
        ),
        ...testFiles,
      ];

      // Initial render — folder at root, signal = 0
      await tester.pumpWidget(
        KeyedSubtree(
          key: const Key('fm_view_key'),
          child: _buildWithSignal(0, folders, recordsWithFolder),
        ),
      );

      // Navigate into the folder
      final folderFinder = find.byKey(const Key('fm_folder_MyFolder'));
      expect(folderFinder, findsOneWidget);
      await tester.tap(folderFinder);
      await tester.pumpAndSettle();

      // Inside the folder — back-item should appear
      expect(
        find.byKey(const Key('fm_back_item')),
        findsOneWidget,
        reason: 'Should see back item after navigating into folder',
      );

      // Rebuild with the same key but signal = 1 — this triggers didUpdateWidget
      await tester.pumpWidget(
        KeyedSubtree(
          key: const Key('fm_view_key'),
          child: _buildWithSignal(1, folders, recordsWithFolder),
        ),
      );
      await tester.pumpAndSettle();

      // Should now be back at root — folder item visible again
      expect(
        find.byKey(const Key('fm_folder_MyFolder')),
        findsOneWidget,
        reason: 'After reset to root, MyFolder should be visible again',
      );
    });

    testWidgets('tabResetSignal does nothing when already at root', (
      tester,
    ) async {
      const folders = {'MyFolder'};

      await tester.pumpWidget(
        KeyedSubtree(
          key: const Key('fm_view_key'),
          child: _buildWithSignal(0, folders),
        ),
      );

      // At root — folder visible
      expect(find.byKey(const Key('fm_folder_MyFolder')), findsOneWidget);

      // Rebuild with signal = 1 while still at root
      await tester.pumpWidget(
        KeyedSubtree(
          key: const Key('fm_view_key'),
          child: _buildWithSignal(1, folders),
        ),
      );
      await tester.pumpAndSettle();

      // Folder still at root
      expect(find.byKey(const Key('fm_folder_MyFolder')), findsOneWidget);
    });
  });
}
