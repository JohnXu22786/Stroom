import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      final path = await DataMigrationService.getExternalBackupRootPath();
      if (mounted) {
        setState(() => _externalBackupPath = path);
      }
    } catch (_) {}
  }

  Future<void> _onExport() async {
    if (_isExporting) return; // 防止重复点击
    setState(() => _isExporting = true);
    try {
      // 显示不可关闭的进度弹窗（showDialog 在 finally 中通过 Navigator.pop 关闭）
      final progressNotifier = ValueNotifier<String>('正在准备数据...');
      final progressValue =
          ValueNotifier<double?>(null); // null = indeterminate

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
      );
    } finally {
      // 关闭进度弹窗
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _onImport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('恢复将覆盖所有现有数据。'),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '导入完成后应用将自动重启，请确保已保存当前工作。',
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

    setState(() => _isImporting = true);
    try {
      final success = await BackupService.importBackup(context);
      if (success && mounted) {
        // 显示倒计时重启弹窗
        await _showRestartCountdown();
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _showRestartCountdown() async {
    if (!mounted) return;

    final countdown = ValueNotifier<int>(5);

    // 启动倒计时（与对话框同时运行）
    _restartTimer?.cancel();
    _restartTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countdown.value--;
      if (countdown.value <= 0) {
        timer.cancel();
        _restartTimer = null;
        // 关闭对话框
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        restartApp();
      }
    });

    // 显示对话框（阻塞直到用户关闭或倒计时结束）
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

    // 对话框关闭后取消计时器（如尚未触发重启）
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
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '导出将打包所有数据（照片、音频、视频、对话、配置等）为一个 .zip 文件。导入将覆盖当前所有数据。',
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
                    '应用在数据格式升级或版本迁移时，会自动将当前数据备份到以下外部位置（不在应用数据目录内，防止应用删除时备份丢失）：',
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
                    '如果数据丢失，可以在此路径下找到自动备份的文件夹（格式：backup_YYYY-MM-DDTHH-MM-SS），'
                    '其中包含 preferences.json（配置数据）。超过2天的自动备份会被自动清理。',
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
          _buildSectionHeader('导出备份'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('将所有数据打包为 .zip 文件'),
                  const SizedBox(height: 16),
                  SizedBox(
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('导入恢复'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text('从 .zip 备份文件恢复所有数据，将覆盖当前所有数据'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '将覆盖现有数据',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
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
                      label: Text(_isImporting ? '正在恢复...' : '选择备份文件并恢复'),
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
