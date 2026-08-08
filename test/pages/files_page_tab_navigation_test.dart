import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/pages/files_page.dart';
import 'package:stroom/pages/files_page_shared.dart';
import 'package:stroom/services/manifest_database.dart';
import 'package:stroom/utils/text_manifest.dart';

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(
      home: FilesPage(),
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ManifestDatabase.enableTestMode();
    TextManifest.invalidateCache();
  });

  group('FilesPage tab navigation - widget tests', () {
    testWidgets('double-tap on same tab increments reset signal',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Get reset signal value before double-tap
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TabBar)),
      );
      final initialReset = container.read(fileTabFolderResetSignalProvider(0));

      // Find the text tab in the TabBar
      final textTab = find.widgetWithText(Tab, '文本');
      expect(textTab, findsOneWidget);

      // First tap on text tab to set _lastTappedLogicalTabIndex to 0
      await tester.tap(textTab);
      await tester.pumpAndSettle();

      // Reset signal should still be unchanged (first tap on the
      // currently-shown tab should NOT reset - it just records the index)
      expect(
        container.read(fileTabFolderResetSignalProvider(0)),
        equals(initialReset),
        reason: 'First tap should NOT reset the tab',
      );

      // Second tap on same text tab should trigger reset
      await tester.tap(textTab);
      await tester.pumpAndSettle();

      // Reset signal should now be incremented
      expect(
        container.read(fileTabFolderResetSignalProvider(0)),
        equals(initialReset + 1),
        reason: 'Second tap SHOULD increment reset signal',
      );
    });

    testWidgets('switching tabs and back does NOT trigger reset signal',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // First tap on text tab to set _lastTappedLogicalTabIndex to 0
      final textTab = find.widgetWithText(Tab, '文本');
      await tester.tap(textTab);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TabBar)),
      );

      // Get reset signal values before switching
      final textResetBefore =
          container.read(fileTabFolderResetSignalProvider(0));
      final audioResetBefore =
          container.read(fileTabFolderResetSignalProvider(1));

      // Switch to audio tab
      final audioTab = find.widgetWithText(Tab, '音频');
      await tester.tap(audioTab);
      await tester.pumpAndSettle();

      // Switch back to text tab
      await tester.tap(textTab);
      await tester.pumpAndSettle();

      // Text tab reset signal should NOT have changed
      expect(
        container.read(fileTabFolderResetSignalProvider(0)),
        equals(textResetBefore),
        reason:
            'Switching to audio tab and back should NOT trigger text tab reset',
      );

      // Audio tab reset signal should also NOT have changed
      expect(
        container.read(fileTabFolderResetSignalProvider(1)),
        equals(audioResetBefore),
        reason: 'Audio tab reset signal should not have changed',
      );
    });

    testWidgets(
        'reorder keeps the viewed tab and does not spuriously reset on first tap',
        (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TabBar)),
      );

      // 先切到音频标签（逻辑标签 1）
      await tester.tap(find.widgetWithText(Tab, '音频'));
      await tester.pumpAndSettle();

      // 长按标签栏打开排序对话框
      // （该对话框此前会因 ReorderableListView 的 shrinkWrap 视口
      // 在 AlertDialog intrinsic 测量下崩溃 —— 必须能正常渲染）
      await tester.longPress(find.byKey(const Key('files_tab_bar_gesture')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('files_reorder_dialog')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '排序对话框必须能正常渲染');

      // 通过排序回调模拟把「文本」拖到「音频」之后。
      // onReorderItem 的 newIndex 已是移除后的索引：
      // 真实拖拽中框架会传 (0, 1)。
      final listView = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      listView.onReorderItem?.call(0, 1);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('files_reorder_confirm_btn')));
      await tester.pumpAndSettle();

      // 顺序变为 音频/文本/图片/视频，且当前查看的标签（音频）保持不变
      expect(container.read(fileTabOrderProvider), [1, 0, 2, 3]);

      // 排序后第一次点按当前标签不得触发「双击重置」误判
      final resetBefore = container.read(fileTabFolderResetSignalProvider(1));
      await tester.tap(find.widgetWithText(Tab, '音频'));
      await tester.pumpAndSettle();
      expect(
        container.read(fileTabFolderResetSignalProvider(1)),
        resetBefore,
        reason: '排序后的第一次点按不应触发重置信号',
      );

      // 连续第二次点按才触发重置
      await tester.tap(find.widgetWithText(Tab, '音频'));
      await tester.pumpAndSettle();
      expect(
        container.read(fileTabFolderResetSignalProvider(1)),
        resetBefore + 1,
      );
    });
  });
}
