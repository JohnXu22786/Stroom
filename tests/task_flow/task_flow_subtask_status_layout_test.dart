import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/task_flow_card.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/widgets/constrained_text.dart';

void main() {
  testWidgets('fallback subtask status reveals only when its slot clips it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final execution = TaskFlowExecution(
      id: 'flow-1',
      flowId: 'flow',
      flowName: 'F',
      status: FlowExecutionStatus.waiting,
      subTasks: [
        FlowSubTask(
          blockTypeKey: 'unknown',
          blockLabel: 'A fallback block',
          subTaskId: 'step-1',
          subTaskType: 'unknown',
          outcome: FlowStepOutcome.interrupted,
        ),
      ],
    );
    final executions = TaskFlowExecutionNotifier()..state = [execution];

    Future<void> pumpCard(Locale locale, double textScale) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskFlowExecutionsProvider.overrideWith((ref) => executions),
          ],
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: Scaffold(body: TaskFlowCard(execution: execution)),
          ),
        ),
      );
    }

    await pumpCard(const Locale('ar', 'SA'), 1.5);
    await tester.pump();
    await tester.tap(find.text('F'));
    await tester.pump();

    final strings = lookupAppLocalizations(const Locale('ar', 'SA'));
    final status = find.byWidgetPredicate(
      (widget) =>
          widget is ConstrainedText &&
          widget.data == strings.taskFlowCardInterrupted,
    );
    expect(status, findsOneWidget);
    expect(
      find.descendant(
        of: status,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == strings.taskFlowCardInterrupted,
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    final statusText = find.text(strings.taskFlowCardInterrupted);
    final start = tester.getTopLeft(statusText);
    await tester.pump(const Duration(milliseconds: 999));
    expect(tester.getTopLeft(statusText), start);
    await tester.pump(const Duration(milliseconds: 1));
    expect(tester.getTopLeft(statusText), start);
    await tester.pump(const Duration(milliseconds: 250));
    expect((tester.getTopLeft(statusText) - start).dx.abs(), greaterThan(1));

    tester.view.physicalSize = const Size(320, 640);
    await pumpCard(const Locale('de', 'DE'), 1);
    await tester.pump();
    await tester.pump();
    final germanStatus = lookupAppLocalizations(const Locale('de', 'DE'))
        .taskFlowCardInterrupted;
    final fittingStatus = find.text(germanStatus);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ConstrainedText && widget.data == germanStatus,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    final fittingStart = tester.getTopLeft(fittingStatus);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(fittingStatus), fittingStart);
  });
}
