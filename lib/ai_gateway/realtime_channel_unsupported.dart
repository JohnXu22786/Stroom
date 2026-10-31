import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectRealtimeChannel(
  Uri uri,
  Map<String, String> headers,
) => throw UnsupportedError(
  'Realtime API-key WebSocket authentication is unavailable on this platform.',
);
