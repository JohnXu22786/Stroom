import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';

class ThemeDisplaySettingsPage extends ConsumerStatefulWidget {
  const ThemeDisplaySettingsPage({super.key});

  @override
  ConsumerState<ThemeDisplaySettingsPage> createState() =>
      _ThemeDisplaySettingsPageState();
}

class _ThemeDisplaySettingsPageState
    extends ConsumerState<ThemeDisplaySettingsPage> {
  static const _languages = [
    _LanguageOption(displayName: '简体中文', nativeName: '简体中文', id: 'zh-cn'),
  ];

  final _languageSearchController = TextEditingController();
  String _languageQuery = '';

  @override
  void dispose() {
    _languageSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final normalizedQuery = _languageQuery.trim().toLowerCase();
    final matchingLanguages = _languages.where((language) {
      return language.searchText.contains(normalizedQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('主题与显示'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, '主题'),
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
              child: Column(
                children: [
                  TextField(
                    key: const Key('language-search-field'),
                    controller: _languageSearchController,
                    onChanged: (query) =>
                        setState(() => _languageQuery = query),
                    decoration: InputDecoration(
                      hintText: '搜索语言',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                  ),
                  const Divider(height: 24),
                  if (matchingLanguages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('没有匹配的语言'),
                    )
                  else
                    for (final language in matchingLanguages)
                      _buildLanguageTile(context, language),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context, _LanguageOption language) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: const Icon(Icons.language, color: Colors.teal),
      title: Text('${language.displayName}（${language.nativeName}）'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          language.id,
          style: TextStyle(
            color: colorScheme.onSecondaryContainer,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      contentPadding: EdgeInsets.zero,
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

/// A language row is shown as `displayName（nativeName）`, followed by a
/// separate badge for `id`. `displayName` is the locale's name translated into
/// the app's currently selected display language. `nativeName` is the
/// language's own self-name (autonym), written in that language and shown in
/// parentheses. `id` is its canonical BCP-47 locale identifier, shown in the
/// badge after both names. Keep this order fixed; for zh-cn the values are
/// `简体中文`, `简体中文`, and `zh-cn`.
class _LanguageOption {
  const _LanguageOption({
    required this.displayName,
    required this.nativeName,
    required this.id,
  });

  final String displayName;
  final String nativeName;
  final String id;

  String get searchText => '$displayName $nativeName $id'.toLowerCase();
}
