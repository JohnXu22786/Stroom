import 'package:flutter/material.dart';
import '../utils/app_version.dart';

/// 版本信息面板：点击设置页「关于」区域版本卡片上的图标后弹出。
///
/// 展示 CD 构建时写入的信息：
/// - 版本号（[appVersion]，即 release 版本号）
/// - 发布时间（[appReleaseTimeFormatted]，CD 构建日期时间，UTC）
/// - 更新内容（[appReleaseNotes]，该 release 的 Release 说明）
///
/// 各字段可通过构造函数注入（测试用），默认读取构建时写入的常量。
class VersionInfoDialog extends StatelessWidget {
  const VersionInfoDialog({
    super.key,
    this.version,
    this.releaseTime,
    this.releaseNotes,
  });

  final String? version;
  final String? releaseTime;
  final String? releaseNotes;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final notes = releaseNotes ?? appReleaseNotes;
    final time = releaseTime ?? appReleaseTimeFormatted;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: cs.primary),
          const SizedBox(width: 8),
          const Text('版本信息'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow(cs, '版本号', version ?? appVersion),
            const SizedBox(height: 12),
            _buildInfoRow(
              cs,
              '发布时间',
              // CD 构建写入的时间一律是 UTC（ISO 8601 `Z`），展示时标注
              // UTC，避免用户误以为是本地时间；本地构建无时间，显示回退文案。
              time.isEmpty ? '本地构建' : '$time UTC',
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('更新内容', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(notes),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(ColorScheme cs, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }
}
