import 'package:http/http.dart' as http;

import 'assistant_catalog_transport_types.dart';

http.Client createAssistantCatalogClient({
  required AssistantCatalogAddressLookup lookup,
  required bool Function(String address) isBlockedAddress,
}) =>
    _UnsupportedAssistantCatalogClient();

Future<List<String>> lookupAssistantCatalogAddresses(String host) =>
    Future.error(
      const FormatException(
        'Assistant downloads require a platform with guarded DNS resolution.',
      ),
    );

class _UnsupportedAssistantCatalogClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => Future.error(
        const FormatException(
          'Assistant downloads require a platform with guarded DNS resolution.',
        ),
      );
}
