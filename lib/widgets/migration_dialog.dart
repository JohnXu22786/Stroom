import 'package:flutter/material.dart';

import '../services/data_migration_service.dart';

/// A non-dismissable dialog shown during data format migration.
///
/// # Behavior
/// - While the migration [future] is running, shows a spinner with the message
///   "正在数据迁移到新版本".
/// - When the future completes successfully: replaces the spinner with a
///   "数据迁移完成，即将重启应用..." message, then auto-closes the dialog
///   after a brief delay and returns `true` to signal the caller to exit
///   the app (ensuring all providers re-initialize with the new format).
/// - If the future fails: shows the error message; the user must manually close.
///
/// The dialog cannot be dismissed by tapping the barrier or pressing back.
class MigrationDialog extends StatefulWidget {
  /// The future that performs the migration.
  final Future<MigrationResult> future;

  const MigrationDialog({super.key, required this.future});

  @override
  State<MigrationDialog> createState() => _MigrationDialogState();
}

class _MigrationDialogState extends State<MigrationDialog> {
  String? _error;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _startMigration();
  }

  Future<void> _startMigration() async {
    try {
      await widget.future;
      if (!mounted) return;

      setState(() {
        _completed = true;
      });

      // 迁移完成后自动关闭对话框并返回 true（退出信号），
      // 确保应用重启后所有 provider 以新数据格式重新初始化
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _completed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 迁移完成后的气泡标题
    return PopScope(
      canPop: false, // 不可通过返回键关闭
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              _completed && _error == null
                  ? Icons.check_circle
                  : _error != null
                      ? Icons.error_outline
                      : Icons.storage,
              color: _completed && _error == null
                  ? Colors.green
                  : _error != null
                      ? Colors.red
                      : Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('数据迁移'),
          ],
        ),
        content: _buildContent(),
        actions: _buildActions(),
      ),
    );
  }

  Widget _buildContent() {
    // 迁移进行中
    if (!_completed) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 16),
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            '正在数据迁移到新版本',
            style: TextStyle(fontSize: 15),
          ),
          SizedBox(height: 8),
          Text(
            '请稍候，正在处理数据格式兼容性...',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      );
    }

    // 迁移出错
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          const Text(
            '数据迁移失败',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // 迁移完成 - 总是提示重启
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 12),
        Icon(Icons.check_circle, color: Colors.green, size: 48),
        SizedBox(height: 12),
        Text(
          '数据迁移完成',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          '即将重启应用...',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  List<Widget> _buildActions() {
    // 迁移进行中 → 无操作按钮
    if (!_completed) {
      return [];
    }

    // 迁移出错 → 关闭按钮
    if (_error != null) {
      return [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('关闭'),
        ),
      ];
    }

    // 迁移成功 → 无按钮（自动关闭后返回 true 触发退出）
    return [];
  }
}
