import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

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
  static Future<String> export({String? dbPath}) async {
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
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final outPath = p.join(dlDir.path, 'stroom_anki_$timestamp.apkg');
    try {
      await File(outPath).writeAsBytes(encoded);
    } catch (_) {
      throw AnkiApkgException.unexpectedError(outPath);
    }

    return outPath;
  }
}
