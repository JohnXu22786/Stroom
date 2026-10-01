import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/task_flow/pages/task_flow_builder_page.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';

class _ControlledNotifier extends TaskFlowNotifier {
  final writes = <Completer<bool>>[];

  @override
  Future<bool> persist() {
    final write = Completer<bool>();
    writes.add(write);
    return write.future;
  }
}

Future<void> _openBuilder(WidgetTester tester, _ControlledNotifier notifier,
    {String? flowId}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [taskFlowListProvider.overrideWith((ref) => notifier)],
    child: MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => TaskFlowBuilderPage(
                    flowId: flowId, startInRunMode: flowId != null))),
            child: const Text('open builder'),
          ),
        );
      }),
    ),
  ));
  await tester.tap(find.text('open builder'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('failed save retains edits and dirty state, then retries once',
      (tester) async {
    final notifier = _ControlledNotifier();
    await _openBuilder(tester, notifier);
    await tester.enterText(
        find.widgetWithText(TextField, '输入任务流名称'), 'draft name');
    await tester.enterText(
        find.widgetWithText(TextField, '添加描述（可选）'), 'draft description');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskFlowBuilderPage), findsOneWidget);
    expect(find.text('任务流已创建'), findsNothing);
    expect(notifier.writes, hasLength(1));
    expect(
        tester
            .widget<TextButton>(find.widgetWithIcon(TextButton, Icons.save))
            .onPressed,
        isNull);
    final id = notifier.state.single.id;
    notifier.writes.single.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('保存失败，更改仍保留，请重试'), findsOneWidget);
    expect(find.text('draft name'), findsOneWidget);
    expect(find.text('draft description'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的更改？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(notifier.writes, hasLength(2));
    notifier.writes.last.complete(true);
    await tester.pumpAndSettle();
    expect(find.byType(TaskFlowBuilderPage), findsNothing);
    expect(find.text('任务流已创建'), findsOneWidget);
    expect(notifier.state.single.id, id);
    expect(notifier.state.single.description, 'draft description');
  });

  testWidgets('failed update stays in edit mode until retry is persisted',
      (tester) async {
    final notifier = _ControlledNotifier();
    final id = notifier.addFlow(name: 'saved name');
    notifier.writes.single.complete(true);
    notifier.writes.clear();
    await _openBuilder(tester, notifier, flowId: id);
    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, '输入任务流名称'), 'changed name');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('任务流已更新'), findsNothing);
    notifier.writes.single.complete(false);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'changed name'), findsOneWidget);
    expect(find.text('保存失败，更改仍保留，请重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    notifier.writes.last.complete(true);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '输入任务流名称'), findsNothing);
    expect(find.text('任务流已更新'), findsOneWidget);
    expect(find.byTooltip('编辑'), findsOneWidget);
    expect(notifier.state.single.name, 'changed name');
  });

  testWidgets('discarding a failed update restores the shared saved flow',
      (tester) async {
    final notifier = _ControlledNotifier();
    final id = notifier.addFlow(name: 'saved name');
    notifier.writes.single.complete(true);
    notifier.writes.clear();
    await _openBuilder(tester, notifier, flowId: id);
    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, '输入任务流名称'), 'discarded name');
    await tester.tap(find.text('保存'));
    await tester.pump();
    notifier.writes.single.complete(false);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();

    expect(notifier.state.single.name, 'saved name');
    expect(find.byTooltip('编辑'), findsOneWidget);
    expect(find.text('保存失败，更改仍保留，请重试'), findsNothing);
  });

  testWidgets('discarding a failed new draft removes it and invalidates retry',
      (tester) async {
    final notifier = _ControlledNotifier();
    await _openBuilder(tester, notifier);
    await tester.enterText(
        find.widgetWithText(TextField, '输入任务流名称'), 'discarded draft');
    await tester.tap(find.text('保存'));
    await tester.pump();
    notifier.writes.single.complete(false);
    await tester.pumpAndSettle();
    final retry =
        tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed;
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();

    expect(notifier.state, isEmpty);
    expect(find.byType(TaskFlowBuilderPage), findsNothing);
    expect(find.text('重试'), findsNothing);
    retry();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
