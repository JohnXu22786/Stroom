import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'platform_tutorial_page.dart';

/// A page that detects current system environment, checks background optimization
/// status, and provides tutorials organized by OS categories.
class BackgroundOptimizationPage extends StatefulWidget {
  const BackgroundOptimizationPage({super.key});

  @override
  State<BackgroundOptimizationPage> createState() =>
      _BackgroundOptimizationPageState();
}

class _BackgroundOptimizationPageState
    extends State<BackgroundOptimizationPage> {
  // ── Detection results ────────────────────────────────────────────────
  String _platformName = '';
  IconData _platformIcon = Icons.devices;
  Color _platformColor = Colors.grey;
  String _platformVersion = '';
  bool _isServiceRunning = false;
  String _optimizationStatus = '';
  bool _isCheckingService = true;

  @override
  void initState() {
    super.initState();
    _detectPlatform();
    _checkBackgroundService();
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
          _buildSectionHeader('平台教程', theme),
          const SizedBox(height: 8),
          _buildDescription(
            '选择您的操作系统查看详细的后台运行优化教程。'
            '不同系统的设置方式有所不同，请根据您的设备选择对应教程。',
            theme,
          ),
          const SizedBox(height: 12),
          ..._buildPlatformTutorialCards(theme),
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
              _isCheckingService
                  ? '正在检测后台服务状态...'
                  : _isServiceRunning
                      ? '后台服务正在运行，任务将在后台正常执行。'
                      : '后台服务未启动或当前平台不支持后台运行。'
                          '请查看下方教程了解如何优化后台运行设置。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (!_isServiceRunning && !_isCheckingService) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _checkBackgroundService,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重新检测'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Platform Tutorial Cards ──────────────────────────────────────────

  List<Widget> _buildPlatformTutorialCards(ThemeData theme) {
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
