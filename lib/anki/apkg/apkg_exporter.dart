import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

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

    if (!File(src).existsSync()) {
      throw Exception('找不到 Anki 数据库: $src');
    }

    // Build the ZIP archive
    final archive = Archive();

    // 1. Add collection.anki2
    final dbBytes = File(src).readAsBytesSync();
    archive.addFile(ArchiveFile('collection.anki2', dbBytes.length, dbBytes));

    // 2. Add media map (empty for now — no media support)
    final mediaJson = jsonEncode(<String, String>{});
    final mediaBytes = utf8.encode(mediaJson);
    archive.addFile(ArchiveFile('media', mediaBytes.length, mediaBytes));

    // 3. Compress as ZIP
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw Exception('打包失败');

    // Write to downloads directory
    final dlDir = await getApplicationDocumentsDirectory();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final outPath = p.join(dlDir.path, 'stroom_anki_$timestamp.apkg');
    await File(outPath).writeAsBytes(encoded);

    return outPath;
  }
}
