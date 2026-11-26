import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/l10n/app_localizations_en.dart';
import 'package:stroom/l10n/app_localizations_zh.dart';
import 'package:stroom/pages/task_list_page.dart';
import 'package:stroom/pages/task_list_shared.dart';
import 'package:stroom/widgets/constrained_text.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/pages/task_flow_run_page.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';

class _RecordingTasks extends TaskListNotifier {
  _RecordingTasks(super.ref, List<SynthesisTask> tasks) {
    state = tasks;
  }

  final calls = <String>[];

  @override
  void pauseTask(String taskId) => calls.add('pause:$taskId');

  @override
  void resumeTask(String taskId,
          {ProviderConfigItem? providerConfig, ModelConfig? modelConfig}) =>
      calls.add('resume:$taskId');

  @override
  void removeTask(String taskId) => calls.add('remove:$taskId');
}

class _SeededExecutions extends TaskFlowExecutionNotifier {
  _SeededExecutions(List<TaskFlowExecution> flows) {
    state = flows;
  }

  void replace(List<TaskFlowExecution> flows) => state = flows;
}

SynthesisTask _task(String id, TaskStatus status) => SynthesisTask(
      id: id,
      title: '任务 $id',
      status: status,
      text: '测试文本',
      providerConfig: ProviderConfigItem(
        providerName: '测试供应商',
        host: 'https://example.com',
        key: 'test',
      ),
      modelConfig: ModelConfig(name: '测试模型', modelId: 'test-model'),
    );

TaskFlowExecution _flow(String id, String name, SynthesisTask child) =>
    TaskFlowExecution(
      id: id,
      flowId: 'definition-$id',
      flowName: name,
      status: child.status == TaskStatus.paused
          ? FlowExecutionStatus.paused
          : FlowExecutionStatus.running,
      subTasks: [
        FlowSubTask(
          blockTypeKey: 'tts',
          blockLabel: '语音合成',
          subTaskId: child.id,
          subTaskType: 'tts',
          status: child.status,
        ),
      ],
    );

Future<_RecordingTasks> _pumpList(WidgetTester tester,
    List<SynthesisTask> tasks, List<TaskFlowExecution> flows,
    {FlowExecutionRestoreStatus restoreStatus =
        FlowExecutionRestoreStatus.ready,
    Locale locale = const Locale('zh', 'CN')}) async {
  late _RecordingTasks notifier;
  final executions = _SeededExecutions(flows);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskListProvider.overrideWith((ref) {
          notifier = _RecordingTasks(ref, tasks);
          return notifier;
        }),
        taskFlowExecutionsProvider.overrideWith((ref) => executions),
        taskFlowExecutionRestoreStatusProvider
            .overrideWith((ref) => restoreStatus),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: TaskListPage(),
      ),
    ),
  );
  await tester.pump();
  return notifier;
}

Future<void> _pumpTaskCard(
  WidgetTester tester,
  SynthesisTask task, {
  Size size = const Size(320, 640),
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool darkMode = false,
  ThemeData? themeOverride,
  FlowExecutionRestoreStatus restoreStatus =
      FlowExecutionRestoreStatus.restoring,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final executions = _SeededExecutions([]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskListProvider.overrideWith((ref) => _RecordingTasks(ref, [task])),
        taskFlowExecutionsProvider.overrideWith((ref) => executions),
        taskFlowExecutionRestoreStatusProvider.overrideWith(
          (ref) => restoreStatus,
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: themeOverride ?? ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            children: [TaskCard(task: task)],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('localized clear messages keep dynamic error details verbatim', () {
    final english = AppLocalizationsEnUs();
    final chinese = AppLocalizationsZhCn();
    const dynamicError = 'Provider timeout: request id 42';

    expect(
      english.unifiedTaskListClearIncomplete(dynamicError),
      'Clear incomplete: $dynamicError',
    );
    expect(
      chinese.unifiedTaskListClearIncomplete(dynamicError),
      '清除未完成：$dynamicError',
    );
    expect(
      english.unifiedTaskListCancellationSaveFailed,
      'Could not save the task flow cancellation state. Please retry clearing.',
    );
    expect(
      chinese.unifiedTaskListCancellationSaveFailed,
      '无法保存任务流的取消状态，请重试清除。',
    );
  });

  testWidgets('task detail dialog titles fit narrow localized layouts', (
    tester,
  ) async {
    const error = 'The synthesis request failed after the server timed out.';
    final task = SynthesisTask(
      id: 'failed-dialog',
      title: 'Failed task',
      status: TaskStatus.failed,
      error: error,
      text: 'Request text',
      providerConfig: ProviderConfigItem(providerName: 'Example'),
      modelConfig: ModelConfig(name: 'Voice', modelId: 'voice'),
      originalRequest: '{"model":"voice"}',
      originalResponse: '{"error":"timeout"}',
    );
    await _pumpTaskCard(
      tester,
      task,
      size: const Size(320, 640),
      locale: const Locale('de', 'DE'),
      textScale: 1.5,
      darkMode: true,
    );

    await tester.tap(find.text(error));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final strings = AppLocalizations.of(
      tester.element(find.byType(TaskCard)),
    )!;
    expect(find.text(strings.taskListSynthesisErrorTitle), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data == strings.taskListSynthesisErrorTitle,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(strings.taskListClose));
    await tester.pumpAndSettle();

    await tester.tap(find.text(strings.taskListDetail));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(strings.taskListOriginalExchange), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data == strings.taskListOriginalExchange,
      ),
      findsOneWidget,
    );
  });

  testWidgets('failed task detail label constrains only when it clips', (
    tester,
  ) async {
    final task = SynthesisTask(
      id: 'failed-detail-label',
      title: 'Failed task',
      status: TaskStatus.failed,
      error: 'The synthesis request failed after the server timed out.',
      text: 'Request text',
      providerConfig: ProviderConfigItem(providerName: 'Example'),
      modelConfig: ModelConfig(name: 'Voice', modelId: 'voice'),
      originalRequest: '{"model":"voice"}',
      originalResponse: '{"error":"timeout"}',
    );
    await _pumpTaskCard(
      tester,
      task,
      size: const Size(240, 640),
      locale: const Locale('de', 'DE'),
      textScale: 2.5,
      restoreStatus: FlowExecutionRestoreStatus.restoring,
    );

    expect(find.text('Details'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == 'Details',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpTaskCard(
      tester,
      task,
      size: const Size(700, 640),
      locale: const Locale('en'),
      restoreStatus: FlowExecutionRestoreStatus.ready,
    );
    expect(find.text('Details'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == 'Details',
      ),
      findsNothing,
    );
    final fittingLabelPosition = tester.getTopLeft(find.text('Details'));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.text('Details')), fittingLabelPosition);
  });

  testWidgets('fitting detail label preserves layout beside standalone control',
      (
    tester,
  ) async {
    final task = SynthesisTask(
      id: 'failed-detail-fitting-boundary',
      title: 'Failed task',
      status: TaskStatus.failed,
      error: 'Timeout',
      text: 'Request text',
      providerConfig: ProviderConfigItem(providerName: 'Example'),
      modelConfig: ModelConfig(name: 'Voice', modelId: 'voice'),
      originalRequest: '{"model":"voice"}',
    );
    await _pumpTaskCard(
      tester,
      task,
      size: const Size(700, 640),
      restoreStatus: FlowExecutionRestoreStatus.ready,
    );

    final label = find.text('Details');
    final constrainedDetails = find.byWidgetPredicate(
      (widget) => widget is ConstrainedText && widget.data == 'Details',
    );
    expect(constrainedDetails, findsNothing);
    final labelWidth = tester.getSize(label).width;
    final errorRow =
        find.ancestor(of: label, matching: find.byType(Container)).first;
    final currentRowWidth = tester.getSize(errorRow).width - 20;
    final targetRowWidth = labelWidth + 14 + 6 + 8 + 16 + 2;
    final targetViewportWidth = 700 - (currentRowWidth - targetRowWidth);

    await _pumpTaskCard(
      tester,
      task,
      size: Size(targetViewportWidth, 640),
      restoreStatus: FlowExecutionRestoreStatus.ready,
    );

    expect(find.text('Details'), findsOneWidget);
    expect(constrainedDetails, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail measurement inherits letter spacing', (
    tester,
  ) async {
    final baseTheme = ThemeData.light(useMaterial3: true);
    final themeWithLetterSpacing = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.copyWith(
        bodyMedium: baseTheme.textTheme.bodyMedium!.copyWith(letterSpacing: 6),
      ),
    );
    final task = SynthesisTask(
      id: 'failed-detail-letter-spacing',
      title: 'Failed task',
      status: TaskStatus.failed,
      error: 'Timeout',
      text: 'Request text',
      providerConfig: ProviderConfigItem(providerName: 'Example'),
      modelConfig: ModelConfig(name: 'Voice', modelId: 'voice'),
      originalRequest: '{"model":"voice"}',
    );
    await _pumpTaskCard(
      tester,
      task,
      size: const Size(390, 640),
      locale: const Locale('de', 'DE'),
      textScale: 2.5,
      themeOverride: themeWithLetterSpacing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == 'Details',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fitting task dialog title remains stationary', (tester) async {
    const error = 'Short failure.';
    final task = SynthesisTask(
      id: 'failed-dialog-fitting',
      title: 'Failed task',
      status: TaskStatus.failed,
      error: error,
      text: 'Request text',
      providerConfig: ProviderConfigItem(providerName: 'Example'),
      modelConfig: ModelConfig(name: 'Voice', modelId: 'voice'),
    );
    await _pumpTaskCard(
      tester,
      task,
      size: const Size(700, 640),
    );
    await tester.tap(find.text(error));
    await tester.pumpAndSettle();
    final title = find.text('Synthesis error details');
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedText &&
            widget.data == 'Synthesis error details',
      ),
      findsOneWidget,
    );
    final initialPosition = tester.getTopLeft(title);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(title), initialPosition);
  });

  testWidgets('task controls stay locked until flow ownership is restored',
      (tester) async {
    final flowChild = _task('flow-child', TaskStatus.paused);
    final standalone = _task('standalone', TaskStatus.paused);
    final notifier = await _pumpList(tester, [flowChild, standalone], [],
        restoreStatus: FlowExecutionRestoreStatus.restoring);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(TaskListPage)));
    final executions = container.read(taskFlowExecutionsProvider.notifier)
        as _SeededExecutions;

    expect(find.byTooltip('正在确认任务归属'), findsNWidgets(2));
    expect(find.text('继续'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    executions.replace([_flow('restored-run', '恢复的任务流', flowChild)]);
    await tester.pump();
    expect(find.text('查看任务流'), findsNothing);
    expect(find.text('继续'), findsNothing);

    container.read(taskFlowExecutionRestoreStatusProvider.notifier).state =
        FlowExecutionRestoreStatus.ready;
    await tester.pump();
    expect(find.text('查看任务流'), findsOneWidget);
    expect(find.text('继续'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(notifier.calls, isEmpty);

    container.read(taskFlowExecutionRestoreStatusProvider.notifier).state =
        FlowExecutionRestoreStatus.failed;
    await tester.pump();
    expect(find.byTooltip('任务流记录读取失败，操作暂不可用'), findsNWidgets(2));
    expect(find.text('继续'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('unified list waits for flow ownership before showing task cards',
      (tester) async {
    final flowChild = _task('flow-child', TaskStatus.paused);
    final executions = _SeededExecutions([]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        taskListProvider
            .overrideWith((ref) => _RecordingTasks(ref, [flowChild])),
        taskFlowExecutionsProvider.overrideWith((ref) => executions),
        taskFlowExecutionRestoreStatusProvider
            .overrideWith((ref) => FlowExecutionRestoreStatus.restoring),
      ],
      child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: UnifiedTaskListPage()),
    ));
    await tester.pump();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(UnifiedTaskListPage)));

    expect(find.text('正在恢复任务流记录…'), findsOneWidget);
    expect(find.text('任务 flow-child'), findsNothing);
    expect(
        tester
            .widget<PopupMenuButton<String>>(
                find.byType(PopupMenuButton<String>))
            .enabled,
        isFalse);
    executions.replace([_flow('restored-run', '恢复的任务流', flowChild)]);
    await tester.pump();
    expect(find.text('正在恢复任务流记录…'), findsOneWidget);

    container.read(taskFlowExecutionRestoreStatusProvider.notifier).state =
        FlowExecutionRestoreStatus.ready;
    await tester.pump();
    expect(find.text('恢复的任务流'), findsOneWidget);
    expect(find.text('任务 flow-child'), findsNothing);
    expect(
        tester
            .widget<PopupMenuButton<String>>(
                find.byType(PopupMenuButton<String>))
            .enabled,
        isTrue);
  });

  testWidgets('running flow child opens its own run without child controls',
      (tester) async {
    final child = _task('flow-child', TaskStatus.running);
    final notifier = await _pumpList(tester, [
      child
    ], [
      _flow('target-run', '目标流程', child),
      TaskFlowExecution(id: 'other-run', flowId: 'other', flowName: '其他流程'),
    ]);

    expect(find.text('查看任务流'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.text('查看任务流'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(TaskFlowRunPage), findsOneWidget);
    expect(find.text('目标流程'), findsOneWidget);
    expect(find.text('其他流程'), findsNothing);
    expect(notifier.calls, isEmpty);
  });

  testWidgets('paused flow child has no direct resume or removal',
      (tester) async {
    final child = _task('paused-child', TaskStatus.paused);
    final notifier =
        await _pumpList(tester, [child], [_flow('paused-run', '已暂停流程', child)]);

    expect(find.text('查看任务流'), findsOneWidget);
    expect(find.text('继续'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(notifier.calls, isEmpty);
  });

  testWidgets('ordinary running and paused tasks keep their controls',
      (tester) async {
    final running = _task('standalone-running', TaskStatus.running);
    final paused = _task('standalone-paused', TaskStatus.paused);
    final notifier = await _pumpList(tester, [running, paused], []);

    expect(find.text('查看任务流'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNWidgets(2));
    await tester.tap(find.descendant(
      of: find.ancestor(
        of: find.text('任务 standalone-running'),
        matching: find.byType(Card),
      ),
      matching: find.byType(PopupMenuButton<String>),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('暂停'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(notifier.calls, ['pause:standalone-running']);

    await tester.tap(find.text('继续'));
    await tester.pump();
    expect(notifier.calls, [
      'pause:standalone-running',
      'resume:standalone-paused',
    ]);

    await tester.tap(find.descendant(
      of: find.ancestor(
        of: find.text('任务 standalone-paused'),
        matching: find.byType(Card),
      ),
      matching: find.byType(PopupMenuButton<String>),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('清除任务'));
    await tester.pump();
    expect(notifier.calls, [
      'pause:standalone-running',
      'resume:standalone-paused',
      'remove:standalone-paused',
    ]);
  });

  testWidgets('shared task card status and actions follow the selected locale',
      (tester) async {
    final task = _task('english-running', TaskStatus.running);
    await _pumpList(
      tester,
      [task],
      [],
      locale: const Locale('en', 'US'),
    );

    expect(find.text('Running'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.ancestor(
        of: find.text('任务 english-running'),
        matching: find.byType(Card),
      ),
      matching: find.byType(PopupMenuButton<String>),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Clear task'), findsOneWidget);
  });
}
