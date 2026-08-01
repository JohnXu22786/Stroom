import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/assistant.dart';
import '../models/built_in_assistants.dart';
import '../providers/assistant_provider.dart';
import '../providers/context_management_provider.dart';
import '../providers/system_assistant_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/provider_config.dart';
import '../providers/update_provider.dart';
import '../utils/app_version.dart';
import '../widgets/update_dialog.dart';
import 'provider_config_page.dart';
import 'backup_restore_page.dart';
import 'background_optimization_page.dart';
import 'notification_settings_page.dart';
import 'browser_cookies_page.dart';
import 'log_viewer_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('主题'),
          _buildThemeSettings(themeMode, themeNotifier),
          const SizedBox(height: 24),
          _buildSectionHeader('任务'),
          _buildNotificationSettings(),
          const SizedBox(height: 8),
          _buildBackgroundOptimizationCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('供应商设置'),
          _buildProviderSettings(),
          const SizedBox(height: 24),
          _buildSectionHeader('系统助手'),
          _buildSystemAssistantSettings(),
          const SizedBox(height: 24),
          _buildSectionHeader('上下文管理'),
          _buildContextManagementSettings(),
          const SizedBox(height: 24),
          _buildSectionHeader('数据备份'),
          _buildBackupSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('浏览器数据'),
          _buildBrowserDataSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('日志'),
          _buildLogSection(),
          const SizedBox(height: 24),
          _buildSectionHeader('关于'),
          _buildAboutSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

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

  Widget _buildProviderSettings() {
    final entriesState = ref.watch(providerEntriesProvider);
    final entries = entriesState.entries;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [...entries.map((entry) => _buildProviderEntryTile(entry))],
        ),
      ),
    );
  }

  Widget _buildProviderEntryTile(ProviderEntry entry) {
    return ListTile(
      leading: Icon(
        Icons.business,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(entry.name),
      trailing: const Icon(Icons.chevron_right),
      contentPadding: EdgeInsets.zero,
      onTap: () => _openProviderConfig(entry.id),
    );
  }

  void _openProviderConfig(String entryId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProviderConfigPage(entryId: entryId)),
    );
  }

  // ================================================================
  // 系统助手（标题生成 / 上下文压缩）
  // ================================================================

  Widget _buildSystemAssistantSettings() {
    final settings = ref.watch(systemAssistantSettingsProvider);
    final assistants = ref.watch(assistantProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '对话页自动任务使用的助手（默认内置，可替换为自己的助手）',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            _buildSystemAssistantPickerTile(
              icon: Icons.title,
              iconColor: Colors.teal,
              title: '标题生成助手',
              subtitle: '自动生成对话标题',
              currentId: settings.titleAssistantId,
              assistants: assistants,
              onSelect: (id) => ref
                  .read(systemAssistantSettingsProvider.notifier)
                  .setTitleAssistant(id),
            ),
            const Divider(height: 1),
            _buildSystemAssistantPickerTile(
              icon: Icons.compress,
              iconColor: Colors.indigo,
              title: '上下文压缩助手',
              subtitle: '对话过长时压缩为锚定摘要',
              currentId: settings.compactionAssistantId,
              assistants: assistants,
              onSelect: (id) => ref
                  .read(systemAssistantSettingsProvider.notifier)
                  .setCompactionAssistant(id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemAssistantPickerTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String currentId,
    required List<Assistant> assistants,
    required ValueChanged<String> onSelect,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(
        systemAssistantDisplayName(
          assistantId: currentId,
          userAssistants: assistants,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showSystemAssistantPicker(
        title: title,
        currentId: currentId,
        assistants: assistants,
        onSelect: onSelect,
      ),
    );
  }

  Future<void> _showSystemAssistantPicker({
    required String title,
    required String currentId,
    required List<Assistant> assistants,
    required ValueChanged<String> onSelect,
  }) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('选择$title'),
        children: [
          for (final builtIn in builtInSystemAssistants)
            RadioListTile<String>(
              value: builtIn.id,
              // ignore: deprecated_member_use
              groupValue: currentId,
              title: Text('${builtIn.emoji} ${builtIn.name}'),
              subtitle: Text(
                builtIn.description,
                style: const TextStyle(fontSize: 12),
              ),
              // ignore: deprecated_member_use
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
          for (final a in assistants)
            RadioListTile<String>(
              value: a.id,
              // ignore: deprecated_member_use
              groupValue: currentId,
              title: Text(a.name),
              subtitle: const Text(
                '自定义助手',
                style: TextStyle(fontSize: 12),
              ),
              // ignore: deprecated_member_use
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
        ],
      ),
    );
    if (selected != null) onSelect(selected);
  }

  // ================================================================
  // 上下文管理（prune / 压缩触发）
  // ================================================================

  Widget _buildContextManagementSettings() {
    final settings = ref.watch(contextManagementSettingsProvider);
    final notifier = ref.read(contextManagementSettingsProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('工具结果自动清理 (Prune)'),
              subtitle: const Text(
                '旧工具结果超过阈值时自动压缩为占位符，'
                '释放存储与上下文（opencode 语义）',
              ),
              value: settings.pruneEnabled,
              onChanged: notifier.setPruneEnabled,
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自定义压缩触发值'),
              subtitle: const Text(
                '关闭时：到达模型设置的上下文窗口即压缩；'
                '开启后：可设置更小的触发值',
              ),
              value: settings.customCompactionThresholdEnabled,
              onChanged: notifier.setCustomCompactionThresholdEnabled,
            ),
            if (settings.customCompactionThresholdEnabled) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextFormField(
                  initialValue: settings.compactionThreshold?.toString() ?? '',
                  decoration: const InputDecoration(
                    labelText: '压缩触发值 (token)',
                    hintText: '如 48000（小于模型上下文时提前压缩）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  // 输入即保存（数字解析失败/为空时清除自定义值，
                  // 回到"用模型上下文"）
                  onChanged: (v) {
                    final parsed = int.tryParse(v.trim());
                    notifier.setCompactionThreshold(
                        parsed != null && parsed > 0 ? parsed : null);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
            Icon(
              Icons.auto_awesome,
              size: 56,
              color: theme.colorScheme.primary,
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

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const UpdateDialog(),
    );
  }

  Widget _buildListTile({
    required Widget leading,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
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
