import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/services/notification_service.dart';

/// 记录插件 show 调用时使用的通知 ID。
final shownIds = <int>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    shownIds.clear();
    SharedPreferences.setMockInitialValues({
      'notifications_enabled': true,
    });

    // 模拟通知插件的方法通道：initialize 返回成功，show 记录通知 ID。
    // （插件在测试环境中没有原生端，通道调用永远不会完成，必须 mock。）
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall call) async {
        if (call.method == 'initialize') return true;
        if (call.method == 'show') {
          final args = call.arguments as Map;
          shownIds.add(args['id'] as int);
          return null;
        }
        return null;
      },
    );

    // 让插件平台分发（resolvePlatformSpecificImplementation）能拿到
    // Android 实现（默认实例在测试环境中未注册，访问会抛错）。
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
  });

  test(
      'task completion notifications use strictly increasing positive IDs '
      '(no hashCode collisions, no negative IDs)', () async {
    final service = NotificationService();
    await service.initialize();

    // 同一任务多次完成（旧实现用 taskId.hashCode 会导致 ID 相同，
    // 后一条通知覆盖前一条）。
    await service.showTaskCompletionNotification(
      taskId: 'task-a',
      title: '测试OCR',
      typeLabel: '文字识别',
      success: true,
    );
    await service.showTaskCompletionNotification(
      taskId: 'task-a',
      title: '测试OCR',
      typeLabel: '文字识别',
      success: true,
    );
    // 不同任务（失败路径同样需要唯一 ID）。
    await service.showTaskCompletionNotification(
      taskId: 'task-b',
      title: '测试ASR',
      typeLabel: '音频转写',
      success: false,
      error: '网络超时',
    );

    expect(shownIds.length, 3);
    expect(shownIds[1], greaterThan(shownIds[0]),
        reason: '同一任务的通知 ID 也必须递增，不能互相覆盖');
    expect(shownIds[2], greaterThan(shownIds[1]));
    expect(shownIds.every((id) => id > 0), isTrue,
        reason: '通知 ID 不能为负数（部分 ROM 对负 ID 处理异常）');
  });

  test('notifications are not sent when the user has disabled them',
      () async {
    SharedPreferences.setMockInitialValues({
      'notifications_enabled': false,
    });

    final service = NotificationService();
    await service.initialize();

    await service.showTaskCompletionNotification(
      taskId: 'task-c',
      title: '测试OCR',
      typeLabel: '文字识别',
      success: true,
    );

    expect(shownIds, isEmpty,
        reason: '关闭通知设置后不应发送任何系统通知');
  });
}
