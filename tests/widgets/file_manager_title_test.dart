import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/utils/file_record.dart';
import 'package:stroom/utils/manifest_bridge.dart';
import 'package:stroom/utils/sort_config.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/widgets/file_manager_config.dart';
import 'package:stroom/widgets/file_manager_view.dart';

class _TitleTestFile implements FileRecord {
  @override
  final String id = 'file_1';
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

const _title =
    'A configured file manager title long enough to exceed the toolbar';

void main() {
  testWidgets('keeps root and selection titles to one constrained line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final file = _TitleTestFile();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: FileManagerView<_TitleTestFile>(
            sortedRecords: [file],
            folders: const {},
            sortConfig: const SortConfig(
              field: SortField.name,
              order: SortOrder.ascending,
            ),
            config: const FileManagerConfig<_TitleTestFile>(
              title: _title,
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
              getParentFolderPath: (path) => path.contains('/')
                  ? path.substring(0, path.lastIndexOf('/'))
                  : '',
              getChildFolderPaths: (_, __) => const [],
              validateFolderName: (_) => null,
              getAllDescendantFolderPaths: (_, __) => const [],
            ),
          ),
        ),
      ),
    );

    final rootTitle = tester.widget<ConstrainedText>(
      find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == _title,
      ),
    );
    expect(rootTitle.maxLines, 1);
    expect(rootTitle.textAlign, TextAlign.center);

    await tester.longPress(find.byKey(const Key('fm_file_file_1')));
    await tester.pumpAndSettle();
    final selectionTitle = tester.widget<ConstrainedText>(
      find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == '1 selected',
      ),
    );
    expect(selectionTitle.maxLines, 1);
    expect(selectionTitle.textAlign, TextAlign.center);
    expect(tester.takeException(), isNull);
  });
}

Widget _fileIcon(_TitleTestFile _) => const Icon(Icons.description);
void _onFileTap(_TitleTestFile _) {}
Future<void> _noop() async {}
Future<void> _rename(String _, String __) async {}
Future<void> _move(String _, String __) async {}
Future<void> _delete(String _) async {}
Future<void> _deleteMany(List<String> _) async {}
Future<void> _moveMany(List<String> _, String __) async {}
Future<void> _export(String _) async {}
Future<void> _create(String _) async {}
void _toggleSort(SortField _) {}
