import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/backup_restore_page.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/manifest_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    AppLogService.disableFileLogging();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    required double textScale,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('de', 'DE'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const BackupRestorePage(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  // Unit owner: vertical_backup_info_scroll.
  // Functional suite mapping: feature-ui; production page dialog layout.
  testWidgets(
    'long German Anki details scroll at 320x640 and 2.5x while action stays visible',
    (tester) async {
      await pumpPage(tester, size: const Size(320, 640), textScale: 2.5);
      final strings = AppLocalizations.of(
        tester.element(find.byType(Scaffold)),
      )!;
      final pageList = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        find.text(strings.backupRestoreCategoryAnki),
        200,
        scrollable: pageList,
      );
      await tester.pump(const Duration(milliseconds: 500));
      final infoButton = find.byTooltip(
        strings.backupRestoreAnkiDataInfoTooltip,
      );
      await tester.tap(infoButton);
      await tester.pump(const Duration(milliseconds: 300));

      final dialog = find.byType(AlertDialog);
      final contentScroll = find.descendant(
        of: dialog,
        matching: find.byType(Scrollable),
      );
      expect(contentScroll, findsOneWidget);
      final scrollable = tester.state<ScrollableState>(contentScroll);
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      await tester.drag(contentScroll, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(scrollable.position.pixels, greaterThan(0));
      expect(
        find.text(strings.backupRestoreAnkiDataInfoMessage),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.text(strings.backupRestoreGotIt)).bottom,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'short German Anki import details keep the original fitting dialog at 320x640',
    (tester) async {
      await pumpPage(tester, size: const Size(320, 640), textScale: 1);
      final strings = AppLocalizations.of(
        tester.element(find.byType(Scaffold)),
      )!;
      final infoButton = find.byTooltip(strings.backupRestoreApkgInfoTooltip);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(infoButton);
      await tester.pump();
      await tester.tap(infoButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(strings.backupRestoreApkgInfoMessage), findsOneWidget);
      expect(find.text(strings.backupRestoreGotIt), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long German Anki details fit at 800x800 and 1x without layout errors',
    (tester) async {
      await pumpPage(tester, size: const Size(800, 800), textScale: 1);
      final strings = AppLocalizations.of(
        tester.element(find.byType(Scaffold)),
      )!;
      final pageList = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.drag(pageList, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 500));
      final infoButton = find.byTooltip(
        strings.backupRestoreAnkiDataInfoTooltip,
      );
      await tester.tap(infoButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(strings.backupRestoreAnkiDataInfoMessage),
        findsOneWidget,
      );
      expect(find.text(strings.backupRestoreGotIt), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
