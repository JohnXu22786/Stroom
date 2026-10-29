import 'llm_oauth_loopback.dart';

Future<LlmOAuthLoopback> bindLlmOAuthLoopback(String path) =>
    Future.error(StateError('OAuth loopback is unavailable on this platform.'));
