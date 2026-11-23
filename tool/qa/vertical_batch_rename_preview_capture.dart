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

void main() {
  final scale = double.tryParse(Uri.base.queryParameters['scale'] ?? '') ?? 1;
  final localeParts =
      (Uri.base.queryParameters['locale'] ?? 'de-DE').split('-');
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(
        localeParts.first,
        localeParts.length > 1 ? localeParts[1] : null,
      ),
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: const _CaptureHome(),
    ),
  );
}

class _CaptureHome extends StatefulWidget {
  const _CaptureHome();

  @override
  State<_CaptureHome> createState() => _CaptureHomeState();
}

class _CaptureHomeState extends State<_CaptureHome> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    if (!_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        const item = BatchRenameItem(
          id: 'local-preview',
          isFolder: false,
          name: 'Projektbericht_Originalfassung_mit_ausfuehrlichem_Zusatz_2025',
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
                  find: 'Originalfassung',
                  replace: 'Endfassung',
                ),
              ],
            ),
          ),
        );
      });
    }
    return const Scaffold(body: SizedBox.expand());
  }
}
