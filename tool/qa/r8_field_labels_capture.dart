import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/theme_display_settings_page.dart';
import 'package:stroom/providers/theme_provider.dart';
import 'package:stroom/utils/batch_rename.dart';
import 'package:stroom/utils/folder_path_utils.dart';
import 'package:stroom/utils/manifest_bridge.dart';
import 'package:stroom/widgets/batch_rename_dialog.dart';
import 'package:stroom/widgets/folder_picker_dialog.dart';

const _bridge = ManifestBridge(
  getFolderBaseName: FolderPathUtils.getFolderBaseName,
  getParentFolderPath: FolderPathUtils.getParentFolderPath,
  getChildFolderPaths: FolderPathUtils.getChildFolderPaths,
  validateFolderName: FolderPathUtils.validateFolderName,
  validateFileName: FolderPathUtils.validateFileName,
  getAllDescendantFolderPaths: FolderPathUtils.getAllDescendantFolderPaths,
);

void main() {
  final query = Uri.base.queryParameters;
  final localeParts = (query['locale'] ?? 'de-DE').split('-');
  final locale = Locale(
    localeParts.first,
    localeParts.length > 1 ? localeParts[1] : null,
  );
  final scale = double.tryParse(query['scale'] ?? '') ?? 1;
  final scene = query['scene'] ?? 'theme';
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
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
      home: switch (scene) {
        'folder' => const _FolderCapture(),
        'batch' => const _BatchCapture(),
        _ => ProviderScope(
            overrides: [themeProvider.overrideWith((ref) => ThemeNotifier())],
            child: const ThemeDisplaySettingsPage(),
          ),
      },
    ),
  );
}

class _FolderCapture extends StatefulWidget {
  const _FolderCapture();

  @override
  State<_FolderCapture> createState() => _FolderCaptureState();
}

class _FolderCaptureState extends State<_FolderCapture> {
  final _fileNameController = TextEditingController();
  bool _opened = false;

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FolderPickerDialog.show(
          context,
          onCreateFolder: (_) async => null,
          fileNameController: _fileNameController,
          fileNameHintText: AppLocalizations.of(context)!.chatSaveFilenameHint,
        );
      });
    }
    return const Scaffold(body: SizedBox.expand());
  }
}

class _BatchCapture extends StatefulWidget {
  const _BatchCapture();

  @override
  State<_BatchCapture> createState() => _BatchCaptureState();
}

class _BatchCaptureState extends State<_BatchCapture> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    if (!_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
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
            initialConfig: const BatchRenameConfig(),
          ),
        );
      });
    }
    return const Scaffold(body: SizedBox.expand());
  }
}
