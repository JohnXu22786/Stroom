import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
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
  AppLocalizations get _strings => AppLocalizations.of(context)!;

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
      _platformVersion = '';
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
      usageReason: _strings.notificationSettingsUsageReason,
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
    if (kIsWeb) return _strings.notificationSettingsWebUnsupported;
    if (_isCheckingPermission) return _strings.notificationSettingsChecking;
    switch (_permissionStatus) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return _strings.notificationSettingsPermissionGranted;
      case PermissionStatus.denied:
        return _strings.notificationSettingsPermissionDenied;
      case PermissionStatus.restricted:
        return _strings.notificationSettingsPermissionRestricted;
      case PermissionStatus.permanentlyDenied:
        return _strings.notificationSettingsPermissionBlocked;
      case PermissionStatus.provisional:
        return _strings.notificationSettingsPermissionProvisional;
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
    if (kIsWeb) return _strings.notificationSettingsWebGuide;
    if (_isCheckingPermission)
      return _strings.notificationSettingsCheckingPermission;
    switch (_permissionStatus) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
      case PermissionStatus.provisional:
        return _strings.notificationSettingsPermissionGrantedGuide;
      case PermissionStatus.denied:
        return _strings.notificationSettingsPermissionDeniedGuide;
      case PermissionStatus.restricted:
        return _strings.notificationSettingsPermissionRestrictedGuide;
      case PermissionStatus.permanentlyDenied:
        if (defaultTargetPlatform == TargetPlatform.android) {
          return _strings.notificationSettingsPermissionBlockedAndroid;
        }
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          return _strings.notificationSettingsPermissionBlockedIos;
        }
        return _strings.notificationSettingsPermissionBlockedGuide;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_strings.notificationSettingsPageTitle),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(_strings.notificationSettingsEnvironment, theme),
          const SizedBox(height: 8),
          _buildPlatformDetectionCard(theme),
          const SizedBox(height: 24),
          _buildSectionHeader(
            _strings.notificationSettingsPermissionSection,
            theme,
          ),
          const SizedBox(height: 8),
          _buildPermissionStatusCard(theme),
          const SizedBox(height: 24),
          _buildSectionHeader(
            _strings.notificationSettingsPlatformGuides,
            theme,
          ),
          const SizedBox(height: 8),
          _buildDescription(_strings.notificationSettingsGuideIntro, theme),
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
              child: Icon(_platformIcon, size: 32, color: _platformColor),
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
                    kIsWeb
                        ? _strings.backgroundOptimizationBrowserEnvironment
                        : _platformVersion,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.check_circle, color: _platformColor, size: 28),
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
                    : Icon(_permissionIcon, color: _permissionColor, size: 24),
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
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
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
                          _strings.notificationSettingsTaskCompleteTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _strings.notificationSettingsTaskCompleteDescription,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _notificationsEnabled && _canToggle,
                    activeThumbColor: Colors.blue,
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
                    label: Text(_strings.notificationSettingsCheckAgain),
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
                      label: Text(
                        _strings.notificationSettingsOpenSystemSettings,
                      ),
                    ),
                  ),
                ],
                // Request permission button (only when denied, not permanently)
                if (_permissionStatus == PermissionStatus.denied) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isCheckingPermission
                          ? null
                          : _requestPermission,
                      icon: const Icon(Icons.notifications, size: 18),
                      label: Text(
                        _strings.notificationSettingsRequestPermission,
                      ),
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
            _strings.notificationSettingsGuideUnsupported,
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
            title: _strings.notificationSettingsAndroidEnableTitle,
            description: _strings.notificationSettingsAndroidEnableDescription,
          ),
          _GuideStep(
            title: _strings.notificationSettingsAndroidDndTitle,
            description: _strings.notificationSettingsAndroidDndDescription,
          ),
          _GuideStep(
            title: _strings.notificationSettingsAndroidPopupTitle,
            description: _strings.notificationSettingsAndroidPopupDescription,
          ),
          _GuideStep(
            title: _strings.notificationSettingsReturnTitle,
            description: _strings.notificationSettingsAndroidReturnDescription,
          ),
        ];
      case 'iOS':
        return [
          _GuideStep(
            title: _strings.notificationSettingsAndroidEnableTitle,
            description: _strings.notificationSettingsIosEnableDescription,
          ),
          _GuideStep(
            title: _strings.notificationSettingsIosFocusTitle,
            description: _strings.notificationSettingsIosFocusDescription,
          ),
          _GuideStep(
            title: _strings.notificationSettingsReturnTitle,
            description: _strings.notificationSettingsIosReturnDescription,
          ),
        ];
      case 'Windows':
        return [
          _GuideStep(
            title: _strings.notificationSettingsWindowsEnableTitle,
            description: _strings.notificationSettingsWindowsEnableDescription,
          ),
          _GuideStep(
            title: _strings.notificationSettingsWindowsFocusTitle,
            description: _strings.notificationSettingsWindowsFocusDescription,
          ),
          _GuideStep(
            title: _strings.notificationSettingsReturnTitle,
            description: _strings.notificationSettingsAndroidReturnDescription,
          ),
        ];
      case 'macOS':
        return [
          _GuideStep(
            title: _strings.notificationSettingsMacEnableTitle,
            description: _strings.notificationSettingsMacEnableDescription,
          ),
          _GuideStep(
            title: _strings.notificationSettingsIosFocusTitle,
            description: _strings.notificationSettingsMacFocusDescription,
          ),
          _GuideStep(
            title: _strings.notificationSettingsReturnTitle,
            description: _strings.notificationSettingsAndroidReturnDescription,
          ),
        ];
      case 'Linux':
        return [
          _GuideStep(
            title: _strings.notificationSettingsLinuxDesktopTitle,
            description: _strings.notificationSettingsLinuxDesktopDescription,
          ),
          _GuideStep(
            title: _strings.notificationSettingsLinuxDaemonTitle,
            description: _strings.notificationSettingsLinuxDaemonDescription,
          ),
          _GuideStep(
            title: _strings.notificationSettingsReturnTitle,
            description: _strings.notificationSettingsAndroidReturnDescription,
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
