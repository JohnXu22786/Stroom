import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

void main() => runApp(const _CaptureApp());

class _CaptureApp extends StatefulWidget {
  const _CaptureApp();

  @override
  State<_CaptureApp> createState() => _CaptureAppState();
}

class _CaptureAppState extends State<_CaptureApp> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: const Locale('de', 'DE'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      cardTheme: const CardThemeData(elevation: 0),
    ),
    home: Builder(
      builder: (context) {
        if (!_opened) {
          _opened = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            const item = BatchRenameItem(
              id: 'label-preview',
              isFolder: false,
              name: 'Very long original filename for label verification',
              format: 'txt',
            );
            showDialog<void>(
              context: context,
              builder: (_) => BatchRenameDialog(
                items: const [item],
                allFiles: const [item],
                allFolders: const {},
                bridge: _bridge,
                initialConfig: const BatchRenameConfig(
                  rules: [
                    BatchReplaceOp(
                      enabled: true,
                      find: 'original',
                      replace: 'updated',
                    ),
                  ],
                ),
              ),
            );
          });
        }
        return const Scaffold(body: SizedBox.expand());
      },
    ),
  );
}
