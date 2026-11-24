import 'llm_oauth_loopback.dart';

Future<LlmOAuthLoopback> bindLlmOAuthLoopback(
  String path, {
  required String host,
  required int port,
}) =>
    Future.error(StateError('OAuth loopback is unavailable on this platform.'));
