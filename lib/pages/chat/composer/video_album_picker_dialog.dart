import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:stroom/utils/video_manifest.dart';
import 'package:stroom/widgets/app_media_picker_dialog.dart';

/// Result from the video picker containing both the record and its data bytes.
class VideoPickerResult {
  final VideoRecord record;
  final Uint8List bytes;

  const VideoPickerResult({required this.record, required this.bytes});
}

/// Shows a dialog for selecting videos from the app's internal album.
///
/// Supports folder navigation. When [multiSelect] is true (default), allows
/// selecting multiple videos and returns a list of [VideoPickerResult].
/// When false, returns a list with at most one entry.
/// Returns null if the user cancels.
///
/// This is now a thin wrapper over the unified [showMediaPickerDialog].
Future<List<VideoPickerResult>?> showAppVideoPickerDialog(
  BuildContext context, {
  bool multiSelect = true,
}) async {
  final result = await showMediaPickerDialog<VideoRecord>(
    context,
    MediaPickerConfig<VideoRecord>(
      title: '选择应用内视频',
      emptyIcon: Icons.video_library_outlined,
      emptyText: '暂无视频',
      fileIcon: Icons.videocam,
      fileIconColor: Colors.indigo,
      multiSelect: multiSelect,
      loadRecords: () async {
        VideoManifest.invalidateCache();
        return VideoManifest.loadRecords();
      },
      loadFolders: () => VideoManifest.getAllFolders(),
      readFile: (record) => VideoManifest.readFile(record.storagePath),
      displayName: (record) => record.name,
      subtitleBuilder: (record) => Row(
        children: [
          Text(
            record.format.toUpperCase(),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(width: 6),
          Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.grey[400]!,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatSize(record.size),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (record.duration > 0) ...[
            const SizedBox(width: 6),
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey[400]!,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _formatDuration(record.duration),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    ),
  );

  if (result == null || result.isEmpty) return null;

  // Look up matching VideoRecords for all selected entries
  final records = await VideoManifest.loadRecords();
  final results = <VideoPickerResult>[];

  for (final entry in result) {
    VideoRecord? matchedRecord;
    for (final r in records) {
      if (r.name == entry.key || '${r.name}.${r.format}' == entry.key) {
        matchedRecord = r;
        break;
      }
    }

    results.add(
      VideoPickerResult(
        record: matchedRecord ??
            VideoRecord(
              name: entry.key,
              hash: '',
              format: 'mp4',
              createdAt: DateTime.now(),
              size: entry.value.length,
            ),
        bytes: entry.value,
      ),
    );
  }

  return results;
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _formatDuration(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  if (seconds < 60) return '$seconds秒';
  if (seconds < 3600) return '${seconds ~/ 60}分${seconds % 60}秒';
  return '${seconds ~/ 3600}时${(seconds % 3600) ~/ 60}分';
}
