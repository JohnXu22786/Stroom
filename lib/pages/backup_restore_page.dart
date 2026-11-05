import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/backup_service.dart';
import '../startup/app_restart.dart';
import '../anki/apkg/apkg_exporter.dart';
import '../anki/apkg/apkg_importer.dart';
import '../utils/system_pick_utils.dart';

class BackupRestorePage extends ConsumerStatefulWidget {
  const BackupRestorePage({super.key});

  @override
  ConsumerState<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends ConsumerState<BackupRestorePage> {
  AppLocalizations get _strings => AppLocalizations.of(context)!;
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isClearing = false;
  bool _isAnkiExporting = false;
  bool _isAnkiImporting = false;

  // 统一选择（对应新 BackupSelection 字段）
  // 聊天记录和附件、设置、图片、音频、视频、文本、任务、Anki数据、浏览器Cookies
  bool _chatRecordsAndAttachments = true;
  bool _settings = true;
  bool _pictures = true;
  bool _audio = true;
  bool _videos = true;
  bool _texts = true;
  bool _tasks = true;
  bool _ankiData = true;
  bool _browserCookies = true;

  BackupSelection get _selection => BackupSelection(
        chatRecordsAndAttachments: _chatRecordsAndAttachments,
        settings: _settings,
        pictures: _pictures,
        audio: _audio,
        videos: _videos,
        texts: _texts,
        tasks: _tasks,
        ankiData: _ankiData,
        browserCookies: _browserCookies,
      );

  bool get _hasSelection {
    return _chatRecordsAndAttachments ||
        _settings ||
        _pictures ||
        _audio ||
        _videos ||
        _texts ||
        _tasks ||
        _ankiData ||
        _browserCookies;
  }

  Future<void> _onExport() async {
    if (_isExporting) return;
    if (!_hasSelection) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_strings.backupRestoreSelectBackupCategory),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final selection = _selection;
    setState(() => _isExporting = true);
    try {
      // 显示不可关闭的进度弹窗
      final progressValue = ValueNotifier<double?>(null);

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(
              AppLocalizations.of(ctx)!.backupRestoreExportingBackup,
            ),
            content: Row(
              children: [
                ValueListenableBuilder<double?>(
                  valueListenable: progressValue,
                  builder: (_, value, __) {
                    if (value != null) {
                      return SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 2.5,
                        ),
                      );
                    }
                    return const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ValueListenableBuilder<double?>(
                    valueListenable: progressValue,
                    builder: (progressContext, progress, __) => Text(
                      _exportProgressLabel(
                        AppLocalizations.of(progressContext)!,
                        progress,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      await BackupService.exportBackup(
        context,
        onProgress: (progress) {
          progressValue.value = progress;
        },
        selection: selection,
      );
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _exportProgressLabel(AppLocalizations strings, double? progress) {
    if (progress == null) return strings.backupRestorePreparingData;
    if (progress < 0.05) return strings.backupRestoreCollectingDatabase;
    if (progress < 0.15) return strings.backupRestoreProcessingSettings;
    if (progress < 0.35) return strings.backupRestoreAddingTasks;
    if (progress < 0.5) return strings.backupRestoreAddingPictures;
    if (progress < 0.65) return strings.backupRestoreAddingAudio;
    if (progress < 0.75) return strings.backupRestoreAddingVideo;
    if (progress < 0.8) return strings.backupRestoreAddingText;
    if (progress < 0.85) return strings.backupRestoreAddingChat;
    if (progress < 1.0) return strings.backupRestoreCompressing;
    return strings.backupRestoreCompleted;
  }

  Future<void> _onImport() async {
    if (!_hasSelection) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_strings.backupRestoreSelectRestoreCategory),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final selection = _selection;
    final restoreWarnings = <String>[];
    if (selection.chatRecordsAndAttachments) {
      restoreWarnings.add(_strings.backupRestoreCategoryChat);
    }
    if (selection.settings) {
      restoreWarnings.add(_strings.backupRestoreCategorySettings);
    }
    if (selection.pictures) {
      restoreWarnings.add(_strings.backupRestoreCategoryPictures);
    }
    if (selection.audio) {
      restoreWarnings.add(_strings.backupRestoreCategoryAudio);
    }
    if (selection.videos) {
      restoreWarnings.add(_strings.backupRestoreCategoryVideos);
    }
    if (selection.texts) {
      restoreWarnings.add(_strings.backupRestoreCategoryTexts);
    }
    if (selection.tasks) {
      restoreWarnings.add(_strings.backupRestoreCategoryTasks);
    }
    if (selection.ankiData) {
      restoreWarnings.add(_strings.backupRestoreCategoryAnki);
    }
    if (selection.browserCookies) {
      restoreWarnings.add(_strings.backupRestoreCategoryBrowser);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_strings.backupRestoreConfirmRestore),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_strings.backupRestoreSelectedCategories),
            const SizedBox(height: 12),
            ...restoreWarnings.map(
              (w) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(w, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _strings.backupRestoreRestoreInfo,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _strings.backupRestoreRestartNotice,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context)!.backupRestoreCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_strings.backupRestoreConfirmRestoreButton),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _isImporting = true);
    try {
      var skippedCategories = <String>[];
      final success = await BackupService.importBackup(
        context,
        selection: selection,
        onSkippedCategories: (categories) => skippedCategories = categories,
      );
      if (success && mounted) {
        // 弹窗展示期间停止按钮 spinner（避免模态框背后持续动画）
        setState(() => _isImporting = false);
        if (selection.selectedLabels.every(skippedCategories.contains)) {
          await _showSkippedCategoriesPrompt(skippedCategories);
        } else {
          final message = skippedCategories.isEmpty
              ? _strings.backupRestoreRestoredMessage
              : '${_skippedCategoriesMessage(skippedCategories)}\n\n'
                  '${_strings.backupRestoreOtherSelectedRestored}';
          await _showRestartPrompt(message: message);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      if (e is BackupValidationException ||
          e is DataManagementPreflightException) {
        // 恢复开始前就失败：未删除任何数据，
        // 错误提示已由 importBackup 弹出，无需重启。
        return;
      }
      // 恢复失败时恢复可能已部分完成（选中类别的文件已被清除但恢复中断），
      // 提示重启以恢复干净状态（失败详情已由 importBackup 弹出）。
      await _showRestartPrompt(
        title: _strings.backupRestoreIncompleteTitle,
        message: _strings.backupRestoreIncompleteMessage,
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange,
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // ── 清除所选数据 ──────────────────────────────────────

  Future<void> _onClearSelectedData() async {
    if (_isClearing) return;
    if (!_hasSelection) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_strings.backupRestoreSelectClearCategory),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final selection = _selection;
    final clearLabels = selection.selectedLabels;
    const browserWebsiteDataClearPlatforms = {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    };
    final browserWebsiteDataUnsupported = selection.browserCookies &&
        (kIsWeb ||
            !browserWebsiteDataClearPlatforms.contains(defaultTargetPlatform));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ClearSelectedDataConfirmationDialog(
        labels: _localizedCategoryLabels(clearLabels),
        browserWebsiteDataUnsupported: browserWebsiteDataUnsupported,
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isClearing = true);
    var progressShown = false;
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(_strings.backupRestoreClearingData),
            content: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 16),
                Expanded(child: Text(_strings.backupRestoreDeletingCategories)),
              ],
            ),
          ),
        ),
      );
      progressShown = true;

      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      final browserWebsiteDataCleared = await BackupService.clearSelectedData(
        selection,
      );
      // 先关闭进度弹窗，再展示重启提示弹窗，避免弹窗叠放
      if (mounted && progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
        progressShown = false;
      }
      if (mounted) {
        // 弹窗展示期间停止按钮 spinner（避免模态框背后持续动画）
        setState(() => _isClearing = false);
        await _showRestartPrompt(
          title: browserWebsiteDataCleared
              ? _strings.backupRestoreClearedTitle
              : _strings.backupRestorePartiallyClearedTitle,
          message: browserWebsiteDataCleared
              ? _strings.backupRestoreClearedMessage
              : _strings.backupRestorePartialClearMessage,
          icon: browserWebsiteDataCleared
              ? Icons.check_circle_outline
              : Icons.warning_amber_rounded,
          iconColor: browserWebsiteDataCleared
              ? const Color(0xFF43A047)
              : Colors.orange,
        );
      }
    } catch (e) {
      // 先关闭进度弹窗，让失败提示可见
      if (mounted && progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
        progressShown = false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_strings.backupRestoreClearFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (e is DataManagementPreflightException) return;
      // 清除可能已部分完成（磁盘数据与内存状态不一致，且 Anki 数据库连接
      // 可能已被关闭），失败后同样提示重启，保证应用以干净状态重新加载。
      if (mounted) {
        setState(() => _isClearing = false);
        await _showRestartPrompt(
          title: _strings.backupRestoreClearIncompleteTitle,
          message: _strings.backupRestoreClearIncompleteMessage,
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.orange,
        );
      }
    } finally {
      if (mounted && progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => _isClearing = false);
    }
  }

  // ── Anki .apkg ──────────────────────────────────────────

  Future<void> _onAnkiExport() async {
    setState(() => _isAnkiExporting = true);
    try {
      final path = await AnkiApkgExporter.export();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_strings.backupRestoreAnkiExportSuccess(path)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_strings.backupRestoreExportFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnkiExporting = false);
    }
  }

  Future<void> _onAnkiImport() async {
    final picked = await FilePicker.pickFile(
      type: FileType.any,
      initialDirectory: SystemPickDirectories.documents(),
    );
    if (picked == null) return;
    final path = picked.path;
    if (path == null || !path.endsWith('.apkg')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_strings.backupRestoreApkgRequired),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isAnkiImporting = true);
    try {
      final summary = await AnkiApkgImporter.import(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(summary), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_strings.backupRestoreImportFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnkiImporting = false);
    }
  }

  /// 展示"操作完成，需要重启"提示弹窗（与启动时数据迁移弹窗同款）。
  ///
  /// 由用户选择「退出应用」或「立即重启」，不做自动倒计时重启。
  Future<void> _showRestartPrompt({
    String? title,
    String? message,
    IconData icon = Icons.check_circle,
    Color iconColor = const Color(0xFF43A047),
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Text(title ?? _strings.backupRestoreRestoreSuccessTitle),
            ],
          ),
          content: Text(message ?? _strings.backupRestoreRestoredMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _exitApp();
              },
              child: Text(_strings.backupRestoreExitApp),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                restartApp();
              },
              child: Text(_strings.backupRestoreRestartNow),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSkippedCategoriesPrompt(List<String> categories) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          categories.every((category) => category == '内置浏览器网站存储')
              ? _strings.backupRestoreSkippedTitle
              : _strings.backupRestoreNothingRestoredTitle,
        ),
        content: Text(_skippedCategoriesMessage(categories)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_strings.backupRestoreGotIt),
          ),
        ],
      ),
    );
  }

  String _skippedCategoriesMessage(List<String> categories) {
    final skippedCategories =
        categories.where((category) => category != '内置浏览器网站存储').toList();
    final displayCategories = _localizedCategoryLabels(skippedCategories);
    var message = skippedCategories.isEmpty
        ? ''
        : _strings.backupRestoreSkippedCategories(displayCategories.join(', '));
    if (skippedCategories.contains('任务')) {
      message += '\n\n${_strings.backupRestoreSkippedTasksLegacy}';
    }
    if (skippedCategories.contains('内置浏览器数据')) {
      message += '\n\n${_strings.backupRestoreSkippedCookies}';
    }
    if (categories.contains('内置浏览器网站存储')) {
      if (message.isNotEmpty) message += '\n\n';
      message += _strings.backupRestoreSkippedWebsiteData;
    }
    return message;
  }

  List<String> _localizedCategoryLabels(List<String> labels) =>
      labels.map((label) {
        switch (label) {
          case '聊天记录和附件':
            return _strings.backupRestoreCategoryChat;
          case '设置':
            return _strings.backupRestoreCategorySettings;
          case '图片':
            return _strings.backupRestoreCategoryPictures;
          case '音频':
            return _strings.backupRestoreCategoryAudio;
          case '视频':
            return _strings.backupRestoreCategoryVideos;
          case '文本':
            return _strings.backupRestoreCategoryTexts;
          case '任务':
            return _strings.backupRestoreCategoryTasks;
          case 'Anki闪卡数据':
          case 'Anki闪卡数据库':
            return _strings.backupRestoreCategoryAnki;
          case '内置浏览器数据':
            return _strings.backupRestoreCategoryBrowser;
          default:
            return label;
        }
      }).toList();

  /// 退出应用（与启动迁移弹窗的行为一致）。
  void _exitApp() {
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        SystemNavigator.pop();
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        exit(0);
      }
    } catch (e) {
      debugPrint('[BackupRestorePage] Failed to exit app: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_strings.backupRestorePageTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 提示信息
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_strings.backupRestoreIntro)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // === Anki 闪卡 .apkg 导出/导入 ===
          _buildSectionHeader(
            _strings.backupRestoreApkgTitle,
            onInfoPressed: () => _showInfoDialog(
              _strings.backupRestoreApkgInfoTitle,
              _strings.backupRestoreApkgInfoMessage,
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _strings.backupRestoreApkgDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isAnkiExporting ? null : _onAnkiExport,
                          icon: _isAnkiExporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.file_upload_outlined),
                          label: Text(
                            _isAnkiExporting
                                ? _strings.backupRestoreExportingApkg
                                : _strings.backupRestoreExportApkg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isAnkiImporting ? null : _onAnkiImport,
                          icon: _isAnkiImporting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.file_download_outlined),
                          label: Text(
                            _isAnkiImporting
                                ? _strings.backupRestoreImportingApkg
                                : _strings.backupRestoreImportApkg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // === 统一选择卡片（导入和导出共用） ===
          _buildSectionHeader(_strings.backupRestoreCategoryHeading),
          _buildUnifiedSelectionCard(),
          const SizedBox(height: 16),
          // === 导入导出按钮 ===
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isExporting ? null : _onExport,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.backup),
                      label: Text(
                        _isExporting
                            ? _strings.backupRestoreExporting
                            : _strings.backupRestoreExportBackup,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isImporting ? null : _onImport,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.restore),
                      label: Text(
                        _isImporting
                            ? _strings.backupRestoreRestoring
                            : _strings.backupRestoreChooseBackup,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // === 清除所选数据 ===
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _strings.backupRestoreClearSelected,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _strings.backupRestoreClearDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isClearing ? null : _onClearSelectedData,
                      icon: _isClearing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_forever_outlined),
                      label: Text(
                        _isClearing
                            ? _strings.backupRestoreClearing
                            : _strings.backupRestoreClearSelected,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _buildCheckboxItem(
              value: _chatRecordsAndAttachments,
              onChanged: (v) =>
                  setState(() => _chatRecordsAndAttachments = v ?? false),
              title: _strings.backupRestoreCategoryChat,
              subtitle: _strings.backupRestoreCategoryChatDescription,
              icon: Icons.chat_bubble_outline,
              iconColor: Colors.blue,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _settings,
              onChanged: (v) => setState(() => _settings = v ?? false),
              title: _strings.backupRestoreCategorySettings,
              subtitle: _strings.backupRestoreCategorySettingsDescription,
              icon: Icons.settings_outlined,
              iconColor: Colors.grey,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _pictures,
              onChanged: (v) => setState(() => _pictures = v ?? false),
              title: _strings.backupRestoreCategoryPictures,
              subtitle: _strings.backupRestoreCategoryPicturesDescription,
              icon: Icons.image_outlined,
              iconColor: Colors.pink,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _audio,
              onChanged: (v) => setState(() => _audio = v ?? false),
              title: _strings.backupRestoreCategoryAudio,
              subtitle: _strings.backupRestoreCategoryAudioDescription,
              icon: Icons.audiotrack_outlined,
              iconColor: Colors.purple,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _videos,
              onChanged: (v) => setState(() => _videos = v ?? false),
              title: _strings.backupRestoreCategoryVideos,
              subtitle: _strings.backupRestoreCategoryVideosDescription,
              icon: Icons.videocam_outlined,
              iconColor: Colors.indigo,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _texts,
              onChanged: (v) => setState(() => _texts = v ?? false),
              title: _strings.backupRestoreCategoryTexts,
              subtitle: _strings.backupRestoreCategoryTextsDescription,
              icon: Icons.description_outlined,
              iconColor: Colors.teal,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _tasks,
              onChanged: (v) => setState(() => _tasks = v ?? false),
              title: _strings.backupRestoreCategoryTasks,
              subtitle: _strings.backupRestoreCategoryTasksDescription,
              icon: Icons.assignment_outlined,
              iconColor: Colors.brown,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _ankiData,
              onChanged: (v) => setState(() => _ankiData = v ?? false),
              title: _strings.backupRestoreCategoryAnki,
              subtitle: _strings.backupRestoreCategoryAnkiDescription,
              icon: Icons.extension,
              iconColor: Colors.green,
              infoTitle: _strings.backupRestoreAnkiDataInfoTitle,
              infoMessage: _strings.backupRestoreAnkiDataInfoMessage,
              infoTooltip: _strings.backupRestoreAnkiDataInfoTooltip,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _browserCookies,
              onChanged: (v) => setState(() => _browserCookies = v ?? false),
              title: _strings.backupRestoreCategoryBrowser,
              subtitle: _strings.backupRestoreCategoryBrowserDescription,
              icon: Icons.cookie,
              iconColor: Colors.orange,
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxItem({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    String? infoTitle,
    String? infoMessage,
    String? infoTooltip,
  }) {
    final checkboxTile = CheckboxListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.only(
        left: 16,
        right: infoMessage == null ? 16 : 0,
      ),
      title: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14)),
        ],
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
    );

    if (infoMessage == null) return checkboxTile;

    return Row(
      children: [
        Expanded(child: checkboxTile),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: IconButton(
            tooltip: infoTooltip ?? _strings.backupRestoreViewInfo,
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: () => _showInfoDialog(infoTitle ?? title, infoMessage),
          ),
        ),
      ],
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_strings.backupRestoreGotIt),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onInfoPressed}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          if (onInfoPressed != null)
            IconButton(
              tooltip: _strings.backupRestoreApkgInfoTooltip,
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: onInfoPressed,
            ),
        ],
      ),
    );
  }
}

class _ClearSelectedDataConfirmationDialog extends StatefulWidget {
  const _ClearSelectedDataConfirmationDialog({
    required this.labels,
    required this.browserWebsiteDataUnsupported,
  });

  final List<String> labels;
  final bool browserWebsiteDataUnsupported;

  @override
  State<_ClearSelectedDataConfirmationDialog> createState() =>
      _ClearSelectedDataConfirmationDialogState();
}

class _ClearSelectedDataConfirmationDialogState
    extends State<_ClearSelectedDataConfirmationDialog> {
  static const _countdownDuration = 10;
  int _secondsRemaining = _countdownDuration;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.backupRestoreConfirmClear),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.backupRestoreClearCategoriesIntro),
          const SizedBox(height: 12),
          ...widget.labels.map(
            (label) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
          if (widget.browserWebsiteDataUnsupported) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!
                        .backupRestoreBrowserClearUnsupported,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
          if (widget.labels.length < 9) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!
                        .backupRestoreUnselectedUnchanged,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.backupRestoreClearWarning,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(AppLocalizations.of(context)!.backupRestoreCancel),
        ),
        FilledButton(
          onPressed: _secondsRemaining == 0
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: Text(
            _secondsRemaining == 0
                ? AppLocalizations.of(context)!.backupRestoreClearSelected
                : AppLocalizations.of(context)!
                    .backupRestoreConfirmClearCountdown(_secondsRemaining),
          ),
        ),
      ],
    );
  }
}
