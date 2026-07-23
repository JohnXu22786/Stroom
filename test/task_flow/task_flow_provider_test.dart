import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/task_flow/models/task_flow_definition.dart';
import 'package:stroom/task_flow/providers/task_flow_provider.dart';

void main() {
  group('TaskFlowNotifier', () {
    test('initial state is empty list', () {
      final notifier = TaskFlowNotifier();
      expect(notifier.state, isEmpty);
    });

    test('addFlow creates a new flow and returns its id', () {
      final notifier = TaskFlowNotifier();

      final id = notifier.addFlow(name: '我的流程');

      expect(notifier.state.length, 1);
      expect(notifier.state[0].name, '我的流程');
      expect(notifier.state[0].id, id);
    });

    test('addFlow with blocks creates a populated flow', () {
      final notifier = TaskFlowNotifier();

      final id = notifier.addFlow(
        name: '网页转文字',
        blocks: [
          TaskFlowBlock(typeKey: 'catcatch'),
          TaskFlowBlock(typeKey: 'audioSeparation'),
          TaskFlowBlock(typeKey: 'asr'),
        ],
      );

      expect(notifier.state[0].blocks.length, 3);
    });

    test('updateFlow updates name and description', () {
      final notifier = TaskFlowNotifier();
      final id = notifier.addFlow(name: '旧名称');

      notifier.updateFlow(id, name: '新名称', description: '新描述');

      expect(notifier.state[0].name, '新名称');
      expect(notifier.state[0].description, '新描述');
    });

    test('updateFlow with blocks updates the block list', () {
      final notifier = TaskFlowNotifier();
      final id = notifier.addFlow(name: '测试');

      notifier.updateFlow(
        id,
        blocks: [
          TaskFlowBlock(typeKey: 'asr'),
          TaskFlowBlock(typeKey: 'tts'),
        ],
      );

      expect(notifier.state[0].blocks.length, 2);
      expect(notifier.state[0].blocks[0].typeKey, 'asr');
    });

    test('updateFlow for nonexistent id does nothing', () {
      final notifier = TaskFlowNotifier();
      notifier.addFlow(name: '测试');

      notifier.updateFlow('nonexistent', name: '新名称');

      expect(notifier.state.length, 1);
      expect(notifier.state[0].name, '测试');
    });

    test('removeFlow removes the flow by id', () {
      final notifier = TaskFlowNotifier();
      final id1 = notifier.addFlow(name: '流程1');
      notifier.addFlow(name: '流程2');

      notifier.removeFlow(id1);

      expect(notifier.state.length, 1);
      expect(notifier.state[0].name, '流程2');
    });

    test('removeFlow for nonexistent id does nothing', () {
      final notifier = TaskFlowNotifier();
      notifier.addFlow(name: '测试');

      notifier.removeFlow('nonexistent');

      expect(notifier.state.length, 1);
    });

    test('duplicateFlow creates a copy with new id', () {
      final notifier = TaskFlowNotifier();
      final originalId = notifier.addFlow(
        name: '原流程',
        blocks: [TaskFlowBlock(typeKey: 'asr', params: {'saveFolder': 'test'})],
      );

      final newId = notifier.duplicateFlow(originalId);

      expect(notifier.state.length, 2);
      expect(newId, isNot(originalId));
      final original = notifier.state.firstWhere((f) => f.id == originalId);
      final copy = notifier.state.firstWhere((f) => f.id == newId);
      expect(copy.name, '${original.name} (副本)');
      expect(copy.blocks.length, original.blocks.length);
      expect(copy.blocks[0].params['saveFolder'], 'test');
    });

    test('duplicateFlow for nonexistent id returns null', () {
      final notifier = TaskFlowNotifier();

      final newId = notifier.duplicateFlow('nonexistent');

      expect(newId, isNull);
    });

    test('flows are ordered by updatedAt (newest first)', () async {
      final notifier = TaskFlowNotifier();
      final id1 = notifier.addFlow(name: '流程A');

      // Small delay to ensure different timestamps
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final id2 = notifier.addFlow(name: '流程B');

      // Initially: B (newer) then A (older)
      expect(notifier.state[0].name, '流程B');
      expect(notifier.state[1].name, '流程A');

      // Update A → it becomes newest
      await Future<void>.delayed(const Duration(milliseconds: 5));
      notifier.updateFlow(id1, name: '流程A_更新');
      expect(notifier.state[0].name, '流程A_更新');

      // Update B → it becomes newest again
      await Future<void>.delayed(const Duration(milliseconds: 5));
      notifier.updateFlow(id2, name: '流程B_更新');
      expect(notifier.state[0].name, '流程B_更新');
    });

    test('flows persist their data structure (toMap/fromMap roundtrip)', () {
      final notifier = TaskFlowNotifier();
      notifier.addFlow(
        name: '流程1',
        blocks: [TaskFlowBlock(typeKey: 'asr')],
      );
      notifier.addFlow(name: '流程2');

      // Check that the internal data structures are valid
      expect(notifier.state.length, 2);
      for (final flow in notifier.state) {
        // Serialize and deserialize
        final map = flow.toMap();
        final restored = TaskFlowDefinition.fromMap(map);
        expect(restored.id, flow.id);
        expect(restored.name, flow.name);
        expect(restored.blocks.length, flow.blocks.length);
      }
    });
  });
}
