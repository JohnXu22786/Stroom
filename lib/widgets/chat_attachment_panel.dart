import 'package:flutter/material.dart';

/// Shows the File Attachment Panel — a modal bottom sheet with file transfer
/// options only. No model selection, tools, or reasoning settings.
///
/// [onPickFromCamera] — called when the camera option is tapped.
/// [onPickFromGallery] — called when the gallery option is tapped.
/// [onPickFromFilePicker] — called when the file picker option is tapped.
/// [onPickFromAppFiles] — called when the app internal file option is tapped.
void showChatAttachmentPanel({
  required BuildContext context,
  required VoidCallback onPickFromCamera,
  required VoidCallback onPickFromGallery,
  required VoidCallback onPickFromFilePicker,
  required VoidCallback onPickFromAppFiles,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ──
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[350],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── Title ──
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.attach_file_outlined,
                        size: 18, color: cs.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '传文件',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ══════════════════════════════════════════════════
              // File action buttons
              // ══════════════════════════════════════════════════
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _FileActionButton(
                    icon: Icons.camera_alt_outlined,
                    label: '拍照',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      onPickFromCamera();
                    },
                  ),
                  _FileActionButton(
                    icon: Icons.photo_library_outlined,
                    label: '相册',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      onPickFromGallery();
                    },
                  ),
                  _FileActionButton(
                    icon: Icons.insert_drive_file_outlined,
                    label: '文件',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      onPickFromFilePicker();
                    },
                  ),
                  _FileActionButton(
                    icon: Icons.folder_outlined,
                    label: '应用内文件',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      onPickFromAppFiles();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A large icon button for file actions (camera, gallery, file, app files).
class _FileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FileActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
