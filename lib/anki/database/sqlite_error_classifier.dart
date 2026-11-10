import 'package:sqflite/sqflite.dart';

/// Whether a SQLite failure points to local database file access/storage.
///
/// SQLite extended result codes retain their primary code in the low byte.
/// Corruption (`SQLITE_CORRUPT`) and invalid format (`SQLITE_NOTADB`) are
/// intentionally not classified as file access failures.
bool isSqliteLocalFileFailure(DatabaseException error) {
  final resultCode = error.getResultCode();
  if (resultCode == null) return false;
  return const {3, 8, 10, 13, 14}.contains(resultCode & 0xff);
}

/// Whether SQLite explicitly reported a damaged or non-SQLite database.
bool isSqliteCorruption(DatabaseException error) {
  final resultCode = error.getResultCode();
  if (resultCode != null && const {11, 26}.contains(resultCode & 0xff)) {
    return true;
  }
  final message = error.toString().toLowerCase();
  return message.contains('database disk image is malformed') ||
      message.contains('file is not a database');
}
