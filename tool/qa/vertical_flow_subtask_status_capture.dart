import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/task_flow_card.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';

void main() {
  final query = Uri.base.queryParameters;
  final localeCode = query['locale'] ?? 'de-DE';
  final localeParts = localeCode.split('-');
  final locale = Locale(
    localeParts.first,
    localeParts.length > 1 ? localeParts[1] : null,
  );
  final textScale = double.tryParse(query['scale'] ?? '') ?? 1;
  final motion = query['motion'] == 'true';
  final brightness =
      query['theme'] == 'dark' ? Brightness.dark : Brightness.light;
  final execution = TaskFlowExecution(
    id: 'flow-status-preview',
    flowId: 'sample-flow',
    flowName: 'Sample flow',
    status: FlowExecutionStatus.interrupted,
    subTasks: [
      FlowSubTask(
        blockTypeKey: 'unknown',
        blockLabel: 'Example fallback step',
        subTaskId: 'sample-step',
        subTaskType: 'unknown',
        outcome: FlowStepOutcome.interrupted,
      ),
    ],
  );
  final executions = TaskFlowExecutionNotifier()..state = [execution];

  runApp(
    ProviderScope(
      overrides: [
        taskFlowExecutionsProvider.overrideWith((_) => executions),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: brightness,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: false,
          ),
          child: TickerMode(enabled: motion, child: child!),
        ),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: TaskFlowCard(execution: execution),
            ),
          ),
        ),
      ),
    ),
  );
}
