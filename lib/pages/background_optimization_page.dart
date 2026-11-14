import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../services/background_service.dart';
import '../services/desktop_app_service.dart';
import '../services/ios_continued_task_service.dart';
import 'platform_tutorial_page.dart';

import '../widgets/constrained_text.dart';

/// A page that detects current system environment, checks background optimization
/// status, and provides tutorials organized by OS categories.
class BackgroundOptimizationPage extends ConsumerStatefulWidget {
  const BackgroundOptimizationPage({super.key});

  @override
  ConsumerState<BackgroundOptimizationPage> createState() =>
      _BackgroundOptimizationPageState();
}

class _BackgroundOptimizationPageState
    extends ConsumerState<BackgroundOptimizationPage>
    with WidgetsBindingObserver {
  AppLocalizations get _strings => AppLocalizations.of(context)!;

  // ── Detection results ────────────────────────────────────────────────
  String _platformName = '';
  IconData _platformIcon = Icons.devices;
  Color _platformColor = Colors.grey;
  String _platformVersion = '';
  bool _isServiceRunning = false;
  bool _isServiceStatusUnknown = false;
  String _optimizationStatus = '';
  bool _isCheckingService = true;
  bool _isOperating = false;
  bool _isServiceSupported = false;
  bool _isIgnoringBattery = false;
  bool _isCheckingBattery = true;
  bool _canScheduleExactAlarms = true;
  bool _isCheckingExactAlarms = true;

  // ── Keep-alive strategy toggles ─────────────────────────────────────
  bool _watchdogEnabled = true;
  bool _coldStartRestoreEnabled = true;
  bool _batteryReminderEnabled = true;
  Locale? _lastLocale;

  // ── Desktop: minimize on close ──────────────────────────────────────
  bool _closeMinimizeEnabled = true;
  int _closeMinimizeChangeVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (isDesktopPlatform()) {
      DesktopAppService.instance.trayReady.addListener(_onTrayReadyChanged);
    }
    _detectPlatform();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkBackgroundService();
    });
    _checkBatteryOptimization();
    _checkExactAlarmStatus();
    _loadStrategyToggles();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    if (_lastLocale != null && _lastLocale != locale) {
      _checkBackgroundService();
    }
    _lastLocale = locale;
  }

  @override
  void dispose() {
    DesktopAppService.instance.trayReady.removeListener(_onTrayReadyChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 从后台恢复（例如从系统设置返回）时重新检测服务与电池状态：
  /// 用户可能在其他应用/系统设置中修改了省电白名单、精确闹钟权限
  /// 或杀掉了服务。（精确闹钟权限只可能在系统设置中变更，且撤销时
  /// 系统不发任何广播 —— 回到前台是唯一可靠的重新检测时机。）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _checkBackgroundService();
    _checkBatteryOptimization();
    _checkExactAlarmStatus();
  }

  Future<void> _loadStrategyToggles() async {
    final closeMinimizeChangeVersion = _closeMinimizeChangeVersion;
    final w = await isWatchdogEnabled();
    final c = await isColdStartRestoreEnabled();
    final b = await isBatteryReminderEnabled();
    final closeMinimize =
        isDesktopPlatform() ? await isDesktopCloseMinimizeEnabled() : true;
    if (isDesktopPlatform()) {
      // 兜底：确保窗口关闭事件被拦截（Application 层初始化
      // 失败时，本页面负责重新建立拦截，保证退出确认始终生效）。
      _ensureWindowCloseIntercepted();
    }
    if (mounted) {
      setState(() {
        _watchdogEnabled = w;
        _coldStartRestoreEnabled = c;
        _batteryReminderEnabled = b;
        if (closeMinimizeChangeVersion == _closeMinimizeChangeVersion) {
          _closeMinimizeEnabled = closeMinimize;
        }
      });
    }
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

    // Try to get OS version from dart:io Platform (not available on web or in all tests)
    try {
      _platformVersion =
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      _platformVersion = _platformName;
    }
  }

  // ── Background Service Check ─────────────────────────────────────────

  Future<void> _checkBackgroundService() async {
    if (!mounted) return; // 前置 setState 保护：页面可能已销毁
    setState(() {
      _isCheckingService = true;
    });

    _isServiceSupported = isBackgroundServiceSupported();

    if (!_isServiceSupported) {
      // 桌面/Web 没有前台服务：直接给出平台对应的真实状态，
      // 不要调用仅 Android/iOS 可用的插件（会抛异常显示误导性文案）。
      _isServiceRunning = false;
      _isServiceStatusUnknown = false;
      if (isDesktopPlatform()) {
        final closeMinimizeChangeVersion = _closeMinimizeChangeVersion;
        final closeMinimize = await isDesktopCloseMinimizeEnabled();
        if (!mounted) return;
        if (closeMinimizeChangeVersion == _closeMinimizeChangeVersion) {
          _closeMinimizeEnabled = closeMinimize;
        }
        _optimizationStatus = _getDesktopOptimizationStatus();
      } else {
        _optimizationStatus = _strings.backgroundOptimizationUnsupportedStatus;
      }
    } else {
      try {
        final service = FlutterBackgroundService();
        final isServiceRunning = await service.isRunning();
        if (!mounted) return;
        _isServiceRunning = isServiceRunning;
        _isServiceStatusUnknown = false;
        _optimizationStatus = _isServiceRunning
            ? _strings.backgroundOptimizationServiceRunning
            : _strings.backgroundOptimizationServiceStopped;
      } catch (_) {
        if (!mounted) return;
        _isServiceRunning = false;
        _isServiceStatusUnknown = true;
        _optimizationStatus = _strings.backgroundOptimizationServiceCheckFailed;
      }
    }

    if (mounted) {
      setState(() {
        _isCheckingService = false;
      });
    }
  }

  void _onTrayReadyChanged() {
    if (!mounted || !isDesktopPlatform()) return;
    setState(() {
      _optimizationStatus = _getDesktopOptimizationStatus();
    });
  }

  String _getDesktopOptimizationStatus() {
    if (!DesktopAppService.instance.isTrayReady) {
      return _strings.backgroundOptimizationDesktopTrayUnavailable;
    }
    if (!_closeMinimizeEnabled) {
      return _strings.backgroundOptimizationDesktopCloseExits;
    }
    return _strings.backgroundOptimizationDesktopTrayKeepsAlive;
  }

  // ── Battery Optimization Check ───────────────────────────────────────

  Future<void> _checkBatteryOptimization() async {
    if (!mounted) return; // 前置 setState 保护：页面可能已销毁
    setState(() {
      _isCheckingBattery = true;
    });

    try {
      _isIgnoringBattery = await isIgnoringBatteryOptimizations();
    } catch (_) {
      _isIgnoringBattery = false;
    }

    if (mounted) {
      setState(() {
        _isCheckingBattery = false;
      });
    }
  }

  Future<void> _requestBatteryExemption() async {
    try {
      await requestIgnoreBatteryOptimizations();
      // Re-check after a short delay to let the system dialog complete.
      await Future<void>.delayed(const Duration(seconds: 2));
      await _checkBatteryOptimization();
    } catch (_) {}
  }

  // ── Exact Alarm Status Check ───────────────────────────────────────

  Future<void> _checkExactAlarmStatus() async {
    if (!mounted) return; // 前置 setState 保护：页面可能已销毁
    setState(() {
      _isCheckingExactAlarms = true;
    });

    try {
      _canScheduleExactAlarms = await canScheduleExactAlarms();
    } catch (_) {
      // 无法确定状态时按「未授权」处理（与电池卡片同向）：
      // 未知状态保守地展示授权入口，而不是隐藏按钮让看门狗
      // 静默降级为不精确闹钟。
      _canScheduleExactAlarms = false;
    }

    if (mounted) {
      setState(() {
        _isCheckingExactAlarms = false;
      });
    }
  }

  Future<void> _requestExactAlarm() async {
    try {
      await requestScheduleExactAlarm();
      // Re-check after a short delay to let the system page close.
      await Future<void>.delayed(const Duration(seconds: 2));
      await _checkExactAlarmStatus();
    } catch (_) {}
  }

  // ── Service Control ──────────────────────────────────────────────────

  Future<void> _startService() async {
    setState(() {
      _isOperating = true;
    });

    final ok = await startBackgroundService();
    if (!ok) {
      if (mounted) {
        setState(() {
          _optimizationStatus = _strings.backgroundOptimizationStartFailed;
          _isOperating = false;
        });
      }
      return;
    }

    await _checkBackgroundService();
    if (mounted) {
      setState(() {
        _isOperating = false;
      });
    }
  }

  Future<void> _stopService() async {
    setState(() {
      _isOperating = true;
    });

    final ok = await stopBackgroundService();
    if (!ok) {
      if (mounted) {
        setState(() {
          _optimizationStatus = _strings.backgroundOptimizationStopFailed;
          _isOperating = false;
        });
      }
      return;
    }

    await _checkBackgroundService();
    if (mounted) {
      setState(() {
        _isOperating = false;
      });
    }
  }

  Future<void> _restartService() async {
    setState(() {
      _isOperating = true;
    });

    final ok = await restartBackgroundService();
    if (!ok) {
      if (mounted) {
        setState(() {
          _optimizationStatus = _strings.backgroundOptimizationRestartFailed;
          _isOperating = false;
        });
      }
      return;
    }

    await _checkBackgroundService();
    if (mounted) {
      setState(() {
        _isOperating = false;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: ConstrainedText(
          _strings.backgroundOptimizationTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(
            _strings.backgroundOptimizationEnvironment,
            theme,
          ),
          const SizedBox(height: 8),
          _buildPlatformDetectionCard(theme),
          const SizedBox(height: 8),
          _buildPlatformTutorialEntry(theme),
          const SizedBox(height: 24),
          _buildSectionHeader(_strings.backgroundOptimizationChecks, theme),
          const SizedBox(height: 8),
          _buildOptimizationStatusCard(theme),
          const SizedBox(height: 24),
          _buildWebBackgroundNoteCard(theme),
          _buildBatteryOptimizationCard(theme),
          const SizedBox(height: 24),
          // Web 没有任何保活策略（移动端策略与桌面端策略都不适用），
          // 此时不显示空的「保活策略」标题。
          if (_hasKeepAliveStrategies) ...[
            _buildSectionHeader(
              _strings.backgroundOptimizationKeepAliveStrategies,
              theme,
            ),
            const SizedBox(height: 8),
            _buildStrategyTogglesCard(theme),
            _buildIosBackgroundNoteCard(theme),
            _buildDesktopKeepAliveCard(theme),
            const SizedBox(height: 24),
          ],
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

  // ── Optimization Status Card ─────────────────────────────────────────

  Widget _buildOptimizationStatusCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _isCheckingService
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isServiceRunning
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: _isServiceRunning ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                const SizedBox(width: 12),
                Text(
                  _isCheckingService
                      ? _strings.backgroundOptimizationDetecting
                      : _optimizationStatus,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _isServiceRunning ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getStatusDescription(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            // ── Action buttons (visible when not checking and platform is supported) ──
            if (!_isCheckingService && _isServiceSupported) ...[
              const SizedBox(height: 16),
              // Primary action: start / stop
              if (_isServiceRunning)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _isOperating ? null : _stopService,
                        icon: _isOperating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.stop, size: 18),
                        label: Text(_strings.backgroundOptimizationStopService),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isOperating ? null : _restartService,
                        icon: _isOperating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.restart_alt, size: 18),
                        label: ConstrainedText(
                          _strings.backgroundOptimizationRestartService,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _isOperating ? null : _startService,
                    icon: _isOperating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow, size: 18),
                    label: Text(_strings.backgroundOptimizationStartService),
                  ),
                ),
              // Re-detect button
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isOperating ? null : _checkBackgroundService,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: ConstrainedText(
                    _strings.backgroundOptimizationRedetect,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            // ── Unsupported platform info ──
            if (!_isCheckingService && !_isServiceSupported) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _strings.backgroundOptimizationUnsupportedControl,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Battery Optimization Card ────────────────────────────────────────

  Widget _buildBatteryOptimizationCard(ThemeData theme) {
    // Web 上 defaultTargetPlatform 会报告宿主 OS（手机浏览器 = android），
    // 必须显式排除 Web，否则会在 Web 页面渲染 Android 专属卡片。
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    if (!_batteryReminderEnabled) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _isCheckingBattery
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isIgnoringBattery
                            ? Icons.check_circle
                            : Icons.battery_alert,
                        color:
                            _isIgnoringBattery ? Colors.green : Colors.orange,
                        size: 20,
                      ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isCheckingBattery
                        ? _strings.backgroundOptimizationCheckingBattery
                        : _isIgnoringBattery
                            ? _strings.backgroundOptimizationBatteryIgnored
                            : _strings.backgroundOptimizationBatteryMayKill,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (!_isIgnoringBattery && !_isCheckingBattery) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _requestBatteryExemption,
                  icon: const Icon(Icons.battery_charging_full, size: 18),
                  label: ConstrainedText(
                    _strings.backgroundOptimizationIgnoreBattery,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            // Android 12+ 精确闹钟权限（保活看门狗准点触发的关键）
            if (!_canScheduleExactAlarms && !_isCheckingExactAlarms) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _requestExactAlarm,
                  icon: const Icon(Icons.alarm_add, size: 18),
                  label: ConstrainedText(
                    _strings.backgroundOptimizationExactAlarm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Strategy Toggles Card ─────────────────────────────────────────────

  /// 当前平台是否展示任何保活策略（移动端策略卡或桌面端保活卡）。
  bool get _hasKeepAliveStrategies {
    // Web 上 defaultTargetPlatform 会报告宿主 OS，必须显式排除。
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        isDesktopPlatform();
  }

  Widget _buildStrategyTogglesCard(ThemeData theme) {
    // 保活策略按平台区分：
    // - Android：AlarmManager 看门狗 + 冷启动恢复 + 电池优化提醒
    // - iOS：仅冷启动恢复（iOS 无 AlarmManager 看门狗）
    // - 桌面/Web：没有移动端保活策略，显示桌面端保活卡片代替
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    final tiles = <Widget>[];
    if (defaultTargetPlatform == TargetPlatform.android) {
      tiles.addAll([
        _buildToggleTile(
          theme: theme,
          title: _strings.backgroundOptimizationWatchdogTitle,
          detail: _strings.backgroundOptimizationWatchdogDetail,
          value: _watchdogEnabled,
          onChanged: (v) async {
            final saved = await setWatchdogEnabled(v);
            if (!saved) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _strings.backgroundOptimizationSaveWatchdogFailed,
                    ),
                  ),
                );
              }
              return;
            }
            if (mounted) setState(() => _watchdogEnabled = v);
            if (v) {
              final activated = await rearmBackgroundServiceWatchdog();
              if (!activated && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _strings.backgroundOptimizationWatchdogActivationFailed,
                    ),
                  ),
                );
              }
            } else {
              disableKeepAlive();
            }
          },
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ]);
    }

    tiles.addAll([
      _buildToggleTile(
        theme: theme,
        title: _strings.backgroundOptimizationColdStartTitle,
        detail: _strings.backgroundOptimizationColdStartDetail,
        value: _coldStartRestoreEnabled,
        onChanged: (v) async {
          final saved = await setColdStartRestoreEnabled(v);
          if (!saved) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _strings.backgroundOptimizationSaveColdStartFailed,
                  ),
                ),
              );
            }
            return;
          }
          if (mounted) setState(() => _coldStartRestoreEnabled = v);
        },
      ),
    ]);

    if (defaultTargetPlatform == TargetPlatform.android) {
      tiles.addAll([
        const Divider(height: 1, indent: 16, endIndent: 16),
        _buildToggleTile(
          theme: theme,
          title: _strings.backgroundOptimizationBatteryReminderTitle,
          detail: _strings.backgroundOptimizationBatteryReminderDetail,
          value: _batteryReminderEnabled,
          onChanged: (v) {
            setState(() => _batteryReminderEnabled = v);
            setBatteryReminderEnabled(v);
          },
        ),
      ]);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section description
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 4,
              ),
              child: Text(
                _strings.backgroundOptimizationStrategyIntro,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ...tiles,
          ],
        ),
      ),
    );
  }

  // ── iOS Background Note Card ───────────────────────────────────────────

  /// iOS 后台任务提示卡：
  /// - iOS 26+ 支持常驻后台（BGContinuedProcessingTask），正向说明；
  /// - 低于 iOS 26 给出「定期返回 App + 勿在切换器划掉」的提示。
  Widget _buildIosBackgroundNoteCard(ThemeData theme) {
    // Web 上 defaultTargetPlatform 会报告宿主 OS，必须显式排除。
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    final supported = IosContinuedTaskService.instance.isSupported;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  supported ? Icons.check_circle_outline : Icons.info_outline,
                  size: 20,
                  color: supported ? Colors.green : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _strings.backgroundOptimizationIosNoteTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              supported
                  ? _strings.backgroundOptimizationIosSupported
                  : _strings.backgroundOptimizationIosUnsupported,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _strings.backgroundOptimizationIosWarning,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Desktop Keep-Alive Card ──────────────────────────────────────────

  /// 桌面端保活：关闭窗口时默认最小化到任务栏，应用与后台任务继续运行。
  Widget _buildDesktopKeepAliveCard(ThemeData theme) {
    if (!isDesktopPlatform()) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 4,
              ),
              child: Text(
                _strings.backgroundOptimizationDesktopIntro,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildToggleTile(
              theme: theme,
              title: _strings.backgroundOptimizationCloseMinimizeTitle,
              detail: _strings.backgroundOptimizationCloseMinimizeDetail,
              value: _closeMinimizeEnabled,
              onChanged: (v) async {
                // 拦截保持开启（关闭行为由 Application 层决策）。
                _ensureWindowCloseIntercepted();
                final saved = await setDesktopCloseMinimizeEnabled(v);
                if (!saved || !mounted) return;
                setState(() {
                  _closeMinimizeChangeVersion++;
                  _closeMinimizeEnabled = v;
                  _optimizationStatus = _getDesktopOptimizationStatus();
                });
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _quitDesktopApp,
                  icon: const Icon(Icons.power_settings_new, size: 18),
                  label: ConstrainedText(
                    _strings.backgroundOptimizationQuitApp,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 确保窗口关闭事件永远被拦截（幂等）。
  ///
  /// 注意：不能根据开关状态调用 setPreventClose(false) 释放拦截——
  /// 拦截一旦释放，原生层会在 Dart 侧确认逻辑运行前直接销毁窗口，
  /// 「关闭即退出」时的任务运行确认就永远不会触发。
  /// 关闭行为（最小化 vs 确认后退出）统一由 DesktopAppService 的
  /// onWindowClose 决策（每次读取最新偏好）。
  ///
  /// 仅在托盘服务已就绪时重新武装：若托盘注册失败（DesktopAppService
  /// 已回滚为「关闭即退出」并撤销拦截），这里绝不能只恢复 setPreventClose
  /// 而不恢复事件监听 —— 否则窗口将无法关闭且没有兜底。
  Future<void> _ensureWindowCloseIntercepted() async {
    if (!DesktopAppService.instance.isTrayReady) {
      debugPrint('[BackgroundOptimizationPage] 托盘未就绪，跳过关闭拦截武装');
      return;
    }
    try {
      await DesktopAppService.instance.ensureWindowCloseInterception();
    } catch (e) {
      debugPrint('[BackgroundOptimizationPage] setPreventClose failed: $e');
    }
  }

  /// 完全退出应用：先确认（有任务运行时弹窗），再销毁托盘与窗口退出。
  ///
  /// 统一走 [DesktopAppService.quitWithConfirmation]，与「关闭即退出」
  /// 的确认逻辑共用同一入口，并确保托盘图标被正确销毁。
  Future<void> _quitDesktopApp() async {
    await DesktopAppService.instance.quitWithConfirmation();
  }

  Widget _buildToggleTile({
    required ThemeData theme,
    required String title,
    required String detail,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showDetailDialog(theme, title, detail),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        detail.length > 60 ? '${detail.substring(0, 60)}…' : detail,
        style: theme.textTheme.bodySmall,
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  void _showDetailDialog(ThemeData theme, String title, String detail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: ConstrainedText(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: SingleChildScrollView(
          child: Text(detail, style: theme.textTheme.bodyMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: ConstrainedText(
              _strings.backgroundOptimizationGotIt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Web Background Note Card ───────────────────────────────────────────

  /// Web 提示卡：浏览器环境无法后台运行，任务会因关标签页/页面挂起
  /// 而中断，需要明确告知用户。
  Widget _buildWebBackgroundNoteCard(ThemeData theme) {
    if (!kIsWeb) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _strings.backgroundOptimizationWebNoteTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _strings.backgroundOptimizationWebNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformTutorialEntry(ThemeData theme) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.menu_book_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(_strings.backgroundOptimizationTutorial),
        subtitle: Text(_strings.backgroundOptimizationTutorialDescription),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PlatformTutorialSelectionPage(),
            ),
          );
        },
      ),
    );
  }

  // ── Status Description ──────────────────────────────────────────────

  String _getStatusDescription() {
    if (_isCheckingService)
      return _strings.backgroundOptimizationServiceCheckingDescription;

    if (_isServiceStatusUnknown) {
      return _strings.backgroundOptimizationServiceUnknown;
    }

    if (_isServiceRunning)
      return _strings.backgroundOptimizationServiceRunningDescription;

    // Platform-specific messaging when service is not running
    if (kIsWeb) {
      return _strings.backgroundOptimizationWebServiceUnsupported;
    }
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows) {
      // 托盘注册失败时展示真实状态，避免误导用户
      // （窗口隐藏后将无法找回）。
      if (!DesktopAppService.instance.isTrayReady) {
        if (defaultTargetPlatform == TargetPlatform.linux) {
          return _strings.backgroundOptimizationLinuxTrayUnavailable;
        }
        return _strings.backgroundOptimizationDesktopTrayUnavailableDescription;
      }
      if (!_closeMinimizeEnabled) {
        return _strings.backgroundOptimizationDesktopExitDescription;
      }
      if (defaultTargetPlatform == TargetPlatform.linux) {
        // Linux appindicator 左键点击弹出的是菜单而非恢复窗口事件，
        // 恢复窗口只能通过托盘菜单项完成。
        return _strings.backgroundOptimizationLinuxTrayDescription;
      }
      return _strings.backgroundOptimizationDesktopTrayDescription;
    }
    return _strings.backgroundOptimizationServiceNotRunningDescription;
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
