part of 'settings_page.dart';

extension _SettingsPageThemeTaskExt on _SettingsPageState {
  // ================================================================
  // 主题设置
  // ================================================================

  Widget _buildGeneralSettings() {
    return _buildSettingsCard([
      _buildListTile(
        leading: const Icon(Icons.palette_outlined, color: Colors.deepPurple),
        title: '主题与显示',
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ThemeDisplaySettingsPage(),
            ),
          );
        },
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
