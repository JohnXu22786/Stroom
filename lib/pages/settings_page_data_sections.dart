part of 'settings_page.dart';

extension _SettingsPageDataSectionsExt on _SettingsPageState {
  Widget _buildManagementSettings() {
    return _buildSettingsCard([
      _buildBackupSection(),
      _buildBrowserDataSection(),
      _buildLogSection(),
    ]);
  }

  // ================================================================
  // 数据备份
  // ================================================================

  Widget _buildBackupSection() {
    return _buildListTile(
      leading: const Icon(Icons.backup, color: Colors.teal),
      title: AppLocalizations.of(context)!.settingsBackupRestore,
      subtitle: AppLocalizations.of(context)!.settingsBackupRestoreDescription,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BackupRestorePage()),
        );
      },
    );
  }

  Widget _buildBrowserDataSection() {
    return _buildListTile(
      leading: const Icon(Icons.cookie, color: Colors.orange),
      title: AppLocalizations.of(context)!.settingsCookies,
      subtitle: AppLocalizations.of(context)!.settingsCookiesDescription,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BrowserCookiesPage()),
        );
      },
    );
  }

  Widget _buildLogSection() {
    return _buildListTile(
      leading: const Icon(Icons.article, color: Colors.blueGrey),
      title: AppLocalizations.of(context)!.settingsAppLogs,
      subtitle: AppLocalizations.of(context)!.settingsAppLogsDescription,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LogViewerPage()),
        );
      },
    );
  }
}
