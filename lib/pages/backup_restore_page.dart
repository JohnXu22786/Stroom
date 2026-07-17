import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/backup_location_manager.dart';
import '../services/backup_service.dart';
import '../services/data_migration_service.dart';
import '../startup/app_restart.dart';

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

  // 导出选择（默认全选）
  bool _exportConversations = true;
  bool _exportPictures = true;
  bool _exportAudio = true;
  bool _exportVideos = true;
  bool _exportTexts = true;
  bool _exportTasks = true;
  bool _exportAttachments = true;

  // 导入选择（默认全选）
  bool _importConversations = true;
  bool _importPictures = true;
  bool _importAudio = true;
  bool _importVideos = true;
  bool _importTexts = true;
  bool _importTasks = true;
  bool _importAttachments = true;

  BackupSelection get _exportSelection => BackupSelection(
        conversations: _exportConversations,
        pictures: _exportPictures,
        audio: _exportAudio,
        videos: _exportVideos,
        texts: _exportTexts,
        tasks: _exportTasks,
        attachments: _exportAttachments,
      );

  BackupSelection get _importSelection => BackupSelection(
        conversations: _importConversations,
        pictures: _importPictures,
        audio: _importAudio,
        videos: _importVideos,
        texts: _importTexts,
        tasks: _importTasks,
        attachments: _importAttachments,
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

  Future<void> _onExport() async {
    if (_isExporting) return; // 防止重复点击
    final selection = _exportSelection;
    if (!selection.conversations &&
        !selection.pictures &&
        !selection.audio &&
        !selection.videos &&
        !selection.texts &&
        !selection.tasks &&
        !selection.attachments) {
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

      // 等待一个微任务让对话框渲染完毕
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      // 传递进度回调
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
            progressNotifier.value = '正在添加附件...';
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
    final selection = _importSelection;
    if (!selection.conversations &&
        !selection.pictures &&
        !selection.audio &&
        !selection.videos &&
        !selection.texts &&
        !selection.tasks &&
        !selection.attachments) {
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

    final restoreWarnings = <String>[];
    if (selection.conversations) {
      restoreWarnings.add('聊天记录和设置将被覆盖');
    }
    if (selection.pictures) restoreWarnings.add('图片将被覆盖');
    if (selection.audio) restoreWarnings.add('音频将被覆盖');
    if (selection.videos) restoreWarnings.add('视频将被覆盖');
    if (selection.texts) restoreWarnings.add('文本将被覆盖');
    if (selection.tasks) restoreWarnings.add('任务将被覆盖');
    if (selection.attachments) restoreWarnings.add('附件将被覆盖');

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
                    Expanded(child: Text(w, style: const TextStyle(fontSize: 13))),
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
          // External backup location info card
          Card(
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
                        Icon(Icons.folder,
                            size: 16, color: Colors.grey.shade600),
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
          ),
          const SizedBox(height: 24),
          // === 导出备份区域 ===
          _buildSectionHeader('导出备份'),
          _buildSelectionCard(
            title: '选择要备份的数据类别',
            conversations: _exportConversations,
            pictures: _exportPictures,
            audio: _exportAudio,
            videos: _exportVideos,
            texts: _exportTexts,
            tasks: _exportTasks,
            attachments: _exportAttachments,
            onConversationsChanged: (v) =>
                setState(() => _exportConversations = v ?? false),
            onPicturesChanged: (v) =>
                setState(() => _exportPictures = v ?? false),
            onAudioChanged: (v) =>
                setState(() => _exportAudio = v ?? false),
            onVideosChanged: (v) =>
                setState(() => _exportVideos = v ?? false),
            onTextsChanged: (v) =>
                setState(() => _exportTexts = v ?? false),
            onTasksChanged: (v) =>
                setState(() => _exportTasks = v ?? false),
            onAttachmentsChanged: (v) =>
                setState(() => _exportAttachments = v ?? false),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
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
            ),
          ),
          const SizedBox(height: 24),
          // === 导入恢复区域 ===
          _buildSectionHeader('导入恢复'),
          _buildSelectionCard(
            title: '选择要恢复的数据类别',
            conversations: _importConversations,
            pictures: _importPictures,
            audio: _importAudio,
            videos: _importVideos,
            texts: _importTexts,
            tasks: _importTasks,
            attachments: _importAttachments,
            onConversationsChanged: (v) =>
                setState(() => _importConversations = v ?? false),
            onPicturesChanged: (v) =>
                setState(() => _importPictures = v ?? false),
            onAudioChanged: (v) =>
                setState(() => _importAudio = v ?? false),
            onVideosChanged: (v) =>
                setState(() => _importVideos = v ?? false),
            onTextsChanged: (v) =>
                setState(() => _importTexts = v ?? false),
            onTasksChanged: (v) =>
                setState(() => _importTasks = v ?? false),
            onAttachmentsChanged: (v) =>
                setState(() => _importAttachments = v ?? false),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isImporting ? null : _onImport,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore),
                  label:
                      Text(_isImporting ? '正在恢复...' : '选择备份文件并恢复'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required bool conversations,
    required bool pictures,
    required bool audio,
    required bool videos,
    required bool texts,
    required bool tasks,
    required bool attachments,
    required ValueChanged<bool?> onConversationsChanged,
    required ValueChanged<bool?> onPicturesChanged,
    required ValueChanged<bool?> onAudioChanged,
    required ValueChanged<bool?> onVideosChanged,
    required ValueChanged<bool?> onTextsChanged,
    required ValueChanged<bool?> onTasksChanged,
    required ValueChanged<bool?> onAttachmentsChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('聊天记录和设置',
                  style: TextStyle(fontSize: 14)),
              subtitle: const Text('对话记录、应用设置、媒体库索引',
                  style: TextStyle(fontSize: 12)),
              value: conversations,
              onChanged: onConversationsChanged,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('图片', style: TextStyle(fontSize: 14)),
              subtitle:
                  const Text('照片和缩略图', style: TextStyle(fontSize: 12)),
              value: pictures,
              onChanged: onPicturesChanged,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('音频', style: TextStyle(fontSize: 14)),
              subtitle:
                  const Text('语音合成和录音', style: TextStyle(fontSize: 12)),
              value: audio,
              onChanged: onAudioChanged,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('视频', style: TextStyle(fontSize: 14)),
              subtitle:
                  const Text('视频文件', style: TextStyle(fontSize: 12)),
              value: videos,
              onChanged: onVideosChanged,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('文本', style: TextStyle(fontSize: 14)),
              subtitle:
                  const Text('文本文档', style: TextStyle(fontSize: 12)),
              value: texts,
              onChanged: onTextsChanged,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('任务', style: TextStyle(fontSize: 14)),
              subtitle:
                  const Text('后台任务记录', style: TextStyle(fontSize: 12)),
              value: tasks,
              onChanged: onTasksChanged,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              title: const Text('附件', style: TextStyle(fontSize: 14)),
              subtitle:
                  const Text('聊天中的文件附件', style: TextStyle(fontSize: 12)),
              value: attachments,
              onChanged: onAttachmentsChanged,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
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
