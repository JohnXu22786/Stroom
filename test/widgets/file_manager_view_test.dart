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
  }) : id = id ?? 'file_${DateTime.now().millisecondsSinceEpoch}',
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
    return parts.length > 1 ? parts.sublist(0, -1).join('/') : '';
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
          return parts.length > 1 ? parts.sublist(0, -1).join('/') : '';
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

    testWidgets('calls onBackToParent when system back pressed in subfolder', (
      tester,
    ) async {
      int backToParentCallCount = 0;

      final bridge = ManifestBridge(
        getFolderBaseName: (path) => path.split('/').last,
        getParentFolderPath: (path) {
          if (path.isEmpty) return '';
          final parts = path.split('/');
          return parts.length > 1 ? parts.sublist(0, -1).join('/') : '';
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
        onBackToParent: () {
          backToParentCallCount++;
        },
      );

      // Create a navigator key so we can simulate system back
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            key: navKey,
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: FileManagerView<_TestFileRecord>(
                    sortedRecords: [],
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
                settings: settings,
              );
            },
          ),
          localizationsDelegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
        ),
      );

      // Navigate into subfolder by tapping on it
      await tester.tap(find.text('subfolder'));
      await tester.pumpAndSettle();

      // Verify we're inside the subfolder (back button visible)
      expect(find.byKey(const Key('fm_back_btn')), findsOneWidget);

      // Simulate system back
      await navKey.currentState?.maybePop();
      await tester.pumpAndSettle();

      // onBackToParent should have been called
      expect(backToParentCallCount, greaterThanOrEqualTo(1));
    });

    testWidgets(
      'does NOT call onBackToParent when at root and system back pressed',
      (tester) async {
        int backToParentCallCount = 0;

        final bridge = ManifestBridge(
          getFolderBaseName: (path) => path.split('/').last,
          getParentFolderPath: (path) {
            if (path.isEmpty) return '';
            final parts = path.split('/');
            return parts.length > 1 ? parts.sublist(0, -1).join('/') : '';
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
          onBackToParent: () {
            backToParentCallCount++;
          },
        );

        final navKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Navigator(
              key: navKey,
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (_) => Scaffold(
                    body: FileManagerView<_TestFileRecord>(
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
                      manifestBridge: bridge,
                    ),
                  ),
                  settings: settings,
                );
              },
            ),
            localizationsDelegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
          ),
        );

        // We're at root - no back button visible
        expect(find.byKey(const Key('fm_back_btn')), findsNothing);

        // Simulate system back
        await navKey.currentState?.maybePop();
        await tester.pumpAndSettle();

        // onBackToParent should NOT have been called (we're at root)
        expect(backToParentCallCount, 0);
      },
    );
  });
}
