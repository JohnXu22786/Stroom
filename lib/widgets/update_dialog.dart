import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/update_provider.dart';

import 'constrained_text.dart';

/// A shared update dialog used by both the settings page and the
/// application startup flow.
///
/// Shows update version info, release notes, and action buttons.
///
/// # Behavior
/// - 发现新版本: Shows version info + "跳过此版本"/"稍后提醒"/"立即更新" buttons.
/// - 立即更新: Downloads the update and auto-installs immediately.
///   During download, a prominent progress bar is shown in the button area.
///   The dialog cannot be dismissed (back button / barrier tap) while
///   downloading or installing to prevent accidental interruption.
///   After download, the installer opens automatically on desktop.
///   The dialog stays open — the user closes it manually via 关闭 button.
/// - If auto-install fails, a fallback "手动安装" button is shown.
class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key});

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  final ScrollController _releaseNotesController = ScrollController();

  /// Whether the download URL points to a GitHub release page (not a direct asset).
  /// When true, the "立即更新" button is replaced with "前往浏览器下载".
  bool get _isHtmlUrlFallback {
    final url = ref.read(updateProvider).downloadUrl;
    if (url == null) return false;
    return url.contains('/releases/tag/');
  }

  @override
  void dispose() {
    _releaseNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateProvider);
    final cs = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context)!;

    // Prevent dialog dismissal during download or install.
    // The user must not accidentally dismiss the dialog while
    // a critical operation is in progress.
    final canPop = (!state.isDownloading || state.downloadInBackground) &&
        !state.isInstalling;

    return PopScope(
      canPop: canPop,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: cs.primary),
            SizedBox(width: 8),
            Expanded(child: Text(strings.updateDialogTitle)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${strings.updateLatestVersionLabel}: ${state.latestVersion ?? ''}',
              ),
              if (state.releaseNotes != null &&
                  state.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  strings.updateReleaseNotesLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                  ),
                  child: Scrollbar(
                    controller: _releaseNotesController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _releaseNotesController,
                      child: Text(state.releaseNotes!),
                    ),
                  ),
                ),
              ],
              // Installing state — shown briefly while the app auto-installs
              if (state.isInstalling) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.tertiaryContainer, width: 0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            cs.onTertiaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        strings.updateInstalling,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onTertiaryContainer,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (state.isDownloading) ...[
                const SizedBox(height: 16),
                _buildDownloadProgress(state),
              ],
              // Download error section
              if (state.downloadError != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 18),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _localizedDownloadError(
                          state.downloadError!,
                          AppLocalizations.of(context)!,
                        ),
                        style: TextStyle(color: cs.error),
                      ),
                    ),
                  ],
                ),
              ],
              // Download complete section (shown briefly before auto-close triggers)
              if (state.downloadComplete && !state.isInstalling) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.check_circle, color: cs.primary, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context)!.updateDownloadComplete,
                      style: TextStyle(color: cs.primary),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: _buildActions(state),
      ),
    );
  }

  List<Widget> _buildActions(UpdateState state) {
    final strings = AppLocalizations.of(context)!;
    final notifier = ref.read(updateProvider.notifier);

    // During download, keep cancellation and background actions fixed below progress.
    if (state.isDownloading) {
      return [
        TextButton(
          onPressed: notifier.cancelDownload,
          child: ConstrainedText(
            strings.updateCancelDownload,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FilledButton(
          onPressed: () {
            notifier.downloadInBackground();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.of(context).pop();
            });
          },
          child: ConstrainedText(
            strings.updateDownloadInBackground,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ];
    }

    // During auto-install, no action buttons needed (auto-proceeding)
    if (state.isInstalling) {
      return [];
    }

    // After download complete: if auto-install failed (downloadError set),
    // show the fallback manual install button.
    if (state.downloadComplete) {
      if (state.downloadError != null) {
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: ConstrainedText(
              strings.updateClose,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton(
            onPressed: () {
              // Retry installing the already-downloaded APK file
              // with visual feedback (isInstalling state).
              notifier.retryInstall();
            },
            child: ConstrainedText(
              strings.updateManualInstall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ];
      }
      // No error — show close and reopen buttons.
      // The "打开安装包" button allows the user to manually re-open the
      // installer if they accidentally closed it without installing.
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: ConstrainedText(
            strings.updateClose,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FilledButton(
          onPressed: () {
            // Re-open the installer (same as manual install fallback)
            notifier.retryInstall();
          },
          child: ConstrainedText(
            strings.updateOpenInstaller,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ];
    }

    // After download error that is non-recoverable (html fallback), show close only
    if (state.downloadError != null) {
      final isNonRecoverable = _isHtmlUrlFallback;
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: ConstrainedText(
            strings.updateClose,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!isNonRecoverable)
          FilledButton(
            onPressed: () => notifier.downloadUpdate(),
            child: ConstrainedText(
              strings.updateRetryDownload,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ];
    }

    // Initial state: check if the download URL is a release page (html fallback)
    if (_isHtmlUrlFallback) {
      return _buildInitialActions(
        state,
        primaryAction: FilledButton(
          onPressed: () => _openInBrowser(state.downloadUrl!),
          child: ConstrainedText(
            strings.updateOpenBrowser,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // Initial state with direct download URL: show all action buttons
    return _buildInitialActions(
      state,
      primaryAction: FilledButton(
        onPressed: () => notifier.downloadUpdate(),
        child: ConstrainedText(
          strings.updateNow,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  List<Widget> _buildInitialActions(
    UpdateState state, {
    required Widget primaryAction,
  }) {
    final strings = AppLocalizations.of(context)!;
    final notifier = ref.read(updateProvider.notifier);
    final skipAction = TextButton(
      onPressed: () {
        if (state.latestVersion != null) {
          notifier.skipVersion(state.latestVersion!);
        }
        Navigator.of(context).pop();
      },
      child: ConstrainedText(
        strings.updateSkipVersion,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final remindAction = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: ConstrainedText(
        strings.updateRemindLater,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    final viewportWidth = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    if (viewportWidth >= 600 && textScale <= 1.2) {
      return [skipAction, remindAction, primaryAction];
    }

    if (viewportWidth < 360 || textScale > 1.2) {
      return [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: double.infinity, child: skipAction),
            SizedBox(width: double.infinity, child: remindAction),
            const SizedBox(height: 4),
            SizedBox(width: double.infinity, child: primaryAction),
          ],
        ),
      ];
    }

    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: skipAction),
              Expanded(child: remindAction),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(width: double.infinity, child: primaryAction),
        ],
      ),
    ];
  }

  /// Builds the download progress card shown in the actions area.
  Widget _buildDownloadProgress(UpdateState state) {
    final cs = Theme.of(context).colorScheme;
    final strings = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primaryContainer, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.download, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  strings.updateDownloading,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: state.downloadTotalBytes == null
                  ? null
                  : state.downloadProgress,
              minHeight: 10,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.center,
            child: Text(
              switch (state.downloadTotalBytes) {
                final int total when total > 0 =>
                  '${_formatBytes(state.downloadReceivedBytes)} / ${_formatBytes(total)}  ·  ${(state.downloadProgress * 100).toInt()}%',
                _ => _formatBytes(state.downloadReceivedBytes),
              },
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _localizedDownloadError(String error, AppLocalizations strings) {
    if (error == '下载地址不可用') return strings.updateDownloadUrlUnavailable;
    if (error.startsWith('当前平台暂无直接下载链接')) {
      return strings.updateNoDirectDownloadLink;
    }

    final httpStatus = RegExp(r'^下载失败: HTTP (\d+)$').firstMatch(error);
    if (httpStatus != null) {
      return strings.updateDownloadHttpFailed(httpStatus.group(1)!);
    }
    if (error.startsWith('自动安装失败: ')) {
      return strings.updateAutomaticInstallFailed(
        error.substring('自动安装失败: '.length),
      );
    }
    if (error.startsWith('下载失败: ')) {
      return strings.updateDownloadFailed(error.substring('下载失败: '.length));
    }
    if (error.startsWith('无法打开文件，请手动安装: ')) {
      return strings.updateManualInstallFileError(
        error.substring('无法打开文件，请手动安装: '.length),
      );
    }
    if (error == '安装失败，请手动打开 APK 安装') {
      return strings.updateApkInstallFailedNoDetails;
    }
    if (error.startsWith('安装失败，请手动打开 APK 安装: ')) {
      return strings.updateApkInstallFailed(
        error.substring('安装失败，请手动打开 APK 安装: '.length),
      );
    }
    if (error.startsWith('安装失败: ')) {
      return strings.updateInstallFailed(error.substring('安装失败: '.length));
    }
    if (error.startsWith('更新失败: ')) {
      return strings.updateFailed(error.substring('更新失败: '.length));
    }
    return error;
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
