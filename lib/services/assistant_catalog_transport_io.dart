import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'assistant_catalog_transport_types.dart';

http.Client createAssistantCatalogClient({
  required AssistantCatalogAddressLookup lookup,
  required bool Function(String address) isBlockedAddress,
}) {
  final httpClient = HttpClient()
    ..autoUncompress = true
    ..connectionFactory = (uri, proxyHost, proxyPort) async {
      if (proxyHost != null || proxyPort != null) {
        throw const FormatException(
          'Assistant downloads cannot use an unverified proxy.',
        );
      }
      final addresses = await lookup(uri.host);
      if (addresses.isEmpty || addresses.any(isBlockedAddress)) {
        throw const FormatException(
          'Assistant host resolved to a blocked network address.',
        );
      }
      return Socket.startConnect(addresses.first, uri.port);
    };
  return IOClient(httpClient);
}

Future<List<String>> lookupAssistantCatalogAddresses(String host) async =>
    (await InternetAddress.lookup(host))
        .map((address) => address.address)
        .toList();
