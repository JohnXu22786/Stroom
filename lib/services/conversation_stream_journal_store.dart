import 'conversation_stream_journal_store_stub.dart'
    if (dart.library.io) 'conversation_stream_journal_store_io.dart' as impl;

class ConversationStreamJournalStore {
  const ConversationStreamJournalStore._();

  static Future<void> append(String path, String line) =>
      impl.append(path, line);

  static Future<List<String>?> readLines(String path) => impl.readLines(path);

  static Future<bool> delete(String path) => impl.delete(path);
}
