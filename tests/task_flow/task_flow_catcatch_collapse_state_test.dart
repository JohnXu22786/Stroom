import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart' as catcatch;
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/unified_task_list/task_flow_card.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';

class _CatCatchTasks extends CatCatchNotifier {
  _CatCatchTasks(Ref ref, catcatch.CatCatchTask task) : super(ref) {
    state = [task];
  }
}

void main() {
  testWidgets(
    'collapsing a flow preserves nested CatCatch resource selection',
    (tester) async {
      const media = MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'video',
        ext: 'mp4',
      );
      final task = catcatch.CatCatchTask(
        id: 'catcatch-1',
        url: 'https://example.com',
        title: 'Example page',
        expectedDurationSec: 0,
        createdAt: DateTime(2026),
        status: catcatch.TaskStatus.running,
        steps: [catcatch.StepStatus.running(catcatch.StepType.userSelecting)],
        detectedMedia: const [media],
      );
      final execution = TaskFlowExecution(
        id: 'flow-1',
        flowId: 'flow',
        flowName: 'Example flow',
        subTasks: [
          FlowSubTask(
            blockTypeKey: 'catcatch',
            blockLabel: 'CatCatch',
            subTaskId: task.id,
            subTaskType: 'catcatch',
          ),
        ],
      );
      final executions = TaskFlowExecutionNotifier()..state = [execution];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskFlowExecutionsProvider.overrideWith((ref) => executions),
            catcatchTasksProvider.overrideWith(
              (ref) => _CatCatchTasks(ref, task),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(body: TaskFlowCard(execution: execution)),
          ),
        ),
      );

      await tester.tap(find.text('Example flow'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('video.mp4'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('1 of 1 resources selected'), findsOneWidget);

      await tester.tap(find.text('Example flow'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('video.mp4'), findsNothing);

      await tester.tap(find.text('Example flow'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('1 of 1 resources selected'), findsOneWidget);
    },
  );
}
