import 'dart:typed_data';

import 'file_manifest.dart';

typedef TtsAudioFileWriter = Future<void> Function(
  String fileName,
  Uint8List bytes,
);
typedef TtsAudioRecordWriter = Future<void> Function(AudioRecord record);
typedef TtsAudioRecordLoader = Future<List<AudioRecord>> Function();
typedef TtsAudioFileDeleter = Future<void> Function(String fileName);
typedef TtsAudioFileReader = Future<Uint8List?> Function(String fileName);
typedef TtsAudioFileExistenceChecker = Future<bool> Function(String fileName);

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
  TtsAudioFileReader? readFile,
  TtsAudioFileExistenceChecker? fileExists,
}) async {
  final write = writeFile ?? FileManifest.writeFile;
  final publish = addRecord ?? FileManifest.addRecord;
  final load = loadRecords ?? FileManifest.loadRecordsStrict;
  final delete = deleteFile ?? FileManifest.deleteFile;
  final read = readFile ?? FileManifest.readFile;
  final exists = fileExists ?? FileManifest.fileExists;
  final previousTextExists =
      textData != null && await exists(record.textStoragePath);
  final previousText =
      previousTextExists ? await read(record.textStoragePath) : null;
  if (previousTextExists && previousText == null) {
    throw StateError('Could not read existing TTS text sidecar');
  }
  final writtenNames = <String>[];
  var textWriteCompleted = false;

  try {
    writtenNames.add(record.storageFileName);
    await write(record.storageFileName, audioData);
    if (textData != null) {
      writtenNames.add(record.textStoragePath);
      await write(record.textStoragePath, textData);
      textWriteCompleted = true;
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
      if (textData != null && previousTextExists) {
        try {
          await write(record.textStoragePath, previousText!);
        } catch (_) {
          // Keep the original write/publication failure as the reported error.
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    for (final name in writtenNames) {
      final isReferenced = records.any(
        (candidate) =>
            name == candidate.storageFileName ||
            (name == record.textStoragePath && candidate.hash == record.hash),
      );
      if (name == record.textStoragePath && isReferenced) {
        try {
          if (previousTextExists) {
            await write(name, previousText!);
          } else if (!textWriteCompleted) {
            await delete(name);
          }
        } catch (_) {
          // Keep the original write/publication failure as the reported error.
        }
      } else if (!isReferenced) {
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
