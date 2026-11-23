import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/utils/file_record.dart';
import 'package:stroom/utils/manifest_bridge.dart';
import 'package:stroom/utils/sort_config.dart';
import 'package:stroom/widgets/file_manager_config.dart';
import 'package:stroom/widgets/file_manager_view.dart';

class _CaptureFile implements FileRecord {
  @override
  final String id = 'delete-confirm-capture';
  @override
  final String name = 'fixture';
  @override
  final String format = 'txt';
  @override
  final DateTime createdAt = DateTime.utc(2026, 1, 1);
  @override
  DateTime get modifiedAt => createdAt;
  @override
  final int size = 0;
  @override
  final String folder = '';
}

void main() {
  final segments = List.generate(
    40,
    (index) => 'nested-folder-level-${(index + 1).toString().padLeft(2, '0')}',
  );
  final folders = <String>{};
  var path = '';
  for (final segment in segments) {
    path = path.isEmpty ? segment : '$path/$segment';
    folders.add(path);
  }

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: FileManagerView<_CaptureFile>(
        sortedRecords: const [],
        folders: folders,
        sortConfig: const SortConfig(
          field: SortField.name,
          order: SortOrder.ascending,
        ),
        config: const FileManagerConfig<_CaptureFile>(
          title: 'Files',
          fileIconBuilder: _fileIcon,
          onFileTap: _onFileTap,
        ),
        onRefresh: _noop,
        onRenameFile: _rename,
        onMoveFile: _move,
        onCopyFile: _move,
        onDeleteFile: _delete,
        onDeleteFiles: _deleteMany,
        onDeleteFolders: _deleteMany,
        onMoveFiles: _moveMany,
        onMoveFolders: _moveMany,
        onExportFile: _export,
        onRenameFolder: _rename,
        onMoveFolder: _move,
        onCopyFolder: _move,
        onDeleteFolder: _delete,
        onCreateFolder: _create,
        onToggleSort: _toggleSort,
        manifestBridge: ManifestBridge(
          getFolderBaseName: (value) => value.split('/').last,
          getParentFolderPath: (value) {
            final parts = value.split('/');
            return parts.length > 1
                ? parts.sublist(0, parts.length - 1).join('/')
                : '';
          },
          getChildFolderPaths: (parent, allPaths) {
            final prefix = parent.isEmpty ? '' : '$parent/';
            return allPaths.where((value) {
              if (parent.isEmpty) return !value.contains('/');
              if (!value.startsWith(prefix)) return false;
              return !value.substring(prefix.length).contains('/');
            }).toList();
          },
          validateFolderName: (_) => null,
          getAllDescendantFolderPaths: (parent, allPaths) =>
              allPaths.where((value) => value.startsWith('$parent/')).toList(),
        ),
      ),
    ),
  );
}

Widget _fileIcon(_CaptureFile _) => const Icon(Icons.description);
void _onFileTap(_CaptureFile _) {}
Future<void> _noop() async {}
Future<void> _rename(String _, String __) async {}
Future<void> _move(String _, String __) async {}
Future<void> _delete(String _) async {}
Future<void> _deleteMany(List<String> _) async {}
Future<void> _moveMany(List<String> _, String __) async {}
Future<void> _export(String _) async {}
Future<void> _create(String _) async {}
void _toggleSort(SortField _) {}
