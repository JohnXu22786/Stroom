// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/pages/tts_page.dart';
import 'package:stroom/providers/provider_config.dart';
import 'package:stroom/providers/task_provider.dart';
import 'package:stroom/providers/tts_state_provider.dart';

class _LifecycleTasks extends TaskListNotifier {
  _LifecycleTasks(super.ref) {
    state = [
      SynthesisTask(
        id: 'running-tts',
        title: 'TTS task',
        text: 'Text',
        providerConfig: ProviderConfigItem(),
        modelConfig: ModelConfig(name: 'Test', modelId: 'test'),
      ),
    ];
  }

  @override
  void failAllRunningTasks({required String error}) {
    state = state
        .map((task) => task.status == TaskStatus.running
            ? task.copyWith(status: TaskStatus.failed, error: error)
            : task)
        .toList();
  }
}

class _EmptyAudioRecords extends AudioRecordsNotifier {
  @override
  Future<void> loadRecords() async {}
}

class _EmptyFolders extends FolderListNotifier {
  @override
  Future<void> loadFolders() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _LifecycleTasks tasks;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget app() => ProviderScope(
        overrides: [
          taskListProvider.overrideWith((ref) => tasks = _LifecycleTasks(ref)),
          audioRecordsProvider.overrideWith((ref) => _EmptyAudioRecords()),
          folderListProvider.overrideWith((ref) => _EmptyFolders()),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const TtsPage(),
        ),
      );

  testWidgets('inactive lifecycle state keeps TTS synthesis running',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    tasks = ProviderScope.containerOf(
      tester.element(find.byType(TtsPage)),
    ).read(taskListProvider.notifier) as _LifecycleTasks;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);

    expect(tasks.state.single.status, TaskStatus.running);
  });

  testWidgets('paused and detached states cancel running TTS synthesis',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    tasks = ProviderScope.containerOf(
      tester.element(find.byType(TtsPage)),
    ).read(taskListProvider.notifier) as _LifecycleTasks;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(tasks.state.single.status, TaskStatus.failed);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pump();
    tasks = ProviderScope.containerOf(
      tester.element(find.byType(TtsPage)),
    ).read(taskListProvider.notifier) as _LifecycleTasks;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
    expect(tasks.state.single.status, TaskStatus.failed);
  });
}
