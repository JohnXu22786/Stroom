import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/utils/batch_rename.dart';
import 'package:stroom/widgets/batch_rename_dialog.dart';
import '../utils/batch_rename_test.dart' show bridge, file;

Future<void> open(WidgetTester tester,
    {BatchRenameConfig config = const BatchRenameConfig(),
    bool settle = true}) async {
  final items = [file('a', 'alpha'), file('b', 'beta')];
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                  key: const Key('open_workbench'),
                  onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => BatchRenameDialog(
                          items: items,
                          allFiles: items,
                          allFolders: const {},
                          bridge: bridge,
                          initialConfig: config)),
                  child: const Text('打开'))))));
  await tester.tap(find.byKey(const Key('open_workbench')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('后台预览完成前禁用执行，切换普通替换后不被旧结果覆盖', (tester) async {
    await open(tester,
        settle: false,
        config: const BatchRenameConfig(rules: [
          BatchReplaceOp(
              enabled: true, useRegex: true, find: '^', replace: 'X'),
        ]));
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('batch_rename_apply_btn')))
            .onPressed,
        isNull);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(find.text('正则表达式'));
    await tester.tap(find.text('正则表达式'));
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.text('Xalpha.txt'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('batch_rename_apply_btn')))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换宽窄布局保留无效数字草稿与搜索条件', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 700);
    await open(tester,
        config: const BatchRenameConfig(rules: [BatchNumberOp(enabled: true)]));
    await tester.enterText(find.byKey(const Key('batch_num_digits_field')), '');
    await tester.enterText(
        find.byKey(const Key('batch_preview_search')), 'beta');
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('batch_num_digits_field')))
            .controller!
            .text,
        isEmpty);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('batch_rename_apply_btn')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const Key('batch_preview_tab')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const Key('batch_preview_search')))
            .controller!
            .text,
        'beta');
    expect(find.text('1_alpha.txt'), findsNothing);
  });

  testWidgets('手机软键盘弹出后仍可滚动预览并操作，放大字体不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester,
        config: const BatchRenameConfig(rules: [
          BatchTemplateOp(enabled: true, pattern: '课程_{n}'),
        ]));
    await tester.tap(find.byKey(const Key('batch_preview_tab')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('batch_preview_search')), 'alpha');
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('batch_rename_preview_list')),
        const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('batch_rename_apply_btn')))
            .onPressed,
        isNotNull);
  });

  testWidgets('排除和手动覆盖后重新检查编号与冲突，可恢复规则结果', (tester) async {
    await open(tester,
        config:
            const BatchRenameConfig(numbering: BatchNumberOp(enabled: true)));
    await tester.ensureVisible(find.byKey(const Key('batch_include_file:a')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('batch_include_file:a')));
    await tester.pumpAndSettle();
    expect(find.text('1_beta.txt'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('batch_edit_file:b')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('batch_edit_file:b')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('batch_manual_name')), 'alpha');
    await tester.ensureVisible(find.byKey(const Key('batch_manual_save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('batch_manual_save')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('batch_rename_apply_btn')))
            .onPressed,
        isNull);
    await tester
        .ensureVisible(find.byKey(const Key('batch_clear_override_file:b')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('batch_clear_override_file:b')));
    await tester.pumpAndSettle();
    expect(find.text('1_beta.txt'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('batch_rename_apply_btn')))
            .onPressed,
        isNotNull);
  });

  testWidgets('调整规则顺序改变实时预览且重复规则可独立编辑', (tester) async {
    await open(tester,
        config: const BatchRenameConfig(rules: [
          BatchInsertOp(enabled: true, text: 'pre_'),
          BatchCaseOp(enabled: true, mode: BatchRenameCaseMode.upper),
        ]));
    expect(find.text('PRE_ALPHA.txt'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('batch_rule_down_0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('batch_rule_down_0')));
    await tester.pumpAndSettle();
    expect(find.text('pre_ALPHA.txt'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('batch_rule_duplicate_0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('batch_rule_duplicate_0')));
    await tester.pumpAndSettle();
    expect(find.text('pre_pre_ALPHA.txt'), findsOneWidget);
  });

  testWidgets('真实窄屏下切换规则与预览，非法位数和重置不使用旧配置', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester,
        config: const BatchRenameConfig(rules: [BatchNumberOp(enabled: true)]));
    await tester.enterText(
        find.byKey(const Key('batch_num_digits_field')), '999999999');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('batch_rename_apply_btn')))
            .onPressed,
        isNull);
    await tester.ensureVisible(find.byKey(const Key('batch_reset')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('batch_reset')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('batch_preview_tab')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('batch_preview_tab')));
    await tester.pumpAndSettle();
    expect(find.text('alpha.txt'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
