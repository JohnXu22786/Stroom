import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/task_list_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';

class _ScreenshotTasks extends TaskListNotifier {
  _ScreenshotTasks(super.ref, SynthesisTask task) {
    state = [task];
  }
}

void main() {
  final query = Uri.base.queryParameters;
  final scale = double.tryParse(query['scale'] ?? '1') ?? 1;
  final locale = switch (query['locale']) {
    'de' => const Locale('de', 'DE'),
    _ => const Locale('en'),
  };
  final disableAnimations = query['motion'] == 'reduce';
  final ownership = query['ownership'] == 'restoring'
      ? FlowExecutionRestoreStatus.restoring
      : FlowExecutionRestoreStatus.ready;
  final task = SynthesisTask(
    id: 'local-task-detail-fixture',
    title: 'Failed local synthesis task',
    status: TaskStatus.failed,
    error: 'The synthesis request failed after the server timed out.',
    text: 'Local screenshot fixture; no service is called.',
    providerConfig: ProviderConfigItem(providerName: 'Local fixture'),
    modelConfig: ModelConfig(name: 'Local fixture', modelId: 'fixture'),
    originalRequest: '{"model":"fixture"}',
    originalResponse: '{"error":"timeout"}',
  );
  final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

  runApp(
    ProviderScope(
      overrides: [
        taskListProvider.overrideWith((ref) {
          return _ScreenshotTasks(ref, task);
        }),
        taskFlowExecutionsProvider.overrideWith(
          (ref) => TaskFlowExecutionNotifier(),
        ),
        taskFlowExecutionRestoreStatusProvider.overrideWith(
          (ref) => ownership,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: const TaskListPage(),
      ),
    ),
  );
}
