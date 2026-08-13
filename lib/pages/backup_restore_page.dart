import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../services/backup_location_manager.dart';
import '../services/backup_service.dart';
import '../startup/app_restart.dart';
import '../anki/apkg/apkg_exporter.dart';
import '../anki/apkg/apkg_importer.dart';

class BackupRestorePage extends ConsumerStatefulWidget {
  const BackupRestorePage({super.key});

  @override
  ConsumerState<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends ConsumerState<BackupRestorePage> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isClearing = false;
  String? _externalBackupPath;
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

  @override
  void initState() {
    super.initState();
    _loadExternalBackupPath();
  }

  Future<void> _loadExternalBackupPath() async {
    try {
      final path = await BackupLocationManager.getDisplayPath();
      if (mounted) {
        setState(() => _externalBackupPath = path);
      }
    } catch (_) {}
  }

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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
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
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '导出过程中请不要离开应用或让屏幕息屏（黑屏），以免备份文件损坏。',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
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
    if (selection.chatRecordsAndAttachments) {
      restoreWarnings.add('聊天记录和附件将被覆盖');
    }
    if (selection.settings) restoreWarnings.add('设置将被覆盖');
    if (selection.pictures) restoreWarnings.add('图片将被覆盖');
    if (selection.audio) restoreWarnings.add('音频将被覆盖');
    if (selection.videos) restoreWarnings.add('视频将被覆盖');
    if (selection.texts) restoreWarnings.add('文本将被覆盖');
    if (selection.tasks) restoreWarnings.add('任务将被覆盖');
    if (selection.ankiData) restoreWarnings.add('Anki闪卡数据库将被覆盖');
    if (selection.browserCookies) restoreWarnings.add('浏览器Cookies将被覆盖');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('将从选中的备份文件恢复以下数据类别：'),
            const SizedBox(height: 12),
            ...restoreWarnings.map(
              (w) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(w, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),
            if (restoreWarnings.length < 9) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '未勾选的类别将保持原样，不会被清除或覆盖。',
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
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 16),
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
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '恢复过程中请不要离开应用或让屏幕息屏（黑屏），以免备份文件损坏。',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              ],
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
    var progressShown = false;
    try {
      // 显示不可关闭的恢复进度弹窗（含"不要离开应用/息屏"提示），
      // 与导出流程对称，保证恢复期间提示持续可见
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: const AlertDialog(
            title: Text('正在恢复备份'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 16),
                    Expanded(child: Text('正在从备份文件恢复数据...')),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '恢复过程中请不要离开应用或让屏幕息屏（黑屏），以免备份文件损坏。',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      progressShown = true;

      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      final success = await BackupService.importBackup(
        context,
        selection: selection,
      );
      if (success && mounted) {
        // 先关闭进度弹窗，再展示重启提示弹窗，避免弹窗叠放
        if (progressShown) {
          Navigator.of(context, rootNavigator: true).pop();
          progressShown = false;
        }
        // 弹窗展示期间停止按钮 spinner（避免模态框背后持续动画）
        setState(() => _isImporting = false);
        await _showRestartPrompt();
      }
    } catch (e) {
      // 先关闭进度弹窗，让失败提示/重启提示可见
      if (mounted && progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
        progressShown = false;
      }
      if (!mounted) return;
      setState(() => _isImporting = false);
      if (e is BackupValidationException) {
        // 恢复开始前就失败（备份文件无效）：未删除任何数据，
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
      if (mounted && progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }
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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('将清除以下数据类别（不经过备份文件）：'),
            const SizedBox(height: 12),
            ...clearLabels.map(
              (label) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            Text(label, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),
            if (clearLabels.length < 9) ...[
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
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 16),
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确定清除'),
          ),
        ],
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
          title: '数据清除完成',
          message: '所选数据已清除。请重启应用以生效。',
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
              backgroundColor: Colors.green),
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
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null || !path.endsWith('.apkg')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('请选择 .apkg 格式的文件'), backgroundColor: Colors.orange),
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
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '手动导出时可选择要备份的数据类别；导入时只恢复勾选的类别，未勾选的类别保持原样；也可直接清除勾选的类别数据。'
                      '自动备份始终为全量备份。',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 自动备份位置信息卡片
          _buildBackupLocationCard(),
          const SizedBox(height: 24),
          // === Anki 闪卡 .apkg 导出/导入 ===
          _buildSectionHeader('Anki闪卡牌组'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('导入/导出 .apkg 格式的 Anki 牌组',
                      style: TextStyle(
                          fontSize: 13,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
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
                      Icon(Icons.delete_outline,
                          color: Colors.red.shade700, size: 20),
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

  Widget _buildBackupLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_open,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  '自动备份位置',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '自动备份文件保存在以下公开位置（不在应用数据目录内，彻底防止应用被删除或清除数据时备份丢失，你可以随时通过文件管理器找到并手动恢复）：',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _externalBackupPath ?? '正在获取...',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '应用在版本迁移或每次启动后会在此目录下自动创建完整数据备份（格式：backup_YYYY-MM-DDTHH-MM-SS.zip）。'
              '备份目录至少保留 3 个最新的备份文件，超出部分自动清理。'
              '这些文件在应用被卸载或清除数据后依然存在，你可通过系统文件管理器直接访问。',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
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
              title: '浏览器Cookies',
              subtitle: '内置浏览器持久化的Cookies数据',
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
