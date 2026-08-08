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
import '../widgets/version_info_dialog.dart';
import 'provider_config_page.dart';
import 'backup_restore_page.dart';
import 'background_optimization_page.dart';
import 'notification_settings_page.dart';
import 'browser_cookies_page.dart';
import 'log_viewer_page.dart';

part 'settings_page_theme_task.dart';
part 'settings_page_provider_system.dart';
part 'settings_page_context_management.dart';
part 'settings_page_data_sections.dart';
part 'settings_page_about.dart';

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
}
