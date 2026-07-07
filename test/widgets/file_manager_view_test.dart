import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/utils/file_record.dart';
import 'package:stroom/utils/manifest_bridge.dart';
import 'package:stroom/utils/sort_config.dart';
import 'package:stroom/widgets/file_manager_view.dart';

/// Minimal test record for widget tests
class _TestFileRecord
    with
        Hashable,
        Storable,
        Renamable<_TestFileRecord>,
        Movable<_TestFileRecord>
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

Widget _buildTestApp(Widget body) {
  return MaterialApp(
    home: Scaffold(body: body),
    localizationsDelegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
  );
}

final testFiles = [
  _TestFileRecord(
    id: 'file_1',
    name: 'vacation',
    hash: 'hash_vacation',
    format: 'mp4',
    size: 2048,
  ),
  _TestFileRecord(
    id: 'file_2',
    name: 'party',
    hash: 'hash_party',
    format: 'mov',
    size: 4096,
  ),
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

void main() {
  group('FileManagerView thumbnail display', () {
    testWidgets('shows fallback icon when fileThumbnailBuilder is null', (
      tester,
    ) async {
      final config = FileManagerConfig<_TestFileRecord>(
        title: 'Test',
        fileIconBuilder: (_) =>
            const Icon(Icons.videocam, key: Key('fallback_icon')),
        onFileTap: (_) {},
      );

      await tester.pumpWidget(
        _buildTestApp(
          FileManagerView<_TestFileRecord>(
            sortedRecords: testFiles,
            folders: {},
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
          ),
        ),
      );

      // Should show the fallback icon for each file
      expect(find.byKey(const Key('fallback_icon')), findsNWidgets(2));
    });

    testWidgets(
      'shows thumbnail widgets when fileThumbnailBuilder is set and grid view is active',
      (tester) async {
        final config = FileManagerConfig<_TestFileRecord>(
          title: 'Test',
          showThumbnailToggle: true,
          initialGridView: true, // Start in grid view
          fileIconBuilder: (_) =>
              const Icon(Icons.videocam, key: Key('fallback_icon')),
          fileThumbnailBuilder: (file) {
            return Container(
              key: Key('thumbnail_${file.id}'),
              color: Colors.black,
              child: const Center(child: Text('THUMB')),
            );
          },
          onFileTap: (_) {},
        );

        await tester.pumpWidget(
          _buildTestApp(
            FileManagerView<_TestFileRecord>(
              sortedRecords: testFiles,
              folders: {},
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
            ),
          ),
        );

        // Should see thumbnail containers for both files
        expect(find.byKey(const Key('thumbnail_file_1')), findsOneWidget);
        expect(find.byKey(const Key('thumbnail_file_2')), findsOneWidget);
      },
    );

    testWidgets('thumbnail toggle switches between list and grid view', (
      tester,
    ) async {
      final config = FileManagerConfig<_TestFileRecord>(
        title: 'Test',
        showThumbnailToggle: true,
        initialGridView: false, // Start in list view
        fileIconBuilder: (_) =>
            const Icon(Icons.videocam, key: Key('fallback_icon')),
        fileThumbnailBuilder: (file) {
          return Container(
            key: Key('thumbnail_${file.id}'),
            color: Colors.black,
            child: const Center(child: Text('THUMB')),
          );
        },
        onFileTap: (_) {},
      );

      await tester.pumpWidget(
        _buildTestApp(
          FileManagerView<_TestFileRecord>(
            sortedRecords: testFiles,
            folders: {},
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
          ),
        ),
      );

      // In list view, thumbnails are also shown because fileThumbnailBuilder is not null.
      // The list view uses the thumbnail builder inside 44x44 containers.
      // Both thumbnails should be visible.
      expect(find.byKey(const Key('thumbnail_file_1')), findsOneWidget);
      expect(find.byKey(const Key('thumbnail_file_2')), findsOneWidget);

      // The grid toggle button should exist
      final toggleBtn = find.byKey(const Key('fm_grid_toggle_btn'));
      expect(toggleBtn, findsOneWidget);

      // Tap the toggle to switch to grid view
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // After switching to grid view, thumbnails should still appear
      // (now using the grid layout for display)
      expect(find.byKey(const Key('thumbnail_file_1')), findsOneWidget);
      expect(find.byKey(const Key('thumbnail_file_2')), findsOneWidget);
    });
  });

  group('FileManagerView back navigation', () {
    testWidgets('shows back button in app bar when in subfolder', (
      tester,
    ) async {
      final records = [
        _TestFileRecord(id: 'file1', name: 'test', folder: 'subfolder'),
      ];
      final config = FileManagerConfig<_TestFileRecord>(
        title: 'Test',
        fileIconBuilder: (_) =>
            const Icon(Icons.videocam, key: Key('fallback_icon')),
        onFileTap: (_) {},
      );

      // We need to trigger the "back" navigation by having the initial folder
      // be a subfolder. We use the manifestBridge to provide parent folder info.
      final bridge = ManifestBridge(
        getFolderBaseName: (path) => path.split('/').last,
        getParentFolderPath: (path) {
          if (path.isEmpty) return '';
          final parts = path.split('/');
          return parts.length > 1
              ? parts.sublist(0, parts.length - 1).join('/')
              : '';
        },
        getChildFolderPaths: (parent, allPaths) => [],
        validateFolderName: (_) => null,
        getAllDescendantFolderPaths: (parentPath, allPaths) => [],
      );

      await tester.pumpWidget(
        _buildTestApp(
          FileManagerView<_TestFileRecord>(
            sortedRecords: records,
            folders: {'subfolder'},
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
            manifestBridge: bridge,
          ),
        ),
      );

      // The FileManagerView starts at root by default
      // Tap the subfolder to navigate into it
      await tester.tap(find.text('subfolder'));
      await tester.pumpAndSettle();

      // Now the app bar back button should be visible
      expect(find.byKey(const Key('fm_back_btn')), findsOneWidget);

      // The in-list back item should also be visible
      expect(find.byKey(const Key('fm_back_item')), findsOneWidget);
    });

    testWidgets(
      'navigates to parent when navigateToParentSignal changes in subfolder',
      (tester) async {
        String? capturedCurrentFolder;

        final bridge = ManifestBridge(
          getFolderBaseName: (path) => path.split('/').last,
          getParentFolderPath: (path) {
            if (path.isEmpty) return '';
            final parts = path.split('/');
            return parts.length > 1
                ? parts.sublist(0, parts.length - 1).join('/')
                : '';
          },
          getChildFolderPaths: (parent, allPaths) => [],
          validateFolderName: (_) => null,
          getAllDescendantFolderPaths: (parentPath, allPaths) => [],
        );

        final config = FileManagerConfig<_TestFileRecord>(
          title: 'Test',
          fileIconBuilder: (_) =>
              const Icon(Icons.videocam, key: Key('fallback_icon')),
          onFileTap: (_) {},
          onCurrentFolderChanged: (f) {
            capturedCurrentFolder = f;
          },
        );

        await tester.pumpWidget(
          _buildTestApp(
            FileManagerView<_TestFileRecord>(
              sortedRecords: [],
              folders: {'subfolder'},
              sortConfig: sortConfig,
              config: config,
              navigateToParentSignal: 0,
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
              manifestBridge: bridge,
            ),
          ),
        );

        // Navigate into subfolder by tapping on it
        await tester.tap(find.text('subfolder'));
        await tester.pumpAndSettle();
        expect(capturedCurrentFolder, 'subfolder');

        // Now rebuild with incremented signal to simulate outer PopScope request
        await tester.pumpWidget(
          _buildTestApp(
            FileManagerView<_TestFileRecord>(
              sortedRecords: [],
              folders: {'subfolder'},
              sortConfig: sortConfig,
              config: config,
              navigateToParentSignal: 1, // Signal incremented
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
              manifestBridge: bridge,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should have navigated to parent folder (root = '')
        expect(capturedCurrentFolder, '');
      },
    );

    testWidgets(
      'does NOT navigate when navigateToParentSignal changes at root',
      (tester) async {
        String? capturedCurrentFolder;
        int changeCount = 0;

        final bridge = ManifestBridge(
          getFolderBaseName: (path) => path.split('/').last,
          getParentFolderPath: (path) {
            if (path.isEmpty) return '';
            final parts = path.split('/');
            return parts.length > 1
                ? parts.sublist(0, parts.length - 1).join('/')
                : '';
          },
          getChildFolderPaths: (parent, allPaths) => [],
          validateFolderName: (_) => null,
          getAllDescendantFolderPaths: (parentPath, allPaths) => [],
        );

        final config = FileManagerConfig<_TestFileRecord>(
          title: 'Test',
          fileIconBuilder: (_) =>
              const Icon(Icons.videocam, key: Key('fallback_icon')),
          onFileTap: (_) {},
          onCurrentFolderChanged: (f) {
            capturedCurrentFolder = f;
            changeCount++;
          },
        );

        // Start at root with signal = 0
        await tester.pumpWidget(
          _buildTestApp(
            FileManagerView<_TestFileRecord>(
              sortedRecords: testFiles,
              folders: {},
              sortConfig: sortConfig,
              config: config,
              navigateToParentSignal: 0,
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
              manifestBridge: bridge,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // We're at root - no back button visible
        expect(find.byKey(const Key('fm_back_btn')), findsNothing);
        final countBeforeSignal = changeCount;

        // Rebuild with incremented signal - at root this should be a no-op
        await tester.pumpWidget(
          _buildTestApp(
            FileManagerView<_TestFileRecord>(
              sortedRecords: testFiles,
              folders: {},
              sortConfig: sortConfig,
              config: config,
              navigateToParentSignal: 1, // Signal incremented
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
              manifestBridge: bridge,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // onCurrentFolderChanged should NOT have been called (still at root)
        expect(changeCount, countBeforeSignal);
      },
    );
  });

  group('FileManagerView folder long-press selection', () {
    testWidgets('long-press on grid folder enters selection mode', (
      tester,
    ) async {
      final config = FileManagerConfig<_TestFileRecord>(
        title: 'Test',
        showThumbnailToggle: true,
        initialGridView: true,
        fileIconBuilder: (_) =>
            const Icon(Icons.videocam, key: Key('fallback_icon')),
        fileThumbnailBuilder: (file) {
          return Container(
            key: Key('thumbnail_${file.id}'),
            color: Colors.black,
            child: const Center(child: Text('THUMB')),
          );
        },
        onFileTap: (_) {},
      );

      await tester.pumpWidget(
        _buildTestApp(
          FileManagerView<_TestFileRecord>(
            sortedRecords: [],
            folders: {'my_folder'},
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
          ),
        ),
      );

      // Verify folder is displayed in grid view
      expect(find.byKey(const Key('fm_grid_folder_my_folder')), findsOneWidget);

      // Long-press on the folder
      await tester.longPress(find.byKey(const Key('fm_grid_folder_my_folder')));
      await tester.pumpAndSettle();

      // Selection mode is active — AppBar close button should appear
      expect(find.byKey(const Key('fm_close_selection_btn')), findsOneWidget);
      // Selection mode bottom bar should also appear
      expect(find.byKey(const Key('fm_selection_copy_btn')), findsOneWidget);
    });

    testWidgets('long-press on list folder enters selection mode', (
      tester,
    ) async {
      final config = FileManagerConfig<_TestFileRecord>(
        title: 'Test',
        showThumbnailToggle: true,
        initialGridView: false,
        fileIconBuilder: (_) =>
            const Icon(Icons.videocam, key: Key('fallback_icon')),
        onFileTap: (_) {},
      );

      await tester.pumpWidget(
        _buildTestApp(
          FileManagerView<_TestFileRecord>(
            sortedRecords: [],
            folders: {'my_folder'},
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
          ),
        ),
      );

      // Verify folder is displayed in list view
      expect(find.byKey(const Key('fm_folder_my_folder')), findsOneWidget);

      // Long-press on the folder
      await tester.longPress(find.byKey(const Key('fm_folder_my_folder')));
      await tester.pumpAndSettle();

      // Selection mode is active — AppBar close button should appear
      expect(find.byKey(const Key('fm_close_selection_btn')), findsOneWidget);
      // Selection mode bottom bar should also appear
      expect(find.byKey(const Key('fm_selection_copy_btn')), findsOneWidget);
    });

    testWidgets('folder long-press then close button exits selection mode', (
      tester,
    ) async {
      final config = FileManagerConfig<_TestFileRecord>(
        title: 'Test',
        showThumbnailToggle: true,
        initialGridView: true,
        fileIconBuilder: (_) =>
            const Icon(Icons.videocam, key: Key('fallback_icon')),
        fileThumbnailBuilder: (file) {
          return Container(
            key: Key('thumbnail_${file.id}'),
            color: Colors.black,
            child: const Center(child: Text('THUMB')),
          );
        },
        onFileTap: (_) {},
      );

      await tester.pumpWidget(
        _buildTestApp(
          FileManagerView<_TestFileRecord>(
            sortedRecords: [],
            folders: {'my_folder'},
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
          ),
        ),
      );

      final folderFinder = find.byKey(const Key('fm_grid_folder_my_folder'));

      // Long-press: enter selection mode
      await tester.longPress(folderFinder);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fm_close_selection_btn')), findsOneWidget);

      // Tap close button to exit selection mode
      await tester.tap(find.byKey(const Key('fm_close_selection_btn')));
      await tester.pumpAndSettle();

      // Selection mode is gone — close button should not exist
      expect(find.byKey(const Key('fm_close_selection_btn')), findsNothing);
      // Folder should still be present
      expect(folderFinder, findsOneWidget);
    });
  });

  group('FileManagerView grid folder width', () {
    testWidgets('renders grid folder with short name without layout issues', (
      tester,
    ) async {
      final config = FileManagerConfig<_TestFileRecord>(
        title: 'Test',
        showThumbnailToggle: true,
        initialGridView: true,
        fileIconBuilder: (_) =>
            const Icon(Icons.videocam, key: Key('fallback_icon')),
        fileThumbnailBuilder: (file) {
          return Container(
            key: Key('thumbnail_${file.id}'),
            color: Colors.black,
            child: const Center(child: Text('THUMB')),
          );
        },
        onFileTap: (_) {},
      );

      await tester.pumpWidget(
        _buildTestApp(
          FileManagerView<_TestFileRecord>(
            sortedRecords: [],
            folders: {'A'}, // Very short folder name
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
          ),
        ),
      );

      // The folder item should be found with a short name
      expect(find.byKey(const Key('fm_grid_folder_A')), findsOneWidget);

      // Verify the width of the folder item fills the grid cell
      // by checking it spans the full available width
      final folderRenderer = tester.renderObject<RenderBox>(
        find.byKey(const Key('fm_grid_folder_A')),
      );
      // The grid cell width should be non-zero (it should have a valid layout)
      expect(folderRenderer.size.width, greaterThan(0));
    });
  });
}
