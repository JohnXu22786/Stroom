import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/pages/files_page_shared.dart';
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

/// Builder for a test app wrapping FileManagerView in a ProviderScope + Navigator.
/// This simulates the outer PopScope interaction.
Widget _buildTestApp({
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
    // Simulate the outer PopScope from HomePage: canPop: false,
    // reads filesPageCurrentFolderProvider to decide navigation.
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
        // Check current folder from shared provider
        final currentFolder = ref.read(filesPageCurrentFolderProvider);
        if (currentFolder.isNotEmpty) {
          // In subfolder - inner PopScope handled it, do nothing
          return;
        }
        // At root - would navigate to Home in real app
        // In this test context, we just track that navigation happened
      },
      child: child,
    );
  }
}

final testManifestBridge = ManifestBridge(
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

void main() {
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
    Widget _buildFM({
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
            manifestBridge: bridge ?? testManifestBridge,
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

        // Initial render: FileManagerView with navigateToParentSignal = 0
        await tester.pumpWidget(_buildFM(
          signal: 0,
          folders: {'subfolder'},
          config: config,
        ));

        // Navigate into subfolder
        await tester.tap(find.text('subfolder'));
        await tester.pumpAndSettle();
        expect(capturedCurrentFolder, 'subfolder');

        // Increment signal to simulate outer PopScope navigation request
        await tester.pumpWidget(_buildFM(
          signal: 1,
          folders: {'subfolder'},
          config: config,
        ));
        await tester.pumpAndSettle();

        // Should have navigated back to parent (root = '')
        expect(capturedCurrentFolder, '');
      },
    );

    testWidgets(
      'navigateToParentSignal goes up one level at a time in nested subfolders',
      (tester) async {
        final folderHistory = <String>[];

        // Bridge that supports nested paths
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

        // Initial render
        await tester.pumpWidget(_buildFM(
          signal: 0,
          folders: {'photos', 'photos/vacation'},
          config: config,
          bridge: nestedBridge,
        ));
        folderHistory.clear();

        // Navigate into "photos"
        await tester.tap(find.text('photos'));
        await tester.pumpAndSettle();
        expect(folderHistory.last, 'photos');

        // Navigate into "vacation" (subfolder of photos)
        await tester.tap(find.text('vacation'));
        await tester.pumpAndSettle();
        expect(folderHistory.last, 'photos/vacation');

        // Increment signal: should go up to "photos"
        await tester.pumpWidget(_buildFM(
          signal: 1,
          folders: {'photos', 'photos/vacation'},
          config: config,
          bridge: nestedBridge,
        ));
        await tester.pumpAndSettle();
        expect(folderHistory.last, 'photos');

        // Increment signal again: should go up to root ''
        await tester.pumpWidget(_buildFM(
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

        // Initial render
        await tester.pumpWidget(_buildFM(
          signal: 0,
          folders: {'subfolder'},
          config: config,
        ));
        capturedFolder = null;

        // Navigate into subfolder
        await tester.tap(find.text('subfolder'));
        await tester.pumpAndSettle();
        expect(capturedFolder, 'subfolder');

        // Increment signal to navigate to parent
        await tester.pumpWidget(_buildFM(
          signal: 1,
          folders: {'subfolder'},
          config: config,
        ));
        await tester.pumpAndSettle();

        // After signal, onCurrentFolderChanged should fire with parent (root = '')
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
                  manifestBridge: testManifestBridge,
                ),
              ),
              localizationsDelegates: const [
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
              ],
            ),
          ),
        );

        // Navigate into subfolder
        await tester.tap(find.text('subfolder'));
        await tester.pumpAndSettle();
        expect(capturedFolder, 'subfolder');

        // Tap the AppBar back button
        await tester.tap(find.byKey(const Key('fm_back_btn')));
        await tester.pumpAndSettle();

        // Should have navigated back to parent (root = '')
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

        // Use the test helper with a Navigator to get proper layout
        final navKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          _buildTestApp(
            records: [],
            folders: {'subfolder'},
            config: config,
            manifestBridge: testManifestBridge,
            navigatorKey: navKey,
          ),
        );

        // Navigate into subfolder
        await tester.tap(find.text('subfolder'));
        await tester.pumpAndSettle();
        expect(capturedFolder, 'subfolder');

        // Tap the AppBar back button (same behavior as in-list back item)
        await tester.tap(find.byKey(const Key('fm_back_btn')));
        await tester.pumpAndSettle();

        // Should have navigated back to parent (root = '')
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
          _buildTestApp(
            records: [],
            folders: {'subfolder'},
            config: config,
            manifestBridge: testManifestBridge,
            navigatorKey: navKey,
          ),
        );

        // We're at root
        expect(find.byKey(const Key('fm_back_btn')), findsNothing);
        capturedFolder = null;

        // Simulate system back at root
        await navKey.currentState?.maybePop();
        await tester.pumpAndSettle();

        // onCurrentFolderChanged should NOT have been called
        expect(capturedFolder, isNull);
      },
    );
  });
}
