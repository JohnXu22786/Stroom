import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
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

/// SharedPreferences keys for individual keep-alive strategy toggles.
/// All default to true (maximum protection). Users can disable
/// individual strategies from the BackgroundOptimizationPage.
const _watchdogEnabledKey = 'background_service_watchdog';
const _coldStartRestoreEnabledKey = 'background_service_cold_start_restore';
const _batteryReminderEnabledKey = 'background_service_battery_reminder';

/// SharedPreferences key for the desktop "minimize on close" behavior.
/// Defaults to true so that closing the window keeps the app running in
/// the taskbar, letting background tasks continue on desktop platforms.
const _desktopCloseMinimizeKey = 'desktop_close_minimize';

/// Method channel for communicating with the native Android keep-alive
/// watchdog (AlarmManager-based BroadcastReceiver).
const _keepAliveChannel = MethodChannel('com.johntsui.stroom/keepalive');

/// Timeout for keep-alive channel calls: a stalled platform channel
/// (busy main thread / ANR window) must never block startup, resume
/// or page checks forever.
const _keepAliveChannelTimeout = Duration(seconds: 8);

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
        // 前台服务类型与 AndroidManifest 中声明的
        // android:foregroundServiceType="dataSync" 保持一致，
        // 否则 Android 14+ 会因类型未声明而拒绝 startForeground。
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
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

  // 在所有平台上注册停止监听（包括 iOS）。
  //
  // iOS 上 FlutterBackgroundService 的前台 worker 会把
  // invoke('stopService') 转发到 on('stopService') 流，
  // 如果不注册监听，iOS 上的服务将永远无法停止，
  // isRunning() 会一直返回 true。
  service.on('stopService').listen((_) {
    timer?.cancel();
    // Android 与 iOS 的 ServiceInstance 都实现了 stopSelf()。
    service.stopSelf();
  });

  if (service is AndroidServiceInstance) {
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

  // Update every 2 seconds to keep the foreground notification
  // visibly active. Frequent updates signal to the OS that the
  // service is important and should not be killed.
  //
  // Android only: iOS 没有前台通知，不需要定时刷新。
  if (service is AndroidServiceInstance) {
    timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        service.setForegroundNotificationInfo(
          title: _serviceTitle,
          content: _serviceContent,
        );
      } catch (e) {
        // 通知刷新失败不影响服务本身运行，仅记录日志。
        debugPrint('[BackgroundService] Failed to update notification: $e');
      }
    });
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

/// 启动后台服务。
///
/// 返回 `true` 表示服务已启动（或已在运行），`false` 表示启动失败。
/// 失败原因已记录日志。
Future<bool> startBackgroundService() async {
  await AppLogService.info('BackgroundService', '启动后台服务');
  try {
    // Android 13+ 上通知权限决定前台服务通知是否可见。
    // 权限被拒绝时服务仍能启动（仅通知不可见），因此请求失败不阻塞。
    await _requestNotificationPermissionIfNeeded();

    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      final started = await service.startService();
      if (started) {
        await AppLogService.info('BackgroundService', '后台服务已启动');
      } else {
        await AppLogService.warning('BackgroundService', '后台服务启动返回失败');
        return false;
      }
    }
    // Persist the enabled state so that if the process is killed by the
    // OS, the service can be auto-restored on the next cold start.
    await _setServiceEnabledPreference(true);
    // Activate the native AlarmManager keep-alive watchdog (only if
    // the user has the watchdog toggle enabled).
    await _enableKeepAlive();
    return true;
  } catch (e) {
    debugPrint('[BackgroundService] Failed to start background service: $e');
    await AppLogService.error('BackgroundService', '启动后台服务失败', e);
    return false;
  }
}

/// 在 Android 13+（API 33）上请求通知权限。
///
/// 没有该权限时前台服务仍然可以运行，但常驻通知不会显示，
/// 用户会误以为服务没有启动。请求失败（例如用户拒绝）不抛出异常。
///
/// 使用超时保护：在极少数平台通道不可用/无响应的环境（例如测试环境）
/// 下，避免权限请求永久挂起阻塞服务启动。
Future<void> _requestNotificationPermissionIfNeeded() async {
  try {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final status = await Permission.notification.status
        .timeout(const Duration(seconds: 8));
    if (!status.isGranted) {
      await Permission.notification
          .request()
          .timeout(const Duration(seconds: 8));
    }
  } catch (e) {
    debugPrint(
        '[BackgroundService] Failed to request notification permission: $e');
  }
}

/// 停止后台服务。
///
/// 返回 `true` 表示停止流程成功执行（服务已停止或原本未运行）。
Future<bool> stopBackgroundService() async {
  await AppLogService.info('BackgroundService', '停止后台服务');
  try {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
      await AppLogService.info('BackgroundService', '后台服务已停止');
    }
    // 先取消 AlarmManager 看门狗，再持久化 enabled=false：
    // 顺序反了的话，若进程在这两步之间被杀，系统重启后会重新
    // 调度看门狗去复活一个用户已明确停止的服务。
    await _disableKeepAlive();
    // Clear the persisted enabled state so the service is not
    // auto-restored on the next cold start.
    await _setServiceEnabledPreference(false);
    return true;
  } catch (e) {
    debugPrint('[BackgroundService] Failed to stop background service: $e');
    await AppLogService.error('BackgroundService', '停止后台服务失败', e);
    return false;
  }
}

/// 重新启动后台服务。
///
/// 返回 `true` 表示重启成功，`false` 表示启动失败。
Future<bool> restartBackgroundService() async {
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
    final started = await service.startService();
    if (!started) {
      await AppLogService.warning('BackgroundService', '重启服务启动返回失败');
      return false;
    }
    // 重启后保持持久化状态与看门狗一致，防止重启过程中
    // 系统杀进程导致状态漂移（例如 enabled 标记丢失）。
    await _setServiceEnabledPreference(true);
    await _enableKeepAlive();
    await AppLogService.info('BackgroundService', '后台服务已重新启动');
    return true;
  } catch (e) {
    debugPrint('[BackgroundService] Failed to restart background service: $e');
    await AppLogService.error('BackgroundService', '重新启动后台服务失败', e);
    return false;
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
  if (!await isColdStartRestoreEnabled()) return;

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
    // 重新武装 AlarmManager 看门狗：进程被强杀/应用更新后闹钟可能丢失，
    // 冷启动恢复服务时必须同步重新调度，否则看门狗会永久失效。
    // 注意：恢复场景不清零失败计数（见 _rearmKeepAlive 注释）。
    await _rearmKeepAlive();
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

// ── Individual keep-alive strategy toggles ──────────────────────────────

/// Returns whether the AlarmManager watchdog is enabled.
/// Defaults to `true`.
Future<bool> isWatchdogEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_watchdogEnabledKey) ?? true;
  } catch (_) {
    return true;
  }
}

/// Enables or disables the AlarmManager watchdog.
Future<void> setWatchdogEnabled(bool enabled) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_watchdogEnabledKey, enabled);
  } catch (_) {}
}

/// Returns whether cold-start auto-restore is enabled.
/// Defaults to `true`.
Future<bool> isColdStartRestoreEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_coldStartRestoreEnabledKey) ?? true;
  } catch (_) {
    return true;
  }
}

/// Enables or disables cold-start auto-restore.
Future<void> setColdStartRestoreEnabled(bool enabled) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_coldStartRestoreEnabledKey, enabled);
  } catch (_) {}
}

/// Returns whether the battery optimization reminder card is visible.
/// Defaults to `true`.
Future<bool> isBatteryReminderEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_batteryReminderEnabledKey) ?? true;
  } catch (_) {
    return true;
  }
}

/// Enables or disables the battery optimization reminder card.
Future<void> setBatteryReminderEnabled(bool enabled) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_batteryReminderEnabledKey, enabled);
  } catch (_) {}
}

/// Activates the native AlarmManager keep-alive watchdog.
///
/// On Android, this schedules a periodic alarm via AlarmManager that
/// re-starts the foreground service if the OS killed the process.
/// The alarm survives process death: on Android 12+ with the exact-alarm
/// permission it uses setExactAndAllowWhileIdle (fires on time even in
/// deep Doze), otherwise it degrades to setAndAllowWhileIdle /
/// setInexactRepeating.
///
/// This is a fire-and-forget call — failures are logged but not
/// propagated since keep-alive is a best-effort enhancement.
Future<void> _enableKeepAlive() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  if (!await isWatchdogEnabled()) return;
  try {
    // await：invokeMethod 的失败是异步抛出的，不 await 会变成
    // 未处理的异步异常（每次冷启动/恢复前台都会触发）。
    // 超时保护：平台通道卡死时不能阻塞启动/恢复流程。
    await _keepAliveChannel
        .invokeMethod('startKeepAlive')
        .timeout(_keepAliveChannelTimeout);
  } catch (e) {
    debugPrint('[BackgroundService] Failed to enable keep-alive alarm: $e');
  }
}

/// 重新武装看门狗（冷启动恢复 / 回到前台补武装）。
///
/// 与 [_enableKeepAlive] 的区别：只重新调度闹钟，不清零连续失败计数。
/// 持久失败环境（Android 15 dataSync 上限、无电池豁免等）下，每次
/// 打开应用都清零计数会让看门狗永远无法进入退避保护。
Future<void> _rearmKeepAlive() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  if (!await isWatchdogEnabled()) return;
  try {
    await _keepAliveChannel
        .invokeMethod('rearmKeepAlive')
        .timeout(_keepAliveChannelTimeout);
  } catch (e) {
    debugPrint('[BackgroundService] Failed to re-arm keep-alive alarm: $e');
  }
}

Future<void> _disableKeepAlive() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _keepAliveChannel
        .invokeMethod('stopKeepAlive')
        .timeout(_keepAliveChannelTimeout);
  } catch (e) {
    debugPrint('[BackgroundService] Failed to disable keep-alive alarm: $e');
  }
}

/// Public wrapper for disabling the keep-alive watchdog from the UI.
void disableKeepAlive() {
  unawaited(_disableKeepAlive());
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
        .invokeMethod<bool>('isIgnoringBatteryOptimizations')
        .timeout(_keepAliveChannelTimeout);
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
Future<void> requestIgnoreBatteryOptimizations() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _keepAliveChannel
        .invokeMethod('requestIgnoreBatteryOptimizations')
        .timeout(_keepAliveChannelTimeout);
  } catch (e) {
    debugPrint(
        '[BackgroundService] Failed to request battery optimization exemption: $e');
  }
}

/// Returns whether the app is allowed to schedule exact alarms
/// (Android 12+). Exact alarms let the watchdog fire on time and are a
/// documented exemption for starting a foreground service from the
/// background. Returns `true` on non-Android platforms or if the status
/// cannot be determined.
Future<bool> canScheduleExactAlarms() async {
  if (defaultTargetPlatform != TargetPlatform.android) return true;
  try {
    final result = await _keepAliveChannel
        .invokeMethod<bool>('canScheduleExactAlarms')
        .timeout(_keepAliveChannelTimeout);
    return result ?? false;
  } catch (e) {
    debugPrint('[BackgroundService] Failed to check exact alarm status: $e');
    return false;
  }
}

/// Opens the system "Alarms & reminders" special-access page so the user
/// can grant the exact-alarm permission. When granted, the system sends
/// SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED and the native watchdog
/// re-arms itself immediately.
Future<void> requestScheduleExactAlarm() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _keepAliveChannel
        .invokeMethod('requestScheduleExactAlarm')
        .timeout(_keepAliveChannelTimeout);
  } catch (e) {
    debugPrint(
        '[BackgroundService] Failed to request exact alarm permission: $e');
  }
}

/// 应用回到前台时补武装保活看门狗（best-effort 自愈）。
///
/// 系统撤销「精确闹钟」权限时不会发送任何广播，且会静默删除所有
/// 精确闹钟 —— 此时看门狗会无声失效。用户从系统设置回到应用时
/// 补一次调度即可恢复。
Future<void> rearmKeepAliveOnResume() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final serviceEnabled = prefs.getBool(_backgroundServiceEnabledKey) ?? false;
    if (!serviceEnabled) return;
    // 补武装：不清零失败计数（持久失败环境下看门狗应保持退避）。
    // 注意：这里不再检查「冷启动自动恢复」开关 —— 该开关只控制冷启动
    // 恢复路径；看门狗开关（isWatchdogEnabled）在 _rearmKeepAlive 内部
    // 已检查。若用冷启动开关门控 resume 补武装，看门狗开启的用户在
    // 精确闹钟被系统撤销后会永久失去看门狗（resume 是唯一的补武装
    // 时机），而且已武装的闹钟触发时只检查 background_service_enabled，
    // 并不会因为冷启动开关而停止复活服务。
    await _rearmKeepAlive();
  } catch (e) {
    debugPrint('[BackgroundService] Failed to re-arm keep-alive on resume: $e');
  }
}

// ── Desktop keep-alive helpers ───────────────────────────────────────

/// Whether the current platform is a desktop platform
/// (Windows / macOS / Linux).
bool isDesktopPlatform() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Returns whether closing the desktop window should minimize the app
/// to the taskbar instead of quitting. Defaults to `true` so background
/// tasks keep running after the window is closed.
Future<bool> isDesktopCloseMinimizeEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_desktopCloseMinimizeKey) ?? true;
  } catch (_) {
    return true;
  }
}

/// Enables or disables the desktop "minimize on close" behavior.
Future<void> setDesktopCloseMinimizeEnabled(bool enabled) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_desktopCloseMinimizeKey, enabled);
  } catch (_) {}
}
