// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:stroom/services/storage_service.dart';
import 'package:stroom/task_flow/models/flow_payload.dart';
import 'package:stroom/task_flow/models/task_flow_execution.dart';
import 'package:stroom/task_flow/providers/task_flow_execution_provider.dart';

class _Documents extends PathProviderPlatform {
  _Documents(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _HeldRegistrationNotifier extends TaskFlowExecutionNotifier {
  _HeldRegistrationNotifier(this.file, {required this.acceptRegistration});

  final File file;
  final bool acceptRegistration;
  final entered = Completer<void>();
  final release = Completer<void>();
  bool holdNextWrite = false;
  int disposedStateReads = 0;
  Future<bool>? latestRequestedWrite;

  @override
  List<TaskFlowExecution> get state {
    if (!mounted) disposedStateReads++;
    return super.state;
  }

  @override
  Future<bool> persist() {
    final write = holdNextWrite ? _heldWrite() : super.persist();
    latestRequestedWrite = write;
    return write;
  }

  Future<bool> _heldWrite() async {
    holdNextWrite = false;
    // Real persistence owns its encoded snapshot before its storage awaits.
    final contents = jsonEncode(toJsonList(state));
    entered.complete();
    await release.future;
    if (!acceptRegistration) return false;
    await file.writeAsString(contents);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File file;
  late PathProviderPlatform previous;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flow_disposal_');
    file = File('${directory.path}/task_flows/executions.json');
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(directory.path);
    AppStorage.resetCache();
  });

  tearDown(() async {
    PathProviderPlatform.instance = previous;
    AppStorage.resetCache();
    await directory.delete(recursive: true);
  });

  Future<_HeldRegistrationNotifier> begin({required bool accepted}) async {
    final notifier =
        _HeldRegistrationNotifier(file, acceptRegistration: accepted);
    addTearDown(() {
      if (notifier.mounted) notifier.dispose();
    });
    notifier.state = [
      TaskFlowExecution(
        id: 'existing',
        flowId: 'flow',
        flowName: 'Flow',
        subTasks: [
          FlowSubTask(
            id: 'step',
            blockTypeKey: 'chat',
            blockLabel: 'Chat',
            subTaskId: 'child',
            subTaskType: 'background',
          ),
        ],
      ),
    ];
    expect(await notifier.persist(), isTrue);
    notifier.holdNextWrite = true;
    return notifier;
  }

  TaskFlowExecution submitted() => TaskFlowExecution(
        id: 'submitted',
        flowId: 'flow',
        flowName: 'Flow',
        status: FlowExecutionStatus.waiting,
        inputText: 'queued input',
      );

  Future<Map<String, Map<String, dynamic>>> saved() async => {
        for (final entry in (jsonDecode(await file.readAsString()) as List)
            .cast<Map<String, dynamic>>())
          entry['id'] as String: entry,
      };

  for (final change in ['checkpoint', 'cancellation']) {
    test('disposal preserves latest $change after a successful registration',
        () async {
      final notifier = await begin(accepted: true);
      final registration = notifier.addExecutions([submitted()]);
      await notifier.entered.future;
      Future<bool>? checkpoint;
      if (change == 'checkpoint') {
        checkpoint = notifier.saveStepResult(
            'existing', 'step', const FlowPayload.text('latest output'));
      } else {
        notifier.cancelExecution('existing');
      }
      notifier.dispose();
      notifier.release.complete();
      expect(await registration, isTrue);
      if (checkpoint != null) expect(await checkpoint, isTrue);
      expect(await notifier.latestRequestedWrite!, isTrue);
      expect(await notifier.persistenceResult, isTrue);

      final records = await saved();
      expect(records.keys, containsAll(['existing', 'submitted']));
      expect(records['submitted']!['status'], 'waiting');
      expect(records['submitted']!['inputText'], 'queued input');
      final existing = TaskFlowExecution.fromMap(records['existing']!);
      if (change == 'checkpoint') {
        expect(existing.subTasks.single.result?.value, 'latest output');
        expect(existing.subTasks.single.outcome, FlowStepOutcome.succeeded);
      } else {
        expect(existing.status, FlowExecutionStatus.cancelled);
        expect(existing.subTasks.single.outcome, FlowStepOutcome.cancelled);
      }
      expect(notifier.disposedStateReads, 0);
      expect(notifier.persistenceError, isNull);
    });
  }

  test(
      'disposal excludes a failed registration and saves existing cancellation',
      () async {
    final notifier = await begin(accepted: false);
    final registration = notifier.addExecutions([submitted()]);
    await notifier.entered.future;
    notifier.cancelExecution('existing');
    notifier.dispose();
    notifier.release.complete();
    expect(await registration, isFalse);
    expect(await notifier.latestRequestedWrite!, isTrue);
    expect(await notifier.persistenceResult, isTrue);

    final records = await saved();
    expect(records.keys, ['existing']);
    expect(records['existing']!['status'], 'cancelled');
    expect(notifier.disposedStateReads, 0);
    expect(notifier.persistenceError, isNull);
  });
}
