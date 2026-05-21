import 'package:flutter/material.dart';

enum CameraChoice { app, system }

Future<CameraChoice?> showCameraChoiceDialog(BuildContext context) {
  return showModalBottomSheet<CameraChoice>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _CameraChoiceSheet(),
  );
}

class _CameraChoiceSheet extends StatelessWidget {
  const _CameraChoiceSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
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
            '选择拍照方式',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.camera_alt,
                  title: '应用相机',
                  subtitle: '使用应用内置相机，支持调整比例和压缩设置',
                  choice: CameraChoice.app,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ChoiceCard(
                  icon: Icons.phone_android,
                  title: '系统相机',
                  subtitle: '使用系统默认相机应用',
                  choice: CameraChoice.system,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final CameraChoice choice;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.choice,
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
        onTap: () => Navigator.of(context).pop(choice),
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
