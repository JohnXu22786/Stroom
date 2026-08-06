import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/backup_restore_page.dart';
import 'package:stroom/services/app_log_service.dart';
import 'package:stroom/services/manifest_database.dart';

Widget createTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: BackupRestorePage(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 清除/恢复流程会触及 ManifestDatabase/WebFileStore，
    // 统一启用内存测试模式（与 backup_selection_test.dart 一致）
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    AppLogService.disableFileLogging();
  });

  group('BackupRestorePage - general rendering', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Title bar
      expect(find.text('数据备份与恢复'), findsOneWidget);
    });

    testWidgets('shows unified selection card with new categories',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Should find the unified selection section header
      expect(find.text('选择要备份或恢复的数据类别'), findsOneWidget);

      // New category labels should be present
      expect(find.text('聊天记录和附件'), findsAtLeast(1));
      expect(find.text('设置'), findsAtLeast(1));
      expect(find.text('图片'), findsAtLeast(1));
      expect(find.text('音频'), findsAtLeast(1));
      expect(find.text('视频'), findsAtLeast(1));
      expect(find.text('文本'), findsAtLeast(1));
      expect(find.text('任务'), findsAtLeast(1));
      expect(find.text('浏览器Cookies'), findsAtLeast(1));
    });

    testWidgets('export and import buttons both exist', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Scroll down to find buttons
      await tester.scrollUntilVisible(
        find.text('导出备份'),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();
      expect(find.text('导出备份'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('选择备份文件并恢复'),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();
      expect(find.text('选择备份文件并恢复'), findsOneWidget);
    });

    testWidgets('old section headers are gone (merged into one)',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // The old separate section headers should not exist
      expect(find.text('导入恢复'), findsNothing);

      // The old selection card titles should be gone
      expect(find.text('选择要备份的数据类别'), findsNothing);
      expect(find.text('选择要恢复的数据类别'), findsNothing);

      // The unified section header should exist
      expect(find.text('选择要备份或恢复的数据类别'), findsOneWidget);
    });

    testWidgets('anki data checkbox appears in unified selection card',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Scroll to find the Anki闪卡数据 checkbox in the unified selection
      await tester.scrollUntilVisible(
        find.text('Anki闪卡数据'),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();
      expect(find.text('Anki闪卡数据'), findsAtLeast(1));

      // Should show the subtitle describing it's the original data format
      expect(find.textContaining('Anki 原始数据库'), findsAtLeast(1));
    });

    testWidgets('auto backup path display does not contain 点击重新选择',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // The description text should not contain "点击重新选择目录"
      expect(find.textContaining('点击重新选择'), findsNothing);
    });

    testWidgets('anki section header shows Anki闪卡牌组', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Scroll to the Anki section
      await tester.scrollUntilVisible(
        find.text('Anki闪卡牌组'),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();
      expect(find.text('Anki闪卡牌组'), findsOneWidget);
      expect(find.text('导入/导出 .apkg 格式的 Anki 牌组'), findsOneWidget);
    });
  });

  group('BackupRestorePage - clear selected data', () {
    testWidgets('clear selected data button exists', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, '清除所选数据'),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();
      expect(find.widgetWithText(OutlinedButton, '清除所选数据'), findsOneWidget);
    });

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
          matching: find.text('浏览器Cookies'),
        ),
        findsOneWidget,
        reason: 'Confirmation dialog must list the selected category',
      );
      expect(find.text('确定清除'), findsOneWidget);

      // Cancel closes the dialog without clearing
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('确认清除'), findsNothing);
    });

    testWidgets('clear flow shows button-based restart prompt (no countdown)',
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
      await tester.tap(find.text('确定清除'));
      await tester.pumpAndSettle();

      // Button-based restart prompt (mirrors the startup migration dialog),
      // no countdown digits
      expect(find.text('数据清除完成'), findsOneWidget);
      expect(find.text('立即重启'), findsOneWidget);
      expect(find.text('退出应用'), findsOneWidget);
      expect(find.text('5'), findsNothing,
          reason: 'Restart prompt must not use a countdown');
    });
  });
}
