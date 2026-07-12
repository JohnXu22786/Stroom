import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

import '../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../providers/task_provider.dart';
import '../../providers/background_task_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/text_manifest.dart';
import '../audio_player_page.dart';
import '../text_preview_edit_page.dart';
import '../video_gallery_shared.dart';

// =============================================================================
// 工具函数
// =============================================================================

String formatSize(int? bytes) {
  if (bytes == null) return '未知大小';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// File extension sets used for classifying files.
final Set<String> _textExtensions = {
  'txt', 'md', 'json', 'xml', 'csv', 'log', 'yaml', 'yml', 'ini', 'cfg',
  'bat', 'sh', 'ps1', 'py', 'js', 'ts', 'jsx', 'tsx', 'html', 'htm', 'css',
  'scss', 'sass', 'less', 'dart', 'java', 'cpp', 'h', 'hpp', 'c', 'sql',
  'rb', 'php', 'pl', 'rs', 'go', 'swift', 'kt', 'toml',
  'lock', 'env', 'gitignore', 'makefile', 'cmake', 'dockerfile',
  'conf', 'properties', 'm', 'mm', 'r', 'scala', 'clj',
  'lua', 'hs', 'erl', 'ex', 'exs', 'vue', 'svelte', 'astro',
  'terraform', 'tf', 'hcl',
};

final Set<String> _videoExtensions = {
  'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v',
  '3gp', '3gpp', 'ogv', 'ts', 'mts', 'm2ts', 'vob', 'divx',
};

final Set<String> _audioExtensions = {
  'mp3', 'wav', 'm4a', 'aac', 'opus', 'ogg', 'flac', 'wma',
  'aiff', 'aif', 'pcm', 'wv', 'caf', 'ra', 'mid', 'midi',
};

/// Open a file with the appropriate built-in viewer based on file extension.
///
/// - Text files → [TextPreviewEditPage]
/// - Video files → [VideoPlayerPage]
/// - Audio files → [AudioPlayerPage]
/// - Other files → OS default application
void openFile(String filePath, BuildContext context) {
  try {
    final file = File(filePath);
    if (!file.existsSync()) {
      debugPrint('File not found: $filePath');
      return;
    }

    final ext = p.extension(filePath).replaceAll('.', '').toLowerCase();

    if (_textExtensions.contains(ext)) {
      _openTextFile(filePath, context);
    } else if (_videoExtensions.contains(ext)) {
      _openVideoFile(filePath, context);
    } else if (_audioExtensions.contains(ext)) {
      _openAudioFile(filePath, context);
    } else {
      _openWithOsDefault(filePath);
    }
  } catch (e) {
    debugPrint('Failed to open file: $e');
  }
}

void _openTextFile(String filePath, BuildContext context) {
  try {
    final file = File(filePath);
    final bytes = file.readAsBytesSync();
    final content = utf8.decode(bytes);
    final name = p.basenameWithoutExtension(filePath);
    final hash = _computeSimpleHash(bytes);
    final record = TextRecord(
      name: name,
      hash: hash,
      format: p.extension(filePath).replaceAll('.', ''),
      createdAt: file.statSync().changed,
      size: bytes.length,
      textLength: content.length,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TextPreviewEditPage(
          file: record,
          initialContent: content,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Failed to open text file: $e');
    _openWithOsDefault(filePath);
  }
}

void _openVideoFile(String filePath, BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => VideoPlayerPage(
        filePath: filePath,
        displayName: p.basename(filePath),
      ),
    ),
  );
}

void _openAudioFile(String filePath, BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AudioPlayerPage(
        filePath: filePath,
        displayName: p.basenameWithoutExtension(filePath),
      ),
    ),
  );
}

void _openWithOsDefault(String filePath) {
  try {
    if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', '', '"$filePath"'], runInShell: true);
    } else if (Platform.isMacOS) {
      Process.start('open', [filePath], mode: ProcessStartMode.detached);
    } else {
      Process.start('xdg-open', [filePath], mode: ProcessStartMode.detached);
    }
  } catch (e) {
    debugPrint('Failed to open file with OS default: $e');
  }
}

String _computeSimpleHash(Uint8List bytes) {
  // Use MD5 hash for TextRecord — consistent with text_manifest.dart
  return computeTextHash(bytes);
}

String truncateUrl(String url, {int maxLen = 40}) {
  if (url.length <= maxLen) return url;
  return '${url.substring(0, maxLen ~/ 2)}...${url.substring(url.length - maxLen ~/ 2)}';
}

String formatDurationSimple(String duration) {
  final sec = parseDurationToSeconds(duration);
  if (sec == null) return duration;
  if (sec < 60) return '${sec.round()}秒';
  if (sec < 3600) return '${(sec ~/ 60)}分${(sec % 60).round()}秒';
  return '${(sec ~/ 3600)}时${((sec % 3600) ~/ 60)}分';
}

double? parseDurationToSeconds(String duration) {
  final parts = duration.split(':');
  if (parts.length == 3) {
    final h = double.tryParse(parts[0]) ?? 0;
    final m = double.tryParse(parts[1]) ?? 0;
    final s = double.tryParse(parts[2]) ?? 0;
    return h * 3600 + m * 60 + s;
  }
  if (parts.length == 2) {
    final m = double.tryParse(parts[0]) ?? 0;
    final s = double.tryParse(parts[1]) ?? 0;
    return m * 60 + s;
  }
  return double.tryParse(duration);
}

String formatRelativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// =============================================================================
// 步骤图标
// =============================================================================

Widget stepIcon(catcatch.StepStatus step) {
  if (step.skipped) {
    return const Icon(Icons.skip_next, color: Colors.orange, size: 20);
  }
  if (step.completed) {
    return const Icon(Icons.check_circle, color: Colors.green, size: 20);
  }
  if (step.running) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
  if (step.failed) {
    return const Icon(Icons.cancel, color: Colors.red, size: 20);
  }
  return Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 20);
}

// =============================================================================
// UnifiedTaskItem 数据模型
// =============================================================================

class UnifiedTaskItem {
  final String id;
  final DateTime createdAt;
  final bool isCatCatch;
  final bool isBackground;
  final catcatch.CatCatchTask? catCatchTask;
  final SynthesisTask? synthesisTask;
  final BackgroundTask? backgroundTask;

  const UnifiedTaskItem({
    required this.id,
    required this.createdAt,
    required this.isCatCatch,
    this.isBackground = false,
    this.catCatchTask,
    this.synthesisTask,
    this.backgroundTask,
  });
}

// =============================================================================
// 任务列表最后读取时间
// =============================================================================

final taskListLastReadProvider =
    StateProvider<DateTime>((ref) => DateTime(2000));

Future<void> persistTaskListLastRead(DateTime dt) async {
  try {
    final dirPath = await AppStorage.directory;
    final file = File(p.join(dirPath, 'task_list_last_read.json'));
    await file.writeAsString(jsonEncode({'lastRead': dt.toIso8601String()}));
  } catch (e) {
    debugPrint('Failed to persist lastRead: $e');
  }
}

Future<DateTime> loadTaskListLastRead() async {
  try {
    final dirPath = await AppStorage.directory;
    final file = File(p.join(dirPath, 'task_list_last_read.json'));
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        final data = jsonDecode(content) as Map;
        if (data['lastRead'] != null) {
          return DateTime.parse(data['lastRead'] as String);
        }
      }
    }
  } catch (e) {
    debugPrint('Failed to load lastRead: $e');
  }
  return DateTime(2000);
}
