part of 'settings_page.dart';

String localizeAboutUpdateError(AppLocalizations strings, String error) {
  final networkPrefix = strings.updateCheckNetworkError('');
  if (error.startsWith(networkPrefix)) {
    return strings.aboutUpdateNetworkError(
      error.substring(networkPrefix.length),
    );
  }

  final httpPrefix = strings.updateCheckHttpFailed('');
  if (error.startsWith(httpPrefix)) {
    final statusCode = error.substring(httpPrefix.length);
    if (RegExp(r'^\d+$').hasMatch(statusCode)) {
      return strings.aboutUpdateHttpError(statusCode);
    }
  }

  if (error == strings.updateCheckInvalidResponse) {
    return strings.aboutUpdateInvalidResponse;
  }

  return strings.aboutUpdateCheckFailed;
}

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
      // 整个卡片可点击，点击弹出版本信息面板（卡片保持紧凑尺寸，不带提示行）
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _showVersionInfoDialog,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 56,
                semanticLabel: AppLocalizations.of(context)!.aboutVersionInfo,
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
                appVersion,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutMenu(ThemeData theme, UpdateState updateState) {
    return Column(
      children: [
        if (!kIsWeb) ...[
          _buildSettingsCard([
            _buildListTile(
              leading: updateState.isChecking
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.update, color: Colors.blue),
              title: AppLocalizations.of(context)!.aboutCheckUpdates,
              subtitle: updateState.updateAvailable
                  ? AppLocalizations.of(context)!
                      .aboutNewVersionFound(updateState.latestVersion!)
                  : null,
              trailing: updateState.updateAvailable
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.aboutNewVersion,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: updateState.isChecking ? () {} : () => _checkForUpdate(),
            ),
            _buildListTile(
              leading: Icon(
                Icons.science,
                color:
                    updateState.acceptPreRelease ? Colors.orange : Colors.grey,
              ),
              title: AppLocalizations.of(context)!.aboutPreviewUpdates,
              subtitle:
                  AppLocalizations.of(context)!.aboutPreviewUpdatesDescription,
              trailing: Switch(
                value: updateState.acceptPreRelease,
                onChanged: (value) {
                  ref.read(updateProvider.notifier).setAcceptPreRelease(value);
                },
                activeThumbColor: Colors.orange,
              ),
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 12),
        ],
        _buildSettingsCard([
          _buildListTile(
            leading: const Icon(Icons.link, color: Colors.blueGrey),
            title: AppLocalizations.of(context)!.aboutProjectHome,
            subtitle: 'https://github.com/JohnXu22786/Stroom',
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl('https://github.com/JohnXu22786/Stroom'),
          ),
          _buildListTile(
            leading: const Icon(Icons.bug_report, color: Colors.deepOrange),
            title: AppLocalizations.of(context)!.aboutFeedback,
            subtitle: 'GitHub Issues',
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () =>
                _openUrl('https://github.com/JohnXu22786/Stroom/issues'),
          ),
          _buildListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.indigo),
            title: AppLocalizations.of(context)!.aboutPrivacyPolicy,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPrivacyDialog(),
          ),
          _buildListTile(
            leading: const Icon(Icons.description, color: Colors.brown),
            title: AppLocalizations.of(context)!.aboutOpenSourceAgreement,
            subtitle: 'GNU Affero General Public License v3.0',
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl(
              'https://github.com/JohnXu22786/Stroom/blob/main/LICENSE',
            ),
          ),
          _buildListTile(
            leading: const Icon(Icons.code, color: Colors.teal),
            title: AppLocalizations.of(context)!.aboutOpenSourceLicenses,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLicenseDialog(),
          ),
        ]),
      ],
    );
  }

  Future<void> _checkForUpdate() async {
    // Show immediate feedback that the check is starting
    final snackBar = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
            Text(AppLocalizations.of(context)!.aboutCheckingUpdates),
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
      _showSnackBar(
        localizeAboutUpdateError(AppLocalizations.of(context)!, state.error!),
      );
    } else if (state.updateAvailable) {
      _showUpdateDialog();
    } else {
      _showSnackBar(AppLocalizations.of(context)!.aboutUpToDate);
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
              Text(AppLocalizations.of(context)!.aboutPrivacyPolicy),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              AppLocalizations.of(context)!.aboutPrivacyContent,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.aboutClose),
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
