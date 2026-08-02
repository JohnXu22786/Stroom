part of 'settings_page.dart';

extension _SettingsPageThemeTaskExt on _SettingsPageState {
  // ================================================================
  // 主题设置
  // ================================================================

  Widget _buildThemeSettings(ThemeMode themeMode, ThemeNotifier themeNotifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
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
            const Divider(height: 1),
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
            const Divider(height: 1),
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
          ],
        ),
      ),
    );
  }

  // ================================================================
  // 通知设置
  // ================================================================

  Widget _buildNotificationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _buildListTile(
          leading: Icon(
            Icons.notifications_active,
            color: Colors.blue,
          ),
          title: '任务完成通知',
          subtitle: '检测通知权限与系统设置，查看通知指南',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationSettingsPage(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackgroundOptimizationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _buildListTile(
          leading: const Icon(Icons.speed, color: Colors.deepPurple),
          title: '后台运行优化',
          subtitle: '检测系统环境与后台服务状态，查看优化教程',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BackgroundOptimizationPage(),
              ),
            );
          },
        ),
      ),
    );
  }
}
