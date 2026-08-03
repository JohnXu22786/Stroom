import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:window_manager/window_manager.dart';

import '../services/background_service.dart';
import 'platform_tutorial_page.dart';

/// A page that detects current system environment, checks background optimization
/// status, and provides tutorials organized by OS categories.
class BackgroundOptimizationPage extends StatefulWidget {
  const BackgroundOptimizationPage({super.key});

  @override
  State<BackgroundOptimizationPage> createState() =>
      _BackgroundOptimizationPageState();
}

class _BackgroundOptimizationPageState extends State<BackgroundOptimizationPage>
    with WidgetsBindingObserver {
  // ── Detection results ────────────────────────────────────────────────
  String _platformName = '';
  IconData _platformIcon = Icons.devices;
  Color _platformColor = Colors.grey;
  String _platformVersion = '';
  bool _isServiceRunning = false;
  String _optimizationStatus = '';
  bool _isCheckingService = true;
  bool _isOperating = false;
  bool _isServiceSupported = false;
  bool _isIgnoringBattery = false;
  bool _isCheckingBattery = true;

  // ── Keep-alive strategy toggles ─────────────────────────────────────
  bool _watchdogEnabled = true;
  bool _coldStartRestoreEnabled = true;
  bool _batteryReminderEnabled = true;

  // ── Desktop: minimize on close ──────────────────────────────────────
  bool _closeMinimizeEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _detectPlatform();
    _checkBackgroundService();
    _checkBatteryOptimization();
    _loadStrategyToggles();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 从后台恢复（例如从系统设置返回）时重新检测服务与电池状态：
  /// 用户可能在其他应用/系统设置中修改了省电白名单或杀掉了服务。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _checkBackgroundService();
    _checkBatteryOptimization();
  }

  Future<void> _loadStrategyToggles() async {
    final w = await isWatchdogEnabled();
    final c = await isColdStartRestoreEnabled();
    final b = await isBatteryReminderEnabled();
    final closeMinimize =
        isDesktopPlatform() ? await isDesktopCloseMinimizeEnabled() : true;
    if (mounted) {
      setState(() {
        _watchdogEnabled = w;
        _coldStartRestoreEnabled = c;
        _batteryReminderEnabled = b;
        _closeMinimizeEnabled = closeMinimize;
      });
    }
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
    setState(() {
      _isCheckingService = true;
    });

    _isServiceSupported = isBackgroundServiceSupported();

    try {
      final service = FlutterBackgroundService();
      _isServiceRunning = await service.isRunning();
      _optimizationStatus = _isServiceRunning ? '后台服务运行中' : '后台服务未启动';
    } catch (_) {
      _isServiceRunning = false;
      _optimizationStatus = '无法检测后台服务状态';
    }

    if (mounted) {
      setState(() {
        _isCheckingService = false;
      });
    }
  }

  // ── Battery Optimization Check ───────────────────────────────────────

  Future<void> _checkBatteryOptimization() async {
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
      requestIgnoreBatteryOptimizations();
      // Re-check after a short delay to let the system dialog complete.
      await Future<void>.delayed(const Duration(seconds: 2));
      await _checkBatteryOptimization();
    } catch (_) {}
  }

  // ── Service Control ──────────────────────────────────────────────────

  Future<void> _startService() async {
    setState(() {
      _isOperating = true;
    });

    try {
      await startBackgroundService();
    } catch (_) {
      if (mounted) {
        setState(() {
          _optimizationStatus = '启动服务失败';
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

    try {
      await stopBackgroundService();
    } catch (_) {
      if (mounted) {
        setState(() {
          _optimizationStatus = '停止服务失败';
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

    try {
      await restartBackgroundService();
    } catch (_) {
      if (mounted) {
        setState(() {
          _optimizationStatus = '重启服务失败';
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
        title: const Text('后台运行优化'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('系统环境检测', theme),
          const SizedBox(height: 8),
          _buildPlatformDetectionCard(theme),
          const SizedBox(height: 24),
          _buildSectionHeader('后台优化检测', theme),
          const SizedBox(height: 8),
          _buildOptimizationStatusCard(theme),
          const SizedBox(height: 24),
          _buildBatteryOptimizationCard(theme),
          const SizedBox(height: 24),
          // Web 没有任何保活策略（移动端策略与桌面端策略都不适用），
          // 此时不显示空的「保活策略」标题。
          if (_hasKeepAliveStrategies) ...[
            _buildSectionHeader('保活策略', theme),
            const SizedBox(height: 8),
            _buildStrategyTogglesCard(theme),
            _buildDesktopKeepAliveCard(theme),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('平台教程', theme),
          const SizedBox(height: 8),
          _buildDescription(
            '选择您的操作系统查看详细的后台运行优化教程。'
            '不同系统的设置方式有所不同，请根据您的设备选择对应教程。',
            theme,
          ),
          const SizedBox(height: 12),
          ..._buildPlatformTutorialCards(),
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
                  _isCheckingService ? '正在检测...' : _optimizationStatus,
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.stop, size: 18),
                        label: const Text('停止服务'),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.restart_alt, size: 18),
                        label: const Text('重新启动服务'),
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
                    label: const Text('启动服务'),
                  ),
                ),
              // Re-detect button
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isOperating ? null : _checkBackgroundService,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重新检测'),
                ),
              ),
            ],
            // ── Unsupported platform info ──
            if (!_isCheckingService && !_isServiceSupported) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '当前平台不支持后台服务控制。',
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
                        ? '正在检测电池优化状态...'
                        : _isIgnoringBattery
                            ? '已忽略电池优化'
                            : '未忽略电池优化 — 后台可能被杀',
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
                  label: const Text('忽略电池优化'),
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
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        isDesktopPlatform();
  }

  Widget _buildStrategyTogglesCard(ThemeData theme) {
    // 保活策略按平台区分：
    // - Android：AlarmManager 看门狗 + 冷启动恢复 + 电池优化提醒
    // - iOS：仅冷启动恢复（iOS 无 AlarmManager 看门狗）
    // - 桌面/Web：没有移动端保活策略，显示桌面端保活卡片代替
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    final tiles = <Widget>[];
    if (defaultTargetPlatform == TargetPlatform.android) {
      tiles.addAll([
        _buildToggleTile(
          theme: theme,
          title: 'AlarmManager 看门狗',
          detail: '启用后，Android 系统会每 5 分钟用原生闹钟检查后台服务是否还活着。'
              '如果进程被系统杀掉，闹钟会触发自动重启。'
              '\n\n闹钟在设备休眠（Doze）模式下依然生效，'
              '重启后也会自动重新调度。'
              '\n\n适用场景：对后台任务要求极高的用户。'
              '\n耗电影响：极低（每次仅短暂唤醒检查一次）。',
          value: _watchdogEnabled,
          onChanged: (v) {
            setState(() => _watchdogEnabled = v);
            setWatchdogEnabled(v);
            if (v && _isServiceRunning) {
              startBackgroundService();
            } else if (!v) {
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
        title: '冷启动自动恢复',
        detail: '启用后，每次重新打开 App 时，会自动检测并恢复之前正在运行的后台服务。'
            '\n\n如果 App 进程被系统或用户手动杀掉，'
            '下次打开 App 时后台服务会自动重启，无需手动操作。'
            '\n\n适用场景：所有用户都建议开启。'
            '\n耗电影响：无（仅在 App 启动时检查一次）。',
        value: _coldStartRestoreEnabled,
        onChanged: (v) {
          setState(() => _coldStartRestoreEnabled = v);
          setColdStartRestoreEnabled(v);
        },
      ),
    ]);

    if (defaultTargetPlatform == TargetPlatform.android) {
      tiles.addAll([
        const Divider(height: 1, indent: 16, endIndent: 16),
        _buildToggleTile(
          theme: theme,
          title: '电池优化提醒',
          detail: '启用后，本页面会显示电池优化状态卡片。'
              '如果检测到 App 未被添加到省电白名单，'
              '会提供一键跳转至系统设置进行豁免。'
              '\n\n电池优化是安卓系统省电机制（Doze），'
              '会限制后台应用的运行。添加到白名单后，'
              '系统不会因省电而杀掉本 App。'
              '\n\n适用场景：关闭本开关仅隐藏提醒卡片，'
              '不影响实际的电池优化豁免状态。',
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
                  left: 16, right: 16, top: 12, bottom: 4),
              child: Text(
                '以下策略可独立开关。默认全部启用以获得最强保活效果。'
                '关闭某项仅影响该策略，不会影响后台服务本身的运行。',
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
                  left: 16, right: 16, top: 12, bottom: 4),
              child: Text(
                '桌面端没有移动系统的进程保活机制，'
                '但可以让应用在关闭窗口后继续运行。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _buildToggleTile(
              theme: theme,
              title: '关闭窗口时最小化',
              detail: '启用后，点击窗口关闭按钮不会退出应用，'
                  '而是最小化到任务栏，后台任务继续运行。'
                  '\n\n需要真正退出时，点击下方「完全退出应用」按钮。'
                  '\n\n适用场景：所有桌面用户都建议开启。',
              value: _closeMinimizeEnabled,
              onChanged: (v) {
                setState(() => _closeMinimizeEnabled = v);
                setDesktopCloseMinimizeEnabled(v);
                _applyWindowCloseBehavior(v);
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
                  label: const Text('完全退出应用'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyWindowCloseBehavior(bool enabled) async {
    try {
      // 启用：拦截系统关闭事件（由 Application 层在 onWindowClose
      // 中执行最小化）；禁用：恢复默认的关闭即退出行为。
      await windowManager.setPreventClose(enabled);
    } catch (e) {
      debugPrint('[BackgroundOptimizationPage] setPreventClose failed: $e');
    }
  }

  Future<void> _quitDesktopApp() async {
    try {
      await windowManager.destroy();
    } catch (e) {
      debugPrint('[BackgroundOptimizationPage] destroy window failed: $e');
    }
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
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(12),
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
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(detail, style: theme.textTheme.bodyMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  // ── Platform Tutorial Cards ──────────────────────────────────────────

  List<Widget> _buildPlatformTutorialCards() {
    final platforms = [
      PlatformTutorialConfig(
        platformName: 'Android',
        icon: Icons.android,
        color: Colors.green,
      ),
      PlatformTutorialConfig(
        platformName: 'iOS',
        icon: Icons.phone_iphone,
        color: Colors.grey,
      ),
      PlatformTutorialConfig(
        platformName: 'Windows',
        icon: Icons.desktop_windows,
        color: Colors.blue,
      ),
      PlatformTutorialConfig(
        platformName: 'macOS',
        icon: Icons.desktop_mac,
        color: Colors.blueGrey,
      ),
      PlatformTutorialConfig(
        platformName: 'Linux',
        icon: Icons.terminal,
        color: Colors.orange,
      ),
    ];

    return platforms.map((config) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Icon(config.icon, color: config.color, size: 24),
            ),
            title: Text(
              config.platformName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text('${config.platformName} 后台运行优化教程'),
            trailing: const Icon(Icons.chevron_right),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlatformTutorialPage(config: config),
                ),
              );
            },
          ),
        ),
      );
    }).toList();
  }

  // ── Status Description ──────────────────────────────────────────────

  String _getStatusDescription() {
    if (_isCheckingService) return '正在检测后台服务状态...';

    if (_isServiceRunning) return '后台服务正在运行，任务将在后台正常执行。';

    // Platform-specific messaging when service is not running
    if (kIsWeb) {
      return 'Web 浏览器环境不支持后台服务运行。请保持页面打开以继续任务。';
    }
    if (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows) {
      return '桌面平台后台服务支持有限。'
          '请保持应用窗口打开以确保任务正常执行。';
    }
    return '后台服务未启动。请点击下方「启动服务」按钮启动后台服务，'
        '或查看平台教程了解如何优化后台运行设置。';
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
