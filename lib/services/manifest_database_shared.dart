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
  static const String folders = 'folders';
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
      ManifestTables.folders: <String>[],
    };
