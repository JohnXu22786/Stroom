import 'dart:convert';
import 'dart:typed_data';

String utf8Decode(Uint8List data) => utf8.decode(data);
Uint8List utf8Encode(String text) => Uint8List.fromList(utf8.encode(text));

/// Database table name constants.
class ManifestTables {
  static const String imageRecords = 'image_records';
  static const String audioRecords = 'audio_records';
  static const String videoRecords = 'video_records';
  static const String textRecords = 'text_records';

  // ⛔ Legacy shared folders table no longer used since v2 format migration.
  // The constant is kept for migration detection purposes only.
  @Deprecated('Legacy shared folders table — not used in v2+ format. '
      'Kept for migration detection.')
  static const String folders = 'folders';

  // Per-type folder tables (replaces the shared [folders] table)
  static const String textFolders = 'text_folders';
  static const String audioFolders = 'audio_folders';
  static const String imageFolders = 'image_folders';
  static const String videoFolders = 'video_folders';

  /// All per-type folder table names.
  static const List<String> allPerTypeFolderTables = [
    textFolders,
    audioFolders,
    imageFolders,
    videoFolders,
  ];

  /// Derive the folder table name from a record table name.
  static String folderTableFor(String recordTable) {
    switch (recordTable) {
      case ManifestTables.textRecords:
        return ManifestTables.textFolders;
      case ManifestTables.audioRecords:
        return ManifestTables.audioFolders;
      case ManifestTables.imageRecords:
        return ManifestTables.imageFolders;
      case ManifestTables.videoRecords:
        return ManifestTables.videoFolders;
      default:
        throw ArgumentError('Unknown record table: $recordTable');
    }
  }
}

/// Dart camelCase -> DB snake_case column name mapping.
const Map<String, String> camelToSnake = {
  'createdAt': 'created_at',
  'sourceText': 'source_text',
  'textLength': 'text_length',
};

/// DB snake_case -> Dart camelCase column name mapping.
const Map<String, String> snakeToCamel = {
  'created_at': 'createdAt',
  'source_text': 'sourceText',
  'text_length': 'textLength',
};

/// Convert a record Map (camelCase keys) to DB row format (snake_case).
Map<String, dynamic> recordToDbRow(Map<String, dynamic> record) {
  final row = <String, dynamic>{};
  for (final entry in record.entries) {
    final dbKey = camelToSnake[entry.key] ?? entry.key;
    var value = entry.value;
    if (dbKey == 'created_at' && value is String) {
      value = DateTime.parse(value).millisecondsSinceEpoch;
    }
    row[dbKey] = value;
  }
  return row;
}

/// Convert a DB row (snake_case) to record Map (camelCase).
Map<String, dynamic> dbRowToRecord(Map<String, dynamic> row) {
  final record = <String, dynamic>{};
  for (final entry in row.entries) {
    final recordKey = snakeToCamel[entry.key] ?? entry.key;
    var value = entry.value;
    if (entry.key == 'created_at' && value is int) {
      value = DateTime.fromMillisecondsSinceEpoch(value).toIso8601String();
    }
    record[recordKey] = value;
  }
  return record;
}

/// Create an empty web data structure.
Map<String, dynamic> emptyWebData() => {
      ManifestTables.imageRecords: <Map<String, dynamic>>[],
      ManifestTables.audioRecords: <Map<String, dynamic>>[],
      ManifestTables.videoRecords: <Map<String, dynamic>>[],
      ManifestTables.textRecords: <Map<String, dynamic>>[],
      ManifestTables.textFolders: <String>[],
      ManifestTables.audioFolders: <String>[],
      ManifestTables.imageFolders: <String>[],
      ManifestTables.videoFolders: <String>[],
    };
