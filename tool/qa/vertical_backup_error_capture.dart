import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/widgets/backup_operation_error_dialog.dart';

void main() {
  runApp(const _BackupErrorCaptureApp());
}

class _BackupErrorCaptureApp extends StatelessWidget {
  const _BackupErrorCaptureApp();

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
        home: const _BackupErrorCapturePage(),
      );
}

class _BackupErrorCapturePage extends StatefulWidget {
  const _BackupErrorCapturePage();

  @override
  State<_BackupErrorCapturePage> createState() =>
      _BackupErrorCapturePageState();
}

class _BackupErrorCapturePageState extends State<_BackupErrorCapturePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final strings = AppLocalizations.of(context)!;
      unawaited(
        showBackupOperationErrorDialog(
          context: context,
          title: strings.backupRestoreIncompleteTitle,
          diagnostic: 'PlatformException(restore_failed, '
              'Local fixture failure: ${List.filled(90, 'unexpected archive detail').join(' ')}, '
              'null, null)',
          additionalMessage: strings.backupRestoreIncompleteMessage,
          actionsBuilder: (dialogContext) => [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.backupRestoreExitApp),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.backupRestoreRestartNow),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.expand());
}
