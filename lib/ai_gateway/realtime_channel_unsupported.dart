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
) =>
    throw UnsupportedError(
      'Realtime API-key WebSocket authentication is unavailable on this platform.',
    );
