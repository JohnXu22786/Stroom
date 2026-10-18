import 'generated/anki/sync.pb.dart';
import 'anki_sync_protocol_client.dart';

/// Legacy placeholder retained for source compatibility. The former protobuf
/// calls to `/sync/sync` were not AnkiWeb's current sync API. Login now uses
/// the verified v10 hostKey exchange; status and collection transfer must use
/// [AnkiSyncProtocolClient] instead of these unfinished protobuf methods.
@Deprecated(
  'Use AnkiSyncProtocolClient; protobuf collection sync is unsupported',
)
class AnkiFullSyncClient {
  final AnkiSyncProtocolClient Function() _clientFactory;

  AnkiFullSyncClient({
    AnkiSyncProtocolClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? AnkiSyncProtocolClient.ankiWeb;

  Future<SyncAuth> login(String email, String password) async {
    final client = _clientFactory();
    try {
      final key = await client.login(email, password);
      return SyncAuth()..hkey = key;
    } finally {
      client.close();
    }
  }

  SyncAuth authWithKey(String key) => SyncAuth()..hkey = key;

  Future<SyncStatusResponse> checkStatus(String hkey) async =>
      throw const AnkiSyncException(
        '旧 protobuf 状态请求已停用；请使用 AnkiSyncProtocolClient.checkStatus()',
      );

  Future<SyncCollectionResponse> startSync(String hkey) async =>
      throw const AnkiSyncException(
        '旧 protobuf 集合请求已停用；当前只支持安全的单向 collection 传输',
      );

  Future<void> fullUpload(String hkey, List<int> collectionData) async =>
      throw const AnkiSyncException('请使用 AnkiCollectionTransfer，并在上传前确认覆盖服务器');

  Future<List<int>> fullDownload(String hkey) async =>
      throw const AnkiSyncException('请使用 AnkiCollectionTransfer，以便验证文件并保留本地备份');
}
