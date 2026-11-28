// Merged from:
//   - file_manager_view_test.dart
//   - file_manager_back_navigation_test.dart
//   - file_preview_test.dart
//   - file_preview_chip_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';

import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/files_page_shared.dart';
import 'package:stroom/utils/file_record.dart';
import 'package:stroom/utils/folder_path_utils.dart';
import 'package:stroom/utils/manifest_bridge.dart';
import 'package:stroom/utils/sort_config.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/file_manager_view.dart';
import 'package:stroom/widgets/file_preview.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';

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
  final DateTime modifiedAt;
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
    DateTime? modifiedAt,
    this.size = 1024,
    this.folder = '',
  })  : id = id ?? 'file_${DateTime.now().millisecondsSinceEpoch}',
        createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? createdAt ?? DateTime.now();

  @override
  String get storagePath => '$hash.$format';

  @override
  _TestFileRecord copyWithName(String name) => _TestFileRecord(
        id: id,
        name: name,
        hash: hash,
        format: format,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
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
        modifiedAt: modifiedAt,
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

Widget _disableTestAnimations(BuildContext context, Widget? child) =>
    MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    );

/// Simple helper from file_manager_view_test.dart — wraps a widget in
/// MaterialApp + Scaffold.
Widget _buildTestApp(
  Widget body, {
  Locale locale = const Locale('zh', 'CN'),
  ThemeData? theme,
  double textScale = 1,
  Key? captureKey,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: true,
        textScaler: TextScaler.linear(textScale),
      ),
      child: RepaintBoundary(key: captureKey, child: child!),
    ),
    locale: locale,
    theme: theme,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: body),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
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
  Locale locale = const Locale('zh', 'CN'),
  ThemeData? theme,
  double? textScale,
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
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            disableAnimations: true,
            textScaler: textScale == null
                ? mediaQuery.textScaler
                : TextScaler.linear(textScale),
          ),
          child: child!,
        );
      },
      locale: locale,
      theme: theme,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Navigator(
        key: navKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (_) => Scaffold(body: fileManager),
            settings: settings,
          );
        },
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
  setUpAll(() async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot == null) return;
    final fontDirectory = '$flutterRoot/bin/cache/artifacts/material_fonts';
    for (final (family, fileName) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final bytes = File('$fontDirectory/$fileName').readAsBytesSync();
      await (FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });

  testWidgets(
      'grid tile grows for scaled folder labels without breaking file taps',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    var openedFile = false;
    const folder =
        'a folder name with enough words to wrap across several visible lines';
    await tester.pumpWidget(
      _buildFileManagerApp(
        config: FileManagerConfig<_TestFileRecord>(
          title: 'Files',
          initialGridView: true,
          fileThumbnailBuilder: (_) => const ColoredBox(
            color: Colors.amber,
            child: SizedBox.expand(),
          ),
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          onFileTap: (_) => openedFile = true,
        ),
        folders: const {folder},
        manifestBridge: testManifestBridge,
        records: [
          _TestFileRecord(
            id: 'grid-height-file',
            name: 'sample',
            format: 'txt',
          ),
        ],
        locale: const Locale('en'),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final folderTile = find.byKey(const Key('fm_grid_folder_$folder'));
    final folderLabel =
        find.descendant(of: folderTile, matching: find.byType(ConstrainedText));
    final tileSize = tester.getSize(folderTile);
    expect(tileSize.height, greaterThan(tileSize.width));
    expect(
      tileSize.height,
      closeTo(46 + tester.getSize(folderLabel).height, 0.5),
      reason: 'the row reserves the visible two-line label without extra space',
    );
    expect(
      find.byKey(const Key('fm_grid_file_grid-height-file')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('fm_grid_file_grid-height-file')));
    await tester.pump();
    expect(openedFile, isTrue);
    expect(tester.takeException(), isNull);

    await tester.longPress(folderTile);
    await tester.pump();
    expect(
      find.descendant(of: folderTile, matching: find.byType(Checkbox)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  group('FileManagerView file menu', () {
    testWidgets('uses Open for the file action', (tester) async {
      var openedFile = false;
      await tester.pumpWidget(
        _buildFileManagerApp(
          config: FileManagerConfig<_TestFileRecord>(
            title: 'Test',
            fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
            onFileTap: (_) => openedFile = true,
          ),
          folders: {},
          manifestBridge: testManifestBridge,
          records: [testFiles.first],
          locale: const Locale('en'),
        ),
      );

      await tester.tap(find.byKey(const Key('fm_file_popup_file_1')));
      await tester.pumpAndSettle();

      expect(find.text('Preview'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(openedFile, isTrue);
    });
  });

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

  group('FileManagerView title bar scroll color', () {
    testWidgets(
      'title bar keeps its color and elevation when the list scrolls under it',
      (tester) async {
        // Enough records to make the list taller than the viewport.
        final manyFiles = List.generate(
          60,
          (i) => _TestFileRecord(
            id: 'scroll_file_$i',
            name: 'file_$i',
            hash: 'hash_$i',
            format: 'txt',
          ),
        );

        final config = FileManagerConfig<_TestFileRecord>(
          title: 'Test',
          fileIconBuilder: (_) => const Icon(Icons.description),
          onFileTap: (_) {},
        );

        await tester.pumpWidget(
          _buildFileManagerApp(
            config: config,
            folders: const {},
            manifestBridge: fileManagerNavManifestBridge,
            records: manyFiles,
          ),
        );
        await tester.pumpAndSettle();

        // The AppBar's background Material is the outermost Material in the
        // AppBar subtree (found first in traversal order).
        Material appBarMaterial() => tester.widget<Material>(
              find
                  .descendant(
                    of: find.byType(AppBar),
                    matching: find.byType(Material),
                  )
                  .first,
            );

        final colorBeforeScroll = appBarMaterial().color;
        final elevationBeforeScroll = appBarMaterial().elevation;
        expect(elevationBeforeScroll, 0);

        // Scroll down so the list content scrolls under the title bar.
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();

        // Regression: Material 3's scrolled-under elevation must not tint the
        // title bar or switch its background color when the list is scrolled.
        expect(
          appBarMaterial().color,
          colorBeforeScroll,
          reason: 'title bar must not change color when the list is '
              'scrolled under it',
        );
        expect(
          appBarMaterial().elevation,
          elevationBeforeScroll,
          reason: 'title bar must not gain scrolled-under elevation when the '
              'list is scrolled under it',
        );
      },
    );
  });

  group('FileManagerView sorting', () {
    FileManagerView<_TestFileRecord> build({
      Set<String> folders = const {},
      List<_TestFileRecord> records = const [],
      SortConfig config = const SortConfig(
        field: SortField.name,
        order: SortOrder.ascending,
      ),
    }) {
      final fmConfig = FileManagerConfig<_TestFileRecord>(
        title: 'Test',
        fileIconBuilder: (_) =>
            const Icon(Icons.videocam, key: Key('fallback_icon')),
        onFileTap: (_) {},
      );
      return FileManagerView<_TestFileRecord>(
        sortedRecords: records,
        folders: folders,
        sortConfig: config,
        config: fmConfig,
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

    testWidgets('folders sort naturally by name (dot-numbered names)', (
      tester,
    ) async {
      // 升序：25.3.9 应排在 25.3.30 之前（字典序会颠倒）
      await tester.pumpWidget(
        _buildTestApp(
          build(
            folders: {'25.3.30', '25.3.9'},
            config: const SortConfig(
              field: SortField.name,
              order: SortOrder.ascending,
            ),
          ),
        ),
      );

      final dy9 =
          tester.getTopLeft(find.byKey(const Key('fm_folder_25.3.9'))).dy;
      final dy30 =
          tester.getTopLeft(find.byKey(const Key('fm_folder_25.3.30'))).dy;
      expect(dy9, lessThan(dy30));

      // 降序：25.3.30 应排在 25.3.9 之前
      await tester.pumpWidget(
        _buildTestApp(
          build(
            folders: {'25.3.30', '25.3.9'},
            config: const SortConfig(
              field: SortField.name,
              order: SortOrder.descending,
            ),
          ),
        ),
      );

      final dy30d =
          tester.getTopLeft(find.byKey(const Key('fm_folder_25.3.30'))).dy;
      final dy9d =
          tester.getTopLeft(find.byKey(const Key('fm_folder_25.3.9'))).dy;
      expect(dy30d, lessThan(dy9d));
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

  group('FileManagerView fixed back item header', () {
    /// Builder with enough content to make the list/grid scrollable.
    FileManagerView<_TestFileRecord> build({
      required List<_TestFileRecord> records,
      required Set<String> folders,
      bool grid = false,
    }) {
      return FileManagerView<_TestFileRecord>(
        sortedRecords: records,
        folders: folders,
        sortConfig: sortConfig,
        config: FileManagerConfig<_TestFileRecord>(
          title: 'Test',
          showThumbnailToggle: true,
          initialGridView: grid,
          fileIconBuilder: (_) =>
              const Icon(Icons.videocam, key: Key('fallback_icon')),
          fileThumbnailBuilder: grid
              ? (file) => Container(
                    key: Key('thumb_${file.id}'),
                    color: Colors.black,
                  )
              : null,
          onFileTap: (_) {},
        ),
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
      );
    }

    testWidgets('back item stays fixed while the file list scrolls', (
      tester,
    ) async {
      final records = [
        for (var i = 0; i < 40; i++)
          _TestFileRecord(id: 'f$i', name: 'f$i', folder: 'a'),
      ];
      await tester.pumpWidget(
        _buildTestApp(build(records: records, folders: {'a'})),
      );

      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();

      final backItem = find.byKey(const Key('fm_back_item'));
      expect(backItem, findsOneWidget);
      // The back row must not be part of the scrollable list
      expect(
        find.ancestor(of: backItem, matching: find.byType(ListView)),
        findsNothing,
      );
      final backYBefore = tester.getTopLeft(backItem).dy;

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // The list really scrolled…
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.pixels, greaterThan(0));
      // …but the back row did not move
      expect(tester.getTopLeft(backItem).dy, closeTo(backYBefore, 0.1));
    });

    testWidgets('back item stays fixed while the grid scrolls', (
      tester,
    ) async {
      final records = [
        for (var i = 0; i < 40; i++)
          _TestFileRecord(id: 'g$i', name: 'g$i', folder: 'a'),
      ];
      await tester.pumpWidget(
        _buildTestApp(build(records: records, folders: {'a'}, grid: true)),
      );

      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      final backItem = find.byKey(const Key('fm_back_item'));
      expect(backItem, findsOneWidget);
      // The back row must not be part of the scrollable grid
      expect(
        find.ancestor(of: backItem, matching: find.byType(GridView)),
        findsNothing,
      );
      final backYBefore = tester.getTopLeft(backItem).dy;

      await tester.drag(find.byType(GridView), const Offset(0, -400));
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.pixels, greaterThan(0));
      expect(tester.getTopLeft(backItem).dy, closeTo(backYBefore, 0.1));
    });

    testWidgets('back label and long folder path stay within narrow row', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const longFolder =
          'very-long-folder-name-with-multiple-segments-and-details';
      await tester.pumpWidget(
        _buildTestApp(build(records: [], folders: {longFolder})),
      );
      await tester.tap(find.text(longFolder));
      await tester.pumpAndSettle();

      final backItem = find.byKey(const Key('fm_back_item'));
      final constrainedLabels = find.descendant(
        of: backItem,
        matching: find.byType(ConstrainedText),
      );
      expect(constrainedLabels, findsNWidgets(2));
      final labels = constrainedLabels.evaluate().map(
            (element) => element.widget as ConstrainedText,
          );
      final pathLabel = labels.singleWhere((label) => label.data == longFolder);
      expect(pathLabel.textAlign, TextAlign.end);
      expect(pathLabel.maxLines, 1);
      expect(pathLabel.overflow, TextOverflow.clip);

      final labelRects = constrainedLabels
          .evaluate()
          .map(
            (element) => tester.getRect(find.byWidget(element.widget)),
          )
          .toList();
      expect(labelRects[0].right, lessThanOrEqualTo(labelRects[1].left));
      expect(labelRects[1].right,
          lessThanOrEqualTo(tester.getRect(backItem).right));
    });

    testWidgets('back item shows even when the subfolder is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(build(records: [], folders: {'a'})),
      );

      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();

      expect(find.text('此文件夹为空'), findsOneWidget);
      expect(find.byKey(const Key('fm_back_item')), findsOneWidget);
    });
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

  // ===========================================================================
  // 2. file_manager_back_navigation_test.dart
  // ===========================================================================
  group('FileManagerView back navigation to parent folder', () {
    /// Helper: wrap FileManagerView in MaterialApp + Scaffold for testing.
    Widget buildFM({
      required int signal,
      required Set<String> folders,
      required FileManagerConfig<_TestFileRecord> config,
      ManifestBridge? bridge,
    }) {
      return MaterialApp(
        builder: _disableTestAnimations,
        locale: const Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
              builder: _disableTestAnimations,
              locale: const Locale('zh', 'CN'),
              supportedLocales: AppLocalizations.supportedLocales,
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
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
  // Batch operations (move / copy / delete) with folders
  // ===========================================================================
  group('FileManagerView batch operations', () {
    /// Bridge whose getAllDescendantFolderPaths returns real descendants.
    ManifestBridge descendantsBridge() => ManifestBridge(
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
          getAllDescendantFolderPaths: (parentPath, allPaths) {
            final prefix = parentPath.isEmpty ? '' : '$parentPath/';
            return allPaths.where((f) => f.startsWith(prefix)).toList();
          },
        );

    FileManagerView<_TestFileRecord> buildBatchFM({
      required List<_TestFileRecord> records,
      required Set<String> folders,
      ManifestBridge? manifestBridge,
      bool isActiveTab = true,
      void Function(String)? onCurrentFolderChanged,
      Future<void> Function()? onRefresh,
      Future<void> Function(List<String>)? onDeleteFiles,
      Future<void> Function(List<String>)? onDeleteFolders,
      Future<void> Function(List<String>, String)? onMoveFiles,
      Future<void> Function(List<String>, String)? onMoveFolders,
      Future<String?> Function(List<String>, String)? onExportFiles,
      Future<String?> Function(List<String>, String, List<String>)?
          onExportFilesWithFolders,
      Future<String?> Function(List<String>, String)? onExportFolders,
      Future<void> Function(String)? onDeleteFolder,
      Future<void> Function(String, String)? onMoveFolder,
      Future<void> Function(String, String)? onRenameFolder,
      Future<void> Function(String, String)? onRenameFile,
      Future<void> Function(String, String, String)? onRenameFileWithFormat,
      Future<void> Function(String)? onCreateFolder,
      Future<void> Function(String, String)? onMoveFile,
      Future<void> Function(String, String)? onCopyFile,
      Future<void> Function(String, String)? onCopyFolder,
      List<String>? renameFormatOptions,
    }) {
      return FileManagerView<_TestFileRecord>(
        sortedRecords: records,
        folders: folders,
        sortConfig: sortConfig,
        config: FileManagerConfig<_TestFileRecord>(
          title: 'Test',
          fileIconBuilder: (_) =>
              const Icon(Icons.videocam, key: Key('fallback_icon')),
          onFileTap: (_) {},
          onCurrentFolderChanged: onCurrentFolderChanged,
          renameFormatOptions: renameFormatOptions,
        ),
        isActiveTab: isActiveTab,
        onRefresh: onRefresh ?? () async {},
        onRenameFile: onRenameFile ?? (_, __) async {},
        onRenameFileWithFormat: onRenameFileWithFormat,
        onMoveFile: onMoveFile ?? (_, __) async {},
        onCopyFile: onCopyFile ?? (_, __) async {},
        onDeleteFile: (_) async {},
        onDeleteFiles: onDeleteFiles ?? (_) async {},
        onDeleteFolders: onDeleteFolders ?? (_) async {},
        onMoveFiles: onMoveFiles ?? (_, __) async {},
        onMoveFolders: onMoveFolders ?? (_, __) async {},
        onExportFile: (_) async {},
        onExportFiles: onExportFiles,
        onExportFilesWithFolders: onExportFilesWithFolders,
        onExportFolders: onExportFolders,
        onRenameFolder: onRenameFolder ?? (_, __) async {},
        onMoveFolder: onMoveFolder ?? (_, __) async {},
        onCopyFolder: onCopyFolder ?? (_, __) async {},
        onDeleteFolder: onDeleteFolder ?? (_) async {},
        onCreateFolder: onCreateFolder ?? (_) async {},
        onToggleSort: (_) {},
        manifestBridge: manifestBridge ?? descendantsBridge(),
      );
    }

    Finder inPicker(Finder matching) => find.descendant(
          of: find.byType(FolderPickerDialog),
          matching: matching,
        );

    testWidgets(
      'empty folder deletion warns that nested folders will also be deleted',
      (tester) async {
        final deletedFolders = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: const [],
              folders: {'a', 'a/b', 'a/b/c'},
              onDeleteFolder: (name) async => deletedFolders.add(name),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('fm_folder_popup_a')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fm_folder_menu_delete')));
        await tester.pumpAndSettle();

        expect(find.textContaining('2 个子文件夹'), findsOneWidget);
        expect(deletedFolders, isEmpty);

        await tester.tap(find.byKey(const Key('fm_delete_folder_confirm_btn')));
        await tester.pumpAndSettle();

        expect(deletedFolders, ['a']);
      },
    );

    testWidgets(
      'long nested folder delete confirmation scrolls and preserves actions',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        const folder =
            'top-level-folder-with-a-long-name/second-level-folder-with-a-long-name/'
            'third-level-folder-with-a-long-name/fourth-level-folder-with-a-long-name/'
            'fifth-level-folder-with-a-long-name/sixth-level-folder-with-a-long-name/'
            'seventh-level-folder-with-a-long-name/eighth-level-folder-with-a-long-name';
        final folderSegments = folder.split('/');
        final folders = <String>{};
        var folderPrefix = '';
        for (final segment in folderSegments) {
          folderPrefix =
              folderPrefix.isEmpty ? segment : '$folderPrefix/$segment';
          folders.add(folderPrefix);
        }
        final deletedFolders = <String>[];

        Future<void> openDeleteMenu() async {
          var parentPath = '';
          for (final segment
              in folderSegments.take(folderSegments.length - 1)) {
            parentPath = parentPath.isEmpty ? segment : '$parentPath/$segment';
            await tester.tap(find.byKey(Key('fm_folder_$parentPath')));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.byKey(Key('fm_folder_popup_$folder')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('fm_folder_menu_delete')));
          await tester.pumpAndSettle();
        }

        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: const [],
              folders: folders,
              onDeleteFolder: (name) async => deletedFolders.add(name),
            ),
            locale: const Locale('en', 'US'),
          ),
        );

        await openDeleteMenu();

        expect(tester.takeException(), isNull);
        expect(
            find.byKey(const Key('fm_delete_folder_dialog')), findsOneWidget);
        expect(
          find.byKey(const Key('fm_delete_folder_cancel_btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('fm_delete_folder_confirm_btn')),
          findsOneWidget,
        );
        expect(find.textContaining(folder), findsOneWidget);
        final dialogScrollable = find.descendant(
          of: find.byKey(const Key('fm_delete_folder_dialog')),
          matching: find.byType(Scrollable),
        );
        expect(dialogScrollable, findsOneWidget);
        await tester.drag(
          dialogScrollable,
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(deletedFolders, isEmpty);

        await tester.tap(find.byKey(const Key('fm_delete_folder_cancel_btn')));
        await tester.pumpAndSettle();
        expect(deletedFolders, isEmpty);
        for (final _ in folderSegments.take(folderSegments.length - 1)) {
          await tester.tap(find.byKey(const Key('fm_back_btn')));
          await tester.pumpAndSettle();
        }

        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: const [],
              folders: folders,
              onDeleteFolder: (name) async => deletedFolders.add(name),
            ),
            locale: const Locale('fr', 'FR'),
            theme: ThemeData.dark(useMaterial3: true),
          ),
        );
        await openDeleteMenu();
        expect(find.textContaining(folder), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('fm_delete_folder_confirm_btn')));
        await tester.pumpAndSettle();
        expect(deletedFolders, [folder]);
      },
    );

    testWidgets(
      'empty folder deletion warning pluralizes English descendant counts',
      (tester) async {
        final scenarios = [
          (
            folders: {'a', 'a/b'},
            warning: '1 nested folder will also be deleted'
          ),
          (
            folders: {'a', 'a/b', 'a/b/c'},
            warning: '2 nested folders will also be deleted',
          ),
        ];

        for (final scenario in scenarios) {
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                records: const [],
                folders: scenario.folders,
              ),
              locale: const Locale('en', 'US'),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_folder_popup_a')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('fm_folder_menu_delete')));
          await tester.pumpAndSettle();

          expect(find.textContaining(scenario.warning), findsOneWidget);

          await tester.tap(
            find.byKey(const Key('fm_delete_folder_cancel_btn')),
          );
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets(
      'single-file move allows same name with a different format',
      (tester) async {
        final moved = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [
                _TestFileRecord(id: 'source', name: 'report', format: 'txt'),
                _TestFileRecord(
                  id: 'existing',
                  name: 'report',
                  format: 'md',
                  folder: 'destination',
                ),
              ],
              folders: {'destination'},
              onMoveFile: (id, folder) async => moved.add('$id->$folder'),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('fm_file_popup_source')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('移动'));
        await tester.pumpAndSettle();
        await tester.tap(inPicker(find.text('destination')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        expect(moved, ['source->destination']);
      },
    );

    testWidgets(
      'batch move allows same-name files with different formats',
      (tester) async {
        final moved = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [
                _TestFileRecord(id: 'txt', name: 'report', format: 'txt'),
                _TestFileRecord(id: 'md', name: 'report', format: 'md'),
              ],
              folders: {'destination'},
              onMoveFiles: (ids, folder) async => moved.addAll(ids),
            ),
          ),
        );

        await tester.longPress(find.byKey(const Key('fm_file_txt')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fm_file_md')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fm_selection_move_btn')));
        await tester.pumpAndSettle();
        await tester.tap(inPicker(find.text('destination')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        expect(moved, unorderedEquals(['txt', 'md']));
      },
    );

    testWidgets(
      'batch copy allows same-name files with different formats',
      (tester) async {
        final copied = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [
                _TestFileRecord(id: 'txt', name: 'report', format: 'txt'),
                _TestFileRecord(id: 'md', name: 'report', format: 'md'),
              ],
              folders: {'destination'},
              onCopyFile: (id, folder) async => copied.add(id),
            ),
          ),
        );

        await tester.longPress(find.byKey(const Key('fm_file_txt')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fm_file_md')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fm_selection_copy_btn')));
        await tester.pumpAndSettle();
        await tester.tap(inPicker(find.text('destination')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        expect(copied, unorderedEquals(['txt', 'md']));
      },
    );

    testWidgets(
      'batch move picker excludes the selected folder and its descendants',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(records: [], folders: {'a', 'a/b', 'c'}),
          ),
        );

        await tester.longPress(find.byKey(const Key('fm_folder_a')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fm_selection_move_btn')));
        await tester.pumpAndSettle();

        expect(
          find.byType(FolderPickerDialog),
          findsOneWidget,
        );
        // 'c' remains available as a target; the selected folder 'a' is gone.
        expect(inPicker(find.text('c')), findsOneWidget);
        expect(inPicker(find.text('a')), findsNothing);
      },
    );

    testWidgets(
      'batch copy picker excludes the selected folder and its descendants',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(records: [], folders: {'a', 'a/b', 'c'}),
          ),
        );

        await tester.longPress(find.byKey(const Key('fm_folder_a')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fm_selection_copy_btn')));
        await tester.pumpAndSettle();

        expect(
          find.byType(FolderPickerDialog),
          findsOneWidget,
        );
        expect(inPicker(find.text('c')), findsOneWidget);
        expect(inPicker(find.text('a')), findsNothing);
      },
    );

    testWidgets(
      'batch move calls onMoveFiles with files and onMoveFolders with folders',
      (tester) async {
        final movedFiles = <String>[];
        final movedFolders = <String>[];
        String? fileTarget;
        String? folderTarget;

        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [_TestFileRecord(id: 'f1', name: 'one')],
              folders: {'a', 'a/b', 'c'},
              onMoveFiles: (ids, t) async {
                movedFiles.addAll(ids);
                fileTarget = t;
              },
              onMoveFolders: (names, t) async {
                movedFolders.addAll(names);
                folderTarget = t;
              },
              onMoveFolder: (name, t) async {
                movedFolders.add('single:$name');
              },
            ),
          ),
        );

        await tester.longPress(find.byKey(const Key('fm_folder_a')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fm_file_f1')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fm_selection_move_btn')));
        await tester.pumpAndSettle();

        await tester.tap(inPicker(find.text('c')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        expect(movedFiles, ['f1']);
        expect(movedFolders, ['a']);
        expect(fileTarget, 'c');
        expect(folderTarget, 'c');
      },
    );

    testWidgets(
      'batch delete calls onDeleteFiles with files and onDeleteFolders with folders',
      (tester) async {
        final deletedFiles = <String>[];
        final deletedFolders = <String>[];

        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [
                _TestFileRecord(id: 'f1', name: 'one'),
                _TestFileRecord(id: 'f2', name: 'two', folder: 'a'),
              ],
              folders: {'a', 'a/b'},
              onDeleteFiles: (ids) async => deletedFiles.addAll(ids),
              onDeleteFolders: (names) async => deletedFolders.addAll(names),
              onDeleteFolder: (name) async =>
                  deletedFolders.add('single:$name'),
            ),
          ),
        );

        // Long-press folder 'a' to enter selection mode, then also select f1.
        await tester.longPress(find.byKey(const Key('fm_folder_a')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fm_file_f1')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fm_selection_delete_btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fm_batch_delete_confirm_btn')));
        await tester.pumpAndSettle();

        // The root-level file f1 goes through the file batch callback; the
        // selected folder 'a' goes through the folder batch callback.
        expect(deletedFiles, ['f1']);
        expect(deletedFolders, ['a']);
      },
    );

    testWidgets(
      'batch export calls onExportFolders with the selected folders',
      (tester) async {
        final exportedFolders = <String>[];
        String? exportTarget;

        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [_TestFileRecord(id: 'f1', name: 'one')],
              folders: {'a', 'c'},
              onExportFolders: (names, t) async {
                exportedFolders.addAll(names);
                exportTarget = t;
                return 'D:\\out';
              },
            ),
          ),
        );

        await tester.longPress(find.byKey(const Key('fm_folder_a')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fm_file_f1')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fm_selection_export_btn')));
        await tester.pumpAndSettle();

        expect(exportedFolders, ['a']);
        expect(exportTarget, '');
        // 导出成功后退出了选择模式
        expect(find.byKey(const Key('fm_close_selection_btn')), findsNothing);
      },
    );

    testWidgets(
      'batch export passes the files directory to the folder export',
      (tester) async {
        String? folderCallbackTarget;
        final exportedFolders = <String>[];
        final reservedFolders = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [_TestFileRecord(id: 'f1', name: 'one')],
              folders: {'a'},
              onExportFilesWithFolders: (ids, t, folders) async {
                reservedFolders.addAll(folders);
                return 'D:\\picked';
              },
              onExportFolders: (names, t) async {
                folderCallbackTarget = t;
                exportedFolders.addAll(names);
                return 'D:\\picked2';
              },
            ),
          ),
        );

        await tester.longPress(find.byKey(const Key('fm_folder_a')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fm_file_f1')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fm_selection_export_btn')));
        await tester.pumpAndSettle();

        // 文件夹导出必须复用文件导出选定的目录，不再弹出第二次目录选择
        expect(folderCallbackTarget, 'D:\\picked');
        expect(exportedFolders, ['a']);
        expect(reservedFolders, ['a']);
        // 导出成功后退出选择模式
        expect(find.byKey(const Key('fm_close_selection_btn')), findsNothing);
      },
    );

    testWidgets(
        'cancelling file export skips folder export and keeps selection', (
      tester,
    ) async {
      var folderExportCalls = 0;
      await tester.pumpWidget(
        _buildTestApp(
          buildBatchFM(
            records: [_TestFileRecord(id: 'f1', name: 'one')],
            folders: {'a'},
            onExportFiles: (ids, t) async => null,
            onExportFolders: (names, t) async {
              folderExportCalls++;
              return 'D:\\out';
            },
          ),
        ),
      );

      await tester.longPress(find.byKey(const Key('fm_folder_a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fm_file_f1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fm_selection_export_btn')));
      await tester.pumpAndSettle();

      expect(folderExportCalls, 0);
      // 取消后选择模式保留
      expect(find.byKey(const Key('fm_close_selection_btn')), findsOneWidget);
    });

    testWidgets(
      'becoming the active tab syncs the current folder to the shared provider',
      (tester) async {
        final folderHistory = <String>[];

        FileManagerView<_TestFileRecord> build(bool active) => buildBatchFM(
              records: [],
              folders: {'sub'},
              isActiveTab: active,
              onCurrentFolderChanged: (f) => folderHistory.add(f),
            );

        await tester.pumpWidget(_buildTestApp(build(true)));
        await tester.pumpAndSettle();
        // 进入子文件夹
        await tester.tap(find.text('sub'));
        await tester.pumpAndSettle();
        expect(folderHistory.last, 'sub');
        folderHistory.clear();

        // 切换到其他标签页（变为不活动）
        await tester.pumpWidget(_buildTestApp(build(false)));
        await tester.pump();

        // 切回本标签页（变为活动）→ 必须把当前文件夹同步到共享 Provider，
        // 否则 HomePage 的系统返回逻辑会读到其他标签页留下的过期路径
        await tester.pumpWidget(_buildTestApp(build(true)));
        await tester.pump();

        expect(folderHistory, ['sub']);
      },
    );

    testWidgets(
      'a root-level folder named "back" renders as a folder, not the back card',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(records: [], folders: {'back'}),
          ),
        );

        // 名为 back 的文件夹必须渲染为文件夹卡片
        expect(find.byKey(const Key('fm_folder_back')), findsOneWidget);
        expect(find.byKey(const Key('fm_back_item')), findsNothing);
      },
    );

    testWidgets(
      'moving a file to its current folder is a no-op with feedback',
      (tester) async {
        final moved = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [_TestFileRecord(id: 'f1', name: 'one', folder: 'a')],
              folders: {'a'},
              onMoveFile: (id, t) async => moved.add('$id->$t'),
            ),
          ),
        );

        // 进入文件夹 a
        await tester.tap(find.text('a'));
        await tester.pumpAndSettle();
        // 文件弹出菜单 → 移动
        await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('移动'));
        await tester.pumpAndSettle();

        // 在面板中选中文件夹 a
        await tester.tap(inPicker(find.text('a')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        expect(moved, isEmpty);
        expect(find.text('文件已在目标位置'), findsOneWidget);
      },
    );

    testWidgets('refresh failure shows an error snackbar', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          buildBatchFM(
            records: [],
            folders: {},
            onRefresh: () async => throw Exception('disk error'),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('fm_refresh_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('刷新失败'), findsOneWidget);
    });

    testWidgets('batch copy aborts files when a folder copy fails', (
      tester,
    ) async {
      final copiedFiles = <String>[];
      await tester.pumpWidget(
        _buildTestApp(
          buildBatchFM(
            records: [_TestFileRecord(id: 'f1', name: 'one')],
            folders: {'a', 'b', 'c'},
            onCopyFolder: (name, t) async {
              if (name == 'b') throw Exception('io');
            },
            onCopyFile: (id, t) async => copiedFiles.add(id),
          ),
        ),
      );

      await tester.longPress(find.byKey(const Key('fm_folder_a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fm_folder_b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fm_file_f1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fm_selection_copy_btn')));
      await tester.pumpAndSettle();
      await tester.tap(inPicker(find.text('c')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      // 文件夹复制失败后文件复制不得执行
      expect(copiedFiles, isEmpty);
      expect(find.textContaining('批量复制失败'), findsOneWidget);
    });

    testWidgets(
      'batch move into a target that already has a same-name folder is rejected',
      (tester) async {
        final movedFolders = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [],
              folders: {'a', 'x', 'x/a'},
              onMoveFolders: (names, t) async => movedFolders.addAll(names),
            ),
          ),
        );

        await tester.longPress(find.byKey(const Key('fm_folder_a')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fm_selection_move_btn')));
        await tester.pumpAndSettle();

        // 'x' 下已存在 'x/a'，把 a 移入 x 会合并 → 必须被拒绝
        await tester.tap(inPicker(find.text('x')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        expect(movedFolders, isEmpty);
        expect(find.text('所选文件夹在目标位置存在同名冲突或位于自身内部，操作已取消'), findsOneWidget);
        // 选择模式仍然保留
        expect(find.byKey(const Key('fm_close_selection_btn')), findsOneWidget);
      },
    );

    testWidgets(
      'inline picker refuses to create a folder that already exists',
      (tester) async {
        final created = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [],
              folders: {'a', 'c'},
              onCreateFolder: (name) async => created.add(name),
            ),
          ),
        );

        await tester.longPress(find.byKey(const Key('fm_folder_a')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fm_selection_move_btn')));
        await tester.pumpAndSettle();

        // Start inline creation with an existing folder name
        await tester
            .tap(find.byKey(const Key('folder_picker_start_create_btn')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          'c',
        );
        await tester
            .tap(find.byKey(const Key('folder_picker_create_confirm_btn')));
        await tester.pumpAndSettle();

        // No folder must be created, and a duplicate-name warning is shown.
        expect(created, isEmpty);
        expect(find.text('文件夹已存在'), findsOneWidget);
      },
    );

    testWidgets(
      'batch move accepts a folder created inside the picker as target',
      (tester) async {
        final movedFiles = <String>[];
        final movedFolders = <String>[];
        String? fileTarget;
        String? folderTarget;
        final created = <String>[];

        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [_TestFileRecord(id: 'f1', name: 'one')],
              folders: {'a', 'c'},
              onCreateFolder: (name) async => created.add(name),
              onMoveFiles: (ids, t) async {
                movedFiles.addAll(ids);
                fileTarget = t;
              },
              onMoveFolders: (names, t) async {
                movedFolders.addAll(names);
                folderTarget = t;
              },
            ),
          ),
        );

        await tester.longPress(find.byKey(const Key('fm_folder_a')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fm_file_f1')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fm_selection_move_btn')));
        await tester.pumpAndSettle();

        // Create a new folder inside the picker, then confirm it as target.
        await tester
            .tap(find.byKey(const Key('folder_picker_start_create_btn')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'd');
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const Key('folder_picker_create_confirm_btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();

        // 新建的文件夹被创建且被用作批量移动的目标
        expect(created, ['d']);
        expect(movedFiles, ['f1']);
        expect(movedFolders, ['a']);
        expect(fileTarget, 'd');
        expect(folderTarget, 'd');
      },
    );

    // ===========================================================================
    // Folder rename / create dialogs
    // ===========================================================================
    group('FileManagerView folder rename dialog', () {
      Future<void> openRenameDialog(
        WidgetTester tester, {
        required Set<String> folders,
        required Future<void> Function(String, String) onRenameFolder,
      }) async {
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [],
              folders: folders,
              onRenameFolder: onRenameFolder,
              // 使用真实的名称校验，否则空名称/非法名称无法被拦截
              manifestBridge: ManifestBridge(
                getFolderBaseName: (path) => path.split('/').last,
                getParentFolderPath: (path) {
                  if (path.isEmpty) return '';
                  final parts = path.split('/');
                  return parts.length > 1
                      ? parts.sublist(0, parts.length - 1).join('/')
                      : '';
                },
                getChildFolderPaths: (parent, allPaths) => [],
                validateFolderName: FolderPathUtils.validateFolderName,
                getAllDescendantFolderPaths: (parentPath, allPaths) => allPaths
                    .where((f) => f.startsWith('$parentPath/'))
                    .toList(),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('fm_folder_popup_a')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('重命名'));
        await tester.pumpAndSettle();
      }

      testWidgets('confirming without editing the name does not rename', (
        tester,
      ) async {
        final renamed = <String>[];
        await openRenameDialog(
          tester,
          folders: {'a'},
          onRenameFolder: (oldName, newName) async {
            renamed.add('$oldName->$newName');
          },
        );

        // 输入框预填基础名 'a'，直接确认 → 无操作
        await tester.tap(find.byKey(const Key('fm_rename_folder_confirm_btn')));
        await tester.pumpAndSettle();

        expect(renamed, isEmpty);
      });

      testWidgets('renaming onto an existing folder is rejected',
          (tester) async {
        final renamed = <String>[];
        await openRenameDialog(
          tester,
          folders: {'a', 'b'},
          onRenameFolder: (oldName, newName) async {
            renamed.add('$oldName->$newName');
          },
        );

        await tester.enterText(
          find.byKey(const Key('fm_rename_folder_input')),
          'b',
        );
        await tester.tap(find.byKey(const Key('fm_rename_folder_confirm_btn')));
        await tester.pumpAndSettle();

        expect(renamed, isEmpty);
        expect(find.text('目标位置已存在同名文件夹，操作已取消'), findsOneWidget);
      });

      testWidgets('empty name shows a validation error and does not rename', (
        tester,
      ) async {
        final renamed = <String>[];
        await openRenameDialog(
          tester,
          folders: {'a'},
          onRenameFolder: (oldName, newName) async {
            renamed.add('$oldName->$newName');
          },
        );

        await tester.enterText(
          find.byKey(const Key('fm_rename_folder_input')),
          '',
        );
        await tester.tap(find.byKey(const Key('fm_rename_folder_confirm_btn')));
        await tester.pumpAndSettle();

        expect(renamed, isEmpty);
        expect(find.text('文件夹名不能为空'), findsOneWidget);
      });

      testWidgets('valid rename calls onRenameFolder with the base name', (
        tester,
      ) async {
        final renamed = <String>[];
        await openRenameDialog(
          tester,
          folders: {'a'},
          onRenameFolder: (oldName, newName) async {
            renamed.add('$oldName->$newName');
          },
        );

        await tester.enterText(
          find.byKey(const Key('fm_rename_folder_input')),
          'new_name',
        );
        await tester.tap(find.byKey(const Key('fm_rename_folder_confirm_btn')));
        await tester.pumpAndSettle();

        expect(renamed, ['a->new_name']);
      });

      testWidgets('creating a folder with a duplicate name is rejected', (
        tester,
      ) async {
        final created = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [],
              folders: {'a'},
              onCreateFolder: (name) async => created.add(name),
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('fm_create_folder_btn')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('fm_create_folder_input')),
          'a',
        );
        await tester.tap(find.byKey(const Key('fm_create_folder_confirm_btn')));
        await tester.pumpAndSettle();

        expect(created, isEmpty);
        expect(find.text('文件夹已存在'), findsOneWidget);
      });

      testWidgets('file rename with an empty name shows an error and no-ops', (
        tester,
      ) async {
        final renamed = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [_TestFileRecord(id: 'f1', name: 'one')],
              folders: {},
              onRenameFile: (id, newName) async {
                renamed.add('$id->$newName');
              },
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('重命名'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('fm_rename_file_input')),
          '',
        );
        await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
        await tester.pumpAndSettle();

        expect(renamed, isEmpty);
        expect(find.text('文件名不能为空'), findsOneWidget);
      });

      testWidgets('file rename hint stays measured while the field edits', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [_TestFileRecord(id: 'f1', name: 'one')],
              folders: {},
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('重命名'));
        await tester.pumpAndSettle();

        final strings = AppLocalizations.of(
          tester.element(find.byKey(const Key('fm_rename_file_dialog'))),
        )!;
        final hintFinder = find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedInputHint &&
              widget.data == strings.fileManagerNewNameHint,
        );
        expect(hintFinder, findsOneWidget);
        final field = find.byKey(const Key('fm_rename_file_input'));
        final input = tester.widget<TextField>(field);
        expect(
          input.statesController,
          tester.widget<ConstrainedInputHint>(hintFinder).statesController,
        );
        await tester.enterText(field, 'new file name');
        expect(input.controller!.text, 'new file name');
        expect(
          tester.widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          ).controller.value.selection.baseOffset,
          'new file name'.length,
        );
      });

      testWidgets('captures the localized file rename input hint', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [_TestFileRecord(id: 'f1', name: 'one')],
              folders: {},
            ),
            locale: const Locale('de', 'DE'),
            textScale: 2,
            theme: ThemeData.light(useMaterial3: true),
            captureKey: const ValueKey('file-rename-hint-capture'),
          ),
        );

        await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
        await tester.pumpAndSettle();
        final strings = AppLocalizations.of(
          tester.element(find.byKey(const Key('fm_file_popup_f1'))),
        )!;
        await tester.tap(find.text(strings.fileManagerRename));
        await tester.pumpAndSettle();
        final renameField = find.byKey(const Key('fm_rename_file_input'));
        await tester.tap(renameField);
        await tester.enterText(renameField, '');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedInputHint &&
                widget.data == strings.fileManagerNewNameHint,
          ),
          findsOneWidget,
        );
        await expectLater(
          find.byKey(const ValueKey('file-rename-hint-capture')),
          matchesGoldenFile(
            '../../docs/ui-constrained-text-qa/round13-form-hints-b/file-rename-hint-de-320x640-scale2-light.png',
          ),
        );
      });

      testWidgets('file rename rejects illegal characters', (tester) async {
        final renamed = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [_TestFileRecord(id: 'f1', name: 'one')],
              folders: {},
              onRenameFile: (id, newName) async {
                renamed.add('$id->$newName');
              },
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('重命名'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('fm_rename_file_input')),
          'a/b',
        );
        await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
        await tester.pumpAndSettle();

        expect(renamed, isEmpty);
        expect(find.textContaining('不能包含'), findsOneWidget);
      });

      testWidgets('file rename calls onRenameFile with the new base name', (
        tester,
      ) async {
        final renamed = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [_TestFileRecord(id: 'f1', name: 'one')],
              folders: {},
              onRenameFile: (id, newName) async {
                renamed.add('$id->$newName');
              },
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('重命名'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('fm_rename_file_input')),
          'renamed',
        );
        await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
        await tester.pumpAndSettle();

        expect(renamed, ['f1->renamed']);
      });

      testWidgets('file rename strips a duplicate extension', (tester) async {
        final renamed = <String>[];
        await tester.pumpWidget(
          _buildTestApp(
            buildBatchFM(
              records: [_TestFileRecord(id: 'f1', name: 'one', format: 'txt')],
              folders: {},
              onRenameFile: (id, newName) async {
                renamed.add('$id->$newName');
              },
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('重命名'));
        await tester.pumpAndSettle();

        // 输入带 .txt 的名称 → 显示名不应变成 xxx.txt.txt
        await tester.enterText(
          find.byKey(const Key('fm_rename_file_input')),
          'report.txt',
        );
        await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
        await tester.pumpAndSettle();

        expect(renamed, ['f1->report']);
      });

      testWidgets(
        'file rename confirming unchanged does not rename when the stored name ends with the format',
        (tester) async {
          final renamed = <String>[];
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                // 导入 report.txt.txt 时存储名为 report.txt、格式为 txt
                records: [
                  _TestFileRecord(id: 'f1', name: 'report.txt', format: 'txt'),
                ],
                folders: {},
                onRenameFile: (id, newName) async {
                  renamed.add('$id->$newName');
                },
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重命名'));
          await tester.pumpAndSettle();

          // 直接确认（输入框预填 report.txt，未修改）
          await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
          await tester.pumpAndSettle();

          expect(renamed, isEmpty,
              reason: '确认未修改时不得把 report.txt 误判为重命名为 report');
        },
      );

      // =========================================================================
      // 文本类型文件重命名：格式下拉框（与创建页一致，仅限几种格式）
      // =========================================================================

      testWidgets(
        'file rename shows a format dropdown for listed text formats',
        (tester) async {
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                records: [
                  _TestFileRecord(id: 'f1', name: 'one', format: 'txt'),
                ],
                folders: {},
                renameFormatOptions: const ['txt', 'md', 'mmd'],
                onRenameFileWithFormat: (_, __, ___) async {},
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重命名'));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('fm_rename_file_format_dropdown')),
            findsOneWidget,
          );
          final formatLabel = find.descendant(
            of: find.byKey(const Key('fm_rename_file_format_dropdown')),
            matching: find.byWidgetPredicate(
              (widget) => widget is ConstrainedText && widget.data == '格式',
            ),
          );
          expect(formatLabel, findsOneWidget);
        },
      );

      testWidgets(
        'file rename reports a format conversion failure',
        (tester) async {
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                records: [
                  _TestFileRecord(id: 'f1', name: 'diagram', format: 'txt'),
                ],
                folders: {},
                renameFormatOptions: const ['txt', 'md', 'mmd'],
                onRenameFileWithFormat: (_, __, ___) async {
                  throw Exception('无法读取原文件内容，格式转换未完成');
                },
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重命名'));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('mmd').last);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
          await tester.pumpAndSettle();

          expect(
            find.text(
              '重命名失败: Exception: 无法读取原文件内容，格式转换未完成',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'file rename hides the format dropdown for formats not in the list',
        (tester) async {
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                // json 不在可切换格式列表中 → 不显示下拉框
                records: [
                  _TestFileRecord(id: 'f1', name: 'one', format: 'json'),
                ],
                folders: {},
                renameFormatOptions: const ['txt', 'md', 'mmd'],
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重命名'));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('fm_rename_file_format_dropdown')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'file rename passes the new format when the dropdown selection changes',
        (tester) async {
          final renamed = <String>[];
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                records: [
                  _TestFileRecord(id: 'f1', name: 'one', format: 'txt'),
                ],
                folders: {},
                renameFormatOptions: const ['txt', 'md', 'mmd'],
                onRenameFileWithFormat: (id, newName, format) async {
                  renamed.add('$id->$newName|$format');
                },
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重命名'));
          await tester.pumpAndSettle();

          // 选择 md
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('md').last);
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
          await tester.pumpAndSettle();

          expect(renamed, ['f1->one|md']);
        },
      );

      testWidgets(
        'file rename with only the format changed renames with the unchanged name',
        (tester) async {
          final renamed = <String>[];
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                records: [
                  _TestFileRecord(id: 'f1', name: 'one', format: 'txt'),
                ],
                folders: {},
                renameFormatOptions: const ['txt', 'md', 'mmd'],
                onRenameFileWithFormat: (id, newName, format) async {
                  renamed.add('$id->$newName|$format');
                },
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重命名'));
          await tester.pumpAndSettle();

          // 名称保持不变，仅把格式从 txt 切到 mmd
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('mmd').last);
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
          await tester.pumpAndSettle();

          expect(renamed, ['f1->one|mmd']);
        },
      );

      testWidgets(
        'file rename confirming with name and format unchanged is a no-op',
        (tester) async {
          final renamed = <String>[];
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                records: [
                  _TestFileRecord(id: 'f1', name: 'one', format: 'txt'),
                ],
                folders: {},
                renameFormatOptions: const ['txt', 'md', 'mmd'],
                onRenameFileWithFormat: (id, newName, format) async {
                  renamed.add('$id->$newName|$format');
                },
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重命名'));
          await tester.pumpAndSettle();

          // 不修改名称、不修改格式，直接确认 → 无操作
          await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
          await tester.pumpAndSettle();

          expect(renamed, isEmpty);
        },
      );

      testWidgets(
        'file rename keeps an imported stored name intact when only the format changes',
        (tester) async {
          final renamed = <String>[];
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                // 导入 report.txt.txt 时存储名为 report.txt、格式为 txt：
                // 名称里的 .txt 是名字的一部分，只切换格式时不能被剥掉
                records: [
                  _TestFileRecord(id: 'f1', name: 'report.txt', format: 'txt'),
                ],
                folders: {},
                renameFormatOptions: const ['txt', 'md', 'mmd'],
                onRenameFileWithFormat: (id, newName, format) async {
                  renamed.add('$id->$newName|$format');
                },
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重命名'));
          await tester.pumpAndSettle();

          // 名称保持不变，仅把格式从 txt 切到 md
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('md').last);
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
          await tester.pumpAndSettle();

          expect(renamed, ['f1->report.txt|md']);
        },
      );

      testWidgets(
        'file rename strips a typed extension that matches the newly selected format',
        (tester) async {
          final renamed = <String>[];
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                records: [
                  _TestFileRecord(id: 'f1', name: 'one', format: 'txt'),
                ],
                folders: {},
                renameFormatOptions: const ['txt', 'md', 'mmd'],
                onRenameFileWithFormat: (id, newName, format) async {
                  renamed.add('$id->$newName|$format');
                },
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重命名'));
          await tester.pumpAndSettle();

          // 输入 report.md 并把格式切到 md → 显示名应为 report.md 而不是 report.md.md
          await tester.enterText(
            find.byKey(const Key('fm_rename_file_input')),
            'report.md',
          );
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('md').last);
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
          await tester.pumpAndSettle();

          expect(renamed, ['f1->report|md']);
        },
      );

      testWidgets(
        'file rename hides the format dropdown when no onRenameFileWithFormat is provided',
        (tester) async {
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                records: [
                  _TestFileRecord(id: 'f1', name: 'one', format: 'txt'),
                ],
                folders: {},
                // 只配置了可选格式列表，但没有 onRenameFileWithFormat →
                // 下拉框不显示，避免格式变更被静默丢弃
                renameFormatOptions: const ['txt', 'md', 'mmd'],
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重命名'));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('fm_rename_file_format_dropdown')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'file rename conflict check is format-aware: same name different format is allowed',
        (tester) async {
          final renamed = <String>[];
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                // 已有 report.txt；把 notes 改名为 report 并切到 md →
                // 显示名 report.md 与 report.txt 不冲突，应允许
                records: [
                  _TestFileRecord(id: 'f1', name: 'notes', format: 'txt'),
                  _TestFileRecord(id: 'f2', name: 'report', format: 'txt'),
                ],
                folders: {},
                renameFormatOptions: const ['txt', 'md', 'mmd'],
                onRenameFileWithFormat: (id, newName, format) async {
                  renamed.add('$id->$newName|$format');
                },
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重命名'));
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(const Key('fm_rename_file_input')),
            'report',
          );
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('md').last);
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
          await tester.pumpAndSettle();

          expect(renamed, ['f1->report|md']);
        },
      );

      testWidgets(
        'file rename conflict check blocks a same name and format collision',
        (tester) async {
          final renamed = <String>[];
          await tester.pumpWidget(
            _buildTestApp(
              buildBatchFM(
                // 已有 report.md；把 report(txt) 切到 md → 显示名都是
                // report.md，必须被拒绝
                records: [
                  _TestFileRecord(id: 'f1', name: 'report', format: 'txt'),
                  _TestFileRecord(id: 'f2', name: 'report', format: 'md'),
                ],
                folders: {},
                renameFormatOptions: const ['txt', 'md', 'mmd'],
                onRenameFileWithFormat: (id, newName, format) async {
                  renamed.add('$id->$newName|$format');
                },
              ),
            ),
          );

          await tester.tap(find.byKey(const Key('fm_file_popup_f1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('重命名'));
          await tester.pumpAndSettle();

          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('md').last);
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const Key('fm_rename_confirm_btn')));
          await tester.pumpAndSettle();

          expect(renamed, isEmpty);
          expect(find.text('文件 “report.md” 已存在'), findsOneWidget);
        },
      );
    });
  });

  // ===========================================================================
  // Thumbnail cache invalidation
  // ===========================================================================
  group('FileManagerView thumbnail cache', () {
    testWidgets(
      'identical-data rebuild reuses cached thumbnails; data change rebuilds',
      (tester) async {
        var builderCalls = 0;
        Widget thumbnailBuilder(_TestFileRecord file) {
          builderCalls++;
          return Container(
            key: Key('thumb_${file.id}'),
            color: Colors.black,
          );
        }

        final config = FileManagerConfig<_TestFileRecord>(
          title: 'Test',
          showThumbnailToggle: true,
          initialGridView: true,
          fileIconBuilder: (_) =>
              const Icon(Icons.videocam, key: Key('fallback_icon')),
          fileThumbnailBuilder: thumbnailBuilder,
          onFileTap: (_) {},
        );

        FileManagerView<_TestFileRecord> buildView(
          List<_TestFileRecord> records,
        ) {
          return FileManagerView<_TestFileRecord>(
            sortedRecords: records,
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
          );
        }

        final records1 = [
          _TestFileRecord(id: 'f1'),
          _TestFileRecord(id: 'f2'),
        ];
        await tester.pumpWidget(_buildTestApp(buildView(records1)));
        expect(builderCalls, 2);

        // Rebuild with a NEW list instance holding identical records — the
        // thumbnails must come from the cache.
        final records2 = [
          _TestFileRecord(id: 'f1'),
          _TestFileRecord(id: 'f2'),
        ];
        await tester.pumpWidget(_buildTestApp(buildView(records2)));
        await tester.pump();
        expect(
          builderCalls,
          2,
          reason: 'identical data must reuse cached thumbnails',
        );

        // Adding a new record invalidates the cache and rebuilds all.
        final records3 = [
          _TestFileRecord(id: 'f1'),
          _TestFileRecord(id: 'f2'),
          _TestFileRecord(id: 'f3'),
        ];
        await tester.pumpWidget(_buildTestApp(buildView(records3)));
        await tester.pump();
        expect(builderCalls, 5);
      },
    );
  });

  // ===========================================================================
  // 3/4. file_preview_chip_test.dart (merged)
  // ===========================================================================
  group('FilePreviewChip', () {
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

    Widget buildChip({
      required Attachment attachment,
      Uint8List? imageBytes,
      VoidCallback? onRemove,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        builder: _disableTestAnimations,
        locale: const Locale('zh', 'CN'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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

    testWidgets('passes complete long file name to bounded display',
        (tester) async {
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

      final nameLabel = tester.widget<ConstrainedText>(
        find.byType(ConstrainedText).first,
      );
      expect(nameLabel.data, longName);
      expect(tester.getSize(find.byType(ConstrainedText).first).width, 64);
    });

    testWidgets('onTap is called when chip is tapped', (tester) async {
      final att = createImageAttachment();
      bool tapped = false;

      await tester.pumpWidget(buildChip(
        attachment: att,
        onTap: () => tapped = true,
      ));

      await tester.tap(find.byType(GestureDetector));
      expect(tapped, true);
    });

    testWidgets('works without onTap (no crash)', (tester) async {
      await tester.pumpWidget(buildChip(
        attachment: createImageAttachment(),
      ));

      expect(find.byType(FilePreviewChip), findsOneWidget);
    });

    testWidgets('tapping remove button fires onRemove, NOT onTap',
        (tester) async {
      bool tapped = false;
      bool removed = false;

      await tester.pumpWidget(buildChip(
        attachment: createImageAttachment(),
        onTap: () => tapped = true,
        onRemove: () => removed = true,
      ));

      await tester.tap(find.byIcon(Icons.close));
      expect(removed, true);
      expect(tapped, false);
    });
  });

  // ===========================================================================
  // Current-folder breadcrumb title (basename + ancestor dropdown) and the
  // full-path label (clipped and revealed when needed) on the fixed back row.
  // ===========================================================================

  /// True when [value] contains no lone surrogates — every high surrogate is
  /// immediately followed by its low half (i.e. no split surrogate pairs).
  bool hasNoLoneSurrogates(String value) {
    for (var i = 0; i < value.length; i++) {
      final unit = value.codeUnitAt(i);
      if (unit >= 0xDC00 && unit <= 0xDFFF) return false; // lone low surrogate
      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (i + 1 >= value.length) return false; // high surrogate without pair
        final next = value.codeUnitAt(i + 1);
        if (next < 0xDC00 || next > 0xDFFF) return false;
        i++; // skip the completed pair
      }
    }
    return true;
  }

  group('FileManagerView current-folder breadcrumb title', () {
    /// Helper: a FileManagerView wrapped for tests with the nested bridge.
    Widget buildBreadcrumbFM({
      required Set<String> folders,
      required FileManagerConfig<_TestFileRecord> config,
      List<_TestFileRecord> records = const [],
    }) {
      return _buildTestApp(
        FileManagerView<_TestFileRecord>(
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
          manifestBridge: fileManagerNavManifestBridge,
        ),
      );
    }

    FileManagerConfig<_TestFileRecord> breadcrumbConfig({
      void Function(String)? onCurrentFolderChanged,
    }) {
      return FileManagerConfig<_TestFileRecord>(
        title: 'Test',
        fileIconBuilder: (_) =>
            const Icon(Icons.videocam, key: Key('fallback_icon')),
        onFileTap: (_) {},
        onCurrentFolderChanged: onCurrentFolderChanged,
      );
    }

    testWidgets(
      'AppBar shows the current folder basename with a dropdown instead of the full path',
      (tester) async {
        await tester.pumpWidget(
          buildBreadcrumbFM(
            folders: {'photos', 'photos/vacation'},
            config: breadcrumbConfig(),
          ),
        );

        // At root the plain config title is shown — no dropdown
        expect(find.byKey(const Key('fm_folder_breadcrumb_btn')), findsNothing);

        await tester.tap(find.text('photos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('vacation'));
        await tester.pumpAndSettle();

        // Title shows only the current folder basename + dropdown arrow,
        // never the full path. (The full path may legitimately appear on
        // the fixed back row's right side, so scope this check to the AppBar.)
        expect(
          find.byKey(const Key('fm_folder_breadcrumb_btn')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('fm_folder_breadcrumb_btn')),
            matching: find.text('vacation'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('photos/vacation'),
          ),
          findsNothing,
        );
        expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      },
    );

    testWidgets(
      'breadcrumb dropdown lists only ancestor folders in root-to-current order',
      (tester) async {
        await tester.pumpWidget(
          buildBreadcrumbFM(
            folders: {'photos', 'photos/vacation', 'photos/other'},
            config: breadcrumbConfig(),
          ),
        );

        await tester.tap(find.text('photos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('vacation'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('fm_folder_breadcrumb_btn')));
        await tester.pumpAndSettle();

        // Chain: 根目录 → photos → vacation (current)
        expect(find.text('根目录'), findsOneWidget);
        expect(find.text('photos'), findsOneWidget);
        final vacationMenuItem = find.descendant(
          of: find.bySubtype<PopupMenuItem<String>>(),
          matching: find.text('vacation'),
        );
        expect(vacationMenuItem, findsOneWidget);
        // 'photos/other' is a sibling of the current folder — must be excluded
        expect(find.text('other'), findsNothing);

        // Ordered root → current (top to bottom)
        final rootY = tester.getTopLeft(find.text('根目录')).dy;
        final photosY = tester.getTopLeft(find.text('photos')).dy;
        final vacationY = tester.getTopLeft(vacationMenuItem).dy;
        expect(rootY, lessThan(photosY));
        expect(photosY, lessThan(vacationY));
      },
    );

    testWidgets(
      'tapping an ancestor in the breadcrumb dropdown navigates to it',
      (tester) async {
        String? capturedFolder;

        await tester.pumpWidget(
          buildBreadcrumbFM(
            folders: {'photos', 'photos/vacation'},
            config: breadcrumbConfig(onCurrentFolderChanged: (f) {
              capturedFolder = f;
            }),
          ),
        );

        await tester.tap(find.text('photos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('vacation'));
        await tester.pumpAndSettle();
        expect(capturedFolder, 'photos/vacation');

        // The current-folder item is disabled — tapping it does not navigate
        await tester.tap(find.byKey(const Key('fm_folder_breadcrumb_btn')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.bySubtype<PopupMenuItem<String>>(),
            matching: find.text('vacation'),
          ),
        );
        await tester.pumpAndSettle();
        expect(capturedFolder, 'photos/vacation');

        // Jump to the root from the dropdown
        await tester.tap(find.text('根目录'));
        await tester.pumpAndSettle();
        expect(capturedFolder, '');

        // Re-enter and jump to the direct parent
        await tester.tap(find.text('photos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('vacation'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('fm_folder_breadcrumb_btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('photos'));
        await tester.pumpAndSettle();
        expect(capturedFolder, 'photos');
      },
    );

    testWidgets(
      'back item right side shows the full current folder path',
      (tester) async {
        await tester.pumpWidget(
          buildBreadcrumbFM(
            folders: {'photos', 'photos/vacation'},
            config: breadcrumbConfig(),
            // The fixed back row always shows the full path on its right side,
            // regardless of whether the folder has content.
            records: [
              _TestFileRecord(
                id: 'beach',
                name: 'beach',
                format: 'mp4',
                folder: 'photos/vacation',
              ),
            ],
          ),
        );

        await tester.tap(find.text('photos'));
        await tester.pumpAndSettle();
        // One level deep — the right side shows the full path ('photos')
        expect(
          find.descendant(
            of: find.byKey(const Key('fm_back_item')),
            matching: find.text('photos'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('vacation'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const Key('fm_back_item')),
            matching: find.text('photos/vacation'),
          ),
          findsOneWidget,
        );
        // The previous "当前：" prefix is gone
        expect(find.textContaining('当前：'), findsNothing);
      },
    );

    testWidgets(
      'back item keeps the complete path available when it is clipped',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(340, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const fullPath = 'a/b/c/d/eeeeeeeeeeeeeeee';
        await tester.pumpWidget(
          buildBreadcrumbFM(
            folders: {'a', 'a/b', 'a/b/c', 'a/b/c/d', fullPath},
            config: breadcrumbConfig(),
            records: [
              _TestFileRecord(
                id: 'beach',
                name: 'beach',
                format: 'mp4',
                folder: fullPath,
              ),
            ],
          ),
        );

        for (final level in ['a', 'b', 'c', 'd', 'eeeeeeeeeeeeeeee']) {
          await tester.tap(find.text(level));
          await tester.pumpAndSettle();
        }

        final path = find.descendant(
          of: find.byKey(const Key('fm_back_item')),
          matching: find.byType(ConstrainedText),
        );
        final pathText = tester.widget<ConstrainedText>(path.last);
        expect(pathText.data, fullPath);
        expect(pathText.textAlign, TextAlign.end);
        expect(pathText.maxLines, 1);
        expect(pathText.overflow, TextOverflow.clip);
      },
    );

    testWidgets(
      'emoji folder path remains complete when clipped',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(340, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const deepest = '😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀😀';
        const fullPath = 'a/b/c/d/$deepest';
        await tester.pumpWidget(
          buildBreadcrumbFM(
            folders: {'a', 'a/b', 'a/b/c', 'a/b/c/d', fullPath},
            config: breadcrumbConfig(),
            records: [
              _TestFileRecord(
                id: 'beach',
                name: 'beach',
                format: 'mp4',
                folder: fullPath,
              ),
            ],
          ),
        );

        for (final level in ['a', 'b', 'c', 'd', deepest]) {
          await tester.tap(find.text(level));
          await tester.pumpAndSettle();
        }

        final path = find.descendant(
          of: find.byKey(const Key('fm_back_item')),
          matching: find.byType(ConstrainedText),
        );
        final pathText = tester.widget<ConstrainedText>(path.last);
        expect(pathText.data, fullPath);
        expect(hasNoLoneSurrogates(pathText.data), isTrue);
        expect(pathText.data.endsWith(deepest), isTrue);
      },
    );

    testWidgets(
      'selection mode replaces the breadcrumb title with the selection count',
      (tester) async {
        await tester.pumpWidget(
          buildBreadcrumbFM(
            folders: {'photos', 'photos/vacation'},
            config: breadcrumbConfig(),
            records: [
              _TestFileRecord(
                id: 'beach',
                name: 'beach',
                format: 'mp4',
                folder: 'photos/vacation',
              ),
            ],
          ),
        );

        await tester.tap(find.text('photos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('vacation'));
        await tester.pumpAndSettle();

        await tester.longPress(find.byKey(const Key('fm_file_beach')));
        await tester.pumpAndSettle();

        expect(find.text('已选择 1 项'), findsOneWidget);
        expect(find.byKey(const Key('fm_folder_breadcrumb_btn')), findsNothing);
      },
    );
  });

  group('FileManagerView localized narrow-layout audit', () {
    for (final locale in [const Locale('de'), const Locale('pt', 'BR')]) {
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        for (final grid in [false, true]) {
          for (final scale in [1.0, 1.6]) {
            testWidgets(
                '${locale.toLanguageTag()} ${theme.brightness.name} '
                '${grid ? 'grid' : 'list'} at scale $scale', (tester) async {
              final narrow = scale > 1;
              await tester.binding.setSurfaceSize(
                narrow ? const Size(320, 640) : const Size(800, 640),
              );
              addTearDown(() => tester.binding.setSurfaceSize(null));
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );

              final config = FileManagerConfig<_TestFileRecord>(
                title: 'Files',
                showThumbnailToggle: true,
                initialGridView: grid,
                fileThumbnailBuilder: (_) => const ColoredBox(
                  color: Colors.amber,
                  child: SizedBox.expand(),
                ),
                fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
                onFileTap: (_) {},
              );
              const alternateFolder =
                  'alternate-folder-path-with-a-long-label-for-audit';
              await tester.pumpWidget(
                _buildFileManagerApp(
                  config: config,
                  folders: const {
                    'very long folder title that exercises wrapping',
                    alternateFolder,
                  },
                  manifestBridge: testManifestBridge,
                  records: [
                    _TestFileRecord(
                      id: 'audit_file',
                      name:
                          'very long file title for constrained display labels',
                      format: 'mmd',
                      folder: '',
                      size: 123456789,
                      createdAt: DateTime.now(),
                    ),
                  ],
                  locale: locale,
                  theme: theme,
                ),
              );
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'locale=$locale theme=${theme.brightness} grid=$grid scale=$scale',
              );
              if (scale == 1.6) {
                await tester.tap(
                  find.byKey(
                    Key(
                      grid
                          ? 'fm_grid_file_popup_audit_file'
                          : 'fm_file_popup_audit_file',
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'file menu locale=$locale grid=$grid',
                );
                await tester.tapAt(const Offset(5, 400));
                await tester.pumpAndSettle();

                const folderName =
                    'very long folder title that exercises wrapping';
                await tester.tap(
                  find.byKey(
                    Key(
                      grid
                          ? 'fm_grid_folder_popup_$folderName'
                          : 'fm_folder_popup_$folderName',
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'folder menu locale=$locale grid=$grid',
                );
                await tester.tapAt(const Offset(5, 400));
                await tester.pumpAndSettle();

                await tester.tap(find.byKey(const Key('fm_sort_btn')));
                await tester.pumpAndSettle();
                expect(
                  tester.takeException(),
                  isNull,
                  reason: 'sort menu locale=$locale grid=$grid',
                );
              }
            });
          }
        }
      }
    }
  });

  testWidgets('TTS format badge grows at large text scales without overlap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> pumpAtScale(double scale) async {
      final config = FileManagerConfig<_TestFileRecord>(
        title: 'TTS files',
        allowFileIconExpansion: true,
        fileIconBuilder: (_) => Builder(
          builder: (context) => Container(
            key: const Key('tts_format_badge'),
            width: MediaQuery.textScalerOf(context)
                .scale(24)
                .clamp(44.0, 112.0)
                .toDouble(),
            constraints: const BoxConstraints(minHeight: 44),
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: const Center(
              child: Text(
                'FLAC',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        onFileTap: (_) {},
      );
      await tester.pumpWidget(
        _buildFileManagerApp(
          config: config,
          folders: const {},
          manifestBridge: testManifestBridge,
          records: [_TestFileRecord(id: 'tts-record', format: 'flac')],
          textScale: scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await pumpAtScale(1);
    final badgeDecoration = find.descendant(
      of: find.byKey(const Key('tts_format_badge')),
      matching: find.byType(DecoratedBox),
    );
    expect(
      tester.getSize(badgeDecoration),
      const Size(44, 44),
    );

    await pumpAtScale(4);
    final badge = find.descendant(
      of: find.byKey(const Key('tts_format_badge')),
      matching: find.byType(DecoratedBox),
    );
    final fileName = find.text('test.flac');
    expect(find.text('FLAC'), findsOneWidget);
    expect(tester.getSize(badge).width, greaterThan(44));
    expect(tester.getSize(badge).height, greaterThan(44));
    expect(tester.getRect(badge).overlaps(tester.getRect(fileName)), isFalse);
    expect(
      tester.getRect(badge).right,
      lessThanOrEqualTo(tester.getRect(fileName).left),
    );
    final menu = find.byKey(const Key('fm_file_popup_tts-record'));
    expect(tester.getRect(badge).overlaps(tester.getRect(menu)), isFalse);
  });
}
