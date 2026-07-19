import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/backup_location_manager.dart';
import '../services/backup_service.dart';
import '../services/data_migration_service.dart';
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
  String? _externalBackupPath;
  Timer? _restartTimer;
  bool _isAnkiExporting = false;
  bool _isAnkiImporting = false;

  // 统一选择（对应新 BackupSelection 字段）
  // 聊天记录和附件、设置、图片、音频、视频、文本、任务
  bool _chatRecordsAndAttachments = true;
  bool _settings = true;
  bool _pictures = true;
  bool _audio = true;
  bool _videos = true;
  bool _texts = true;
  bool _tasks = true;

  BackupSelection get _selection => BackupSelection(
        chatRecordsAndAttachments: _chatRecordsAndAttachments,
        settings: _settings,
        pictures: _pictures,
        audio: _audio,
        videos: _videos,
        texts: _texts,
        tasks: _tasks,
      );

  @override
  void initState() {
    super.initState();
    _loadExternalBackupPath();
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    super.dispose();
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
        _tasks;
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
    if (selection.chatRecordsAndAttachments) {
      restoreWarnings.add('聊天记录和附件将被覆盖');
    }
    if (selection.settings) restoreWarnings.add('设置将被覆盖');
    if (selection.pictures) restoreWarnings.add('图片将被覆盖');
    if (selection.audio) restoreWarnings.add('音频将被覆盖');
    if (selection.videos) restoreWarnings.add('视频将被覆盖');
    if (selection.texts) restoreWarnings.add('文本将被覆盖');
    if (selection.tasks) restoreWarnings.add('任务将被覆盖');

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
            if (restoreWarnings.length < 7) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '未选中的类别将保持不变，不会被覆盖。',
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
                      '导入完成后应用将自动重启，请确保已保存当前工作。',
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

    setState(() => _isImporting = true);
    try {
      if (!mounted) return;
      final success = await BackupService.importBackup(
        context,
        selection: selection,
      );
      if (success && mounted) {
        await _showRestartCountdown();
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
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
              content: Text('闪卡片组已导出到: $path'), backgroundColor: Colors.green),
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
    // Use file_picker to select .apkg file
    // Since file_picker may need Android permissions, use a simpler approach:
    // show a dialog asking for path, or use the file_picker if available
    final ctl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入 .apkg'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            hintText: '/path/to/file.apkg',
            labelText: '.apkg 文件路径',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('导入')),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    setState(() => _isAnkiImporting = true);
    try {
      final summary = await AnkiApkgImporter.import(result);
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

  Future<void> _showRestartCountdown() async {
    if (!mounted) return;

    final countdown = ValueNotifier<int>(5);

    _restartTimer?.cancel();
    _restartTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countdown.value--;
      if (countdown.value <= 0) {
        timer.cancel();
        _restartTimer = null;
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        restartApp();
      }
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
              const SizedBox(width: 8),
              const Text('数据恢复成功'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('数据已从备份中恢复。应用将在倒计时后自动重启。'),
              const SizedBox(height: 16),
              Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: countdown,
                  builder: (_, value, __) => Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('秒后自动重启'),
              ),
            ],
          ),
        ),
      ),
    );

    _restartTimer?.cancel();
    _restartTimer = null;
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
                      '手动导出时可选择要备份的数据类别；导入时也可选择性恢复部分数据。'
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
          const SizedBox(height: 24),
          // === 闪卡 .apkg 导出/导入 ===
          _buildSectionHeader('闪卡牌组'),
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
