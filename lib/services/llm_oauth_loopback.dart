import 'llm_oauth_loopback_stub.dart'
    if (dart.library.io) 'llm_oauth_loopback_io.dart'
    as platform;

abstract interface class LlmOAuthLoopback {
  Uri get redirectUri;
  Future<Uri> nextCallback();
  Future<void> respond({required bool accepted});
  Future<void> close();

  static Future<LlmOAuthLoopback> bind(String path) =>
      platform.bindLlmOAuthLoopback(path);
}
