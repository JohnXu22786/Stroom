import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/update_provider.dart';

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
  /// Whether the download URL points to a GitHub release page (not a direct asset).
  /// When true, the "立即更新" button is replaced with "前往浏览器下载".
  bool get _isHtmlUrlFallback {
    final url = ref.read(updateProvider).downloadUrl;
    if (url == null) return false;
    return url.contains('/releases/tag/');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateProvider);
    final cs = Theme.of(context).colorScheme;

    // Prevent dialog dismissal during download or install.
    // The user must not accidentally dismiss the dialog while
    // a critical operation is in progress.
    final canPop = !state.isDownloading && !state.isInstalling;

    return PopScope(
      canPop: canPop,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: cs.primary),
            SizedBox(width: 8),
            Expanded(child: Text('发现新版本')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('最新版本: ${state.latestVersion ?? ''}'),
              if (state.releaseNotes != null &&
                  state.releaseNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('更新内容:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(state.releaseNotes!),
              ],
              // Installing state — shown briefly while the app auto-installs
              if (state.isInstalling) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cs.tertiaryContainer,
                      width: 0.5,
                    ),
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
                              cs.onTertiaryContainer),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '正在安装...',
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
              // Download error section
              if (state.downloadError != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.error, size: 18),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        state.downloadError!,
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
                      '下载完成',
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
    final notifier = ref.read(updateProvider.notifier);

    // During download, show progress bar in the button area
    if (state.isDownloading) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: _buildDownloadProgress(state),
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
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              // Retry installing the already-downloaded APK file
              // with visual feedback (isInstalling state).
              notifier.retryInstall();
            },
            child: const Text('手动安装'),
          ),
        ];
      }
      // No error — show a close button for manual dismissal.
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ];
    }

    // After download error that is non-recoverable (html fallback), show close only
    if (state.downloadError != null) {
      final isNonRecoverable = state.downloadError!.contains('暂无直接下载链接');
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        if (!isNonRecoverable)
          FilledButton(
            onPressed: () => notifier.downloadUpdate(),
            child: const Text('重试下载'),
          ),
      ];
    }

    // Initial state: check if the download URL is a release page (html fallback)
    if (_isHtmlUrlFallback) {
      return [
        TextButton(
          onPressed: () {
            if (state.latestVersion != null) {
              notifier.skipVersion(state.latestVersion!);
            }
            Navigator.of(context).pop();
          },
          child: const Text('跳过此版本'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('稍后提醒'),
        ),
        FilledButton(
          onPressed: () => _openInBrowser(state.downloadUrl!),
          child: const Text('前往浏览器下载'),
        ),
      ];
    }

    // Initial state with direct download URL: show all action buttons
    return [
      TextButton(
        onPressed: () {
          if (state.latestVersion != null) {
            notifier.skipVersion(state.latestVersion!);
          }
          Navigator.of(context).pop();
        },
        child: const Text('跳过此版本'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('稍后提醒'),
      ),
      FilledButton(
        onPressed: () => notifier.downloadUpdate(),
        child: const Text('立即更新'),
      ),
    ];
  }

  /// Builds the download progress card shown in the actions area.
  Widget _buildDownloadProgress(UpdateState state) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.primaryContainer,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.download, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Text('正在下载更新...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.downloadProgress,
              minHeight: 10,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(state.downloadProgress * 100).toInt()}%',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
