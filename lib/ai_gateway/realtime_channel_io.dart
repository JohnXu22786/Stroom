import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RealtimeChannelConnection {
  final WebSocketChannel channel;
  final Future<void> Function() abort;
  final int? Function(Object error) handshakeStatusCode;

  const RealtimeChannelConnection({
    required this.channel,
    required this.abort,
    required this.handshakeStatusCode,
  });
}

Future<RealtimeChannelConnection> connectRealtimeChannel(
  Uri uri,
  Map<String, String> headers,
  Duration connectTimeout,
) async {
  final client = HttpClient()..connectionTimeout = connectTimeout;
  final channel = IOWebSocketChannel.connect(
    uri,
    headers: headers,
    connectTimeout: connectTimeout,
    customClient: client,
  );
  return RealtimeChannelConnection(
    channel: channel,
    handshakeStatusCode: (error) {
      if (error is WebSocketChannelException &&
          error.inner is WebSocketException) {
        return (error.inner as WebSocketException).httpStatusCode;
      }
      return null;
    },
    abort: () async {
      client.close(force: true);
      try {
        await channel.sink.close().timeout(const Duration(seconds: 1));
      } catch (_) {
        // Closing an in-progress handshake can complete with a socket error.
      }
    },
  );
}
