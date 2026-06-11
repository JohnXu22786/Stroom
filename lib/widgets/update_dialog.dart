import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/update_provider.dart';

/// A shared update dialog used by both the settings page and the
/// application startup flow.
///
/// Shows update version info, release notes, and action buttons.
/// The "立即更新" button downloads the update file within the app
/// and allows the user to open/install it when complete.
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
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.system_update, color: Colors.blue),
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
            // Download progress section
            if (state.isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: state.downloadProgress),
              const SizedBox(height: 8),
              Text(
                '正在下载... ${(state.downloadProgress * 100).toInt()}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
            // Download error section
            if (state.downloadError != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      state.downloadError!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ],
            // Download complete section
            if (state.downloadComplete) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 4),
                  const Text(
                    '下载完成，点击下方按钮进行安装',
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: _buildActions(state),
    );
  }

  List<Widget> _buildActions(UpdateState state) {
    final notifier = ref.read(updateProvider.notifier);

    // During download, show only a cancel/disabled state
    if (state.isDownloading) {
      return [
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ];
    }

    // After download complete, show install button
    if (state.downloadComplete) {
      return [
        TextButton(
          onPressed: () async {
            await notifier.installDownloadedFile();
            if (!mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('打开/安装'),
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

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
