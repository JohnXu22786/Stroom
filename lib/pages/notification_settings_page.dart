import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/notification_provider.dart';
import '../services/notification_service.dart';

/// A page that detects current system environment, checks notification
/// permission status, and provides a switch to enable/disable task completion
/// notifications. The switch is only enabled when the system permission is
/// granted.
class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  // ── Detection results ────────────────────────────────────────────────
  String _platformName = '';
  IconData _platformIcon = Icons.devices;
  Color _platformColor = Colors.grey;
  String _platformVersion = '';
  bool _isCheckingPermission = true;
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _detectPlatform();
    _loadSettings();
  }

  // ── Platform Detection ───────────────────────────────────────────────

  void _detectPlatform() {
    if (kIsWeb) {
      _platformName = 'Web';
      _platformIcon = Icons.web;
      _platformColor = Colors.blue;
      _platformVersion = '浏览器环境';
      return;
    }

    final platform = defaultTargetPlatform;
    switch (platform) {
      case TargetPlatform.android:
        _platformName = 'Android';
        _platformIcon = Icons.android;
        _platformColor = Colors.green;
        break;
      case TargetPlatform.iOS:
        _platformName = 'iOS';
        _platformIcon = Icons.phone_iphone;
        _platformColor = Colors.grey;
        break;
      case TargetPlatform.windows:
        _platformName = 'Windows';
        _platformIcon = Icons.desktop_windows;
        _platformColor = Colors.blue;
        break;
      case TargetPlatform.macOS:
        _platformName = 'macOS';
        _platformIcon = Icons.desktop_mac;
        _platformColor = Colors.blueGrey;
        break;
      case TargetPlatform.linux:
        _platformName = 'Linux';
        _platformIcon = Icons.terminal;
        _platformColor = Colors.orange;
        break;
      case TargetPlatform.fuchsia:
        _platformName = 'Fuchsia';
        _platformIcon = Icons.devices;
        _platformColor = Colors.purple;
        break;
    }

    // Try to get OS version from dart:io Platform
    try {
      _platformVersion =
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      _platformVersion = _platformName;
    }
  }

  // ── Permission Check ─────────────────────────────────────────────────

  Future<void> _loadSettings() async {
    await _checkPermission();
    final enabled = await NotificationService().isEnabled;
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
      });
    }
  }

  Future<void> _checkPermission() async {
    if (kIsWeb) {
      setState(() {
        _permissionStatus = PermissionStatus.denied;
        _isCheckingPermission = false;
      });
      return;
    }

    setState(() {
      _isCheckingPermission = true;
    });

    try {
      final status = await Permission.notification.status;
      if (mounted) {
        setState(() {
          _permissionStatus = status;
          _isCheckingPermission = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _permissionStatus = PermissionStatus.denied;
          _isCheckingPermission = false;
        });
      }
    }
  }

  Future<void> _requestPermission() async {
    final service = NotificationService();
    final granted = await service.requestPermission(
      usageReason: '用于在任务完成时发送通知',
    );
    await _checkPermission();
    if (granted && mounted) {
      ref.read(notificationSettingsProvider.notifier).setEnabled(true);
      setState(() {
        _notificationsEnabled = true;
      });
    }
  }

  Future<void> _openSystemSettings() async {
    await openAppSettings();
  }

  // ── Is the switch allowed? ───────────────────────────────────────────

  bool get _canToggle {
    // Only allow toggling when permission is granted and we're not on web
    if (kIsWeb) return false;
    return _permissionStatus.isGranted;
  }

  // ── Permission status label ──────────────────────────────────────────

  String get _permissionLabel {
    if (kIsWeb) return 'Web 环境不支持通知权限';
    if (_isCheckingPermission) return '正在检测...';
    switch (_permissionStatus) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return '通知权限已授权';
      case PermissionStatus.denied:
        return '通知权限未授予';
      case PermissionStatus.restricted:
        return '通知权限受限';
      case PermissionStatus.permanentlyDenied:
        return '通知权限已被永久屏蔽';
      case PermissionStatus.provisional:
        return '通知权限为临时授权';
    }
  }

  Color get _permissionColor {
    if (kIsWeb) return Colors.grey;
    if (_isCheckingPermission) return Colors.grey;
    switch (_permissionStatus) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return Colors.green;
      case PermissionStatus.denied:
        return Colors.orange;
      case PermissionStatus.restricted:
      case PermissionStatus.permanentlyDenied:
        return Colors.red;
    }
  }

  IconData get _permissionIcon {
    if (kIsWeb) return Icons.warning_amber_rounded;
    if (_isCheckingPermission) return Icons.hourglass_empty;
    switch (_permissionStatus) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return Icons.check_circle;
      case PermissionStatus.denied:
        return Icons.warning_amber_rounded;
      case PermissionStatus.restricted:
      case PermissionStatus.permanentlyDenied:
        return Icons.cancel;
    }
  }

  String get _permissionGuide {
    if (kIsWeb) return '当前为 Web 环境，不支持系统通知功能。';
    if (_isCheckingPermission) return '正在检测通知权限状态...';
    switch (_permissionStatus) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return '通知权限已授予，您可以开启任务完成通知，'
            '在任务完成或失败时收到系统通知。';
      case PermissionStatus.denied:
        return '通知权限尚未授予。您可以点击下方按钮请求权限，'
            '或在系统设置中手动开启 Stroom 的通知权限。';
      case PermissionStatus.restricted:
        return '通知权限受系统限制（如家长控制）。'
            '请在系统设置中检查 Stroom 的通知权限设置。';
      case PermissionStatus.permanentlyDenied:
        return NotificationService().blockedGuide;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知权限设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('系统环境检测', theme),
          const SizedBox(height: 8),
          _buildPlatformDetectionCard(theme),
          const SizedBox(height: 24),
          _buildSectionHeader('通知权限检测', theme),
          const SizedBox(height: 8),
          _buildPermissionStatusCard(theme),
          const SizedBox(height: 24),
          _buildSectionHeader('平台指南', theme),
          const SizedBox(height: 8),
          _buildDescription(
            '根据您的操作系统，按照以下步骤开启 Stroom 的通知权限。',
            theme,
          ),
          const SizedBox(height: 12),
          _buildPlatformGuideCard(theme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Platform Detection Card ──────────────────────────────────────────

  Widget _buildPlatformDetectionCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _platformColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(28),
              ),
              alignment: Alignment.center,
              child: Icon(
                _platformIcon,
                size: 32,
                color: _platformColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _platformName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _platformVersion,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.check_circle,
              color: _platformColor,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  // ── Permission Status Card ───────────────────────────────────────────

  Widget _buildPermissionStatusCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Row(
              children: [
                _isCheckingPermission
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _permissionIcon,
                        color: _permissionColor,
                        size: 24,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _permissionLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _permissionColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Guide text
            Text(
              _permissionGuide,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Notification toggle row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.notifications_active,
                    color: _notificationsEnabled && _canToggle
                        ? Colors.blue
                        : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '任务完成通知',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '任务完成或失败时发送通知',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _notificationsEnabled && _canToggle,
                    activeColor: Colors.blue,
                    onChanged: _canToggle
                        ? (value) async {
                            await ref
                                .read(notificationSettingsProvider.notifier)
                                .setEnabled(value);
                            if (mounted) {
                              setState(() {
                                _notificationsEnabled = value;
                              });
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ),
            // Action buttons
            const SizedBox(height: 16),
            Row(
              children: [
                // Retry check button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isCheckingPermission ? null : _checkPermission,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重新检测'),
                  ),
                ),
                // Go to system settings button (only when permanently denied)
                if (_permissionStatus == PermissionStatus.permanentlyDenied ||
                    _permissionStatus == PermissionStatus.restricted) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _openSystemSettings,
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('前往系统设置'),
                    ),
                  ),
                ],
                // Request permission button (only when denied, not permanently)
                if (_permissionStatus == PermissionStatus.denied) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed:
                          _isCheckingPermission ? null : _requestPermission,
                      icon: const Icon(Icons.notifications, size: 18),
                      label: const Text('请求权限'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Platform Guide Card ──────────────────────────────────────────────

  Widget _buildPlatformGuideCard(ThemeData theme) {
    final steps = _getGuideSteps();
    if (steps.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '当前平台暂不支持通知权限设置指南。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        ...List.generate(steps.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[index].title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            steps[index].description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  List<_GuideStep> _getGuideSteps() {
    final platform = _platformName;
    switch (platform) {
      case 'Android':
        return [
          _GuideStep(
            title: '开启通知权限',
            description: '进入「设置」→「应用」→「Stroom」→「通知管理」，确保已允许通知权限。'
                '如果找不到 Stroom，请确认应用已安装。如果权限被禁用，请手动开启。',
          ),
          _GuideStep(
            title: '检查勿扰模式',
            description: '进入「设置」→「声音与振动」→「勿扰模式」，确认勿扰模式未开启，'
                '或已将在其中允许 Stroom 的通知。',
          ),
          _GuideStep(
            title: '允许后台弹出通知',
            description: '部分 Android 系统（如 MIUI、EMUI、ColorOS 等）'
                '需要额外在应用信息中开启「允许通知」和「允许弹窗」。'
                '建议同时关闭该应用的「通知过滤」或「智能通知」功能。',
          ),
          _GuideStep(
            title: '完成后返回此页面',
            description: '完成以上设置后，点击「重新检测」按钮确认通知权限状态已更新。'
                '如果权限已显示为已授权，即可开启任务完成通知开关。',
          ),
        ];
      case 'iOS':
        return [
          _GuideStep(
            title: '开启通知权限',
            description: '进入「设置」→「通知」→「Stroom」，开启「允许通知」。'
                '建议同时开启「横幅」和「通知中心」以便及时获知任务状态。',
          ),
          _GuideStep(
            title: '关闭专注模式',
            description: '进入「设置」→「专注模式」，确保未开启或已将 Stroom 加入允许的应用列表。'
                '专注模式可能会屏蔽应用通知。',
          ),
          _GuideStep(
            title: '完成后返回此页面',
            description: '完成以上设置后，点击「重新检测」按钮确认通知权限状态已更新。'
                'iOS 上通知权限通常需要用户手动在系统设置中开启。',
          ),
        ];
      case 'Windows':
        return [
          _GuideStep(
            title: '开启系统通知',
            description: '进入「设置」→「系统」→「通知和操作」，确保「获取来自应用和其他发送者的通知」'
                '已开启。在下方应用列表中找到 Stroom 并确保通知已开启。',
          ),
          _GuideStep(
            title: '开启专注助手排除项',
            description: '进入「设置」→「系统」→「专注助手」，确保 Stroom 已加入'
                '「仅优先打断」或「关闭专注助手」。专注助手开启时会屏蔽通知。',
          ),
          _GuideStep(
            title: '完成后返回此页面',
            description: '完成以上设置后，点击「重新检测」按钮确认通知权限状态已更新。',
          ),
        ];
      case 'macOS':
        return [
          _GuideStep(
            title: '开启通知权限',
            description: '进入「系统设置」→「通知」→「Stroom」，开启「允许通知」。'
                '建议同时开启「横幅」和「通知中心」。',
          ),
          _GuideStep(
            title: '关闭专注模式',
            description: '进入「系统设置」→「专注模式」，确保未开启或已将 Stroom 加入允许的应用列表。',
          ),
          _GuideStep(
            title: '完成后返回此页面',
            description: '完成以上设置后，点击「重新检测」按钮确认通知权限状态已更新。',
          ),
        ];
      case 'Linux':
        return [
          _GuideStep(
            title: '检查桌面环境通知设置',
            description: '根据您使用的桌面环境（GNOME、KDE、XFCE 等），进入「系统设置」→'
                '「通知」→ 找到 Stroom 并确保通知已开启。',
          ),
          _GuideStep(
            title: '检查是否安装了通知守护进程',
            description: 'Linux 桌面环境需要安装通知守护进程（如 notify-osd 或 dunst）'
                '来显示系统通知。请确认您的系统中已安装并运行了通知守护进程。',
          ),
          _GuideStep(
            title: '完成后返回此页面',
            description: '完成以上设置后，点击「重新检测」按钮确认通知权限状态已更新。',
          ),
        ];
      default:
        return [];
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildDescription(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
    );
  }
}

class _GuideStep {
  final String title;
  final String description;

  const _GuideStep({required this.title, required this.description});
}
