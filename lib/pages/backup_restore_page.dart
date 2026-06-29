import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/backup_service.dart';
import '../services/data_migration_service.dart';

class BackupRestorePage extends ConsumerStatefulWidget {
  const BackupRestorePage({super.key});

  @override
  ConsumerState<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends ConsumerState<BackupRestorePage> {
  bool _isExporting = false;
  bool _isImporting = false;
  String? _externalBackupPath;

  @override
  void initState() {
    super.initState();
    _loadExternalBackupPath();
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
    setState(() => _isExporting = true);
    try {
      await BackupService.exportBackup(context);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _onImport() async {
    bool backupFirst = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('确认恢复'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('恢复将覆盖所有现有数据。'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: backupFirst,
                    onChanged: (v) =>
                        setDialogState(() => backupFirst = v ?? true),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setDialogState(() => backupFirst = !backupFirst),
                      child: const Text('先备份当前数据（推荐）'),
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
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isImporting = true);
    try {
      if (backupFirst) {
        final backupPath = await BackupService.exportBackupAuto();
        if (backupPath != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已备份当前数据到: $backupPath')),
          );
        }
      }
      await BackupService.importBackup(context);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
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
                children: [
                  const Text('从 .zip 备份文件恢复所有数据'),
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
