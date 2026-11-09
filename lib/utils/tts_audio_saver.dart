import 'dart:typed_data';

import 'file_manifest.dart';

typedef TtsAudioFileWriter = Future<void> Function(
  String fileName,
  Uint8List bytes,
);
typedef TtsAudioRecordWriter = Future<void> Function(AudioRecord record);
typedef TtsAudioRecordLoader = Future<List<AudioRecord>> Function();
typedef TtsAudioFileDeleter = Future<void> Function(String fileName);

/// Writes TTS content before publishing its record, removing any newly
/// unreferenced destinations if publication fails.
Future<AudioRecord> writeTtsAudioAndPublish(
  AudioRecord record,
  Uint8List audioData,
  Uint8List? textData, {
  TtsAudioFileWriter? writeFile,
  TtsAudioRecordWriter? addRecord,
  TtsAudioRecordLoader? loadRecords,
  TtsAudioFileDeleter? deleteFile,
}) async {
  final write = writeFile ?? FileManifest.writeFile;
  final publish = addRecord ?? FileManifest.addRecord;
  final load = loadRecords ?? FileManifest.loadRecordsStrict;
  final delete = deleteFile ?? FileManifest.deleteFile;
  final writtenNames = <String>[];

  try {
    writtenNames.add(record.storageFileName);
    await write(record.storageFileName, audioData);
    if (textData != null) {
      writtenNames.add(record.textStoragePath);
      await write(record.textStoragePath, textData);
    }
    await publish(record);
    return record;
  } catch (error, stackTrace) {
    // A failed authoritative read cannot prove that a destination is unused.
    // Preserve it in that case rather than deleting bytes another record may
    // still reference.
    late final List<AudioRecord> records;
    try {
      records = await load();
    } catch (_) {
      Error.throwWithStackTrace(error, stackTrace);
    }

    for (final name in writtenNames) {
      final isReferenced = records.any(
        (candidate) =>
            name == candidate.storageFileName ||
            (name == record.textStoragePath && candidate.hash == record.hash),
      );
      if (!isReferenced) {
        try {
          await delete(name);
        } catch (_) {
          // Keep the original write/publication failure as the reported error.
        }
      }
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}
