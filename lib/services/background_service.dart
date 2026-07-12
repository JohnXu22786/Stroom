import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _serviceName = 'com.johntsui.stroom.background_service';
const _serviceTitle = 'Stroom';
const _serviceContent = '后台任务运行中…';

Future<void> initializeBackgroundService() async {
  // ====================================================================
  // 在配置背景服务之前，先创建 Android 通知渠道。
  //
  // flutter_background_service_android v6.3.1 有一个 bug：
  // 当提供了自定义 notificationChannelId 时，插件不会自动创建
  // 通知渠道（只在未提供时创建默认渠道 "FOREGROUND_DEFAULT"）。
  // 如果不预先创建渠道，Android 8+ 上 startForeground() 会抛出
  // "Bad notification for startForeground" 导致应用崩溃。
  // ====================================================================
  try {
    await _createNotificationChannel();
  } catch (e) {
    debugPrint('[BackgroundService] Failed to create notification channel: $e');
  }

  try {
    final service = FlutterBackgroundService();

    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        // 不允许开机自启，避免 Android 12+ 的
        // ForegroundServiceStartNotAllowedException
        autoStartOnBoot: false,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _serviceName,
        initialNotificationTitle: _serviceTitle,
        initialNotificationContent: _serviceContent,
        foregroundServiceNotificationId: 4521,
      ),
    );
  } catch (e) {
    debugPrint('[BackgroundService] Failed to configure background service: $e');
  }
}

/// 创建 Android 通知渠道。
///
/// 使用 [FlutterLocalNotificationsPlugin] 的 Android 平台实现来创建
/// 通知渠道，确保背景服务的前台通知在 Android 8+ 上能正常显示。
Future<void> _createNotificationChannel() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;

  final plugin = FlutterLocalNotificationsPlugin();
  final androidPlugin =
      plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin == null) return;

  await androidPlugin.createNotificationChannel(
    AndroidNotificationChannel(
      _serviceName,
      _serviceTitle,
      description: _serviceContent,
      importance: Importance.low,
    ),
  );
  debugPrint('[BackgroundService] Notification channel created: $_serviceName');
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  Timer? _timer;
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((_) {
      _timer?.cancel();
      service.stopSelf();
    });
  }

  _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: _serviceTitle,
        content: _serviceContent,
      );
    }
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

Future<void> startBackgroundService() async {
  try {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  } catch (e) {
    debugPrint('[BackgroundService] Failed to start background service: $e');
  }
}

Future<void> stopBackgroundService() async {
  try {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  } catch (e) {
    debugPrint('[BackgroundService] Failed to stop background service: $e');
  }
}
