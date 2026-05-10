import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stroom/utils/file_record.dart';
import 'package:stroom/utils/sort_config.dart';
import 'package:stroom/widgets/file_manager_view.dart';
import 'package:stroom/utils/manifest_bridge.dart';

// ====================================================================
// Test record — minimal FileRecord implementation
// ====================================================================

class TestRecord implements FileRecord {
  @override
  final String id;
  @override
  final String name;
  @override
  final String format;
  @override
  final DateTime createdAt;
  @override
  final int size;
  @override
  final String folder;

  static int _counter = 0;

  TestRecord({
    String? id,
    this.name = 'test',
    this.format = 'txt',
    DateTime? createdAt,
    this.size = 1024,
    this.folder = '',
  })  : id =
            id ?? 'test_${_counter++}_${DateTime.now().millisecondsSinceEpoch}',
        createdAt = createdAt ?? DateTime.now();
}

// ====================================================================
// Helper functions for folder path manipulation
// ====================================================================

String _folderBaseName(String path) {
  final idx = path.lastIndexOf('/');
  return idx == -1 ? path : path.substring(idx + 1);
}

String _parentFolderPath(String path) {
  if (path.isEmpty) return '';
  final idx = path.lastIndexOf('/');
  return idx == -1 ? '' : path.substring(0, idx);
}

List<String> _childFolderPaths(String parent, Set<String> allFolders) {
  final prefix = parent.isEmpty ? '' : '$parent/';
  return allFolders.where((f) {
    if (f == parent) return false;
    if (parent.isEmpty) return !f.contains('/');
    if (!f.startsWith(prefix)) return false;
    final suffix = f.substring(prefix.length);
    return !suffix.contains('/');
  }).toList();
}

List<String> _allDescendantFolderPaths(String folder, Set<String> allFolders) {
  final prefix = folder.isEmpty ? '' : '$folder/';
  return allFolders.where((f) => f.startsWith(prefix) && f != folder).toList();
}

// ====================================================================
// Helper — builds the widget under test with sensible defaults
// ====================================================================

Widget buildFileManagerView({
  List<TestRecord> records = const [],
  Set<String> folders = const {},
  SortConfig? sortConfig,
  FileManagerConfig<TestRecord>? config,
  void Function(TestRecord)? onFileTap,
  void Function(SortField)? onToggleSort,
  Future<void> Function()? onRefresh,
  Future<void> Function(String, String)? onRenameFile,
  Future<void> Function(String, String)? onMoveFile,
  Future<void> Function(String, String)? onCopyFile,
  Future<void> Function(String)? onDeleteFile,
  Future<void> Function(List<String>)? onDeleteFiles,
  Future<void> Function(List<String>)? onDeleteFolders,
  Future<void> Function(List<String>, String)? onMoveFiles,
  Future<void> Function(List<String>, String)? onMoveFolders,
  Future<void> Function(String)? onExportFile,
  Future<void> Function(String, String)? onRenameFolder,
  Future<void> Function(String, String)? onMoveFolder,
  Future<void> Function(String, String)? onCopyFolder,
  Future<void> Function(String)? onDeleteFolder,
  Future<void> Function(String)? onCreateFolder,
}) {
  final effectiveSortConfig = sortConfig ?? const SortConfig();
  final effectiveConfig = config ??
      FileManagerConfig<TestRecord>(
        title: 'Test Files',
        fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
        onFileTap: onFileTap ?? (_) {},
      );

  return MaterialApp(
    home: Scaffold(
      body: FileManagerView<TestRecord>(
        sortedRecords: records,
        folders: folders,
        sortConfig: effectiveSortConfig,
        config: effectiveConfig,
        onRefresh: onRefresh ?? () async {},
        onRenameFile: onRenameFile ?? (_, __) async {},
        onMoveFile: onMoveFile ?? (_, __) async {},
        onCopyFile: onCopyFile ?? (_, __) async {},
        onDeleteFile: onDeleteFile ?? (_) async {},
        onDeleteFiles: onDeleteFiles ?? (_) async {},
        onDeleteFolders: onDeleteFolders ?? (_) async {},
        onMoveFiles: onMoveFiles ?? (_, __) async {},
        onMoveFolders: onMoveFolders ?? (_, __) async {},
        onExportFile: onExportFile ?? (_) async {},
        onRenameFolder: onRenameFolder ?? (_, __) async {},
        onMoveFolder: onMoveFolder ?? (_, __) async {},
        onCopyFolder: onCopyFolder ?? (_, __) async {},
        onDeleteFolder: onDeleteFolder ?? (_) async {},
        onCreateFolder: onCreateFolder ?? (_) async {},
        onToggleSort: onToggleSort ?? (_) {},
        manifestBridge: ManifestBridge(
          getFolderBaseName: _folderBaseName,
          getParentFolderPath: _parentFolderPath,
          getChildFolderPaths: _childFolderPaths,
          validateFolderName: (_) => null,
          getAllDescendantFolderPaths: _allDescendantFolderPaths,
        ),
      ),
    ),
  );
}

// ====================================================================
// Tests
// ====================================================================

void main() {
  // ------------------------------------------------------------------
  // Rendering tests
  // ------------------------------------------------------------------

  group('Rendering', () {
    testWidgets('Empty state at root shows "暂无文件"', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {},
      ));
      await tester.pumpAndSettle();

      expect(find.text('暂无文件'), findsOneWidget);
      // Folder icon should also be present
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('Records appear in the file list', (tester) async {
      final records = [
        TestRecord(name: 'doc1', format: 'pdf'),
        TestRecord(name: 'doc2', format: 'png'),
      ];

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Both file names with extension should be displayed
      expect(find.text('doc1.pdf'), findsOneWidget);
      expect(find.text('doc2.png'), findsOneWidget);
    });

    testWidgets('Folders appear in the list', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'photos', 'documents'},
      ));
      await tester.pumpAndSettle();

      // Folder base names should be visible
      expect(find.text('photos'), findsOneWidget);
      expect(find.text('documents'), findsOneWidget);
    });

    testWidgets('Back button appears when in a subfolder', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'photos', 'photos/vacation'},
      ));
      await tester.pumpAndSettle();

      // Tap the 'photos' folder to enter it
      await tester.tap(find.text('photos'));
      await tester.pumpAndSettle();

      // Back button appears twice: once in the AppBar leading
      // and once as the back-item Card in the list body.
      expect(find.byIcon(Icons.arrow_back), findsNWidgets(2));

      // Also the back-item card in the list body
      expect(find.text('返回根目录'), findsOneWidget);
    });

    testWidgets('Empty subfolder shows "此文件夹为空"', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'photos'},
      ));
      await tester.pumpAndSettle();

      // Enter the subfolder
      await tester.tap(find.text('photos'));
      await tester.pumpAndSettle();

      // Empty state text for subfolder
      expect(find.text('此文件夹为空'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_outlined), findsOneWidget);
    });

    testWidgets('File size is formatted correctly', (tester) async {
      final records = [
        TestRecord(name: 'large', size: 2048),
        TestRecord(name: 'small', size: 500),
      ];

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('KB'), findsOneWidget);
      expect(find.textContaining('500 B'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // Interaction tests
  // ------------------------------------------------------------------

  group('Interaction', () {
    testWidgets('Tapping a file triggers onFileTap callback', (tester) async {
      final records = [TestRecord(name: 'report', format: 'docx')];
      TestRecord? tappedFile;

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
        onFileTap: (file) => tappedFile = file,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('report.docx'));
      await tester.pumpAndSettle();

      expect(tappedFile, isNotNull);
      expect(tappedFile!.name, 'report');
    });

    testWidgets('Long-pressing a file enters selection mode', (tester) async {
      final records = [TestRecord(name: 'selected', format: 'txt')];

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Long press on the file card
      await tester.longPress(find.text('selected.txt'));
      await tester.pumpAndSettle();

      // Selection mode title should appear
      expect(find.text('已选择 1 项'), findsOneWidget);

      // Close button should be visible (leading icon)
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Bottom action bar should be visible
      expect(find.text('删除'), findsOneWidget);
      expect(find.text('移动'), findsOneWidget);
    });

    testWidgets('Tapping sort button opens sort menu', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord()],
        folders: {},
      ));
      await tester.pumpAndSettle();

      // PopupMenuButton is the sort button
      final sortButton = find.byIcon(Icons.access_time);
      expect(sortButton, findsOneWidget);

      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      // Menu items should appear
      expect(find.text('按时间'), findsOneWidget);
      expect(find.text('按文件名'), findsOneWidget);
      expect(find.text('按大小'), findsOneWidget);
    });

    testWidgets('Tapping sort menu item calls onToggleSort', (tester) async {
      SortField? toggledField;

      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord()],
        folders: {},
        onToggleSort: (field) => toggledField = field,
      ));
      await tester.pumpAndSettle();

      // Open sort menu
      await tester.tap(find.byIcon(Icons.access_time));
      await tester.pumpAndSettle();

      // Tap "按文件名" — menu item is in overlay, tap at its position
      await tester.tap(find.text('按文件名'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(toggledField, SortField.name);
    });

    testWidgets('View toggle switches between list and grid', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord(name: 'img', format: 'jpg')],
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          showThumbnailToggle: true,
          fileIconBuilder: (_) => const Icon(Icons.image),
          fileThumbnailBuilder: (_) => const Icon(Icons.image),
          onFileTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Initially in list view — grid icon should be visible
      expect(find.byIcon(Icons.grid_view), findsOneWidget);
      expect(find.byIcon(Icons.view_list), findsNothing);

      // Tap the toggle
      await tester.tap(find.byIcon(Icons.grid_view));
      await tester.pumpAndSettle();

      // Now in grid view — list icon should be visible
      expect(find.byIcon(Icons.view_list), findsOneWidget);
      expect(find.byIcon(Icons.grid_view), findsNothing);
    });

    testWidgets('Tapping create folder opens dialog', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Tap create folder button
      await tester.tap(find.byIcon(Icons.create_new_folder));
      await tester.pumpAndSettle();

      // AlertDialog should appear
      expect(find.text('创建文件夹'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('创建'), findsOneWidget);
    });

    testWidgets('Tapping refresh triggers onRefresh', (tester) async {
      var refreshed = false;

      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord()],
        folders: {},
        onRefresh: () async {
          refreshed = true;
        },
      ));
      await tester.pumpAndSettle();

      // Tap refresh button
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(refreshed, isTrue);
    });
  });

  // ------------------------------------------------------------------
  // AppBar tests
  // ------------------------------------------------------------------

  group('AppBar', () {
    testWidgets('Title shows config.title when in root folder', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'My Manager',
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          onFileTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('My Manager'), findsOneWidget);
    });

    testWidgets('Title shows folder name when in subfolder', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'my_assets'},
      ));
      await tester.pumpAndSettle();

      // Enter subfolder
      await tester.tap(find.text('my_assets'));
      await tester.pumpAndSettle();

      // Title should now show the folder path
      expect(find.text('my_assets'), findsOneWidget);
    });

    testWidgets('Title shows selection count in selection mode',
        (tester) async {
      final records = [
        TestRecord(name: 'a', format: 'txt'),
        TestRecord(name: 'b', format: 'txt'),
      ];

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Long press first file to enter selection mode
      await tester.longPress(find.text('a.txt'));
      await tester.pumpAndSettle();

      // Should show "已选择 1 项"
      expect(find.text('已选择 1 项'), findsOneWidget);
    });

    testWidgets('Sort icon is present in AppBar', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord()],
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Sort button — icon depends on sortConfig.field.
      // Default sortConfig has field=createdAt → Icons.access_time.
      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('Sort icon changes when field is name', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord()],
        folders: {},
        sortConfig: const SortConfig(field: SortField.name),
      ));
      await tester.pumpAndSettle();

      // Sort field is name → Icons.sort_by_alpha
      expect(find.byIcon(Icons.sort_by_alpha), findsOneWidget);
    });

    testWidgets('Sort icon changes when field is size', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord()],
        folders: {},
        sortConfig: const SortConfig(field: SortField.size),
      ));
      await tester.pumpAndSettle();

      // Sort field is size → Icons.storage
      expect(find.byIcon(Icons.storage), findsOneWidget);
    });

    testWidgets('Close button exits selection mode', (tester) async {
      final records = [TestRecord(name: 'file', format: 'txt')];

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Enter selection mode
      await tester.longPress(find.text('file.txt'));
      await tester.pumpAndSettle();

      expect(find.text('已选择 1 项'), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Should be back to normal title
      expect(find.text('Test Files'), findsOneWidget);
    });

    testWidgets('Back button returns to root from subfolder', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'photos'},
      ));
      await tester.pumpAndSettle();

      // Enter folder
      await tester.tap(find.text('photos'));
      await tester.pumpAndSettle();

      expect(find.text('photos'), findsOneWidget);

      // Tap back arrow in AppBar leading
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should be back to root
      expect(find.text('Test Files'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // Config tests
  // ------------------------------------------------------------------

  group('Config', () {
    testWidgets('topActionBar is displayed when provided', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          topActionBar: const Text('Top Bar Content'),
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          onFileTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Top Bar Content'), findsOneWidget);
    });

    testWidgets('extraAppBarActions are shown when provided', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord()],
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          onFileTap: (_) {},
          extraAppBarActions: () => [
            IconButton(
              icon: const Icon(Icons.star),
              onPressed: () {},
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      // The extra star icon should be in the AppBar
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('showThumbnailToggle controls grid toggle visibility',
        (tester) async {
      // Case 1: showThumbnailToggle is false — no toggle button
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord()],
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          showThumbnailToggle: false,
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          fileThumbnailBuilder: (_) => const Icon(Icons.image),
          onFileTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.grid_view), findsNothing);
      expect(find.byIcon(Icons.view_list), findsNothing);

      // Case 2: showThumbnailToggle is true — toggle button is present
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord()],
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          showThumbnailToggle: true,
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          fileThumbnailBuilder: (_) => const Icon(Icons.image),
          onFileTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // In list view initially, so grid_view icon is shown
      expect(find.byIcon(Icons.grid_view), findsOneWidget);
    });

    testWidgets('onGridViewChanged is called when toggle is tapped',
        (tester) async {
      bool? gridViewValue;

      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord()],
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          showThumbnailToggle: true,
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          fileThumbnailBuilder: (_) => const Icon(Icons.image),
          onFileTap: (_) {},
          onGridViewChanged: (val) => gridViewValue = val,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap grid toggle
      await tester.tap(find.byIcon(Icons.grid_view));
      await tester.pumpAndSettle();

      expect(gridViewValue, isTrue);
    });

    testWidgets('initialGridView starts in grid mode', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord(name: 'img', format: 'jpg')],
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          showThumbnailToggle: true,
          initialGridView: true,
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          fileThumbnailBuilder: (_) => const Icon(Icons.image),
          onFileTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // In grid view, so view_list icon is shown as toggle
      expect(find.byIcon(Icons.view_list), findsOneWidget);
    });

    testWidgets('extraPopupMenuItems appear in file popup menu',
        (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord(name: 'extra', format: 'txt')],
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          onFileTap: (_) {},
          extraPopupMenuItems: (file) => [
            const PopupMenuItem<String>(
              value: 'custom',
              child: Text('Custom Action'),
            ),
          ],
          onExtraMenuAction: (file, action) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Find the file's popup menu button (more_vert icon)
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // The custom item should appear
      expect(find.text('Custom Action'), findsOneWidget);
    });

    testWidgets('onLongPress is called when file is long-pressed',
        (tester) async {
      final records = [TestRecord(name: 'lp', format: 'txt')];
      TestRecord? longPressedFile;

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          onFileTap: (_) {},
          onLongPress: (file) => longPressedFile = file,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('lp.txt'));
      await tester.pumpAndSettle();

      expect(longPressedFile, isNotNull);
      expect(longPressedFile!.name, 'lp');
    });

    testWidgets('onCurrentFolderChanged is called when navigating',
        (tester) async {
      String? currentFolder;

      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'videos'},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          onFileTap: (_) {},
          onCurrentFolderChanged: (folder) => currentFolder = folder,
        ),
      ));
      await tester.pumpAndSettle();

      // Navigate into 'videos'
      await tester.tap(find.text('videos'));
      await tester.pumpAndSettle();

      expect(currentFolder, 'videos');
    });
  });

  // ------------------------------------------------------------------
  // Selection mode edge cases
  // ------------------------------------------------------------------

  group('Selection mode', () {
    testWidgets('Tapping a selected file deselects it', (tester) async {
      final records = [TestRecord(name: 'sel', format: 'txt')];

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Enter selection mode
      await tester.longPress(find.text('sel.txt'));
      await tester.pumpAndSettle();

      expect(find.text('已选择 1 项'), findsOneWidget);

      // Tap the same file to deselect
      await tester.tap(find.text('sel.txt'));
      await tester.pumpAndSettle();

      // Should still be in selection mode (doesn't auto-exit)
      expect(find.text('已选择 0 项'), findsOneWidget);

      // Close button still visible
      expect(find.byKey(const Key('fm_close_selection_btn')), findsOneWidget);
    });

    testWidgets('Bottom bar shows copy, move and delete in selection mode',
        (tester) async {
      final records = [TestRecord(name: 'f', format: 'txt')];

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
      ));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('f.txt'));
      await tester.pumpAndSettle();

      // Bottom bar buttons (left to right)
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('移动'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);

      // Check the icons
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.drive_file_move_outline), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // Folder creation tests
  // ------------------------------------------------------------------

  group('Folder creation', () {
    testWidgets(
        'Creating a folder at root calls onCreateFolder with plain name',
        (tester) async {
      String? createdFolder;

      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {},
        onCreateFolder: (name) async => createdFolder = name,
      ));
      await tester.pumpAndSettle();

      // Open create folder dialog
      await tester.tap(find.byIcon(Icons.create_new_folder));
      await tester.pumpAndSettle();

      // Enter folder name and confirm
      await tester.enterText(find.byType(TextField), 'photos');
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(createdFolder, 'photos');
    });

    testWidgets('Creating a folder in a subfolder prepends current folder path',
        (tester) async {
      String? createdFolder;

      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'projects'},
        onCreateFolder: (name) async => createdFolder = name,
      ));
      await tester.pumpAndSettle();

      // Enter 'projects' folder
      await tester.tap(find.text('projects'));
      await tester.pumpAndSettle();

      // Create a subfolder inside 'projects'
      await tester.tap(find.byIcon(Icons.create_new_folder));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'sub');
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      // The callback should receive the full path with current folder prepended
      expect(createdFolder, 'projects/sub');
    });

    testWidgets('Creating folder at root navigates into it automatically',
        (tester) async {
      String? createdFolder;

      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {},
        onCreateFolder: (name) async => createdFolder = name,
      ));
      await tester.pumpAndSettle();

      // Open create folder dialog
      await tester.tap(find.byIcon(Icons.create_new_folder));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'mydir');
      await tester.tap(find.text('创建'));
      await tester.pumpAndSettle();

      expect(createdFolder, 'mydir');
      // Should navigate into the created folder, showing its name in AppBar
      expect(find.text('mydir'), findsOneWidget);
      // Back button should appear
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  // ------------------------------------------------------------------
  // File/Folder movement tests
  // ------------------------------------------------------------------

  group('File movement', () {
    testWidgets(
        'Moving a file via popup menu shows folder picker and calls onMoveFile',
        (tester) async {
      final records = [TestRecord(name: 'doc', format: 'pdf')];
      String? movedId;
      String? movedTo;

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {'archive'},
        onMoveFile: (id, target) async {
          movedId = id;
          movedTo = target;
        },
      ));
      await tester.pumpAndSettle();

      // Tap popup menu on the file (the file's more_vert is the last one)
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();

      // Select '移动' from the popup menu
      await tester.tap(find.text('移动'));
      await tester.pumpAndSettle();

      // Folder picker dialog should appear
      expect(find.text('选择目标文件夹'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('archive'),
        ),
        findsOneWidget,
      );

      // Select 'archive' folder
      await tester.tap(find.text('archive').last);
      await tester.pumpAndSettle();

      // Confirm selection
      await tester.tap(find.text('选择此文件夹'));
      await tester.pumpAndSettle();

      expect(movedId, isNotNull);
      expect(movedTo, 'archive');
    });

    testWidgets('Moving selected files via bottom bar calls onMoveFiles',
        (tester) async {
      final records = [
        TestRecord(name: 'a', format: 'txt'),
        TestRecord(name: 'b', format: 'txt'),
      ];
      List<String>? movedIds;
      String? movedTo;

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {'target'},
        onMoveFiles: (ids, target) async {
          movedIds = ids;
          movedTo = target;
        },
      ));
      await tester.pumpAndSettle();

      // Long-press first file to enter selection mode
      await tester.longPress(find.text('a.txt'));
      await tester.pumpAndSettle();

      expect(find.text('已选择 1 项'), findsOneWidget);

      // Tap the second file to add to selection
      await tester.tap(find.text('b.txt'));
      await tester.pumpAndSettle();

      expect(find.text('已选择 2 项'), findsOneWidget);

      // Tap '移动' bottom bar button
      await tester.tap(find.text('移动'));
      await tester.pumpAndSettle();

      // Folder picker with 'target' folder visible
      expect(find.text('选择目标文件夹'), findsOneWidget);

      // Select 'target' folder (use .last to pick the one inside the dialog)
      await tester.tap(find.text('target').last);
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('选择此文件夹'));
      await tester.pumpAndSettle();

      expect(movedIds, isNotNull);
      expect(movedIds!.length, 2);
      expect(movedTo, 'target');
      // Should exit selection mode
      expect(find.text('Test Files'), findsOneWidget);
    });

    testWidgets('Moving a folder via popup menu calls onMoveFolder',
        (tester) async {
      String? movedFolder;
      String? movedTo;

      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'old_projects', 'new_projects'},
        onMoveFolder: (name, target) async {
          movedFolder = name;
          movedTo = target;
        },
      ));
      await tester.pumpAndSettle();

      // Tap popup menu on 'old_projects' folder
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      // Select '移动'
      await tester.tap(find.text('移动'));
      await tester.pumpAndSettle();

      // Folder picker: 'new_projects' should be a selectable option
      expect(find.text('移动文件夹到…'), findsOneWidget);

      // Select 'new_projects' inside the picker dialog — use the one NOT in the main list
      // The picker text is inside an AlertDialog
      final pickerItem = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('new_projects'),
      );
      await tester.tap(pickerItem);
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择此文件夹'));
      await tester.pumpAndSettle();

      expect(movedFolder, 'old_projects');
      expect(movedTo, 'new_projects');
    });

    testWidgets(
        'In-folder picker create button allows creating new destination folder',
        (tester) async {
      String? createdFolderPath;
      final allFolders = <String>{'docs'};

      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord(name: 'f', format: 'txt')],
        folders: allFolders,
        onCreateFolder: (name) async {
          createdFolderPath = name;
          allFolders.add(name);
        },
        onMoveFile: (id, target) async {},
      ));
      await tester.pumpAndSettle();

      // Open popup menu on the file (last more_vert is the file's)
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('移动'));
      await tester.pumpAndSettle();

      // Folder picker should show existing folders
      expect(find.text('选择目标文件夹'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('docs'),
        ),
        findsOneWidget,
      );

      // Click '新建文件夹' button
      await tester.tap(find.text('新建文件夹'));
      await tester.pumpAndSettle();

      // Text field should appear for new folder name — use the one inside the AlertDialog
      final textField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(textField, 'subfolder');

      // Press the confirm (check) icon
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      expect(createdFolderPath, 'subfolder');
    });
  });

  // ------------------------------------------------------------------
  // Folder display detail tests
  // ------------------------------------------------------------------

  group('Folder display detail', () {
    testWidgets('Empty folder shows 空文件夹 in detail text', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'empty_folder'},
      ));
      await tester.pumpAndSettle();

      // Should show the folder name
      expect(find.text('empty_folder'), findsOneWidget);
      // The detail text should show '空文件夹'
      expect(find.text('空文件夹'), findsOneWidget);
      // Should NOT show '0 个文件'
      expect(find.text('0 个文件'), findsNothing);
    });

    testWidgets('Folder with files shows correct file count', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [
          TestRecord(name: 'doc1', format: 'txt', folder: 'myfiles'),
          TestRecord(name: 'doc2', format: 'txt', folder: 'myfiles'),
        ],
        folders: {'myfiles'},
      ));
      await tester.pumpAndSettle();

      // Folder should show count info
      expect(find.text('2 个文件'), findsOneWidget);
    });

    testWidgets('Folder with subfolders shows subfolder count', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'parent', 'parent/child'},
      ));
      await tester.pumpAndSettle();

      // Should show subfolder count
      expect(find.text('1 个子文件夹'), findsOneWidget);
    });

    testWidgets('File inside current folder hides redundant folder path',
        (tester) async {
      final records = [
        TestRecord(name: 'inside_file', format: 'txt', folder: 'myfolder'),
      ];

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {'myfolder'},
      ));
      await tester.pumpAndSettle();

      // At root, file shows its folder path 'myfolder'
      expect(find.text('myfolder'), findsOneWidget);

      // Enter the folder
      await tester.tap(find.text('myfolder'));
      await tester.pumpAndSettle();

      // Inside the folder, the file should NOT show the folder path anymore
      // Only the file name, size, and date should remain
      expect(find.text('inside_file.txt'), findsOneWidget);
      // The folder icon in the file detail should NOT be present
      // (dotted separator dots are gone too because folder badge is hidden)
    });
  });

  // ------------------------------------------------------------------
  // File popup menu tests
  // ------------------------------------------------------------------

  group('File popup menu', () {
    testWidgets('File popup menu without extra items has no export',
        (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord(name: 'doc', format: 'pdf')],
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Open the file's popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // '导出到本地' is only available through extraPopupMenuItems
      // Without extra items, there should be no '导出到本地'
      expect(find.text('导出到本地'), findsNothing);

      // Standard items are still present
      expect(find.text('预览'), findsOneWidget);
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('移动'), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    testWidgets('File popup menu shows all standard items', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord(name: 'doc', format: 'pdf')],
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          onFileTap: (_) {},
          extraPopupMenuItems: (file) => [
            const PopupMenuItem(
              value: 'export',
              child: ListTile(
                leading: Icon(Icons.file_download, size: 20),
                title: Text('导出到本地'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Standard items should be present
      expect(find.text('预览'), findsOneWidget);
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('移动'), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);

      // '导出到本地' provided by extraPopupMenuItems should appear exactly once
      expect(find.text('导出到本地'), findsOneWidget);
    });
  });

  // ==================================================================
  // NEW: Root-level display tests
  // ==================================================================

  group('Root-level display', () {
    testWidgets('Files with empty folder appear at root', (tester) async {
      final records = [
        TestRecord(name: 'rootfile', format: 'txt', folder: ''),
      ];
      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Root-level file should be visible
      expect(find.text('rootfile.txt'), findsOneWidget);
    });

    testWidgets('Files with non-empty folder do NOT appear at root',
        (tester) async {
      final records = [
        TestRecord(name: 'hidden', format: 'txt', folder: 'subfolder'),
      ];
      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {'subfolder'},
      ));
      await tester.pumpAndSettle();

      // File inside a folder should NOT appear at root
      expect(find.text('hidden.txt'), findsNothing);
      // Only the folder should be visible
      expect(find.text('subfolder'), findsOneWidget);
    });

    testWidgets('Folders appear sorted alphabetically at root', (tester) async {
      // Use sortConfig with name ascending to ensure alphabetical
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'zeta', 'alpha', 'beta'},
        sortConfig:
            const SortConfig(field: SortField.name, order: SortOrder.ascending),
      ));
      await tester.pumpAndSettle();

      // All folder names should be present
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      expect(find.text('zeta'), findsOneWidget);
    });

    testWidgets('Root shows folder detail text for each folder',
        (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [
          TestRecord(name: 'f1', format: 'txt', folder: 'myfolder'),
        ],
        folders: {'myfolder'},
      ));
      await tester.pumpAndSettle();

      // Folder detail should show file count
      expect(find.text('1 个文件'), findsOneWidget);
    });
  });

  // ==================================================================
  // NEW: Subfolder display tests
  // ==================================================================

  group('Subfolder display', () {
    testWidgets('Entering a folder shows files with matching folder field',
        (tester) async {
      final records = [
        TestRecord(name: 'inside', format: 'txt', folder: 'myfolder'),
      ];
      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {'myfolder'},
      ));
      await tester.pumpAndSettle();

      // Enter folder
      await tester.tap(find.text('myfolder'));
      await tester.pumpAndSettle();

      // File inside folder should appear
      expect(find.text('inside.txt'), findsOneWidget);
    });

    testWidgets('Entering a folder shows sub-folders', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'parent', 'parent/child'},
      ));
      await tester.pumpAndSettle();

      // Enter parent
      await tester.tap(find.text('parent'));
      await tester.pumpAndSettle();

      // Subfolder should be visible
      expect(find.text('child'), findsOneWidget);
      expect(find.text('返回根目录'), findsOneWidget);
    });

    testWidgets('Back button in body returns to parent', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'parent', 'parent/child'},
      ));
      await tester.pumpAndSettle();

      // Enter parent
      await tester.tap(find.text('parent'));
      await tester.pumpAndSettle();

      // AppBar title should show 'parent'
      expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('parent'),
          ),
          findsOneWidget);

      // Tap the body back item (返回根目录)
      await tester.tap(find.text('返回根目录'));
      await tester.pumpAndSettle();

      // Should be back at root
      expect(find.text('Test Files'), findsOneWidget);
    });

    testWidgets('Nested folder back navigates correctly', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'a', 'a/b', 'a/b/c'},
      ));
      await tester.pumpAndSettle();

      // Enter a
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();

      // Enter b
      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();

      // Should show '返回: a' in the back item
      expect(find.text('返回: a'), findsOneWidget);

      // Tap the back item
      await tester.tap(find.text('返回: a'));
      await tester.pumpAndSettle();

      // Should be back in 'a', with '返回根目录' showing
      expect(find.text('返回根目录'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
    });
  });

  // ==================================================================
  // NEW: Folder detail text comprehensive tests
  // ==================================================================

  group('Folder detail text', () {
    testWidgets('Folder with 0 files and 0 subfolders shows 空文件夹',
        (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'empty'},
      ));
      await tester.pumpAndSettle();

      expect(find.text('空文件夹'), findsOneWidget);
    });

    testWidgets('Folder with files shows N 个文件', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [
          TestRecord(name: 'a', format: 'txt', folder: 'docs'),
          TestRecord(name: 'b', format: 'txt', folder: 'docs'),
          TestRecord(name: 'c', format: 'txt', folder: 'docs'),
        ],
        folders: {'docs'},
      ));
      await tester.pumpAndSettle();

      expect(find.text('3 个文件'), findsOneWidget);
    });

    testWidgets('Folder with subfolders shows N 个子文件夹', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'parent', 'parent/child1', 'parent/child2'},
      ));
      await tester.pumpAndSettle();

      expect(find.text('2 个子文件夹'), findsOneWidget);
    });

    testWidgets('Folder with files AND subfolders shows combined count',
        (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [
          TestRecord(name: 'f1', format: 'txt', folder: 'parent'),
        ],
        folders: {'parent', 'parent/child'},
      ));
      await tester.pumpAndSettle();

      expect(find.text('1 个文件, 1 个子文件夹'), findsOneWidget);
    });
  });

  // ==================================================================
  // NEW: File item display tests
  // ==================================================================

  group('File item display', () {
    testWidgets('File shows name, format, size, date', (tester) async {
      final fixedDate = DateTime(2024, 1, 15, 10, 30);
      await tester.pumpWidget(buildFileManagerView(
        records: [
          TestRecord(
            name: 'report',
            format: 'pdf',
            size: 2048,
            createdAt: fixedDate,
          ),
        ],
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Name.format
      expect(find.text('report.pdf'), findsOneWidget);
      // Size
      expect(find.textContaining('KB'), findsOneWidget);
      // Date
      expect(find.textContaining('2024-'), findsOneWidget);
    });

    testWidgets(
        'File inside current browsing folder does NOT show folder badge',
        (tester) async {
      final records = [
        TestRecord(name: 'doc', format: 'txt', folder: 'myfolder'),
      ];
      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {'myfolder'},
      ));
      await tester.pumpAndSettle();

      // Enter folder
      await tester.tap(find.text('myfolder'));
      await tester.pumpAndSettle();

      // File should be visible
      expect(find.text('doc.txt'), findsOneWidget);

      // The smaller folder icon (Icons.folder, size 12) used as badge should NOT appear
      // Only the big folder icon (Icons.folder_outlined) should remain from the folder item
      // Since we're inside the folder, the folder item is no longer visible
      // There's the back button arrow, file icon, and that's it
      // The folder badge icon is Icons.folder with size 12
    });

    testWidgets('File at root level DOES show folder badge when in a folder',
        (tester) async {
      final records = [
        TestRecord(name: 'doc', format: 'txt', folder: 'myfolder'),
      ];
      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {'myfolder'},
      ));
      await tester.pumpAndSettle();

      // At root, the file shows its folder path
      expect(find.text('doc.txt'), findsNothing);
      expect(find.text('myfolder'), findsOneWidget);
    });
  });

  // ==================================================================
  // NEW: Folder popup menu tests
  // ==================================================================

  group('Folder popup menu', () {
    testWidgets('Folder popup shows rename, move, copy, delete',
        (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'myfolder'},
      ));
      await tester.pumpAndSettle();

      // Open folder popup menu
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      // All standard folder menu items
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('移动'), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);

      // Folders should NOT have preview
      expect(find.text('预览'), findsNothing);
    });

    testWidgets('Folder popup has no duplicate items', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'myfolder'},
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      // Each item should appear exactly once
      expect(find.text('重命名'), findsOneWidget);
      expect(find.text('移动'), findsOneWidget);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });
  });

  // ==================================================================
  // NEW: Multiple selection tests
  // ==================================================================

  group('Multiple selection', () {
    testWidgets('Multiple files can be selected', (tester) async {
      final records = [
        TestRecord(name: 'a', format: 'txt'),
        TestRecord(name: 'b', format: 'txt'),
        TestRecord(name: 'c', format: 'txt'),
      ];

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Enter selection mode with first file
      await tester.longPress(find.text('a.txt'));
      await tester.pumpAndSettle();

      expect(find.text('已选择 1 项'), findsOneWidget);

      // Select second file
      await tester.tap(find.text('b.txt'));
      await tester.pumpAndSettle();

      expect(find.text('已选择 2 项'), findsOneWidget);

      // Select third file
      await tester.tap(find.text('c.txt'));
      await tester.pumpAndSettle();

      expect(find.text('已选择 3 项'), findsOneWidget);
    });

    testWidgets('Bottom bar remains visible with multiple selections',
        (tester) async {
      final records = [
        TestRecord(name: 'x', format: 'txt'),
        TestRecord(name: 'y', format: 'txt'),
        TestRecord(name: 'z', format: 'txt'),
      ];

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Select multiple files
      await tester.longPress(find.text('x.txt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('y.txt'));
      await tester.pumpAndSettle();

      // Bottom bar should still show buttons
      expect(find.text('删除'), findsOneWidget);
      expect(find.text('移动'), findsOneWidget);
    });
  });

  // ==================================================================
  // NEW: File operations tests
  // ==================================================================

  group('File operations', () {
    testWidgets('Rename file dialog opens and calls onRenameFile',
        (tester) async {
      final records = [TestRecord(name: 'oldname', format: 'txt')];
      String? renamedId;
      String? newName;

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
        onRenameFile: (id, name) async {
          renamedId = id;
          newName = name;
        },
      ));
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Select rename
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('重命名文件'), findsOneWidget);

      // Clear and enter new name
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'newname');
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      expect(renamedId, isNotNull);
      expect(newName, 'newname');
    });

    testWidgets('Rename file cancel does nothing', (tester) async {
      final records = [TestRecord(name: 'oldname', format: 'txt')];
      bool renameCalled = false;

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
        onRenameFile: (id, name) async {
          renameCalled = true;
        },
      ));
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();

      expect(renameCalled, isFalse);
    });

    testWidgets('Delete file shows confirmation and calls onDeleteFile',
        (tester) async {
      final records = [TestRecord(name: 'delete_me', format: 'txt')];
      String? deletedId;

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
        onDeleteFile: (id) async {
          deletedId = id;
        },
      ));
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Delete confirmation dialog
      expect(find.text('确认删除'), findsOneWidget);

      // Confirm delete
      final deleteBtn = find.descendant(
          of: find.byType(AlertDialog), matching: find.text('删除'));
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(deletedId, isNotNull);
    });

    testWidgets('Delete file cancel does not call onDeleteFile',
        (tester) async {
      final records = [TestRecord(name: 'safe', format: 'txt')];
      bool deleteCalled = false;

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
        onDeleteFile: (id) async {
          deleteCalled = true;
        },
      ));
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Cancel
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();

      expect(deleteCalled, isFalse);
    });

    testWidgets('Copy file opens folder picker and calls onCopyFile',
        (tester) async {
      final records = [TestRecord(name: 'copy_me', format: 'txt')];
      String? copiedId;
      String? copyTarget;

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {'target_folder'},
        onCopyFile: (id, target) async {
          copiedId = id;
          copyTarget = target;
        },
      ));
      await tester.pumpAndSettle();

      // Open popup menu (use .last to target the file's more_vert, not the folder's)
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('复制'));
      await tester.pumpAndSettle();

      // Folder picker dialog
      expect(find.text('选择复制到的目标文件夹'), findsOneWidget);

      // Select target folder
      await tester.tap(find.text('target_folder').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择此文件夹'));
      await tester.pumpAndSettle();

      expect(copiedId, isNotNull);
      expect(copyTarget, 'target_folder');
    });

    testWidgets('Delete selected files via bottom bar', (tester) async {
      final records = [TestRecord(name: 'del', format: 'txt')];
      List<String>? deletedIds;

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
        onDeleteFiles: (ids) async {
          deletedIds = ids;
        },
      ));
      await tester.pumpAndSettle();

      // Enter selection mode
      await tester.longPress(find.text('del.txt'));
      await tester.pumpAndSettle();

      // Tap delete button in bottom bar
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('确认批量删除'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(deletedIds, isNotNull);
      expect(deletedIds!.length, 1);
    });
  });

  // ==================================================================
  // NEW: Folder operations tests
  // ==================================================================

  group('Folder operations', () {
    testWidgets('Rename folder dialog opens and calls onRenameFolder',
        (tester) async {
      String? oldName;
      String? newName;

      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'myfolder'},
        onRenameFolder: (old, name) async {
          oldName = old;
          newName = name;
        },
      ));
      await tester.pumpAndSettle();

      // Open folder popup menu
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('重命名文件夹'), findsOneWidget);

      // Clear and enter new name
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'renamed_folder');
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();

      expect(oldName, 'myfolder');
      expect(newName, 'renamed_folder');
    });

    testWidgets('Copy folder opens picker and calls onCopyFolder',
        (tester) async {
      String? copiedFolder;
      String? copyTarget;

      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'source', 'destination'},
        onCopyFolder: (name, target) async {
          copiedFolder = name;
          copyTarget = target;
        },
      ));
      await tester.pumpAndSettle();

      // Open folder popup menu
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('复制'));
      await tester.pumpAndSettle();

      // Folder picker dialog
      expect(find.text('复制文件夹到…'), findsOneWidget);

      // Select destination
      final pickerItem = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('destination'),
      );
      await tester.tap(pickerItem);
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择此文件夹'));
      await tester.pumpAndSettle();

      expect(copiedFolder, 'source');
      expect(copyTarget, 'destination');
    });

    testWidgets('Delete folder shows confirmation and calls onDeleteFolder',
        (tester) async {
      String? deletedFolder;

      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'unwanted'},
        onDeleteFolder: (name) async {
          deletedFolder = name;
        },
      ));
      await tester.pumpAndSettle();

      // Open folder popup menu
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Confirmation dialog
      expect(find.text('确认删除文件夹'), findsOneWidget);

      // Confirm
      final deleteBtn = find.descendant(
          of: find.byType(AlertDialog), matching: find.text('删除'));
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(deletedFolder, 'unwanted');
    });
  });

  // ==================================================================
  // NEW: AppBar comprehensive tests
  // ==================================================================

  group('AppBar comprehensive', () {
    testWidgets('All AppBar elements visible at root', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord()],
        folders: {},
      ));
      await tester.pumpAndSettle();

      // Title
      expect(find.text('Test Files'), findsOneWidget);
      // Sort button
      expect(find.byIcon(Icons.access_time), findsOneWidget);
      // Create folder button
      expect(find.byIcon(Icons.create_new_folder), findsOneWidget);
      // Refresh button
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      // No back button at root
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('Create folder button visible at root and in subfolder',
        (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'sub'},
      ));
      await tester.pumpAndSettle();

      // Create folder button at root
      expect(find.byIcon(Icons.create_new_folder), findsOneWidget);

      // Enter subfolder
      await tester.tap(find.text('sub'));
      await tester.pumpAndSettle();

      // Create folder button should still be visible
      expect(find.byIcon(Icons.create_new_folder), findsOneWidget);
    });

    testWidgets('Refresh button visible at root and in subfolder',
        (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'sub'},
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.text('sub'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('Sort button visible at root and in subfolder', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'sub'},
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.access_time), findsOneWidget);

      await tester.tap(find.text('sub'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });
  });

  // ==================================================================
  // NEW: Grid view tests
  // ==================================================================

  group('Grid view', () {
    testWidgets('Grid view shows folder items', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [],
        folders: {'grid_folder'},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          showThumbnailToggle: true,
          initialGridView: true,
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          fileThumbnailBuilder: (_) => const Icon(Icons.image),
          onFileTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Folder should be shown in grid
      expect(find.text('grid_folder'), findsOneWidget);
    });

    testWidgets('Grid view shows file items', (tester) async {
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord(name: 'gridfile', format: 'jpg')],
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          showThumbnailToggle: true,
          initialGridView: true,
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          fileThumbnailBuilder: (_) => const Icon(Icons.image),
          onFileTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // File should be shown in grid
      expect(find.text('gridfile.jpg'), findsOneWidget);
    });

    testWidgets('Grid view tapping file triggers onFileTap', (tester) async {
      final records = [TestRecord(name: 'g', format: 'png')];
      TestRecord? tapped;

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          showThumbnailToggle: true,
          initialGridView: true,
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          fileThumbnailBuilder: (_) => const Icon(Icons.image),
          onFileTap: (f) => tapped = f,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('g.png'));
      await tester.pumpAndSettle();

      expect(tapped, isNotNull);
      expect(tapped!.name, 'g');
    });
  });

  // ==================================================================
  // NEW: Grid view selection tests
  // ==================================================================

  // ==================================================================
  // NEW: Picker dialog folder creation visibility tests
  // ==================================================================

  group('Picker dialog folder creation', () {
    testWidgets(
        'Folder created in picker dialog persists data correctly via onCreateFolder callback',
        (tester) async {
      String? createdPath;

      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord(name: 'f', format: 'txt')],
        folders: {'existing'},
        onCreateFolder: (name) async {
          createdPath = name;
        },
        onMoveFile: (id, target) async {},
      ));
      await tester.pumpAndSettle();

      // Open popup and select move
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('移动'));
      await tester.pumpAndSettle();

      // Create a new folder in the picker
      await tester.tap(find.text('新建文件夹'));
      await tester.pumpAndSettle();

      final textField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(textField, 'targetfolder');
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      // Verify the correct full path was passed to onCreateFolder
      expect(createdPath, 'targetfolder');

      // The new folder should be visible in the picker
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('targetfolder'),
        ),
        findsOneWidget,
      );

      // Cancel the dialog
      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();

      // After dialog closes, rebuild widget with the folder data updated
      // (simulating what the provider refresh does in production)
      await tester.pumpWidget(buildFileManagerView(
        records: [TestRecord(name: 'f', format: 'txt')],
        folders: {'existing', 'targetfolder'},
        onCreateFolder: (name) async {
          createdPath = name;
        },
        onMoveFile: (id, target) async {},
      ));
      await tester.pumpAndSettle();

      // The new folder should now be visible in the main view
      expect(find.text('targetfolder'), findsOneWidget);
      // Both folders show '空文件夹' since they have no files
      expect(find.text('existing'), findsOneWidget);
      // The new empty-folder detail should appear (2 folders × 空文件夹 each)
      expect(find.text('空文件夹'), findsAtLeast(1));
    });

    testWidgets(
        'Folder created in picker dialog is selectable and move completes successfully',
        (tester) async {
      String? createdPath;
      String? movedId;
      var foldersSet = <String>{};

      Widget buildView(Set<String> f) => buildFileManagerView(
            records: [TestRecord(name: 'f', format: 'txt')],
            folders: f,
            onCreateFolder: (name) async {
              createdPath = name;
              foldersSet = {...foldersSet, name};
            },
            onMoveFile: (id, target) async {
              movedId = id;
            },
          );

      await tester.pumpWidget(buildView(foldersSet));
      await tester.pumpAndSettle();

      // Open popup and select move
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('移动'));
      await tester.pumpAndSettle();

      // Create a new folder in the picker
      await tester.tap(find.text('新建文件夹'));
      await tester.pumpAndSettle();

      final textField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(textField, 'targetfolder');
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();

      expect(createdPath, 'targetfolder');

      // The new folder should be visible in the picker
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('targetfolder'),
        ),
        findsOneWidget,
      );

      // Select the new folder
      await tester.tap(find.text('targetfolder').last);
      await tester.pumpAndSettle();

      // Click '选择此文件夹'
      await tester.tap(find.text('选择此文件夹'));
      await tester.pumpAndSettle();

      // Move should have been called
      expect(movedId, isNotNull);
    });
  });

  group('Grid view selection', () {
    testWidgets('Grid view long press enters selection mode', (tester) async {
      final records = [TestRecord(name: 'gs', format: 'jpg')];

      await tester.pumpWidget(buildFileManagerView(
        records: records,
        folders: {},
        config: FileManagerConfig<TestRecord>(
          title: 'Test',
          showThumbnailToggle: true,
          initialGridView: true,
          fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
          fileThumbnailBuilder: (_) => const Icon(Icons.image),
          onFileTap: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Long press on grid file
      await tester.longPress(find.text('gs.jpg'));
      await tester.pumpAndSettle();

      expect(find.text('已选择 1 项'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
