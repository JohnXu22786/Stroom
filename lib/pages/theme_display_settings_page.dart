import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';

class ThemeDisplaySettingsPage extends ConsumerWidget {
  const ThemeDisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('主题与显示'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, '设置为主题'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildThemeModeTile(
                    icon: Icons.light_mode,
                    iconColor: Colors.amber,
                    title: '浅色模式',
                    value: ThemeMode.light,
                    groupValue: themeMode,
                    onSelected: themeNotifier.setLight,
                  ),
                  const Divider(height: 1),
                  _buildThemeModeTile(
                    icon: Icons.dark_mode,
                    iconColor: Colors.indigo,
                    title: '深色模式',
                    value: ThemeMode.dark,
                    groupValue: themeMode,
                    onSelected: themeNotifier.setDark,
                  ),
                  const Divider(height: 1),
                  _buildThemeModeTile(
                    icon: Icons.settings_suggest,
                    iconColor: Colors.grey,
                    title: '跟随系统',
                    value: ThemeMode.system,
                    groupValue: themeMode,
                    onSelected: themeNotifier.setSystem,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, '语言'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.language, color: Colors.teal),
                title: const Text('中文'),
                trailing: const Icon(Icons.check, color: Colors.teal),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
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

  Widget _buildThemeModeTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required ThemeMode value,
    required ThemeMode groupValue,
    required VoidCallback onSelected,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      trailing: Radio<ThemeMode>(
        value: value,
        // ignore: deprecated_member_use
        groupValue: groupValue,
        // ignore: deprecated_member_use
        onChanged: (_) => onSelected(),
      ),
      onTap: onSelected,
      contentPadding: EdgeInsets.zero,
    );
  }
}
