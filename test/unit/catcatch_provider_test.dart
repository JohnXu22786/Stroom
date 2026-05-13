import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroom/catcatch/models/catcatch_task.dart';
import 'package:stroom/catcatch/models/media_resource.dart';
import 'package:stroom/catcatch/providers/catcatch_provider.dart';

// =============================================================================
// 单元测试：CatCatchNotifier
//
// 注意：addTask 会触发异步 _executeTask，但状态更新是同步发生的。
// 我们在`addTask`后立即检查状态（不 await），此时 async _executeTask
// 尚未更新状态，因此能正确验证初始同步值。
// testWidgets 用于自动管理测试 Zone 和初始化绑定。
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CatCatchNotifier', () {
    late ProviderContainer container;
    late CatCatchNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(catcatchTasksProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    // ──────────────────────────────────────────────
    // Initial state
    // ──────────────────────────────────────────────
    testWidgets('initial state is empty list', (tester) async {
      expect(container.read(catcatchTasksProvider), isEmpty);
    });

    // ──────────────────────────────────────────────
    // addTask — synchronous state, async execution pending
    // ──────────────────────────────────────────────
    testWidgets('addTask creates a running task synchronously', (tester) async {
      notifier.addTask('https://example.com/video.mp4', 30);

      final tasks = container.read(catcatchTasksProvider);
      expect(tasks.length, 1);
      expect(tasks[0].url, 'https://example.com/video.mp4');
      expect(tasks[0].expectedDurationSec, 30);
      // 同步状态下 task 是 running
      expect(tasks[0].status, TaskStatus.running);
    });

    testWidgets('addTask returns a non-empty id', (tester) async {
      final id = notifier.addTask('https://example.com/v.mp4', 10);
      expect(id, isNotEmpty);
    });

    testWidgets('addTask infers title from URL path segment', (tester) async {
      notifier.addTask('https://example.com/videos/cool_clip.mp4', 15);

      final tasks = container.read(catcatchTasksProvider);
      expect(tasks[0].title, contains('cool_clip.mp4'));
    });

    testWidgets('multiple tasks are appended (newest at last index)',
        (tester) async {
      notifier.addTask('https://example.com/1.mp4', 10);
      notifier.addTask('https://example.com/2.mp4', 20);

      final tasks = container.read(catcatchTasksProvider);
      expect(tasks.length, 2);
      // Implementation appends new tasks to the end (oldest first)
      expect(tasks.last.url, 'https://example.com/2.mp4');
    });

    testWidgets('addTask creates task with correct default properties',
        (tester) async {
      notifier.addTask('https://example.com/v.mp4', 30);

      final task = container.read(catcatchTasksProvider).first;
      expect(task.url, 'https://example.com/v.mp4');
      expect(task.expectedDurationSec, 30);
      expect(task.status, TaskStatus.running);
      expect(task.title, isNotEmpty);
      expect(task.id, isNotEmpty);
      expect(task.error, isNull);
      expect(task.selectedMedia, isNull);
      expect(task.downloadedFilePath, isNull);
    });

    // ──────────────────────────────────────────────
    // removeTask — synchronous
    // ──────────────────────────────────────────────
    testWidgets('removeTask removes the task', (tester) async {
      final id1 = notifier.addTask('https://example.com/a.mp4', 10);
      notifier.addTask('https://example.com/b.mp4', 20);

      notifier.removeTask(id1);
      final tasks = container.read(catcatchTasksProvider);
      expect(tasks.length, 1);
      expect(tasks[0].url, 'https://example.com/b.mp4');
    });

    testWidgets('removeTask with unknown id does nothing', (tester) async {
      notifier.addTask('https://example.com/a.mp4', 10);
      notifier.removeTask('non-existent-id');
      final tasks = container.read(catcatchTasksProvider);
      expect(tasks.length, 1);
    });

    // ──────────────────────────────────────────────
    // pauseTask — synchronous
    // ──────────────────────────────────────────────
    testWidgets('pauseTask changes status to paused', (tester) async {
      final id = notifier.addTask('https://example.com/v.mp4', 30);
      notifier.pauseTask(id);

      final task = container.read(catcatchTasksProvider).first;
      expect(task.status, TaskStatus.paused);
    });

    testWidgets('pauseTask with unknown id does nothing', (tester) async {
      notifier.addTask('https://example.com/v.mp4', 30);
      notifier.pauseTask('non-existent-id');

      final task = container.read(catcatchTasksProvider).first;
      expect(task.status, TaskStatus.running);
    });

    // ──────────────────────────────────────────────
    // selectMedia — synchronous
    // ──────────────────────────────────────────────
    testWidgets('selectMedia sets selectedMedia', (tester) async {
      final id = notifier.addTask('https://example.com/v.mp4', 30);
      const media = MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'video',
        ext: 'mp4',
        isPlayable: true,
      );
      notifier.selectMedia(id, media);

      final task = container.read(catcatchTasksProvider).first;
      expect(task.selectedMedia?.url, 'https://example.com/video.mp4');
      expect(task.selectedMedia?.name, 'video');
    });

    testWidgets('selectMedia with unknown id does nothing', (tester) async {
      notifier.addTask('https://example.com/v.mp4', 30);
      const media = MediaResource(
        url: 'https://example.com/video.mp4',
        name: 'video',
        ext: 'mp4',
        isPlayable: true,
      );
      notifier.selectMedia('non-existent-id', media);

      final task = container.read(catcatchTasksProvider).first;
      expect(task.selectedMedia, isNull);
    });

    // ──────────────────────────────────────────────
    // failAllRunningTasks — synchronous
    // ──────────────────────────────────────────────
    testWidgets('failAllRunningTasks marks running tasks as failed',
        (tester) async {
      // failAllRunningTasks catches tasks that are running or paused.
      // This test must see the task in running state, so we check
      // immediately after addTask before _executeTask completes.
      notifier.addTask('https://example.com/v.mp4', 30);
      notifier.failAllRunningTasks(error: 'App closed');

      final task = container.read(catcatchTasksProvider).first;
      expect(task.status, TaskStatus.failed);
      expect(task.error, contains('App closed'));
    });

    testWidgets('failAllRunningTasks also marks paused tasks as failed',
        (tester) async {
      final id = notifier.addTask('https://example.com/v.mp4', 30);
      notifier.pauseTask(id);
      notifier.failAllRunningTasks(error: 'Force quit');

      final task = container.read(catcatchTasksProvider).first;
      expect(task.status, TaskStatus.failed);
    });

    // ──────────────────────────────────────────────
    // resumeTask — synchronous
    // ──────────────────────────────────────────────
    testWidgets('resumeTask on a running task does nothing', (tester) async {
      final id = notifier.addTask('https://example.com/v.mp4', 30);
      notifier.resumeTask(id);

      final task = container.read(catcatchTasksProvider).first;
      expect(task.status, TaskStatus.running);
    });

    testWidgets('resumeTask with unknown id does nothing', (tester) async {
      notifier.addTask('https://example.com/v.mp4', 30);
      notifier.resumeTask('non-existent-id');

      final tasks = container.read(catcatchTasksProvider);
      expect(tasks.length, 1);
    });

    // ──────────────────────────────────────────────
    // retryTask — synchronous
    // ──────────────────────────────────────────────
    testWidgets('retryTask on a non-failed task does nothing', (tester) async {
      final id = notifier.addTask('https://example.com/v.mp4', 30);
      notifier.retryTask(id);

      final task = container.read(catcatchTasksProvider).first;
      expect(task.status, TaskStatus.running);
    });

    // ──────────────────────────────────────────────
    // Task ordering
    // ──────────────────────────────────────────────
    testWidgets('tasks preserve insertion order', (tester) async {
      notifier.addTask('https://example.com/first.mp4', 10);
      notifier.addTask('https://example.com/second.mp4', 20);
      notifier.addTask('https://example.com/third.mp4', 30);

      final tasks = container.read(catcatchTasksProvider);
      expect(tasks.length, 3);
      expect(tasks[0].url, 'https://example.com/first.mp4');
      expect(tasks[1].url, 'https://example.com/second.mp4');
      expect(tasks[2].url, 'https://example.com/third.mp4');
    });

    testWidgets('removeTask middle element preserves order of remaining',
        (tester) async {
      final id1 = notifier.addTask('https://example.com/first.mp4', 10);
      notifier.addTask('https://example.com/second.mp4', 20);
      notifier.addTask('https://example.com/third.mp4', 30);

      notifier.removeTask(id1);
      final tasks = container.read(catcatchTasksProvider);
      expect(tasks.length, 2);
      expect(tasks[0].url, 'https://example.com/second.mp4');
      expect(tasks[1].url, 'https://example.com/third.mp4');
    });

    // ──────────────────────────────────────────────
    // Property-based checks on CatCatchTask model
    // ──────────────────────────────────────────────
    testWidgets('createdAt is set to current time', (tester) async {
      final before = DateTime.now().millisecondsSinceEpoch;
      notifier.addTask('https://example.com/t.mp4', 60);
      final after = DateTime.now().millisecondsSinceEpoch;

      final task = container.read(catcatchTasksProvider).first;
      final createdAt = task.createdAt.millisecondsSinceEpoch;
      expect(createdAt, greaterThanOrEqualTo(before));
      expect(createdAt, lessThanOrEqualTo(after));
    });

    testWidgets('each task gets a unique id', (tester) async {
      final id1 = notifier.addTask('https://example.com/a.mp4', 10);
      final id2 = notifier.addTask('https://example.com/b.mp4', 20);

      expect(id1, isNot(equals(id2)));
    });
  });
}
