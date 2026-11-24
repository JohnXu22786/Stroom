import 'package:http/http.dart' as http;

import 'assistant_catalog_transport_stub.dart'
    if (dart.library.io) 'assistant_catalog_transport_io.dart' as platform;
import 'assistant_catalog_transport_types.dart';

export 'assistant_catalog_transport_types.dart';

http.Client createAssistantCatalogClient({
  required AssistantCatalogAddressLookup lookup,
  required bool Function(String address) isBlockedAddress,
}) =>
    platform.createAssistantCatalogClient(
      lookup: lookup,
      isBlockedAddress: isBlockedAddress,
    );

Future<List<String>> lookupAssistantCatalogAddresses(String host) =>
    platform.lookupAssistantCatalogAddresses(host);
