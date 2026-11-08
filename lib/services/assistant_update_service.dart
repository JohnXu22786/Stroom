import '../models/assistant.dart';
import 'assistant_catalog_service.dart';

class AssistantUpdateService {
  static Future<DownloadedRemoteAssistant?> checkForUpdate(
    Assistant assistant,
  ) async {
    final catalogUrl = assistant.remoteCatalogUrl;
    final service = AssistantCatalogService();
    try {
      if (catalogUrl != null && catalogUrl.isNotEmpty) {
        final catalog = await service.fetchCatalog(catalogUrl);
        final entry = catalog.assistants
            .where((item) => item.id == assistant.remoteAssistantId)
            .firstOrNull;
        if (entry == null) return null;
        if (entry.version == assistant.remoteVersion &&
            entry.sha256 == assistant.remoteSha256) {
          return null;
        }
        return await service.fetchCatalogEntry(
          catalogUrl: catalogUrl,
          entry: entry,
        );
      }

      final fileUrl = assistant.remoteFileUrl;
      if (fileUrl == null || fileUrl.isEmpty) return null;
      final remote = await service.fetchDirectAssistant(fileUrl);
      if (remote.definition.id != assistant.remoteAssistantId) {
        throw const FormatException(
            'Remote assistant id changed unexpectedly.');
      }
      if (remote.definition.version == assistant.remoteVersion &&
          remote.sha256 == assistant.remoteSha256) {
        return null;
      }
      return remote;
    } finally {
      service.close();
    }
  }
}
