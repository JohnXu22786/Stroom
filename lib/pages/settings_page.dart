import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/built_in_assistants.dart';
import '../providers/context_management_provider.dart';
import '../providers/system_assistant_provider.dart';
import '../providers/provider_config.dart';
import '../providers/provider_config_display_names.dart';
import '../providers/update_provider.dart';
import '../services/chat_adapter.dart'
    show AvailableModel, availableLlmModels, resolveModelRef;
import '../utils/app_version.dart';
import '../utils/model_order.dart' show applySavedOrder;
import '../widgets/update_dialog.dart';
import '../widgets/version_info_dialog.dart';
import 'provider_config_page.dart';
import 'backup_restore_page.dart';
import 'background_optimization_page.dart';
import 'notification_settings_page.dart';
import 'browser_cookies_page.dart';
import 'log_viewer_page.dart';
import 'theme_display_settings_page.dart';

import '../widgets/constrained_text.dart';

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
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: ConstrainedText(
          strings.settingsPageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(strings.settingsSectionGeneral),
          _buildGeneralSettings(),
          const SizedBox(height: 24),
          _buildSectionHeader(strings.settingsSectionProviders),
          _buildProviderSettings(),
          const SizedBox(height: 24),
          _buildSectionHeader(strings.settingsSectionSystemAssistant),
          _buildSystemAssistantSettings(),
          const SizedBox(height: 24),
          _buildSectionHeader(strings.settingsSectionContextManagement),
          _buildContextManagementSettings(),
          const SizedBox(height: 24),
          _buildSectionHeader(strings.settingsSectionManagement),
          _buildManagementSettings(),
          const SizedBox(height: 24),
          _buildSectionHeader(strings.settingsSectionAbout),
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

  Widget _buildSettingsCard(List<Widget> tiles) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              tiles[i],
            ],
          ],
        ),
      ),
    );
  }
}
