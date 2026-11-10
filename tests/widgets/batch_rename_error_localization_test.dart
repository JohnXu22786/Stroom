import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/utils/batch_rename.dart';
import 'package:stroom/utils/folder_path_utils.dart';
import 'package:stroom/utils/manifest_bridge.dart';
import 'package:stroom/widgets/batch_rename_dialog.dart';

final _bridge = ManifestBridge(
  getFolderBaseName: FolderPathUtils.getFolderBaseName,
  getParentFolderPath: FolderPathUtils.getParentFolderPath,
  getChildFolderPaths: FolderPathUtils.getChildFolderPaths,
  validateFolderName: FolderPathUtils.validateFolderName,
  validateFileName: FolderPathUtils.validateFileName,
  getAllDescendantFolderPaths: FolderPathUtils.getAllDescendantFolderPaths,
);

Future<(String, String)> _showPlannerError(
  WidgetTester tester,
  Locale locale, {
  required bool conflict,
}) async {
  String? copiedText;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      copiedText = (call.arguments as Map)['text'] as String;
    }
    return null;
  });

  final item = BatchRenameItem(
    id: 'file-1',
    isFolder: false,
    name: 'alpha',
    format: 'txt',
  );
  final occupied = BatchRenameItem(
    id: 'file-2',
    isFolder: false,
    name: 'beta',
    format: 'txt',
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: BatchRenameDialog(
          items: [item],
          allFolders: const {},
          allFiles: conflict ? [item, occupied] : [item],
          bridge: _bridge,
          initialConfig: BatchRenameConfig(
            rules: [
              BatchReplaceOp(
                enabled: true,
                find: 'alpha',
                replace: conflict ? 'beta' : 'bad/name',
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.text(locale.languageCode == 'en' ? 'Copy list' : '复制清单'),
  );
  await tester.pumpAndSettle();
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? '')
      .join('\n');
  return (visibleText, copiedText ?? '');
}

void main() {
  testWidgets('English preview and copied report localize validation errors', (
    tester,
  ) async {
    final (visible, copied) = await _showPlannerError(
      tester,
      const Locale('en', 'US'),
      conflict: false,
    );
    const message = 'File name cannot contain Windows-invalid characters';
    expect(visible, contains(message));
    expect(copied, contains(message));
    expect('$visible$copied', isNot(contains('文件名不能包含 Windows 非法字符')));
  });

  testWidgets('English preview and copied report localize conflict errors', (
    tester,
  ) async {
    final (visible, copied) = await _showPlannerError(
      tester,
      const Locale('en', 'US'),
      conflict: true,
    );
    const message = 'Another file in this folder has the same name';
    expect(visible, contains(message));
    expect(copied, contains(message));
    expect('$visible$copied', isNot(contains('同一文件夹内存在同名文件')));
  });

  testWidgets(
    'Simplified Chinese preview and copied report retain validation errors',
    (tester) async {
      final (visible, copied) = await _showPlannerError(
        tester,
        const Locale('zh', 'CN'),
        conflict: false,
      );
      const message = '文件名不能包含 Windows 非法字符';
      expect(visible, contains(message));
      expect(copied, contains(message));
    },
  );

  testWidgets(
    'Simplified Chinese preview and copied report retain conflict errors',
    (tester) async {
      final (visible, copied) = await _showPlannerError(
        tester,
        const Locale('zh', 'CN'),
        conflict: true,
      );
      const message = '同一文件夹内存在同名文件';
      expect(visible, contains(message));
      expect(copied, contains(message));
    },
  );
}
