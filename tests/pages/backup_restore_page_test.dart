import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/backup_restore_page.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/manifest_database.dart';

class _CancelingFilePicker extends FilePickerPlatform {
  int pickCallCount = 0;

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
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickCallCount++;
    return null;
  }
}

Widget createTestApp({Locale locale = const Locale('zh', 'CN')}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: BackupRestorePage(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('backup page title and categories follow the selected locale', (
    tester,
  ) async {
    await tester.pumpWidget(createTestApp(locale: const Locale('en', 'US')));
    await tester.pumpAndSettle();
    expect(find.text('Backup and Restore'), findsOneWidget);
    expect(find.text('Chat History and Attachments'), findsOneWidget);
    expect(find.text('Export .apkg'), findsOneWidget);
    expect(find.text('Import .apkg'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  setUp(() {
    // 清除/恢复流程会触及 ManifestDatabase/WebFileStore，
    // 统一启用内存测试模式（与 backup_selection_test.dart 一致）
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    AppLogService.disableFileLogging();
  });

  group('BackupRestorePage - clear selected data', () {
    testWidgets('clear button opens confirmation dialog with categories',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, '清除所选数据'),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, '清除所选数据'));
      await tester.pumpAndSettle();

      // Confirmation dialog lists the selected categories
      expect(find.text('确认清除'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('聊天记录和附件'),
        ),
        findsOneWidget,
        reason: 'Confirmation dialog must list the selected category',
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('内置浏览器数据'),
        ),
        findsOneWidget,
        reason: 'Confirmation dialog must list the selected category',
      );
      expect(find.text('确定清除（10）'), findsOneWidget);

      // Cancel closes the dialog without clearing
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('确认清除'), findsNothing);
    });

    testWidgets('clear flow unlocks confirmation after the countdown',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, '清除所选数据'),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, '清除所选数据'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, '清除所选数据'),
      );
      await tester.pumpAndSettle();

      // Button-based restart prompt (mirrors the startup migration dialog),
      // no countdown digits
      expect(find.text('部分数据已清除'), findsOneWidget);
      expect(find.text('立即重启'), findsOneWidget);
      expect(find.text('退出应用'), findsOneWidget);
      expect(find.text('5'), findsNothing,
          reason: 'Restart prompt must not use a countdown');
    });
  });

  testWidgets(
    'clear confirmation scrolls its full content at a compact viewport',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);

      await tester.pumpWidget(createTestApp(locale: const Locale('de')));
      await tester.pumpAndSettle();

      final clearButton = find.widgetWithText(
        OutlinedButton,
        'Ausgewählte Daten löschen',
      );
      for (var i = 0; i < 8 && clearButton.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(clearButton, findsOneWidget);
      await tester.ensureVisible(clearButton);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(clearButton);
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Gesprächsverlauf und Anhänge'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Dieser Vorgang kann nicht rückgängig gemacht werden. Starte die App nach dem Löschen neu, damit die Änderungen wirksam werden.',
        ),
        findsOneWidget,
      );

      final dialog = find.byType(AlertDialog);
      final cancel = find.descendant(
        of: dialog,
        matching: find.text('Abbrechen'),
      );
      final confirm = find.descendant(
        of: dialog,
        matching: find.text('Löschen (10)'),
      );
      expect(cancel, findsOneWidget);
      expect(confirm, findsOneWidget);
      expect(tester.getRect(cancel).overlaps(tester.getRect(confirm)), isFalse);

      final contentScroll = find.descendant(
        of: dialog,
        matching: find.byType(SingleChildScrollView),
      );
      expect(contentScroll, findsOneWidget);
      await tester.drag(contentScroll, const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      final viewport = tester.getRect(contentScroll);
      final warning = tester.getRect(
        find.text(
          'Dieser Vorgang kann nicht rückgängig gemacht werden. Starte die App nach dem Löschen neu, damit die Änderungen wirksam werden.',
        ),
      );
      expect(warning.top, greaterThanOrEqualTo(viewport.top));
      expect(warning.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(640));
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(640));

      await tester.tap(cancel);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Teilweise gelöscht'), findsNothing);
    },
  );

  testWidgets(
    'restore confirmation scrolls localized details and keeps both choices reachable',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final originalPicker = FilePickerPlatform.instance;
      final picker = _CancelingFilePicker();
      FilePickerPlatform.instance = picker;
      addTearDown(() => FilePickerPlatform.instance = originalPicker);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('de'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.7)),
              child: child!,
            ),
            home: const BackupRestorePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chooseBackup = find.widgetWithIcon(OutlinedButton, Icons.restore);
      await tester.scrollUntilVisible(
        chooseBackup,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(chooseBackup);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final dialog = find.byType(AlertDialog);
      final contentScroll = find.descendant(
        of: dialog,
        matching: find.byType(SingleChildScrollView),
      );
      expect(contentScroll, findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Gesprächsverlauf und Anhänge'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.text('Einstellungen'),
        ),
        findsOneWidget,
      );
      final cancel = find.descendant(
        of: dialog,
        matching: find.text('Abbrechen'),
      );
      final confirm = find.descendant(
        of: dialog,
        matching: find.text('Wiederherstellen'),
      );
      final cancelButton = find.ancestor(
        of: cancel,
        matching: find.byType(TextButton),
      );
      expect(cancel, findsOneWidget);
      expect(confirm, findsOneWidget);
      expect(tester.takeException(), isNull);

      final viewport = tester.getRect(contentScroll);
      final restartNoticeText =
          find.textContaining('Starte die App nach der Wiederherstellung neu');
      await tester.scrollUntilVisible(
        restartNoticeText,
        200,
        scrollable: find.descendant(
          of: contentScroll,
          matching: find.byType(Scrollable),
        ),
      );
      final restartNotice = tester.getRect(restartNoticeText);
      expect(restartNotice.top, greaterThanOrEqualTo(viewport.top));
      expect(restartNotice.bottom, lessThanOrEqualTo(viewport.bottom));
      expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(640));
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(640));
      // The decision buttons are fixed in the dialog action area while the
      // body scrolls; verify the actual button bounds remain on-screen.
      expect(tester.getRect(cancelButton).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(cancelButton).bottom, lessThanOrEqualTo(640));
      expect(cancelButton.hitTestable(), findsOneWidget);

      await tester.tap(cancelButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(AlertDialog), findsNothing);
      expect(picker.pickCallCount, 0);

      await tester.tap(chooseBackup);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final confirmAfterScroll = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Wiederherstellen'),
      );
      final confirmButton = find.ancestor(
        of: confirmAfterScroll,
        matching: find.byType(FilledButton),
      );
      await tester.tap(confirmButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(AlertDialog), findsNothing);
      expect(picker.pickCallCount, 1,
          reason: 'Confirming opens only the safe canceled file picker');
      expect(tester.takeException(), isNull);
    },
  );
}
