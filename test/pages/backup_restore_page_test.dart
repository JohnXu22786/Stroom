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
    testWidgets('shows unified selection card with new categories',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      // Scroll to the unified selection card (it sits below the Anki section)
      await tester.scrollUntilVisible(
        find.text('选择要备份或恢复的数据类别'),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      // Should find the unified selection section header
      expect(find.text('选择要备份或恢复的数据类别'), findsOneWidget);

      // New category labels should be present (ListView is lazy-loaded,
      // so scroll to each label as needed)
      for (final label in [
        '聊天记录和附件',
        '设置',
        '图片',
        '音频',
        '视频',
        '文本',
        '任务',
        '浏览器Cookies',
      ]) {
        await tester.scrollUntilVisible(
          find.text(label),
          100.0,
          scrollable: find.byType(Scrollable),
        );
        await tester.pump();
        expect(find.text(label), findsAtLeast(1));
      }
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

  group('BackupRestorePage - stay-in-app hints', () {
    testWidgets('import confirm dialog shows the stay-in-app hint',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, '选择备份文件并恢复'),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(
          find.widgetWithText(OutlinedButton, '选择备份文件并恢复'));
      await tester.pumpAndSettle();

      expect(find.text('确认恢复'), findsOneWidget);
      expect(find.textContaining('不要离开应用'), findsOneWidget,
          reason: '恢复确认弹窗必须提示用户在恢复期间不要离开应用或息屏');
      expect(find.textContaining('息屏'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('确认恢复'), findsNothing);
    });

    testWidgets('export progress dialog shows the stay-in-app hint',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, '导出备份'),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, '导出备份'));
      await tester.pump();
      await tester.pump();

      expect(find.text('正在导出备份'), findsOneWidget);
      expect(find.textContaining('不要离开应用'), findsOneWidget,
          reason: '导出进度弹窗必须提示用户在导出期间不要离开应用或息屏');

      // 测试环境中 FilePicker 平台通道不可用，导出会失败并关闭进度弹窗。
      // 用有限次 pump 推进，避免在无限动画的进度圈上无超时等待。
      for (var i = 0;
          i < 10 && tester.any(find.text('正在导出备份'));
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('正在导出备份'), findsNothing);
    });

    testWidgets('restore progress dialog shows the stay-in-app hint',
        (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump();

      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, '选择备份文件并恢复'),
        200.0,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      await tester.tap(
          find.widgetWithText(OutlinedButton, '选择备份文件并恢复'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定恢复'));
      await tester.pump();
      // 等待确认弹窗退场动画完成（进度弹窗此时是唯一可见弹窗）
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('正在恢复备份'), findsOneWidget);
      expect(find.textContaining('不要离开应用'), findsOneWidget,
          reason: '恢复进度弹窗必须提示用户在恢复期间不要离开应用或息屏');
      expect(find.text('确认恢复'), findsNothing,
          reason: '确认弹窗应已退场，提示文本来自恢复进度弹窗');

      // 测试环境中 FilePicker 平台通道无响应，恢复流程会停在进度弹窗，
      // 这里只验证提示可见性，不等待操作结束。
    });
  });
}
