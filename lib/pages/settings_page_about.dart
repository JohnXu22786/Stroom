part of 'settings_page.dart';

extension _SettingsPageAboutExt on _SettingsPageState {
  // ================================================================
  // 关于
  // ================================================================

  Widget _buildAboutSection() {
    final updateState = ref.watch(updateProvider);
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildAboutHeader(theme),
        const SizedBox(height: 16),
        _buildAboutMenu(theme, updateState),
      ],
    );
  }

  Widget _buildAboutHeader(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            // 仅图标区域可点击，点击弹出版本信息面板
            InkWell(
              onTap: _showVersionInfoDialog,
              borderRadius: BorderRadius.circular(12),
              child: Icon(
                Icons.auto_awesome,
                size: 56,
                semanticLabel: '查看版本信息',
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Stroom',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '版本 $appVersion',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutMenu(ThemeData theme, UpdateState updateState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Web端不提供更新功能
            if (!kIsWeb) ...[
              // Pre-release toggle switch - above the check update button
              _buildListTile(
                leading: Icon(
                  Icons.science,
                  color: updateState.acceptPreRelease
                      ? Colors.orange
                      : Colors.grey,
                ),
                title: '接收预览版',
                subtitle: '开启后可检查预览版更新',
                trailing: Switch(
                  value: updateState.acceptPreRelease,
                  onChanged: (value) {
                    ref
                        .read(updateProvider.notifier)
                        .setAcceptPreRelease(value);
                  },
                  activeThumbColor: Colors.orange,
                ),
                onTap: () {},
              ),
              const Divider(height: 1),
              _buildListTile(
                leading: updateState.isChecking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.update, color: Colors.blue),
                title: '检查更新',
                subtitle: updateState.updateAvailable
                    ? '发现新版本 ${updateState.latestVersion}'
                    : null,
                trailing: updateState.updateAvailable
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '新版本',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: updateState.isChecking ? () {} : () => _checkForUpdate(),
              ),
              const Divider(height: 1),
            ],
            _buildListTile(
              leading: const Icon(Icons.code, color: Colors.teal),
              title: '开源许可',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLicenseDialog(),
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.privacy_tip, color: Colors.indigo),
              title: '隐私政策',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPrivacyDialog(),
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.link, color: Colors.blueGrey),
              title: '项目主页',
              subtitle: 'https://github.com/JohnXu22786/Stroom',
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openUrl('https://github.com/JohnXu22786/Stroom'),
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.description, color: Colors.brown),
              title: '开源协议',
              subtitle: 'GNU Affero General Public License v3.0',
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openUrl(
                'https://github.com/JohnXu22786/Stroom/blob/main/LICENSE',
              ),
            ),
            const Divider(height: 1),
            _buildListTile(
              leading: const Icon(Icons.bug_report, color: Colors.deepOrange),
              title: '问题反馈',
              subtitle: 'GitHub Issues',
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () =>
                  _openUrl('https://github.com/JohnXu22786/Stroom/issues'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    // Show immediate feedback that the check is starting
    final snackBar = ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('正在检查更新...'),
          ],
        ),
        duration: Duration(days: 1), // Keep visible until dismissed
      ),
    );

    final notifier = ref.read(updateProvider.notifier);
    await notifier.checkForUpdate();
    final state = ref.read(updateProvider);

    // Dismiss the checking snackbar
    snackBar.close();

    if (state.error != null) {
      _showSnackBar(state.error!);
    } else if (state.updateAvailable) {
      _showUpdateDialog();
    } else {
      _showSnackBar('已是最新版本');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _showVersionInfoDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const VersionInfoDialog(),
    );
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const UpdateDialog(),
    );
  }

  void _showLicenseDialog() {
    showLicensePage(
      context: context,
      applicationName: 'Stroom',
      applicationVersion: appVersion,
      applicationLegalese: '© 2023 Stroom Team',
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.privacy_tip,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('隐私政策'),
            ],
          ),
          content: const SingleChildScrollView(
            child: Text(
              'Stroom 尊重并保护所有使用服务用户的个人隐私权。\n\n'
              '1. 相机权限：仅用于拍摄照片，不会收集或上传任何图像数据。\n\n'
              '2. 相册权限：仅用于选择照片和保存照片，所有照片都保存在本地设备。\n\n'
              '3. 数据安全：所有拍摄的照片都保存在您的设备本地，'
              '我们不会访问或上传任何数据。\n\n'
              '4. 第三方服务：本应用不包含任何第三方分析或广告服务。\n\n'
              '如果您有任何疑问，请联系我们。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
