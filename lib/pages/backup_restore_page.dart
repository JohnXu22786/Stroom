import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

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
          const SnackBar(
            content: Text('请至少选择一项要备份的数据类别'),
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
      final progressNotifier = ValueNotifier<String>('正在准备数据...');
      final progressValue = ValueNotifier<double?>(null);

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('正在导出备份'),
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
                  child: ValueListenableBuilder<String>(
                    valueListenable: progressNotifier,
                    builder: (_, msg, __) => Text(msg),
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
          if (progress < 0.05) {
            progressNotifier.value = '正在收集数据库记录...';
          } else if (progress < 0.15) {
            progressNotifier.value = '正在处理配置数据...';
          } else if (progress < 0.35) {
            progressNotifier.value = '正在添加任务文件...';
          } else if (progress < 0.5) {
            progressNotifier.value = '正在添加图片文件...';
          } else if (progress < 0.65) {
            progressNotifier.value = '正在添加音频文件...';
          } else if (progress < 0.75) {
            progressNotifier.value = '正在添加视频文件...';
          } else if (progress < 0.8) {
            progressNotifier.value = '正在添加文本文件...';
          } else if (progress < 0.85) {
            progressNotifier.value = '正在添加聊天记录和附件...';
          } else if (progress < 1.0) {
            progressNotifier.value = '正在压缩打包...';
          } else {
            progressNotifier.value = '已完成';
          }
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

  Future<void> _onImport() async {
    if (!_hasSelection) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请至少选择一项要恢复的数据类别'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final selection = _selection;
    final restoreWarnings = <String>[];
    if (selection.chatRecordsAndAttachments) restoreWarnings.add('聊天记录和附件');
    if (selection.settings) restoreWarnings.add('设置');
    if (selection.pictures) restoreWarnings.add('图片');
    if (selection.audio) restoreWarnings.add('音频');
    if (selection.videos) restoreWarnings.add('视频');
    if (selection.texts) restoreWarnings.add('文本');
    if (selection.tasks) restoreWarnings.add('任务');
    if (selection.ankiData) restoreWarnings.add('Anki闪卡数据库');
    if (selection.browserCookies) restoreWarnings.add('内置浏览器数据');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('已勾选的数据类别：'),
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
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '备份中实际包含的已勾选类别会替换本机现有数据，不会合并。未勾选或备份中缺少的类别保持原样；缺少的类别会跳过并提示。',
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
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '恢复完成后需重启应用才能生效，请确保已保存当前工作。',
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
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定恢复'),
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
              ? '数据已从备份中恢复。请重启应用以使用恢复的数据。'
              : '${_skippedCategoriesMessage(skippedCategories)}'
                  '其余所选数据已恢复，请重启应用以生效。';
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
        title: '恢复未完成',
        message: '数据未能完整恢复，部分数据可能已被清除。请重启应用后重试。',
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
          const SnackBar(
            content: Text('请至少选择一项要清除的数据类别'),
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
        labels: clearLabels,
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
          child: const AlertDialog(
            title: Text('正在清除数据'),
            content: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('正在删除所选类别的数据...')),
              ],
            ),
          ),
        ),
      );
      progressShown = true;

      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      final browserWebsiteDataCleared =
          await BackupService.clearSelectedData(selection);
      // 先关闭进度弹窗，再展示重启提示弹窗，避免弹窗叠放
      if (mounted && progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
        progressShown = false;
      }
      if (mounted) {
        // 弹窗展示期间停止按钮 spinner（避免模态框背后持续动画）
        setState(() => _isClearing = false);
        await _showRestartPrompt(
          title: browserWebsiteDataCleared ? '数据清除完成' : '部分数据已清除',
          message: browserWebsiteDataCleared
              ? '所选数据已清除。请重启应用以生效。'
              : '其他所选数据已清除。当前平台不支持完整清除内置浏览器网站存储（localStorage、IndexedDB 等）；未能清除的浏览器数据仍会保留。请重启应用使已清除的数据生效。',
          icon: browserWebsiteDataCleared
              ? Icons.check_circle_outline
              : Icons.warning_amber_rounded,
          iconColor: browserWebsiteDataCleared ? null : Colors.orange,
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
          SnackBar(content: Text('清除失败: $e'), backgroundColor: Colors.red),
        );
      }
      if (e is DataManagementPreflightException) return;
      // 清除可能已部分完成（磁盘数据与内存状态不一致，且 Anki 数据库连接
      // 可能已被关闭），失败后同样提示重启，保证应用以干净状态重新加载。
      if (mounted) {
        setState(() => _isClearing = false);
        await _showRestartPrompt(
          title: '清除未完成',
          message: '部分数据未能清除。请重启应用后重试清除操作。',
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
            content: Text('Anki闪卡片组已导出到: $path'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnkiExporting = false);
    }
  }

  Future<void> _onAnkiImport() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      initialDirectory: SystemPickDirectories.documents(),
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null || !path.endsWith('.apkg')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请选择 .apkg 格式的文件'),
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
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
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
    String title = '数据恢复成功',
    String message = '数据已从备份中恢复。请重启应用以使用恢复的数据。',
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
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _exitApp();
              },
              child: const Text('退出应用'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                restartApp();
              },
              child: const Text('立即重启'),
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
          categories.every(
            (category) => category == '内置浏览器网站存储',
          )
              ? '部分数据已跳过'
              : '未恢复任何数据',
        ),
        content: Text(_skippedCategoriesMessage(categories)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  String _skippedCategoriesMessage(List<String> categories) {
    final skippedCategories = categories
        .where((category) => category != '内置浏览器网站存储')
        .toList();
    var message = skippedCategories.isEmpty
        ? ''
        : '备份中未能确认以下勾选的数据类型包含可恢复内容，已跳过；'
            '当前数据保持不变：${skippedCategories.join('、')}。';
    if (skippedCategories.contains('任务')) {
      message += '\n\n如果这是旧版备份，空任务文件无法区分“任务列表为空”和“该平台未导出任务”；'
          '为避免覆盖当前任务，任务类别已跳过并保留原数据。';
    }
    if (skippedCategories.contains('内置浏览器数据')) {
      message += '\n\n为保护本机现有浏览器数据，当前平台无法安全恢复备份中的浏览器目录或 Cookies；'
          '整个内置浏览器类别已跳过，本机原数据保持不变。';
    }
    if (categories.contains('内置浏览器网站存储')) {
      if (message.isNotEmpty) message += '\n\n';
      message += '备份没有包含可在当前平台恢复的内置浏览器网站存储目录；'
          'Cookies（若备份中包含）仍可单独恢复。Android/Windows 的网站数据目录仅支持同平台导入。';
    }
    return message;
  }

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
      appBar: AppBar(title: const Text('数据备份与恢复')),
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
                  Expanded(
                    child: Text(
                      '手动导出可按数据类别选择备份内容。导入时，只恢复已勾选且备份包中包含的类别；若备份缺少某类别或其必需文件不完整，该类别会自动跳过并提示，未勾选的类别保持原样。也可直接清除所选类别的数据。\n\n'
                      '文件名格式为 backup_YYYY-MM-DDTHH-MM-SS.zip。Android 备份保存在已授权的系统文件夹中，即使卸载应用或清除应用数据，仍可通过系统文件管理器访问。其他平台的保存位置和文件保留方式因平台而异。'
                      '${kIsWeb ? '\n\nWeb 版暂不支持任务、Anki 闪卡数据和浏览器 Cookies 的备份。' : '\n\n任务备份包含任务流引用的应用内附件、CatCatch 已完成文件，以及进行中的下载临时文件、分段文件、续传进度和转码中间文件。导入时会重定位 Stroom 数据目录内的任务文件路径；是否能继续下载仍取决于源站资源是否可用。任务引用的图片、音频、视频或文本文件也需同时勾选对应类别。\n\nAndroid/Windows 会把内置浏览器 Cookies 和网站存储目录一并备份；这些目录仅支持在相同平台导入，恢复或清除后需重启应用。Android/Windows 的 Cookies 快照按已访问域名采集，可能不完整；若备份不含相同平台的网站存储目录，内置浏览器类别会自动跳过并提示，以免覆盖无法完整回滚的本机 Cookies。Linux 桌面版无法完整读取本机 Cookies，浏览器类别也会跳过并提示。其他平台可能因无法取得 Cookies 快照而省略该类别；在可导入的平台上，未开启 Cookies 保留时，导入的 Cookies 仅在当前内置浏览器会话中有效。iOS/macOS 的 WKWebView 不公开网站存储目录，因此只包含可读取的 Cookies。\n\nAnki 备份会包含 collection.media 目录中的卡片媒体。'}'
                      '${kIsWeb ? '' : '\n\n音频类别也会包含尚未保存到音频库的录音草稿，导入后可在录音页继续保存。'}'
                      '\n\n内置浏览器数据集中放在备份包的 browser_data/ 目录：cookies.json 保存 Cookies，Android/Windows 子目录保存网站存储数据（包括 localStorage、IndexedDB 等）。网站存储目录只支持相同平台导入；iOS/macOS 的 WKWebView 不提供可直接打包的网站数据目录。',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // === Anki 闪卡 .apkg 导出/导入 ===
          _buildSectionHeader('Anki闪卡牌组'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '导入/导出 .apkg 格式的 Anki 牌组',
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
                          label: Text(_isAnkiExporting ? '导出中...' : '导出 .apkg'),
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
                          label: Text(_isAnkiImporting ? '导入中...' : '导入 .apkg'),
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
          _buildSectionHeader('选择要备份或恢复的数据类别'),
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
                      label: Text(_isExporting ? '正在导出...' : '导出备份'),
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
                      label: Text(_isImporting ? '正在恢复...' : '选择备份文件并恢复'),
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
                        '清除所选数据',
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
                    '直接清除当前勾选的数据类别（不需要备份文件）。'
                    '未勾选的类别将保持原样。此操作不可撤销。',
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
                      label: Text(_isClearing ? '正在清除...' : '清除所选数据'),
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
              title: '聊天记录和附件',
              subtitle: '聊天对话记录、消息内容与附件文件',
              icon: Icons.chat_bubble_outline,
              iconColor: Colors.blue,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _settings,
              onChanged: (v) => setState(() => _settings = v ?? false),
              title: '设置',
              subtitle: '应用配置、提供商设置与界面偏好',
              icon: Icons.settings_outlined,
              iconColor: Colors.grey,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _pictures,
              onChanged: (v) => setState(() => _pictures = v ?? false),
              title: '图片',
              subtitle: '照片和缩略图',
              icon: Icons.image_outlined,
              iconColor: Colors.pink,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _audio,
              onChanged: (v) => setState(() => _audio = v ?? false),
              title: '音频',
              subtitle: '语音合成和录音',
              icon: Icons.audiotrack_outlined,
              iconColor: Colors.purple,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _videos,
              onChanged: (v) => setState(() => _videos = v ?? false),
              title: '视频',
              subtitle: '视频文件',
              icon: Icons.videocam_outlined,
              iconColor: Colors.indigo,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _texts,
              onChanged: (v) => setState(() => _texts = v ?? false),
              title: '文本',
              subtitle: '文本文档',
              icon: Icons.description_outlined,
              iconColor: Colors.teal,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _tasks,
              onChanged: (v) => setState(() => _tasks = v ?? false),
              title: '任务',
              subtitle: '后台任务记录',
              icon: Icons.assignment_outlined,
              iconColor: Colors.brown,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _ankiData,
              onChanged: (v) => setState(() => _ankiData = v ?? false),
              title: 'Anki闪卡数据',
              subtitle: 'Anki 原始数据库',
              icon: Icons.extension,
              iconColor: Colors.green,
            ),
            const Divider(height: 1),
            _buildCheckboxItem(
              value: _browserCookies,
              onChanged: (v) => setState(() => _browserCookies = v ?? false),
              title: '内置浏览器数据',
              subtitle: 'Cookies 和网站存储；Android/Windows 支持完整站点目录',
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
  }) {
    return CheckboxListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
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
      title: const Text('确认清除'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('将清除以下数据类别（不经过备份文件）：'),
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
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '当前平台不支持完整清除内置浏览器网站存储（localStorage、IndexedDB 等）；确认后会清除其他所选数据，无法清除的浏览器数据将保留。',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],
          if (widget.labels.length < 9) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '未勾选的类别将保持原样，不会被清除。',
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
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '此操作不可撤销。清除完成后需重启应用才能生效。',
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _secondsRemaining == 0
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: Text(
            _secondsRemaining == 0 ? '确定清除' : '确定清除（$_secondsRemaining）',
          ),
        ),
      ],
    );
  }
}
