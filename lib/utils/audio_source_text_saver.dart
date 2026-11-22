import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

import 'file_manifest.dart';

Future<void> saveAudioSourceText(String audioFilePath, String text) async {
  final hash = path.basename(path.withoutExtension(audioFilePath));
  final textFileName = '$hash.txt';
  while (true) {
    final record = await FileManifest.getRecordByHash(hash);
    final saveLockName = record?.storageFileName ?? textFileName;
    final retry = await FileManifest.withStorageFileSaveLock(
      saveLockName,
      () async {
        final currentRecord = await FileManifest.getRecordByHash(hash);
        if (currentRecord != null &&
            currentRecord.storageFileName != saveLockName) {
          return true;
        }

        final previousFileExists = await FileManifest.fileExists(textFileName);
        final previousText = previousFileExists
            ? await FileManifest.readFile(textFileName)
            : null;
        if (previousFileExists && previousText == null) {
          throw StateError(
            'Could not read existing source text sidecar: $textFileName',
          );
        }
        await FileManifest.writeFile(
          textFileName,
          Uint8List.fromList(utf8.encode(text)),
        );

        try {
          if (currentRecord != null) {
            await FileManifest.updateRecord(
              currentRecord.copyWith(sourceText: text),
            );
          }
        } catch (_) {
          if (previousText == null) {
            final removed = await FileManifest.deleteFile(textFileName);
            if (!removed) {
              throw StateError(
                'Failed to remove sidecar after manifest update failure: $textFileName',
              );
            }
          } else {
            await FileManifest.writeFile(textFileName, previousText);
          }
          rethrow;
        }
        return false;
      },
    );
    if (!retry) return;
  }
}
