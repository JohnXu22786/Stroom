import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../l10n/locale_name_catalog.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';

class ThemeDisplaySettingsPage extends ConsumerStatefulWidget {
  const ThemeDisplaySettingsPage({super.key});

  @override
  ConsumerState<ThemeDisplaySettingsPage> createState() =>
      _ThemeDisplaySettingsPageState();
}

class _ThemeDisplaySettingsPageState
    extends ConsumerState<ThemeDisplaySettingsPage> {
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
    final selectedLocale = ref.watch(localeProvider);
    final strings = AppLocalizations.of(context)!;
    final normalizedQuery = _languageQuery.trim().toLowerCase();
    final matchingLanguages = supportedAppLocales
        .map(
          (locale) => _LanguageOption(
            locale: locale,
            displayName: localeDisplayName(strings, locale),
            nativeName: localeNativeName(locale),
            id: localeIdTag(locale),
          ),
        )
        .where((language) => language.searchText.contains(normalizedQuery))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.themeDisplaySettingsTitle),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, strings.themeDisplayThemeSection),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildThemeModeTile(
                    icon: Icons.light_mode,
                    iconColor: Colors.amber,
                    title: strings.themeModeLight,
                    value: ThemeMode.light,
                    groupValue: themeMode,
                    onSelected: themeNotifier.setLight,
                  ),
                  const Divider(height: 1),
                  _buildThemeModeTile(
                    icon: Icons.dark_mode,
                    iconColor: Colors.indigo,
                    title: strings.themeModeDark,
                    value: ThemeMode.dark,
                    groupValue: themeMode,
                    onSelected: themeNotifier.setDark,
                  ),
                  const Divider(height: 1),
                  _buildThemeModeTile(
                    icon: Icons.settings_suggest,
                    iconColor: Colors.grey,
                    title: strings.themeModeSystem,
                    value: ThemeMode.system,
                    groupValue: themeMode,
                    onSelected: themeNotifier.setSystem,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, strings.languageSettingsTitle),
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
                      hintText: strings.languageSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                  ),
                  const Divider(height: 24),
                  _buildLocaleTile(
                    title: strings.followSystemLanguage,
                    selected: selectedLocale == null,
                    onTap: () =>
                        ref.read(localeProvider.notifier).followSystem(),
                  ),
                  const Divider(height: 1),
                  if (matchingLanguages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(strings.languageNoMatches),
                    )
                  else
                    for (final language in matchingLanguages)
                      _buildLanguageTile(
                        context,
                        language,
                        selected: selectedLocale == language.locale,
                        onTap: () => ref
                            .read(localeProvider.notifier)
                            .setLocaleCode(localeCode(language.locale)),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocaleTile({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: const Icon(Icons.language, color: Colors.teal),
      title: Text(title),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    _LanguageOption language, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: const Icon(Icons.language, color: Colors.teal),
      title: Text('${language.displayName}（${language.nativeName}）'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(Icons.check),
            const SizedBox(width: 8),
          ],
          Container(
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
        ],
      ),
      onTap: onTap,
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

class _LanguageOption {
  const _LanguageOption({
    required this.locale,
    required this.displayName,
    required this.nativeName,
    required this.id,
  });

  final Locale locale;
  final String displayName;
  final String nativeName;
  final String id;

  String get searchText => '$displayName $nativeName $id'.toLowerCase();
}
