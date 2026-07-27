import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_log_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _serviceName = 'com.johntsui.stroom.background_service';
const _serviceTitle = 'Stroom';
const _serviceContent = '后台任务运行中…';

/// SharedPreferences key that stores whether the user has enabled the
/// background service. Persisted so that after a process death (e.g.,
/// Android system killing the process for memory), the app can restore
/// the background service on the next cold start.
const _backgroundServiceEnabledKey = 'background_service_enabled';

/// Method channel for communicating with the native Android keep-alive
/// watchdog (AlarmManager-based BroadcastReceiver).
const _keepAliveChannel = MethodChannel('com.johntsui.stroom/keepalive');

Future<void> initializeBackgroundService() async {
  await AppLogService.info('BackgroundService', '初始化后台服务');
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
    await AppLogService.error('BackgroundService', '创建通知渠道失败', e);
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
    await AppLogService.info('BackgroundService', '后台服务配置完成');
  } catch (e) {
    debugPrint(
        '[BackgroundService] Failed to configure background service: $e');
    await AppLogService.error('BackgroundService', '配置后台服务失败', e);
  }
}

/// 创建 Android 通知渠道。
///
/// 使用 [FlutterLocalNotificationsPlugin] 的 Android 平台实现来创建
/// 通知渠道，确保背景服务的前台通知在 Android 8+ 上能正常显示。
Future<void> _createNotificationChannel() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;

  final plugin = FlutterLocalNotificationsPlugin();
  final androidPlugin = plugin.resolvePlatformSpecificImplementation<
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
  Timer? timer;
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((_) {
      timer?.cancel();
      service.stopSelf();
    });

    // Set foreground notification immediately to ensure the foreground
    // service is properly recognized by the system from the start.
    // The periodic timer below keeps the notification updated, but the
    // first call should be immediate to avoid any window where the
    // foreground notification info is not yet set on the native side.
    service.setForegroundNotificationInfo(
      title: _serviceTitle,
      content: _serviceContent,
    );
  }

  timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
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
  await AppLogService.info('BackgroundService', '启动后台服务');
  try {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      final started = await service.startService();
      if (started) {
        await AppLogService.info('BackgroundService', '后台服务已启动');
      } else {
        await AppLogService.warning('BackgroundService', '后台服务启动返回失败');
        return;
      }
    }
    // Persist the enabled state so that if the process is killed by the
    // OS, the service can be auto-restored on the next cold start.
    await _setServiceEnabledPreference(true);
    // Activate the native AlarmManager keep-alive watchdog.
    // Schedules a periodic alarm that restarts the service if the
    // process was killed by the OS.
    _enableKeepAlive();
  } catch (e) {
    debugPrint('[BackgroundService] Failed to start background service: $e');
    await AppLogService.error('BackgroundService', '启动后台服务失败', e);
  }
}

Future<void> stopBackgroundService() async {
  await AppLogService.info('BackgroundService', '停止后台服务');
  try {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
      await AppLogService.info('BackgroundService', '后台服务已停止');
    }
    // Clear the persisted enabled state so the service is not
    // auto-restored on the next cold start.
    await _setServiceEnabledPreference(false);
    // Deactivate the native AlarmManager keep-alive watchdog.
    _disableKeepAlive();
  } catch (e) {
    debugPrint('[BackgroundService] Failed to stop background service: $e');
    await AppLogService.error('BackgroundService', '停止后台服务失败', e);
  }
}

Future<void> restartBackgroundService() async {
  await AppLogService.info('BackgroundService', '重新启动后台服务');
  try {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
      // Wait briefly for the service to stop before restarting.
      // The invoke('stopService') is fire-and-forget (no completion
      // acknowledgment from the platform), so we use a small delay as
      // a best-effort wait. 300ms is sufficient on all tested devices.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    await service.startService();
    await AppLogService.info('BackgroundService', '后台服务已重新启动');
  } catch (e) {
    debugPrint('[BackgroundService] Failed to restart background service: $e');
    await AppLogService.error('BackgroundService', '重新启动后台服务失败', e);
  }
}

/// Returns whether the current platform supports the background service.
///
/// Only Android and iOS support `flutter_background_service`.
/// Web and desktop platforms (Linux, macOS, Windows) return `false`.
bool isBackgroundServiceSupported() {
  if (kIsWeb) return false;
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return true;
  }
  return false;
}

/// Restores the background service on a cold start if it was previously
/// running before the process was killed.
///
/// On Android, the OS may kill the app process even when a foreground
/// service is active (memory pressure, aggressive battery optimization
/// on some ROMs). When the user reopens the app, this function detects
/// that the service was previously enabled and restarts it automatically,
/// providing a seamless experience.
///
/// Should be called once during app initialization, after
/// [initializeBackgroundService] has completed.
Future<void> restoreBackgroundServiceOnColdStart() async {
  if (!isBackgroundServiceSupported()) return;

  try {
    final prefs = await SharedPreferences.getInstance();
    final wasEnabled = prefs.getBool(_backgroundServiceEnabledKey) ?? false;
    if (!wasEnabled) return;

    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await AppLogService.info('BackgroundService', '检测到后台服务之前已启用，正在恢复...');
      await service.startService();
      await AppLogService.info('BackgroundService', '后台服务已恢复');
    }
  } catch (e) {
    debugPrint('[BackgroundService] Failed to restore background service: $e');
    await AppLogService.error('BackgroundService', '恢复后台服务失败', e);
  }
}

/// Persists the background service enabled state to SharedPreferences.
Future<void> _setServiceEnabledPreference(bool enabled) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backgroundServiceEnabledKey, enabled);
  } catch (e) {
    debugPrint('[BackgroundService] Failed to save service enabled state: $e');
    await AppLogService.error('BackgroundService', '保存后台服务启用状态失败', e);
  }
}

/// Activates the native AlarmManager keep-alive watchdog.
///
/// On Android, this schedules a periodic alarm via AlarmManager that
/// re-starts the foreground service if the OS killed the process.
/// The alarm survives process death and fires even if the device is
/// in deep sleep (Doze mode, with setInexactRepeating).
///
/// This is a fire-and-forget call — failures are logged but not
/// propagated since keep-alive is a best-effort enhancement.
void _enableKeepAlive() {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    _keepAliveChannel.invokeMethod('startKeepAlive');
  } catch (e) {
    debugPrint('[BackgroundService] Failed to enable keep-alive alarm: $e');
  }
}

/// Deactivates the native AlarmManager keep-alive watchdog.
void _disableKeepAlive() {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    _keepAliveChannel.invokeMethod('stopKeepAlive');
  } catch (e) {
    debugPrint('[BackgroundService] Failed to disable keep-alive alarm: $e');
  }
}

/// Checks whether the app is exempt from Android battery optimization.
///
/// Returns `true` if the user has added the app to the battery
/// optimization whitelist (Doze mode exemption). Returns `false` on
/// non-Android platforms or if the status cannot be determined.
Future<bool> isIgnoringBatteryOptimizations() async {
  if (defaultTargetPlatform != TargetPlatform.android) return true;
  try {
    final result = await _keepAliveChannel
        .invokeMethod<bool>('isIgnoringBatteryOptimizations');
    return result ?? false;
  } catch (e) {
    debugPrint(
        '[BackgroundService] Failed to check battery optimization status: $e');
    return false;
  }
}

/// Opens the system settings dialog for the user to exempt the app
/// from battery optimization.
///
/// On Android 6+, this shows the system's "Ignore battery optimization"
/// confirmation dialog. On some Chinese ROMs, this may fall back to
/// opening the app's settings page.
void requestIgnoreBatteryOptimizations() {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  if (const bool.fromEnvironment('FLUTTER_TEST')) return;
  try {
    _keepAliveChannel.invokeMethod('requestIgnoreBatteryOptimizations');
  } catch (e) {
    debugPrint(
        '[BackgroundService] Failed to request battery optimization exemption: $e');
  }
}
