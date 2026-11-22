import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list_page.dart';
import 'package:stroom/providers/background_task_provider.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/providers/catcatch_provider.dart';

void main() {
  final query = Uri.base.queryParameters;
  final status = switch (query['status']) {
    'paused' => TaskStatus.paused,
    'failed' => TaskStatus.failed,
    _ => TaskStatus.completed,
  };
  final locale = const Locale('en');
  final task = SynthesisTask(
    id: 'local-screenshot-fixture',
    title: 'Local synthesis task',
    status: status,
    error: status == TaskStatus.failed ? 'Local example error' : null,
    text: 'Layout screenshot fixture; no service is called.',
    providerConfig: ProviderConfigItem(
      providerName: 'Local fixture',
      host: 'https://example.invalid',
      key: 'fixture-only',
    ),
    modelConfig: ModelConfig(name: 'Local fixture', modelId: 'fixture'),
    createdAt: DateTime(2025, 6, 1),
    downloadedFilePath: status == TaskStatus.completed
        ? '/tmp/stroom-synthesis-fixture.mp3'
        : null,
  );
  final dark = query['theme'] == 'dark';
  final scale = double.tryParse(query['scale'] ?? '2.5') ?? 2.5;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: dark ? Brightness.dark : Brightness.light,
  );

  runApp(
    ProviderScope(
      overrides: [
        catcatchTasksProvider.overrideWith((ref) {
          final notifier = CatCatchNotifier(ref);
          notifier.state = [];
          return notifier;
        }),
        taskListProvider.overrideWith((ref) {
          final notifier = TaskListNotifier(ref);
          notifier.state = [task];
          return notifier;
        }),
        backgroundTasksProvider.overrideWith((ref) {
          final notifier = BackgroundTaskNotifier();
          notifier.state = [];
          return notifier;
        }),
        taskListLastReadProvider.overrideWith((ref) => DateTime(2025, 1, 1)),
        taskFlowExecutionsProvider.overrideWith(
          (ref) => TaskFlowExecutionNotifier(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: const UnifiedTaskListPage(),
      ),
    ),
  );
}
