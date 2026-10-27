import 'package:sqflite/sqflite.dart';

import '../database/anki_schema.dart';

/// Stores the sync destination associated with the active local collection.
/// Anki's USNs are destination-specific, so an incremental sync to a different
/// account or server must be preceded by an explicit full transfer.
class AnkiSyncDestinationState {
  const AnkiSyncDestinationState._();

  /// Reserved marker that makes every incremental destination fail closed
  /// until a full upload or download has a confirmed outcome.
  static const String fullTransferPending =
      'stroom:full-transfer-outcome-unknown';

  static Future<String?> read(DatabaseExecutor db) async {
    final rows = await db.query(
      'stroom_sync_destination',
      columns: ['identity'],
      where: 'id = 1',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['identity'] as String;
  }

  static Future<void> mark(DatabaseExecutor db, String destination) async {
    await db.insert('stroom_sync_destination', {
      'id': 1,
      'identity': destination,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Record a confirmed destination in a closed collection file.
  static Future<void> markCollectionFile(
    String path,
    String destination,
  ) async {
    final db = await openDatabase(path, singleInstance: false);
    try {
      await db.execute(AnkiSchema.syncDestinationStatement);
      await db.transaction((txn) => mark(txn, destination));
    } finally {
      await db.close();
    }
  }

  /// Fail closed while a full transfer's server-side outcome is unknown.
  static Future<void> markCollectionFilePending(String path) =>
      markCollectionFile(path, fullTransferPending);
}
