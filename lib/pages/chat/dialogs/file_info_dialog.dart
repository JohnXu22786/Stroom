import 'package:flutter/material.dart';
import 'package:stroom/models/chat_message.dart';
import 'package:stroom/pages/chat/widgets/info_row.dart';
import 'package:stroom/utils/format_file_size.dart';

/// Full-screen preview for non-image files (documents, audio, video).
void showFileInfoPreviewDialog({
  required BuildContext context,
  required Attachment attachment,
}) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  IconData fileIcon;
  switch (attachment.fileType) {
    case 'audio':
      fileIcon = Icons.audiotrack_outlined;
      break;
    case 'video':
      fileIcon = Icons.videocam_outlined;
      break;
    default:
      fileIcon = Icons.insert_drive_file_outlined;
  }

  String typeLabel;
  switch (attachment.fileType) {
    case 'audio':
      typeLabel = '音频文件';
      break;
    case 'video':
      typeLabel = '视频文件';
      break;
    case 'document':
      typeLabel = '文档';
      break;
    default:
      typeLabel = '文件';
  }

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large file icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(fileIcon, size: 48, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            // File name
            Text(
              attachment.fileName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            // File info rows
            InfoRow(label: '类型', value: '$typeLabel (${attachment.mimeType})'),
            const SizedBox(height: 6),
            InfoRow(label: '大小', value: formatFileSize(attachment.fileSize)),
            const SizedBox(height: 6),
            InfoRow(label: '路径', value: attachment.storagePath),
            const SizedBox(height: 24),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('关闭'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
