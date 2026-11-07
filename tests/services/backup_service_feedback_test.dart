import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/backup_location_manager.dart';
import 'package:stroom/services/backup_service.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

class _MissingBackupPicker extends FilePickerPlatform {
  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
  }) async =>
      _MissingBackupFile();
}

final class _MissingBackupFile extends PlatformFile {
  @override
  String get name => 'missing.zip';

  @override
  Uri get uri => Uri.file('/missing-backup-service-feedback.zip');

  @override
  XFile get xFile => XFile(uri.toFilePath());

  @override
  int? lengthSync() => null;

  @override
  Future<int?> length() async => null;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();
}

Widget _testApp({
  required GlobalKey<NavigatorState> navigatorKey,
  required Locale locale,
}) =>
    MaterialApp(
      navigatorKey: navigatorKey,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: SizedBox()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppLogService.disableFileLogging();
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  testWidgets('backup service restore failures follow the app locale', (
    tester,
  ) async {
    final originalPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = _MissingBackupPicker();
    addTearDown(() => FilePickerPlatform.instance = originalPicker);

    for (final (locale, expectedPrefix) in [
      (const Locale('en', 'US'), 'Restore failed:'),
      (const Locale('zh', 'CN'), '恢复失败:'),
    ]) {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester
          .pumpWidget(_testApp(navigatorKey: navigatorKey, locale: locale));

      await expectLater(
        BackupService.importBackup(navigatorKey.currentContext!),
        throwsA(isA<BackupValidationException>()),
      );
      await tester.pump();

      expect(find.textContaining(expectedPrefix), findsOneWidget);
      expect(
        find.textContaining('/missing-backup-service-feedback.zip'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });

  testWidgets('backup service export success and errors follow the app locale',
      (tester) async {
    final tempDir = await Directory.systemTemp.createTemp('backup_feedback_');
    addTearDown(() => tempDir.delete(recursive: true));
    const selectorChannel = MethodChannel('plugins.flutter.io/file_selector');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Object? pickerFailure;
    var selectedOutputPath = '';
    messenger.setMockMethodCallHandler(selectorChannel, (call) async {
      if (pickerFailure != null) throw pickerFailure!;
      return selectedOutputPath;
    });
    addTearDown(
        () => messenger.setMockMethodCallHandler(selectorChannel, null));

    const emptySelection = BackupSelection(
      chatRecordsAndAttachments: false,
      settings: false,
      pictures: false,
      audio: false,
      videos: false,
      texts: false,
      tasks: false,
      ankiData: false,
      browserCookies: false,
      includeMediaFiles: false,
    );

    for (final (locale, savedPrefix, failedPrefix) in [
      (
        const Locale('en', 'US'),
        'Backup saved to:',
        'Backup failed:',
      ),
      (
        const Locale('zh', 'CN'),
        '备份已保存到:',
        '备份失败:',
      ),
    ]) {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester
          .pumpWidget(_testApp(navigatorKey: navigatorKey, locale: locale));
      final outputPath =
          p.join(tempDir.path, 'backup-${locale.languageCode}.zip');
      selectedOutputPath = outputPath;
      final l10n = AppLocalizations.of(navigatorKey.currentContext!)!;
      final isEnglish = locale.languageCode == 'en';
      expect(
        l10n.backupServiceExportSavedTo(outputPath),
        isEnglish ? 'Backup saved to: $outputPath' : '备份已保存到: $outputPath',
      );
      expect(
        l10n.backupServiceExportFailed('disk detail'),
        isEnglish ? 'Backup failed: disk detail' : '备份失败: disk detail',
      );
      expect(
        l10n.backupServiceNoBackupFolderSelected,
        isEnglish
            ? 'No backup folder has been selected. Authorize one during startup.'
            : '尚未选择备份目录，请在启动流程中授权',
      );

      expect(
        await BackupService.exportBackup(
          navigatorKey.currentContext!,
          selection: emptySelection,
        ),
        isTrue,
      );
      await tester.pump();
      expect(find.textContaining(savedPrefix), findsOneWidget);
      expect(find.textContaining(outputPath), findsOneWidget);

      ScaffoldMessenger.of(navigatorKey.currentContext!).clearSnackBars();
      await tester.pump();
      pickerFailure =
          PlatformException(code: 'test', message: 'export picker detail');
      expect(
        await BackupService.exportBackup(
          navigatorKey.currentContext!,
          selection: emptySelection,
        ),
        isFalse,
      );
      await tester.pump();
      expect(find.textContaining(failedPrefix), findsOneWidget);
      expect(find.textContaining('export picker detail'), findsOneWidget);
      ScaffoldMessenger.of(navigatorKey.currentContext!).clearSnackBars();
      await tester.pump();

      pickerFailure = Exception(
        BackupLocationManager.noBackupDirectoryWriteErrorMessage,
      );
      expect(
        await BackupService.exportBackup(
          navigatorKey.currentContext!,
          selection: emptySelection,
        ),
        isFalse,
      );
      await tester.pump();
      expect(
        find.text(
          l10n.backupServiceExportFailed(
            l10n.backupServiceNoBackupFolderSelected,
          ),
        ),
        findsOneWidget,
      );
      pickerFailure = null;

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
}
