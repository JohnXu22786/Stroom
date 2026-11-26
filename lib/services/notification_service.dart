import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart'
    show
        debugPrint,
        defaultTargetPlatform,
        kIsWeb,
        TargetPlatform,
        visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/locale_provider.dart';

import '../widgets/constrained_text.dart';

// ============================================================================
// Notification settings keys
// ============================================================================

const _notificationsEnabledKey = 'notifications_enabled';
const _notificationsPermissionRequestedKey =
    'notifications_permission_requested';
const _lastNotificationIdKey = 'last_notification_id';
const _notificationIdNamespaceStart = 2000000000;
const _legacyNotificationIdSafetyMargin = 10000000;

// ============================================================================
// Notification Service
// ============================================================================

/// Notification service for in-app banner and system notifications.
///
/// Handles:
/// - In-app top banner when task completes while app is in foreground
/// - System notification when task completes while app is in background
/// - Permission request with rationale
/// - Settings persistence
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  FlutterLocalNotificationsPlugin? _plugin;
  bool _initialized = false;
  Locale? _localeOverride;

  /// Keeps service strings in sync with the app's selected locale.
  void updateLocaleOverride(Locale? locale) => _localeOverride = locale;

  /// Serializes ID reservations so overlapping notifications cannot store
  /// the same value in shared preferences.
  Future<void> _notificationIdReservationQueue = Future.value();
  Future<void> _notificationSettingQueue = Future.value();

  /// Callback for in-app notification display.
  /// Set by the app shell to show an in-app banner.
  void Function(NotificationPayload)? onInAppNotification;

  // ========================================================================
  // Initialization
  // ========================================================================

  /// Initialize the notification plugin.
  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _localeOverride ??= localeFromCode(prefs.getString(localePreferenceKey));
      _plugin = FlutterLocalNotificationsPlugin();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      // 桌面端也需要初始化：窗口最小化/关闭后任务完成通知
      // 仍要通过系统通知提示用户（in-app 横幅不可见）。
      final strings = appLocalizationsForLocale(_localeOverride);
      final settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
        linux: LinuxInitializationSettings(
          defaultActionName: strings.desktopTrayOpen,
        ),
        windows: WindowsInitializationSettings(
          appName: 'Stroom',
          appUserModelId: 'com.johntsui.stroom',
          guid: '1a2b3c4d-0000-4000-8000-000000000000',
        ),
      );

      await _plugin!.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      _initialized = true;
      debugPrint('[NotificationService] Initialized');
    } catch (e) {
      debugPrint('[NotificationService] Initialization failed: $e');
    }
  }

  // ========================================================================
  // Permissions
  // ========================================================================

  /// Check if notifications are enabled (user setting).
  Future<bool> get isEnabled {
    if (kIsWeb) return Future.value(false);
    final completer = Completer<bool>();
    _notificationSettingQueue = _notificationSettingQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        completer.complete(prefs.getBool(_notificationsEnabledKey) ?? false);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  /// Set whether notifications are enabled.
  Future<void> setEnabled(bool value) {
    final completer = Completer<void>();
    _notificationSettingQueue = _notificationSettingQueue.then((_) async {
      try {
        await _writeEnabled(value);
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  /// Lets widget tests drain work before a fake-async zone is closed.
  @visibleForTesting
  Future<void> get notificationSettingQueueForTesting =>
      _notificationSettingQueue;

  /// Detaches the next test from a previous test's async zone.
  @visibleForTesting
  void resetNotificationSettingQueueForTesting() {
    _notificationSettingQueue = Future<void>.value();
  }

  Future<void> _writeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final previousValue = prefs.getBool(_notificationsEnabledKey);
    try {
      if (!await prefs.setBool(_notificationsEnabledKey, value)) {
        throw StateError('Failed to save notification setting.');
      }
    } catch (_) {
      if (previousValue == null) {
        await prefs.remove(_notificationsEnabledKey);
      } else {
        await prefs.setBool(_notificationsEnabledKey, previousValue);
      }
      rethrow;
    }
  }

  /// Check if permission has been requested before.
  Future<bool> get hasPermissionBeenRequested async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsPermissionRequestedKey) ?? false;
  }

  /// Request notification permission with rationale.
  ///
  /// Returns true if permission is granted.
  Future<bool> requestPermission({required String usageReason}) async {
    if (kIsWeb) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsPermissionRequestedKey, true);

      // On Android 13+, notification permission is needed
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        if (status.isGranted) return true;

        final result = await Permission.notification.request();
        if (result.isGranted) return true;

        if (result.isPermanentlyDenied) {
          debugPrint('[NotificationService] Permission permanently denied');
        }
        return false;
      }

      // On iOS, permission is handled by the plugin
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final status = await Permission.notification.status;
        if (status.isGranted) return true;

        final result = await Permission.notification.request();
        return result.isGranted;
      }

      return false;
    } catch (e) {
      debugPrint('[NotificationService] Permission request failed: $e');
      return false;
    }
  }

  /// Check the system permission status.
  Future<PermissionStatus> get systemPermissionStatus async {
    if (kIsWeb) return PermissionStatus.granted;
    return await Permission.notification.status;
  }

  /// Open app settings.
  Future<bool> openAppSystemSettings() async {
    return await openAppSettings();
  }

  // ========================================================================
  // Show Notifications
  // ========================================================================

  /// Show a notification for task completion.
  ///
  /// If the app is in the foreground, shows an in-app banner.
  /// Otherwise, shows a system notification.
  Future<void> showTaskCompletionNotification({
    required String taskId,
    required String title,
    required String typeLabel,
    required bool success,
    String? error,
  }) async {
    if (!await isEnabled) return;

    final payload = NotificationPayload(
      taskId: taskId,
      type: success
          ? NotificationType.taskCompleted
          : NotificationType.taskFailed,
      title: title,
      typeLabel: typeLabel,
      error: error,
    );

    // Always show in-app banner (foreground)
    onInAppNotification?.call(payload);

    // Also show system notification (for when app is in background)
    await _showSystemNotification(payload);
  }

  Future<void> _showSystemNotification(NotificationPayload payload) async {
    if (_plugin == null || !_initialized) return;

    try {
      final strings = appLocalizationsForLocale(_localeOverride);
      final androidDetails = AndroidNotificationDetails(
        'task_completion',
        strings.notificationSettingsTaskCompleteTitle,
        channelDescription: strings.notificationSettingsTaskCompleteDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
        linux: LinuxNotificationDetails(
          defaultActionName: strings.desktopTrayOpen,
        ),
        windows: const WindowsNotificationDetails(),
      );

      final title = payload.success
          ? strings.notificationTaskCompletedTitle(payload.typeLabel)
          : strings.notificationTaskFailedTitle(payload.typeLabel);
      final body = payload.success
          ? strings.notificationTaskCompletedBody(payload.title)
          : strings.notificationTaskFailedBody(
              payload.title,
              payload.error ?? strings.notificationUnknownError,
            );

      // Persist each ID before showing it so a quick process restart cannot
      // reuse an ID that is still present in the system notification tray.
      final notificationId = await _reserveNotificationId();
      await _plugin!.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload.taskId,
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Failed to show system notification: $e',
      );
    }
  }

  Future<int> _reserveNotificationId() {
    final completer = Completer<int>();
    _notificationIdReservationQueue = _notificationIdReservationQueue.then((
      _,
    ) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentSecond = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final firstId = _notificationIdNamespaceStart >
                currentSecond + _legacyNotificationIdSafetyMargin
            ? _notificationIdNamespaceStart
            : currentSecond + _legacyNotificationIdSafetyMargin;
        final lastId = prefs.getInt(_lastNotificationIdKey) ?? firstId - 1;
        if (lastId >= 0x7fffffff) {
          throw StateError('Notification ID range is exhausted');
        }
        final nextId = lastId + 1;
        if (!await prefs.setInt(_lastNotificationIdKey, nextId)) {
          throw StateError('Could not persist the next notification ID');
        }
        completer.complete(nextId);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _onNotificationResponse(NotificationResponse response) {
    // Handle notification tap - navigate to task list
    debugPrint(
      '[NotificationService] Notification tapped: ${response.payload}',
    );
  }

  // ========================================================================
  // Blocked/Denied Guide
  // ========================================================================

  /// Get a guide string for when notifications are blocked by the system.
  String get blockedGuide {
    final strings = appLocalizationsForLocale(_localeOverride);
    if (Platform.isAndroid) {
      return strings.notificationSettingsPermissionBlockedAndroid;
    } else if (Platform.isIOS) {
      return strings.notificationSettingsPermissionBlockedIos;
    }
    return strings.notificationSettingsPermissionBlockedGuide;
  }
}

// ============================================================================
// Payload
// ============================================================================

enum NotificationType { taskCompleted, taskFailed }

class NotificationPayload {
  final String taskId;
  final NotificationType type;
  final String title;
  final String typeLabel;
  final String? error;

  const NotificationPayload({
    required this.taskId,
    required this.type,
    required this.title,
    required this.typeLabel,
    this.error,
  });

  bool get success => type == NotificationType.taskCompleted;
}

// ============================================================================
// In-App Banner Widget
// ============================================================================

/// Shows an animated floating frosted-glass banner inside the app when a
/// notification arrives.
class InAppNotificationBanner extends StatefulWidget {
  final NotificationPayload payload;
  final Locale? locale;
  final bool isDark;
  final VoidCallback onDismiss;

  const InAppNotificationBanner({
    super.key,
    required this.payload,
    this.locale,
    required this.isDark,
    required this.onDismiss,
  });

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;
  Duration? _scheduledDismissal;
  Duration? _remainingDismissal;
  int _dismissalGeneration = 0;
  bool _dismissStarted = false;
  bool _appVisible = false;
  bool _tickerEnabled = true;
  double _measuredOverflow = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appVisible =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
    _scheduleDismissal(
      _measuredOverflow,
      _appVisible && _tickerEnabled,
    );
  }

  @override
  void didUpdateWidget(covariant InAppNotificationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload.taskId != widget.payload.taskId ||
        oldWidget.payload.type != widget.payload.type ||
        oldWidget.payload.title != widget.payload.title) {
      _dismissTimer?.cancel();
      _dismissTimer = null;
      _scheduledDismissal = null;
      _remainingDismissal = null;
      _dismissStarted = false;
      _dismissalGeneration++;
      _controller.forward();
    }
  }

  void _dismiss() {
    if (_dismissStarted) return;
    _dismissStarted = true;
    final generation = ++_dismissalGeneration;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _controller.reverse().then((_) {
      if (mounted && generation == _dismissalGeneration) widget.onDismiss();
    });
  }

  void _scheduleDismissal(double overflow, bool visible) {
    if (!visible) {
      _pauseDismissalTimer();
      return;
    }
    // ConstrainedText waits 1s before motion, traverses each way at 24 px/s,
    // and pauses 2s at both endpoints. The banner entrance runs concurrently
    // with the initial wait, so it does not add to the reveal cycle.
    final travelMilliseconds = math.max(1, (overflow / 24 * 1000).round());
    final duration = overflow <= 0
        ? const Duration(seconds: 4)
        : Duration(milliseconds: 5000 + 2 * travelMilliseconds);
    if (_dismissStarted) return;
    if (duration == _scheduledDismissal && _dismissTimer != null) return;
    if (duration != _scheduledDismissal) {
      _dismissTimer?.cancel();
      _dismissTimer = null;
      _remainingDismissal = duration;
      _scheduledDismissal = duration;
    }
    _remainingDismissal ??= duration;
    const tick = Duration(milliseconds: 50);
    _dismissTimer = Timer.periodic(tick, (timer) {
      final remaining = _remainingDismissal ?? Duration.zero;
      if (remaining <= tick) {
        timer.cancel();
        _dismissTimer = null;
        _remainingDismissal = Duration.zero;
        if (mounted) _dismiss();
      } else {
        _remainingDismissal = remaining - tick;
      }
    });
  }

  void _pauseDismissalTimer() {
    final timer = _dismissTimer;
    if (timer == null) return;
    timer.cancel();
    _dismissTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.payload.success;
    final strings = appLocalizationsForLocale(widget.locale);
    final isDark = widget.isDark;
    // 前景色：浅色主题用深色文字，深色主题用白色文字。
    final fg = isDark ? Colors.white : Colors.black87;
    // 成功/失败色只用在最前面的图标块上，卡片本身是毛玻璃透明。
    final accent = isSuccess ? Colors.green.shade600 : Colors.red.shade600;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // 悬浮阴影，让卡片与页面内容分离。
          // 注意：阴影位于 BackdropFilter 之下，会被模糊采样进卡片
          // 内部，因此透明度/偏移不宜过大，否则卡片内部会染上
          // 不均匀的暗色（深色模式下尤其明显）。
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          // 毛玻璃：模糊背景 + 半透明填充 + 细描边
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.6),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.5),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // 唯一带纯色的元素：成功打勾（绿）/ 失败（红）
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSuccess ? Icons.check : Icons.close,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isSuccess
                              ? strings.notificationBannerTaskCompletedHeading
                              : strings.notificationBannerTaskFailedHeading,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final titleStyle = TextStyle(
                              color: fg.withValues(alpha: 0.7),
                              fontSize: 12,
                            );
                            final direction = Directionality.of(context);
                            final textScaler = MediaQuery.textScalerOf(context);
                            final locale = widget.locale ??
                                Localizations.maybeLocaleOf(context);
                            final painter = TextPainter(
                              text: TextSpan(
                                text: widget.payload.title,
                                style: titleStyle,
                              ),
                              textDirection: direction,
                              textScaler: textScaler,
                              locale: locale,
                              maxLines: 1,
                              ellipsis: '…',
                            )..layout(maxWidth: constraints.maxWidth);
                            final measured = TextPainter(
                              text: TextSpan(
                                text: widget.payload.title,
                                style: titleStyle,
                              ),
                              textDirection: direction,
                              textScaler: textScaler,
                              locale: locale,
                              maxLines: 1,
                            )..layout();
                            final overflow = painter.didExceedMaxLines
                                ? (measured.width - constraints.maxWidth)
                                    .clamp(0.0, double.infinity)
                                    .toDouble()
                                : 0.0;
                            final reducedMotion =
                                MediaQuery.disableAnimationsOf(context);
                            _tickerEnabled =
                                TickerMode.valuesOf(context).enabled;
                            final timingOverflow =
                                reducedMotion ? 0.0 : overflow;
                            _measuredOverflow = timingOverflow;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _scheduleDismissal(
                                  _measuredOverflow,
                                  _appVisible && _tickerEnabled,
                                );
                              }
                            });
                            return ConstrainedText(
                              widget.payload.title,
                              style: titleStyle,
                              locale: locale,
                              maxLines:
                                  reducedMotion && overflow > 0 ? null : 1,
                              overflow: TextOverflow.ellipsis,
                              semanticsLabel: widget.payload.title,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: fg.withValues(alpha: 0.7),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
