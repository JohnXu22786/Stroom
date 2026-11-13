/// Web-safe substitute for the desktop-only `window_manager` legacy API.
///
/// Desktop window management is never invoked on Web, but importing its
/// implementation still pulls in native-only APIs that do not compile there.
abstract mixin class WindowListener {
  void onWindowClose() {}
}

class _WindowManager {
  Future<void> ensureInitialized() async {}
  Future<void> setPreventClose(bool isPreventClose) async {}
  Future<void> close() async {}
  Future<void> hide() async {}
  Future<void> show() async {}
  Future<void> focus() async {}
  Future<void> destroy() async {}
  void addListener(WindowListener listener) {}
  void removeListener(WindowListener listener) {}
}

final windowManager = _WindowManager();
