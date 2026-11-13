import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/window_manager_legacy_stub.dart';

void main() {
  test('web window manager stub safely accepts desktop operations', () async {
    final listener = _TestWindowListener();

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(listener);
    await windowManager.hide();
    await windowManager.show();
    await windowManager.focus();
    await windowManager.close();
    await windowManager.destroy();
    windowManager.removeListener(listener);

    expect(listener.closeCalls, 0);
  });
}

class _TestWindowListener with WindowListener {
  int closeCalls = 0;

  @override
  void onWindowClose() => closeCalls++;
}
