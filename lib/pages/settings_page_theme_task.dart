part of 'settings_page.dart';

extension _SettingsPageThemeTaskExt on _SettingsPageState {
  // ================================================================
  // 主题设置
  // ================================================================

  Widget _buildGeneralSettings() {
    return _buildSettingsCard([
      _buildListTile(
        leading: const Icon(Icons.palette_outlined, color: Colors.deepPurple),
        title: AppLocalizations.of(context)!.settingsThemeDisplay,
        subtitle: AppLocalizations.of(context)!.settingsThemeDisplayDescription,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ThemeDisplaySettingsPage()),
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
      title: AppLocalizations.of(context)!.settingsTaskNotifications,
      subtitle:
          AppLocalizations.of(context)!.settingsTaskNotificationsDescription,
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
      leading: const Icon(Icons.speed, color: Colors.teal),
      title: AppLocalizations.of(context)!.settingsBackgroundOptimization,
      subtitle: AppLocalizations.of(context)!
          .settingsBackgroundOptimizationDescription,
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
