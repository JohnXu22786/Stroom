import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stroom/l10n/app_localizations.dart';
import 'package:stroom/services/notification_service.dart';

/// 记录插件 show 调用时使用的通知 ID。
final shownIds = <int>[];
final shownNotifications = <Map>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    shownIds.clear();
    shownNotifications.clear();
    NotificationService().updateLocaleOverride(null);
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
          shownNotifications.add(args);
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

  testWidgets('iOS notification permission request returns the system result',
      (tester) async {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var requestResult = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissionStatus') return 0;
      if (call.method == 'requestPermissions') {
        return <int, int>{17: requestResult};
      }
      return true;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = NotificationService();
    expect(
      await service.requestPermission(usageReason: 'test'),
      isFalse,
      reason: 'a denied system response must not be treated as permission',
    );

    requestResult = 1;
    expect(
      await service.requestPermission(usageReason: 'test'),
      isTrue,
      reason: 'a granted system response should enable notifications',
    );
    debugDefaultTargetPlatformOverride = null;
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

  test('notification IDs continue past persisted IDs after a process restart',
      () async {
    final service = NotificationService();
    await service.initialize();

    // The previous allocator used epoch seconds, with the first ID at the
    // process start second plus one. New IDs must use a separate range.
    final legacyRangeStart = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await service.showTaskCompletionNotification(
      taskId: 'before-restart',
      title: '测试OCR',
      typeLabel: '文字识别',
      success: true,
    );
    expect(shownIds.single, greaterThan(legacyRangeStart),
        reason: 'upgraded IDs must continue above the legacy timestamp range');

    // Retain the stored sequence while resetting the in-memory preferences,
    // as if the process had restarted within the same second.
    final prefs = await SharedPreferences.getInstance();
    final persistedId = prefs.getInt('last_notification_id')!;
    SharedPreferences.setMockInitialValues({
      'notifications_enabled': true,
      'last_notification_id': persistedId,
    });
    shownIds.clear();

    await service.showTaskCompletionNotification(
      taskId: 'after-restart',
      title: '测试OCR',
      typeLabel: '文字识别',
      success: true,
    );

    expect(shownIds, hasLength(1));
    expect(shownIds.single, greaterThan(persistedId),
        reason: 'a restarted process must not reuse a previously issued ID');
  });

  test('notifications are not sent when the user has disabled them', () async {
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

    expect(shownIds, isEmpty, reason: '关闭通知设置后不应发送任何系统通知');
  });

  test('system notifications localize app text and preserve task data',
      () async {
    final service = NotificationService();
    await service.initialize();

    service.updateLocaleOverride(const Locale('en', 'US'));
    await service.showTaskCompletionNotification(
      taskId: 'task-en',
      title: 'OCR report',
      typeLabel: 'OCR',
      success: true,
    );
    service.updateLocaleOverride(const Locale('zh', 'CN'));
    await service.showTaskCompletionNotification(
      taskId: 'task-zh',
      title: '识别报告',
      typeLabel: 'OCR',
      success: false,
      error: 'provider error',
    );

    expect(shownNotifications, hasLength(2));
    expect(shownNotifications[0]['title'], 'Task completed: OCR');
    expect(shownNotifications[0]['body'], 'OCR report completed');
    expect(shownNotifications[0]['payload'], 'task-en');
    expect(shownNotifications[1]['title'], '任务失败：OCR');
    expect(shownNotifications[1]['body'], '识别报告 失败：provider error');
    expect(shownNotifications[1]['payload'], 'task-zh');
  });

  test('blocked permission guidance follows the selected locale', () {
    final service = NotificationService();

    service.updateLocaleOverride(const Locale('en', 'US'));
    expect(
      service.blockedGuide,
      'Notifications are blocked. Open system settings and allow notifications for Stroom.',
    );
    service.updateLocaleOverride(const Locale('zh', 'CN'));
    expect(
      service.blockedGuide,
      '通知已被系统屏蔽，请前往系统设置允许 Stroom 的通知权限。',
    );
  });

  testWidgets('in-app banner localizes its heading and preserves task title',
      (tester) async {
    for (final locale in const [Locale('en', 'US'), Locale('zh', 'CN')]) {
      final strings = lookupAppLocalizations(locale);
      for (final (type, heading) in [
        (
          NotificationType.taskCompleted,
          strings.notificationBannerTaskCompletedHeading,
        ),
        (
          NotificationType.taskFailed,
          strings.notificationBannerTaskFailedHeading,
        ),
      ]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: InAppNotificationBanner(
              locale: locale,
              payload: NotificationPayload(
                taskId: 'task-banner',
                type: type,
                title: 'OCR report',
                typeLabel: 'OCR',
              ),
              isDark: false,
              onDismiss: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(heading), findsOneWidget);
        expect(find.text('OCR report'), findsOneWidget);
      }
    }

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
  testWidgets('fitting in-app banner title still dismisses after four seconds',
      (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: InAppNotificationBanner(
          payload: const NotificationPayload(
            taskId: 'fitting-title',
            type: NotificationType.taskCompleted,
            title: 'Done',
            typeLabel: 'Task',
          ),
          isDark: false,
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 3599));
    expect(dismissed, isFalse);
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets('clipped in-app title remains visible for the complete reveal',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var dismissed = false;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: InAppNotificationBanner(
          payload: NotificationPayload(
            taskId: 'clipped-title',
            type: NotificationType.taskCompleted,
            title: List.filled(100, 'long task title').join(' '),
            typeLabel: 'Task',
          ),
          isDark: false,
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 5));
    expect(dismissed, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 2));
    expect(dismissed, isFalse);
  });

  testWidgets('manual banner dismissal wins an auto-dismiss race',
      (tester) async {
    var dismissals = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: InAppNotificationBanner(
          payload: const NotificationPayload(
            taskId: 'manual-dismiss',
            type: NotificationType.taskCompleted,
            title: 'Done',
            typeLabel: 'Task',
          ),
          isDark: false,
          onDismiss: () => dismissals++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(dismissals, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(dismissals, 1);
  });

  testWidgets('banner auto dismissal pauses while the app is hidden',
      (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: InAppNotificationBanner(
          payload: const NotificationPayload(
            taskId: 'hidden-banner',
            type: NotificationType.taskCompleted,
            title: 'Done',
            typeLabel: 'Task',
          ),
          isDark: false,
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 10));
    expect(dismissed, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(dismissed, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(dismissed, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets('reduced motion wraps a clipped in-app banner title',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final title = List.filled(20, 'long task title').join(' ');
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: InAppNotificationBanner(
            payload: NotificationPayload(
              taskId: 'reduced-motion-title',
              type: NotificationType.taskCompleted,
              title: title,
              typeLabel: 'Task',
            ),
            isDark: false,
            onDismiss: () {},
          ),
        ),
      ),
    );
    final titleWidget = tester.widget<Text>(find.text(title));
    expect(titleWidget.maxLines, isNull);
  });

  testWidgets('updated banner title cancels a stale slide-out dismissal',
      (tester) async {
    var dismissals = 0;
    Widget banner(String title) => Directionality(
          textDirection: TextDirection.ltr,
          child: InAppNotificationBanner(
            key: const ValueKey('updated-banner'),
            payload: NotificationPayload(
              taskId: 'same-task',
              type: NotificationType.taskCompleted,
              title: title,
              typeLabel: 'Task',
            ),
            isDark: false,
            onDismiss: () => dismissals++,
          ),
        );

    await tester.pumpWidget(banner('Original title'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(banner('Updated title'));
    await tester.pumpAndSettle();

    expect(find.text('Updated title'), findsOneWidget);
    expect(dismissals, 0);
  });

  testWidgets('updated banner status cancels a stale slide-out dismissal',
      (tester) async {
    var dismissals = 0;
    Widget banner(NotificationType type) => Directionality(
          textDirection: TextDirection.ltr,
          child: InAppNotificationBanner(
            key: const ValueKey('updated-status-banner'),
            payload: NotificationPayload(
              taskId: 'same-task',
              type: type,
              title: 'Same title',
              typeLabel: 'Task',
            ),
            isDark: false,
            onDismiss: () => dismissals++,
          ),
        );

    await tester.pumpWidget(banner(NotificationType.taskFailed));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(banner(NotificationType.taskCompleted));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(dismissals, 0);
  });

  testWidgets('banner does not schedule dismissal after becoming hidden',
      (tester) async {
    var dismissed = false;
    tester.binding.addPostFrameCallback((_) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: InAppNotificationBanner(
          payload: const NotificationPayload(
            taskId: 'hidden-before-layout',
            type: NotificationType.taskCompleted,
            title: 'Done',
            typeLabel: 'Task',
          ),
          isDark: false,
          onDismiss: () => dismissed = true,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(dismissed, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });
}
