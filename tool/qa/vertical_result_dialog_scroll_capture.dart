import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/backup_restore_result_dialogs.dart';

void main() => runApp(const _CaptureApp());

class _CaptureApp extends StatelessWidget {
  const _CaptureApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('de', 'DE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        ),
        home: const _CapturePage(),
      );
}

class _CapturePage extends StatefulWidget {
  const _CapturePage();

  @override
  State<_CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<_CapturePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final strings = AppLocalizations.of(context)!;
      final categories = [
        strings.backupRestoreCategoryChat,
        strings.backupRestoreCategorySettings,
        strings.backupRestoreCategoryPictures,
        strings.backupRestoreCategoryAudio,
        strings.backupRestoreCategoryVideos,
        strings.backupRestoreCategoryTexts,
        strings.backupRestoreCategoryTasks,
        strings.backupRestoreCategoryAnki,
      ].join(', ');
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: BackupRestoreRestartDialog(
              title: strings.backupRestoreRestoreSuccessTitle,
              message: [
                strings.backupRestoreSkippedCategories(categories),
                strings.backupRestoreSkippedTasksLegacy,
                strings.backupRestoreSkippedCookies,
                strings.backupRestoreSkippedWebsiteData,
                strings.backupRestoreOtherSelectedRestored,
              ].join('\n\n'),
              exitLabel: strings.backupRestoreExitApp,
              restartLabel: strings.backupRestoreRestartNow,
              onExit: () => Navigator.of(dialogContext).pop(),
              onRestart: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}
