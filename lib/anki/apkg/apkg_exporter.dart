import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import 'apkg_result.dart';

/// Exports Stroom's Anki collection to the .apkg format.
///
/// .apkg is a ZIP archive containing:
/// - `collection.anki2`  — SQLite database (same schema as Anki)
/// - `media`             — JSON file mapping filenames to sha1 hashes
///
/// Media files are not yet supported; they are exported with an empty `media` JSON.
class AnkiApkgExporter {
  /// Export the Anki database at [dbPath] to an .apkg file.
  ///
  /// Returns the path of the created .apkg file.
  static Future<String> export({
    String? dbPath,
    @visibleForTesting Future<void> Function(File, List<int>)? writeBytes,
    @visibleForTesting DateTime Function()? clock,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final src = dbPath ?? p.join(docsDir.path, 'collection.anki2');

    bool sourceExists;
    try {
      sourceExists = File(src).existsSync();
    } catch (_) {
      throw AnkiApkgException.unexpectedError(src);
    }
    if (!sourceExists) {
      throw AnkiApkgException.targetDatabaseMissing(src);
    }

    // Build the ZIP archive
    final archive = Archive();

    // 1. Add collection.anki2
    late final List<int> dbBytes;
    try {
      dbBytes = File(src).readAsBytesSync();
    } catch (_) {
      throw AnkiApkgException.unexpectedError(src);
    }
    archive.addFile(ArchiveFile('collection.anki2', dbBytes.length, dbBytes));

    // 2. Add media map (empty for now — no media support)
    final mediaJson = jsonEncode(<String, String>{});
    final mediaBytes = utf8.encode(mediaJson);
    archive.addFile(ArchiveFile('media', mediaBytes.length, mediaBytes));

    // 3. Compress as ZIP
    List<int>? encoded;
    try {
      encoded = ZipEncoder().encode(archive);
    } catch (_) {
      throw AnkiApkgException.unexpectedError(src);
    }
    if (encoded == null) throw AnkiApkgException.exportFailed(src);

    // Write to downloads directory
    final dlDir = await getApplicationDocumentsDirectory();
    final timestamp = (clock ?? DateTime.now)().toIso8601String().replaceAll(
          RegExp(r'[:.]'),
          '-',
        );
    final fileStem = p.join(dlDir.path, 'stroom_anki_$timestamp');
    String? outPath;
    File? reservationFile;
    Directory? tempDir;
    try {
      // A sidecar reservation coordinates exporters without exposing an
      // incomplete .apkg at its final path. Rename publishes the staged file.
      for (var suffix = 0; outPath == null; suffix++) {
        final candidatePath = '$fileStem${suffix == 0 ? '' : '_$suffix'}.apkg';
        final candidateReservation = File('$candidatePath.reserve');
        try {
          await candidateReservation.create(exclusive: true);
        } on FileSystemException catch (error) {
          final errorCode = error.osError?.errorCode;
          final alreadyExists =
              errorCode == 17 || errorCode == 80 || errorCode == 183;
          if (!alreadyExists && !await candidateReservation.exists()) rethrow;
          continue;
        }

        if (await File(candidatePath).exists()) {
          await candidateReservation.delete();
          continue;
        }
        outPath = candidatePath;
        reservationFile = candidateReservation;
      }

      tempDir = await Directory(dlDir.path).createTemp('.stroom_anki_export_');
      final tempFile = File(p.join(tempDir.path, 'export.apkg.part'));
      await (writeBytes ?? (file, bytes) => file.writeAsBytes(bytes))(
        tempFile,
        encoded,
      );
      await tempFile.rename(outPath);
    } catch (_) {
      throw AnkiApkgException.unexpectedError(outPath ?? fileStem);
    } finally {
      if (reservationFile != null) {
        try {
          await reservationFile.delete();
        } catch (_) {
          // Preserve the export result if reservation cleanup fails.
        }
      }
      if (tempDir != null) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {
          // Preserve the export result if staging cleanup fails.
        }
      }
    }

    return outPath;
  }
}
