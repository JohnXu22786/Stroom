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
      return connectToAllowedAssistantCatalogAddress<ConnectionTask<Socket>>(
        addresses: addresses,
        port: uri.port,
        isBlockedAddress: isBlockedAddress,
        connect: (address, port) async {
          final task = await Socket.startConnect(address, port);
          try {
            await task.socket;
            return task;
          } on SocketException {
            task.cancel();
            rethrow;
          }
        },
      );
    };
  return IOClient(httpClient);
}

Future<T> connectToAllowedAssistantCatalogAddress<T>({
  required List<String> addresses,
  required int port,
  required bool Function(String address) isBlockedAddress,
  required Future<T> Function(String address, int port) connect,
}) async {
  if (addresses.isEmpty || addresses.any(isBlockedAddress)) {
    throw const FormatException(
      'Assistant host resolved to a blocked network address.',
    );
  }

  SocketException? lastConnectionError;
  for (final address in addresses) {
    try {
      return await connect(address, port);
    } on SocketException catch (error) {
      lastConnectionError = error;
    }
  }

  throw lastConnectionError!;
}

Future<List<String>> lookupAssistantCatalogAddresses(String host) async =>
    (await InternetAddress.lookup(host))
        .map((address) => address.address)
        .toList();
