import 'anki_sync_protocol_client.dart';

export 'anki_sync_protocol_client.dart' show AnkiSyncException;

/// Compatibility entry point for callers that only need AnkiWeb login.
/// New sync code should use [AnkiSyncProtocolClient] directly so its v10
/// multipart session can also be used for the subsequent status request.
class AnkiSyncClient {
  static Future<String> login(
    String email,
    String password, {
    AnkiSyncProtocolClient Function()? clientFactory,
  }) async {
    final client = (clientFactory ?? AnkiSyncProtocolClient.ankiWeb)();
    try {
      return await client.login(email, password);
    } finally {
      client.close();
    }
  }
}
