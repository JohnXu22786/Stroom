// Merged from:
//   - file_manager_view_test.dart
//   - file_manager_back_navigation_test.dart
//   - file_preview_test.dart
//   - file_preview_chip_test.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/files_page_shared.dart';
import 'package:stroom/utils/file_record.dart';
import 'package:stroom/utils/manifest_bridge.dart';
import 'package:stroom/utils/sort_config.dart';
import 'package:stroom/widgets/file_manager_view.dart';
import 'package:stroom/widgets/file_preview.dart';

// =============================================================================
// Test fixtures shared by file_manager_view_test.dart and
// file_manager_back_navigation_test.dart
// =============================================================================

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

/// Used by file_manager_view_test.dart style tests (a getter returning a new
/// instance per call).
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

/// Shared manifest bridge for file_manager_back_navigation_test.dart style
/// tests — includes an empty-path guard required by nested-folder tests.
final fileManagerNavManifestBridge = ManifestBridge(
  getFolderBaseName: (path) => path.split('/').last,
  getParentFolderPath: (path) {
    if (path.isEmpty) return '';
    final parts = path.split('/');
    return parts.length > 1 ? parts.sublist(0, parts.length - 1).join('/') : '';
  },
  getChildFolderPaths: (parent, allPaths) => [],
  validateFolderName: (_) => null,
  getAllDescendantFolderPaths: (parentPath, allPaths) => [],
);

/// Simple helper from file_manager_view_test.dart — wraps a widget in
/// MaterialApp + Scaffold.
Widget _buildTestApp(Widget body) {
  return MaterialApp(
    home: Scaffold(body: body),
    localizationsDelegates: const [
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
  );
}

/// Builder for a test app wrapping FileManagerView in a ProviderScope + Navigator.
/// This simulates the outer PopScope interaction. Renamed from
/// file_manager_back_navigation_test.dart's `_buildTestApp` to avoid
/// signature collision with the simple version above.
Widget _buildFileManagerApp({
  required FileManagerConfig<_TestFileRecord> config,
  required Set<String> folders,
  required ManifestBridge manifestBridge,
  List<_TestFileRecord> records = const [],
  GlobalKey<NavigatorState>? navigatorKey,
  bool wrapInHomeStylePopScope = false,
}) {
  final navKey = navigatorKey ?? GlobalKey<NavigatorState>();

  Widget fileManager = FileManagerView<_TestFileRecord>(
    sortedRecords: records,
    folders: folders,
    sortConfig: const SortConfig(
      field: SortField.name,
      order: SortOrder.ascending,
    ),
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
    manifestBridge: manifestBridge,
  );

  if (wrapInHomeStylePopScope) {
    fileManager = _HomeStylePopScopeWrapper(child: fileManager);
  }

  return ProviderScope(
    child: MaterialApp(
      home: Navigator(
        key: navKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (_) => Scaffold(body: fileManager),
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
}

/// Wraps child in a PopScope similar to HomePage's outer PopScope.
/// Uses canPop: false and reads filesPageCurrentFolderProvider to decide
/// whether to navigate to Home or stay.
class _HomeStylePopScopeWrapper extends ConsumerWidget {
  final Widget child;
  const _HomeStylePopScopeWrapper({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final currentFolder = ref.read(filesPageCurrentFolderProvider);
        if (currentFolder.isNotEmpty) {
          return;
        }
      },
      child: child,
    );
  }
}

void main() {
  // ===========================================================================
  // 1. file_manager_view_test.dart
  // ===========================================================================
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

      expect(find.byKey(const Key('fallback_icon')), findsNWidgets(2));
    });

    testWidgets(
      'shows thumbnail widgets when fileThumbnailBuilder is set and grid view is active',
      (tester) async {
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
        initialGridView: false,
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

      expect(find.byKey(const Key('thumbnail_file_1')), findsOneWidget);
      expect(find.byKey(const Key('thumbnail_file_2')), findsOneWidget);

      final toggleBtn = find.byKey(const Key('fm_grid_toggle_btn'));
      expect(toggleBtn, findsOneWidget);

      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

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

      await tester.tap(find.text('subfolder'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fm_back_btn')), findsOneWidget);

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

        await tester.tap(find.text('subfolder'));
        await tester.pumpAndSettle();
        expect(capturedCurrentFolder, 'subfolder');

        await tester.pumpWidget(
          _buildTestApp(
            FileManagerView<_TestFileRecord>(
              sortedRecords: [],
              folders: {'subfolder'},
              sortConfig: sortConfig,
              config: config,
              navigateToParentSignal: 1,
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

        expect(capturedCurrentFolder, '');
      },
    );

    testWidgets(
      'does NOT navigate when navigateToParentSignal changes at root',
      (tester) async {
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
            changeCount++;
          },
        );

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

        expect(find.byKey(const Key('fm_back_btn')), findsNothing);
        final countBeforeSignal = changeCount;

        await tester.pumpWidget(
          _buildTestApp(
            FileManagerView<_TestFileRecord>(
              sortedRecords: testFiles,
              folders: {},
              sortConfig: sortConfig,
              config: config,
              navigateToParentSignal: 1,
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

      expect(find.byKey(const Key('fm_grid_folder_my_folder')), findsOneWidget);

      await tester.longPress(find.byKey(const Key('fm_grid_folder_my_folder')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fm_close_selection_btn')), findsOneWidget);
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

      expect(find.byKey(const Key('fm_folder_my_folder')), findsOneWidget);

      await tester.longPress(find.byKey(const Key('fm_folder_my_folder')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fm_close_selection_btn')), findsOneWidget);
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

      await tester.longPress(folderFinder);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fm_close_selection_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('fm_close_selection_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fm_close_selection_btn')), findsNothing);
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
            folders: {'A'},
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

      expect(find.byKey(const Key('fm_grid_folder_A')), findsOneWidget);

      final folderRenderer = tester.renderObject<RenderBox>(
        find.byKey(const Key('fm_grid_folder_A')),
      );
      expect(folderRenderer.size.width, greaterThan(0));
    });
  });

  // ===========================================================================
  // 2. file_manager_back_navigation_test.dart
  // ===========================================================================
  group('filesPageCurrentFolderProvider', () {
    test('starts with empty string (root folder)', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());
      expect(container.read(filesPageCurrentFolderProvider), '');
    });

    test('can be updated to a subfolder path', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      container.read(filesPageCurrentFolderProvider.notifier).state = 'photos';
      expect(container.read(filesPageCurrentFolderProvider), 'photos');
    });

    test('can be reset to empty string (root)', () {
      final container = ProviderContainer();
      addTearDown(() => container.dispose());

      container.read(filesPageCurrentFolderProvider.notifier).state = 'photos';
      container.read(filesPageCurrentFolderProvider.notifier).state = '';
      expect(container.read(filesPageCurrentFolderProvider), '');
    });
  });

  group('FileManagerView back navigation to parent folder', () {
    /// Helper: wrap FileManagerView in MaterialApp + Scaffold for testing.
    Widget buildFM({
      required int signal,
      required Set<String> folders,
      required FileManagerConfig<_TestFileRecord> config,
      ManifestBridge? bridge,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: FileManagerView<_TestFileRecord>(
            sortedRecords: [],
            folders: folders,
            sortConfig: const SortConfig(
              field: SortField.name,
              order: SortOrder.ascending,
            ),
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
            manifestBridge: bridge ?? fileManagerNavManifestBridge,
            navigateToParentSignal: signal,
          ),
        ),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      );
    }

    testWidgets(
      'navigateToParentSignal increment navigates to parent from subfolder',
      (tester) async {
        String? capturedCurrentFolder;

        final config = FileManagerConfig<_TestFileRecord>(
          title: 'Test',
          fileIconBuilder: (_) =>
              const Icon(Icons.videocam, key: Key('fallback_icon')),
          onFileTap: (_) {},
          onCurrentFolderChanged: (f) {
            capturedCurrentFolder = f;
          },
        );

        await tester.pumpWidget(buildFM(
          signal: 0,
          folders: {'subfolder'},
          config: config,
        ));

        await tester.tap(find.text('subfolder'));
        await tester.pumpAndSettle();
        expect(capturedCurrentFolder, 'subfolder');

        await tester.pumpWidget(buildFM(
          signal: 1,
          folders: {'subfolder'},
          config: config,
        ));
        await tester.pumpAndSettle();

        expect(capturedCurrentFolder, '');
      },
    );

    testWidgets(
      'navigateToParentSignal goes up one level at a time in nested subfolders',
      (tester) async {
        final folderHistory = <String>[];

        final nestedBridge = ManifestBridge(
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
            folderHistory.add(f);
          },
        );

        await tester.pumpWidget(buildFM(
          signal: 0,
          folders: {'photos', 'photos/vacation'},
          config: config,
          bridge: nestedBridge,
        ));
        folderHistory.clear();

        await tester.tap(find.text('photos'));
        await tester.pumpAndSettle();
        expect(folderHistory.last, 'photos');

        await tester.tap(find.text('vacation'));
        await tester.pumpAndSettle();
        expect(folderHistory.last, 'photos/vacation');

        await tester.pumpWidget(buildFM(
          signal: 1,
          folders: {'photos', 'photos/vacation'},
          config: config,
          bridge: nestedBridge,
        ));
        await tester.pumpAndSettle();
        expect(folderHistory.last, 'photos');

        await tester.pumpWidget(buildFM(
          signal: 2,
          folders: {'photos', 'photos/vacation'},
          config: config,
          bridge: nestedBridge,
        ));
        await tester.pumpAndSettle();
        expect(folderHistory.last, '');
      },
    );

    testWidgets(
      'onCurrentFolderChanged fires with parent folder after signal navigation',
      (tester) async {
        String? capturedFolder;

        final config = FileManagerConfig<_TestFileRecord>(
          title: 'Test',
          fileIconBuilder: (_) =>
              const Icon(Icons.videocam, key: Key('fallback_icon')),
          onFileTap: (_) {},
          onCurrentFolderChanged: (f) {
            capturedFolder = f;
          },
        );

        await tester.pumpWidget(buildFM(
          signal: 0,
          folders: {'subfolder'},
          config: config,
        ));
        capturedFolder = null;

        await tester.tap(find.text('subfolder'));
        await tester.pumpAndSettle();
        expect(capturedFolder, 'subfolder');

        await tester.pumpWidget(buildFM(
          signal: 1,
          folders: {'subfolder'},
          config: config,
        ));
        await tester.pumpAndSettle();

        expect(capturedFolder, '');
      },
    );

    testWidgets(
      'AppBar back button also navigates to parent folder',
      (tester) async {
        String? capturedFolder;

        final config = FileManagerConfig<_TestFileRecord>(
          title: 'Test',
          fileIconBuilder: (_) =>
              const Icon(Icons.videocam, key: Key('fallback_icon')),
          onFileTap: (_) {},
          onCurrentFolderChanged: (f) {
            capturedFolder = f;
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: FileManagerView<_TestFileRecord>(
                  sortedRecords: [],
                  folders: {'subfolder'},
                  sortConfig: const SortConfig(
                    field: SortField.name,
                    order: SortOrder.ascending,
                  ),
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
                  manifestBridge: fileManagerNavManifestBridge,
                ),
              ),
              localizationsDelegates: const [
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
              ],
            ),
          ),
        );

        await tester.tap(find.text('subfolder'));
        await tester.pumpAndSettle();
        expect(capturedFolder, 'subfolder');

        await tester.tap(find.byKey(const Key('fm_back_btn')));
        await tester.pumpAndSettle();

        expect(capturedFolder, '');
      },
    );

    testWidgets(
      'in-list back item navigates to parent folder',
      (tester) async {
        String? capturedFolder;

        final config = FileManagerConfig<_TestFileRecord>(
          title: 'Test',
          fileIconBuilder: (_) =>
              const Icon(Icons.videocam, key: Key('fallback_icon')),
          onFileTap: (_) {},
          onCurrentFolderChanged: (f) {
            capturedFolder = f;
          },
        );

        final navKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          _buildFileManagerApp(
            records: [],
            folders: {'subfolder'},
            config: config,
            manifestBridge: fileManagerNavManifestBridge,
            navigatorKey: navKey,
          ),
        );

        await tester.tap(find.text('subfolder'));
        await tester.pumpAndSettle();
        expect(capturedFolder, 'subfolder');

        await tester.tap(find.byKey(const Key('fm_back_btn')));
        await tester.pumpAndSettle();

        expect(capturedFolder, '');
      },
    );

    testWidgets(
      'system back at root does not trigger folder navigation',
      (tester) async {
        final navKey = GlobalKey<NavigatorState>();
        String? capturedFolder;

        final config = FileManagerConfig<_TestFileRecord>(
          title: 'Test',
          fileIconBuilder: (_) =>
              const Icon(Icons.videocam, key: Key('fallback_icon')),
          onFileTap: (_) {},
          onCurrentFolderChanged: (f) {
            capturedFolder = f;
          },
        );

        await tester.pumpWidget(
          _buildFileManagerApp(
            records: [],
            folders: {'subfolder'},
            config: config,
            manifestBridge: fileManagerNavManifestBridge,
            navigatorKey: navKey,
          ),
        );

        expect(find.byKey(const Key('fm_back_btn')), findsNothing);
        capturedFolder = null;

        await navKey.currentState?.maybePop();
        await tester.pumpAndSettle();

        expect(capturedFolder, isNull);
      },
    );
  });

  // ===========================================================================
  // 3. file_preview_test.dart
  // ===========================================================================
  group('FilePreviewChip - bytes & document variants', () {
    final testBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

    Attachment createImageAttachment() {
      return Attachment(
        fileName: 'test.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'abc123',
        storagePath: '/tmp/test.png',
        fileSize: 100,
      );
    }

    Attachment createDocumentAttachment() {
      return Attachment(
        fileName: 'doc.txt',
        mimeType: 'text/plain',
        fileType: 'document',
        hash: 'def456',
        storagePath: '/tmp/doc.txt',
        fileSize: 200,
      );
    }

    Widget buildChip({
      required Attachment attachment,
      Uint8List? imageBytes,
      VoidCallback? onRemove,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(
            attachment: attachment,
            imageBytes: imageBytes,
            onRemove: onRemove,
            onTap: onTap,
          ),
        ),
      );
    }

    testWidgets('renders image with ExtendedImage when imageBytes provided',
        (tester) async {
      await tester.pumpWidget(buildChip(
        attachment: createImageAttachment(),
        imageBytes: testBytes,
      ));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FilePreviewChip), findsOneWidget);
      expect(find.text('test.png'), findsOneWidget);
    });

    testWidgets('shows file icon for non-image attachments', (tester) async {
      await tester.pumpWidget(buildChip(
        attachment: createDocumentAttachment(),
      ));

      await tester.pump();

      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    });

    testWidgets('remove button calls onRemove when tapped', (tester) async {
      bool removed = false;
      await tester.pumpWidget(buildChip(
        attachment: createImageAttachment(),
        imageBytes: testBytes,
        onRemove: () => removed = true,
      ));

      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(removed, isTrue);
    });

    testWidgets('truncates long file names', (tester) async {
      final longName = 'a' * 30 + '.png';
      final att = Attachment(
        fileName: longName,
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'ghi789',
        storagePath: '/tmp/long.png',
        fileSize: 100,
      );

      await tester.pumpWidget(buildChip(
        attachment: att,
        imageBytes: testBytes,
      ));

      await tester.pump();

      expect(find.text('aaaaaaaaaaaaaa…'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 4. file_preview_chip_test.dart
  // ===========================================================================
  group('FilePreviewChip - tap & type variants', () {
    final testAttachment = Attachment(
      id: 'att-1',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      fileType: 'image',
      hash: 'abc123',
      storagePath: 'attachments/abc123_1234567890.jpg',
      fileSize: 102400,
    );

    testWidgets('renders file icon and name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(
            attachment: testAttachment,
          ),
        ),
      ));

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.text('photo.jpg'), findsOneWidget);
    });

    testWidgets('onTap is called when chip is tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(
            attachment: testAttachment,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(GestureDetector));
      expect(tapped, true);
    });

    testWidgets('works without onTap (no crash)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(
            attachment: testAttachment,
          ),
        ),
      ));

      expect(find.byType(FilePreviewChip), findsOneWidget);
    });

    testWidgets('onTap and onRemove both work independently', (tester) async {
      bool tapped = false;
      bool removed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(
            attachment: testAttachment,
            onTap: () => tapped = true,
            onRemove: () => removed = true,
          ),
        ),
      ));

      await tester.tap(find.byType(GestureDetector).first);
      expect(tapped, true);
      expect(removed, false);
    });

    testWidgets('tapping remove button fires onRemove, NOT onTap',
        (tester) async {
      bool tapped = false;
      bool removed = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(
            attachment: testAttachment,
            onTap: () => tapped = true,
            onRemove: () => removed = true,
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.close));
      expect(removed, true);
      expect(tapped, false);
    });

    testWidgets('long filename is truncated with ellipsis', (tester) async {
      final longNameAttachment = Attachment(
        id: 'att-long',
        fileName: 'a_very_long_file_name_that_exceeds.png',
        mimeType: 'image/png',
        fileType: 'image',
        hash: 'mno345',
        storagePath: 'attachments/mno345_1234567890.png',
        fileSize: 51200,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FilePreviewChip(attachment: longNameAttachment),
        ),
      ));

      expect(find.text('a_very_long_file_name_that_exceeds.png'), findsNothing);
      expect(find.text('a_very_long_fi…'), findsOneWidget);
    });

    testWidgets('different file types show correct icons', (tester) async {
      final types = <String, IconData>{
        'image': Icons.image_outlined,
        'audio': Icons.audiotrack_outlined,
        'video': Icons.videocam_outlined,
        'document': Icons.insert_drive_file_outlined,
      };

      for (final entry in types.entries) {
        final att = Attachment(
          id: 'att-${entry.key}',
          fileName: 'file.${entry.key}',
          mimeType: '${entry.key}/test',
          fileType: entry.key,
          hash: 'hash-${entry.key}',
          storagePath: 'attachments/hash-${entry.key}.test',
          fileSize: 1024,
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: FilePreviewChip(attachment: att),
          ),
        ));

        expect(find.byIcon(entry.value), findsOneWidget,
            reason: 'Expected ${entry.value} for fileType ${entry.key}');
      }
    });
  });
}
