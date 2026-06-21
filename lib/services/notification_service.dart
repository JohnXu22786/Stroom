import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/storage_service.dart';

// ============================================================================
// Notification settings keys
// ============================================================================

const _notificationsEnabledKey = 'notifications_enabled';
const _notificationsPermissionRequestedKey =
    'notifications_permission_requested';

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
      _plugin = FlutterLocalNotificationsPlugin();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin!.initialize(
        settings,
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
  Future<bool> get isEnabled async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? false;
  }

  /// Set whether notifications are enabled.
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, value);
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
      if (Platform.isIOS) {
        return true; // Plugin handles this
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
      final androidDetails = AndroidNotificationDetails(
        'task_completion',
        '任务完成通知',
        channelDescription: '任务完成或失败时发送通知',
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
      );

      final title = payload.success
          ? '任务完成: ${payload.typeLabel}'
          : '任务失败: ${payload.typeLabel}';
      final body = payload.success
          ? '${payload.title} 已完成'
          : '${payload.title} 失败: ${payload.error ?? "未知错误"}';

      await _plugin!.show(
        payload.taskId.hashCode,
        title,
        body,
        details,
        payload: payload.taskId,
      );
    } catch (e) {
      debugPrint(
        '[NotificationService] Failed to show system notification: $e',
      );
    }
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
    if (Platform.isAndroid) {
      return '通知已被系统屏蔽。请前往 系统设置 > 应用 > Stroom > 通知管理，允许通知权限。';
    } else if (Platform.isIOS) {
      return '通知已被系统屏蔽。请前往 系统设置 > Stroom > 通知，允许通知权限。';
    }
    return '通知已被系统屏蔽，请在系统设置中允许通知权限。';
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

/// Shows an animated top banner inside the app when a notification arrives.
class InAppNotificationBanner extends StatefulWidget {
  final NotificationPayload payload;
  final VoidCallback onDismiss;

  const InAppNotificationBanner({
    super.key,
    required this.payload,
    required this.onDismiss,
  });

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSuccess = widget.payload.success;

    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        elevation: 6,
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSuccess
                  ? [Colors.green.shade600, Colors.green.shade400]
                  : [Colors.red.shade600, Colors.red.shade400],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
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
                      isSuccess ? '任务完成' : '任务失败',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.payload.title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
