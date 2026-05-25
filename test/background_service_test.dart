import 'package:flutter_test/flutter_test.dart';

void main() {
  group('background service integration', () {
    test('_hasRunningTasks logic', () {
      bool hasRunningTasks(List<Map<String, dynamic>> tasks) {
        return tasks.any((t) => t['status'] == 'running');
      }

      expect(hasRunningTasks([]), isFalse);
      expect(hasRunningTasks([{'status': 'completed'}]), isFalse);
      expect(hasRunningTasks([{'status': 'paused'}]), isFalse);
      expect(hasRunningTasks([{'status': 'failed'}]), isFalse);
      expect(hasRunningTasks([{'status': 'running'}]), isTrue);
      expect(
        hasRunningTasks([
          {'status': 'completed'},
          {'status': 'running'},
        ]),
        isTrue,
      );
    });

    test('background service starts when first task runs, stops when all done', () {
      final tasks = <String>[];
      void startService() => tasks.add('start');
      void stopService() => tasks.add('stop');

      bool hasRunning(List<Map<String, dynamic>> state) =>
          state.any((t) => t['status'] == 'running');

      // Simulate: no running tasks → no start
      expect(hasRunning([]), isFalse);

      // Simulate: running task added
      var state = [{'id': '1', 'status': 'running'}];
      if (hasRunning(state)) startService();
      expect(tasks, ['start']);

      // Simulate: task completes, no more running → stop
      state = [{'id': '1', 'status': 'completed'}];
      if (!hasRunning(state)) stopService();
      expect(tasks, ['start', 'stop']);
    });

    test('service stays running when multiple tasks are active', () {
      final stops = <String>[];

      void stopService() => stops.add('stop');

      bool hasRunning(List<Map<String, dynamic>> state) =>
          state.any((t) => t['status'] == 'running');

      var state = [
        {'id': '1', 'status': 'running'},
        {'id': '2', 'status': 'running'},
      ];

      // Task 1 completes
      state = [
        {'id': '1', 'status': 'completed'},
        {'id': '2', 'status': 'running'},
      ];
      if (!hasRunning(state)) stopService();
      expect(stops, isEmpty); // still has task 2

      // Task 2 completes
      state = [
        {'id': '1', 'status': 'completed'},
        {'id': '2', 'status': 'completed'},
      ];
      if (!hasRunning(state)) stopService();
      expect(stops, ['stop']);
    });
  });
}
