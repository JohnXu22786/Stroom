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
  final String id = 'title-capture';
  @override
  final String name = 'example';
  @override
  final String format = 'txt';
  @override
  final DateTime createdAt = DateTime.utc(2026, 1, 1);
  @override
  DateTime get modifiedAt => createdAt;
  @override
  final int size = 512;
  @override
  final String folder = '';
}

void main() {
  runApp(const _CaptureApp());
}

class _CaptureApp extends StatelessWidget {
  const _CaptureApp();

  @override
  Widget build(BuildContext context) {
    final file = _CaptureFile();
    return MaterialApp(
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
        sortedRecords: [file],
        folders: const {},
        sortConfig: const SortConfig(
          field: SortField.name,
          order: SortOrder.ascending,
        ),
        config: const FileManagerConfig<_CaptureFile>(
          title: 'A long sample file manager title for clipped reveal',
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
          getFolderBaseName: (path) => path.split('/').last,
          getParentFolderPath: (_) => '',
          getChildFolderPaths: (_, __) => const [],
          validateFolderName: (_) => null,
          getAllDescendantFolderPaths: (_, __) => const [],
        ),
      ),
    );
  }

  static Widget _fileIcon(_CaptureFile _) => const Icon(Icons.description);
  static void _onFileTap(_CaptureFile _) {}
  static Future<void> _noop() async {}
  static Future<void> _rename(String _, String __) async {}
  static Future<void> _move(String _, String __) async {}
  static Future<void> _delete(String _) async {}
  static Future<void> _deleteMany(List<String> _) async {}
  static Future<void> _moveMany(List<String> _, String __) async {}
  static Future<void> _export(String _) async {}
  static Future<void> _create(String _) async {}
  static void _toggleSort(SortField _) {}
}
