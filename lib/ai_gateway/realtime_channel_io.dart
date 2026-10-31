import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<WebSocketChannel> connectRealtimeChannel(
  Uri uri,
  Map<String, String> headers,
) async =>
    IOWebSocketChannel.connect(uri, headers: headers);
