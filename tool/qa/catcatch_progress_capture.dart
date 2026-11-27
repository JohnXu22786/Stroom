import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/catcatch_task_card.dart';

void main() {
  final query = Uri.base.queryParameters;
  final textScale = double.tryParse(query['scale'] ?? '') ?? 1;
  final darkTheme = query['theme'] == 'dark';
  final task = catcatch.CatCatchTask(
    id: 'catcatch-progress-percentage-capture',
    url: 'https://example.test/video',
    title: 'Example video download',
    expectedDurationSec: 120,
    status: catcatch.TaskStatus.running,
    steps: [
      catcatch.StepStatus.progressing(catcatch.StepType.downloading, 100),
    ],
    progress: 100,
    createdAt: DateTime(2026, 11, 27),
  );

  runApp(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: darkTheme ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ListView(
            children: [
              CatCatchTaskCard(
                task: task,
                isFlowManaged: true,
                taskListViewportHeight: 640,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
