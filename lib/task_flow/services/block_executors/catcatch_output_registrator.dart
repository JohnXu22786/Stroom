import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path/path.dart' as p;

import '../../../catcatch/models/catcatch_task.dart' as catcatch;
import '../../../utils/file_manifest.dart';
import '../../../utils/video_manifest.dart';

const _videoExts = {
  'mp4',
  'webm',
  'ogg',
  'mov',
  'mkv',
  'ogv',
  'avi',
  'flv',
  'wmv'
};

const _audioExts = {'mp3', 'wav', 'm4a', 'aac', 'wma', 'opus', 'flac', 'ogg'};

/// Reads the file and computes its MD5 off the UI isolate — hashing a
/// multi-GB video on the main isolate would freeze the GUI.
Future<(Uint8List, String)> _readAndHashInIsolate(String filePath) {
  return Isolate.run(() {
    final bytes = File(filePath).readAsBytesSync();
    return (bytes, md5.convert(bytes).toString());
  });
}

Future<void> registerFlowCatCatchOutput(
  String filePath,
  catcatch.CatCatchTask task,
) async {
  final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
  final file = File(filePath);
  if (!await file.exists()) {
    debugPrint('[TaskFlow] registerFlowCatCatchOutput: file not found');
    return;
  }

  final (fileBytes, contentHash) = await _readAndHashInIsolate(filePath);

  if (_videoExts.contains(ext)) {
    try {
      final videoFolder = task.metadata['videoFolder'] ?? '';
      final records = await VideoManifest.loadRecords();
      final basename = p.basenameWithoutExtension(filePath);
      String name = basename;
      int idx = 2;
      while (records.any((r) => r.name == name && r.folder == videoFolder) &&
          idx <= 10000) {
        name = '$basename ($idx)';
        idx++;
      }
      if (idx > 10000) {
        name = '$basename _${DateTime.now().millisecondsSinceEpoch}';
      }
      final record = VideoRecord(
        name: name,
        hash: contentHash,
        format: ext,
        createdAt: DateTime.now(),
        size: fileBytes.length,
        duration: task.expectedDurationSec * 1000,
        folder: videoFolder,
      );
      final existingVideo = await VideoManifest.getRecordByHash(contentHash);
      if (existingVideo == null) {
        await VideoManifest.writeFile('$contentHash.$ext', fileBytes);
        await VideoManifest.addRecord(record);
        debugPrint(
          '[TaskFlow] Registered video: $name.$ext (folder: $videoFolder)',
        );
      } else {
        debugPrint(
          '[TaskFlow] Video hash $contentHash already registered, skipping',
        );
      }
    } catch (e) {
      debugPrint('[TaskFlow] Register video failed: $e');
    }
  }

  if (_audioExts.contains(ext)) {
    try {
      final audioFolder = task.metadata['audioFolder'] ?? '';
      final records = await FileManifest.loadRecords();
      final basename = p.basenameWithoutExtension(filePath);
      String name = basename;
      int idx = 2;
      while (records.any((r) => r.name == name && r.folder == audioFolder) &&
          idx <= 10000) {
        name = '$basename ($idx)';
        idx++;
      }
      if (idx > 10000) {
        name = '$basename _${DateTime.now().millisecondsSinceEpoch}';
      }
      final record = AudioRecord(
        name: name,
        hash: contentHash,
        format: ext,
        createdAt: DateTime.now(),
        size: fileBytes.length,
        duration: task.expectedDurationSec,
        folder: audioFolder,
      );
      final existingAudio = await FileManifest.getRecordByHash(contentHash);
      if (existingAudio == null) {
        await FileManifest.writeFile('$contentHash.$ext', fileBytes);
        await FileManifest.addRecord(record);
        debugPrint(
          '[TaskFlow] Registered audio: $name.$ext (folder: $audioFolder)',
        );
      } else {
        debugPrint(
          '[TaskFlow] Audio hash $contentHash already registered, skipping',
        );
      }
    } catch (e) {
      debugPrint('[TaskFlow] Register audio failed: $e');
    }
  }
}
