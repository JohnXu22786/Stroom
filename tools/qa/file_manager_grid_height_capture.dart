import 'package:flutter/material.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/utils/file_record.dart';
import 'package:stroom/utils/manifest_bridge.dart';
import 'package:stroom/utils/sort_config.dart';
import 'package:stroom/widgets/file_manager_config.dart';
import 'package:stroom/widgets/file_manager_view.dart';

void main() {
  final now = DateTime(2026, 1, 1);
  const folder = 'Sample folder with a long localized-style name';
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        brightness: Brightness.light,
      ),
      home: Scaffold(
        body: FileManagerView<_GridCaptureFile>(
          sortedRecords: [
            _GridCaptureFile(
              id: 'root-file',
              name: 'A sample text document',
              format: 'txt',
              folder: '',
              createdAt: now,
            ),
            _GridCaptureFile(
              id: 'folder-file',
              name: 'Nested example',
              format: 'md',
              folder: folder,
              createdAt: now,
            ),
          ],
          folders: const {folder},
          sortConfig: const SortConfig(
            field: SortField.name,
            order: SortOrder.ascending,
          ),
          config: FileManagerConfig<_GridCaptureFile>(
            title: 'Files',
            initialGridView: true,
            fileThumbnailBuilder: (_) => const ColoredBox(
              color: Color(0xffe8efff),
              child: Center(
                child: Icon(Icons.insert_drive_file_outlined, size: 32),
              ),
            ),
            fileIconBuilder: (_) => const Icon(Icons.insert_drive_file),
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
          manifestBridge: ManifestBridge(
            getFolderBaseName: (path) => path.split('/').last,
            getParentFolderPath: (path) {
              final parts = path.split('/');
              return parts.length > 1
                  ? parts.sublist(0, parts.length - 1).join('/')
                  : '';
            },
            getChildFolderPaths: (_, __) => const [],
            validateFolderName: (_) => null,
            getAllDescendantFolderPaths: (_, __) => const [],
          ),
        ),
      ),
    ),
  );
}

class _GridCaptureFile implements FileRecord {
  const _GridCaptureFile({
    required this.id,
    required this.name,
    required this.format,
    required this.folder,
    required this.createdAt,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final String format;
  @override
  final String folder;
  @override
  final DateTime createdAt;
  @override
  DateTime get modifiedAt => createdAt;
  @override
  int get size => 1024;
}
