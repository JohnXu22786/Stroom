import 'package:flutter/material.dart';

enum GalleryChoice { system, app }

/// 相册选择对话框的返回结果
class GalleryChoiceResult {
  final GalleryChoice choice;

  const GalleryChoiceResult({required this.choice});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GalleryChoiceResult && choice == other.choice;

  @override
  int get hashCode => choice.hashCode;
}

/// 显示相册来源选择弹窗，UI 设计与拍照选择面板一致
Future<GalleryChoiceResult?> showGalleryChoiceDialog(
  BuildContext context,
) {
  return showModalBottomSheet<GalleryChoiceResult>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _GalleryChoiceSheet(),
  );
}

class _GalleryChoiceSheet extends StatelessWidget {
  const _GalleryChoiceSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '选择图片来源',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ChoiceCard(
                    icon: Icons.photo_album_outlined,
                    title: '系统相册',
                    subtitle: '从系统相册选择图片',
                    onTap: () => Navigator.of(context).pop(
                      const GalleryChoiceResult(choice: GalleryChoice.system),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ChoiceCard(
                    icon: Icons.folder_outlined,
                    title: '应用相册',
                    subtitle: '从应用内部相册选择',
                    onTap: () => Navigator.of(context).pop(
                      const GalleryChoiceResult(choice: GalleryChoice.app),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: cs.shadow,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cs.onPrimaryContainer),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
