import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/startup/app_restart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('restartApp', () {
    test('is callable on mobile platforms without throwing', () async {
      // 测试环境默认平台为 Android：restartApp 走 SystemNavigator.pop()
      // 分支（测试中为 no-op），所有失败都在内部 try/catch 中消化。
      // 断言调用不抛异常、不产生未处理异步错误。
      expect(restartApp, returnsNormally);
      restartApp();
      // 让 fire-and-forget 的异步体有机会执行（内部全部 try/catch）。
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
}
