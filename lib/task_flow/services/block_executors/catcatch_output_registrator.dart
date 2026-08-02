import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

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

/// Computes the file's MD5 off the UI isolate — hashing a multi-GB video
/// on the main isolate would freeze the GUI. Streams in chunks so neither
/// the worker nor the main isolate ever holds the full file in memory.
Future<String> _computeHashInIsolate(String filePath) {
  return Isolate.run(() {
    final file = File(filePath);
    var digest = '';
    final chunked = md5.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback((chunks) {
        if (chunks.isNotEmpty) digest = chunks.last.toString();
      }),
    );
    final raf = file.openSync();
    try {
      const chunkSize = 8 * 1024 * 1024;
      while (true) {
        final chunk = raf.readSync(chunkSize);
        if (chunk.isEmpty) break;
        chunked.add(chunk);
      }
    } finally {
      raf.closeSync();
    }
    chunked.close();
    return digest;
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

  final contentHash = await _computeHashInIsolate(filePath);
  final size = await file.length();

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
        size: size,
        duration: task.expectedDurationSec * 1000,
        folder: videoFolder,
      );
      final existingVideo = await VideoManifest.getRecordByHash(contentHash);
      if (existingVideo == null) {
        final storageDir = await VideoManifest.videoDir;
        await file.copy(p.join(storageDir, '$contentHash.$ext'));
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
        size: size,
        duration: task.expectedDurationSec,
        folder: audioFolder,
      );
      final existingAudio = await FileManifest.getRecordByHash(contentHash);
      if (existingAudio == null) {
        final storageDir = await FileManifest.ttsAudioDir;
        await file.copy(p.join(storageDir, '$contentHash.$ext'));
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
