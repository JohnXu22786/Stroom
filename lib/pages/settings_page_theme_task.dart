part of 'settings_page.dart';

extension _SettingsPageThemeTaskExt on _SettingsPageState {
  // ================================================================
  // 主题设置
  // ================================================================

  Widget _buildGeneralSettings(
    ThemeMode themeMode,
    ThemeNotifier themeNotifier,
  ) {
    return _buildSettingsCard([
      _buildListTile(
        leading: const Icon(Icons.light_mode, color: Colors.amber),
        title: '浅色模式',
        trailing: Radio<ThemeMode>(
          value: ThemeMode.light,
          // ignore: deprecated_member_use
          groupValue: themeMode,
          // ignore: deprecated_member_use
          onChanged: (_) => themeNotifier.setLight(),
        ),
        onTap: () => themeNotifier.setLight(),
      ),
      _buildListTile(
        leading: const Icon(Icons.dark_mode, color: Colors.indigo),
        title: '深色模式',
        trailing: Radio<ThemeMode>(
          value: ThemeMode.dark,
          // ignore: deprecated_member_use
          groupValue: themeMode,
          // ignore: deprecated_member_use
          onChanged: (_) => themeNotifier.setDark(),
        ),
        onTap: () => themeNotifier.setDark(),
      ),
      _buildListTile(
        leading: const Icon(Icons.settings_suggest, color: Colors.grey),
        title: '跟随系统',
        trailing: Radio<ThemeMode>(
          value: ThemeMode.system,
          // ignore: deprecated_member_use
          groupValue: themeMode,
          // ignore: deprecated_member_use
          onChanged: (_) => themeNotifier.setSystem(),
        ),
        onTap: () => themeNotifier.setSystem(),
      ),
      _buildNotificationSettings(),
      _buildBackgroundOptimizationSettings(),
    ]);
  }

  // ================================================================
  // 通知设置
  // ================================================================

  Widget _buildNotificationSettings() {
    return _buildListTile(
      leading: Icon(Icons.notifications_active, color: Colors.blue),
      title: '任务完成通知',
      subtitle: '检测通知权限与系统设置，查看通知指南',
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
        );
      },
    );
  }

  Widget _buildBackgroundOptimizationSettings() {
    return _buildListTile(
      leading: const Icon(Icons.speed, color: Colors.deepPurple),
      title: '后台运行优化',
      subtitle: '检测系统环境与后台服务状态，查看优化教程',
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BackgroundOptimizationPage()),
        );
      },
    );
  }
}
