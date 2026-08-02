part of 'settings_page.dart';

extension _SettingsPageDataSectionsExt on _SettingsPageState {
  // ================================================================
  // 数据备份
  // ================================================================

  Widget _buildBackupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _buildListTile(
          leading: const Icon(Icons.backup, color: Colors.teal),
          title: '数据备份与恢复',
          subtitle: '导出或导入应用数据',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackupRestorePage()),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrowserDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _buildListTile(
          leading: const Icon(Icons.cookie, color: Colors.orange),
          title: 'Cookies与浏览器数据',
          subtitle: '管理持久化的Cookies和浏览器存储数据',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BrowserCookiesPage()),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLogSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _buildListTile(
          leading: const Icon(Icons.article, color: Colors.blueGrey),
          title: '应用日志',
          subtitle: '查看应用运行日志',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogViewerPage()),
            );
          },
        ),
      ),
    );
  }
}
