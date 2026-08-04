import 'dart:io' show exit;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroom/services/desktop_app_service.dart';
import 'package:tray_manager/tray_manager.dart' show trayManager;
import 'package:window_manager/window_manager.dart' show windowManager;

/// Records method calls made on a mocked platform channel.
class RecordingChannelMock {
  final List<MethodCall> calls = [];
  Object? throwError;

  Future<Object?> handler(MethodCall call) async {
    calls.add(call);
    if (throwError != null) throw throwError!;
    return true;
  }
}

/// Registers recording mocks for the window_manager / tray_manager channels
/// and returns them keyed by channel name.
Map<String, RecordingChannelMock> registerChannelMocks() {
  final mocks = <String, RecordingChannelMock>{
    'window_manager': RecordingChannelMock(),
    'tray_manager': RecordingChannelMock(),
  };
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('window_manager'),
    mocks['window_manager']!.handler,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('tray_manager'),
    mocks['tray_manager']!.handler,
  );
  return mocks;
}

/// Runs [body] with the desktop platform override active.
Future<void> withDesktopPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

bool _calledWith(List<MethodCall> calls, String method) {
  return calls.any((c) => c.method == method);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Restore the default exit function between tests.
    DesktopAppService.exitApp = exit;
    DesktopAppService.instance.resetForTesting();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('DesktopAppService - platform gating', () {
    test('isDesktopPlatform is false on non-desktop platforms', () {
      // Test environment default is Android — desktop service must not run.
      expect(DesktopAppService.isDesktopPlatform, isFalse);
    });

    test('isDesktopPlatform is true for Windows, macOS and Linux', () {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(DesktopAppService.isDesktopPlatform, isTrue,
            reason: '$platform should be a desktop platform');
      }
      debugDefaultTargetPlatformOverride = null;
    });

    test('initialize() is a no-op on non-desktop platforms', () async {
      final mocks = registerChannelMocks();
      await DesktopAppService.instance.initialize();
      expect(mocks['window_manager']!.calls, isEmpty);
    });
  });

  group('DesktopAppService - initialization', () {
    test('initialize() calls window_manager ensureInitialized on Windows',
        () async {
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.initialize();
      });
      expect(
        _calledWith(mocks['window_manager']!.calls, 'ensureInitialized'),
        isTrue,
      );
    });

    test('initialize() is idempotent', () async {
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.initialize();
        await DesktopAppService.instance.initialize();
      });
      final ensureCount = mocks['window_manager']!
          .calls
          .where((c) => c.method == 'ensureInitialized')
          .length;
      expect(ensureCount, 1);
    });
  });

  group('DesktopAppService - tray setup', () {
    test('setupTrayAndCloseBehavior prevents close and registers tray',
        () async {
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
      });

      final windowCalls = mocks['window_manager']!.calls;
      final trayCalls = mocks['tray_manager']!.calls;

      // Close interception must be enabled.
      expect(
        windowCalls.any((c) =>
            c.method == 'setPreventClose' &&
            (c.arguments as Map)['isPreventClose'] == true),
        isTrue,
      );

      // Windows tray icon must be the .ico asset.
      final setIcon = trayCalls.where((c) => c.method == 'setIcon').toList();
      expect(setIcon, hasLength(1));
      final iconArg = (setIcon.single.arguments as Map)['iconPath'] as String;
      expect(iconArg, contains('tray_icon.ico'));

      // Tooltip + menu must be registered.
      expect(_calledWith(trayCalls, 'setToolTip'), isTrue);
      final menuCall =
          trayCalls.firstWhere((c) => c.method == 'setContextMenu');
      final menuJson = (menuCall.arguments as Map)['menu'] as Map;
      final labels = (menuJson['items'] as List)
          .map((e) => (e as Map)['label'] as String)
          .toList();
      expect(labels, contains('显示主窗口'));
      expect(labels, contains('退出 Stroom'));
    });

    test('setupTrayAndCloseBehavior is idempotent', () async {
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
      });
      final setIconCount = mocks['tray_manager']!
          .calls
          .where((c) => c.method == 'setIcon')
          .length;
      expect(setIconCount, 1);
    });

    test('macOS and Linux use the .png tray icon', () async {
      for (final platform in [TargetPlatform.macOS, TargetPlatform.linux]) {
        DesktopAppService.instance.resetForTesting();
        final mocks = registerChannelMocks();
        await withDesktopPlatform(platform, () async {
          await DesktopAppService.instance.setupTrayAndCloseBehavior();
        });
        final setIcon = mocks['tray_manager']!
            .calls
            .where((c) => c.method == 'setIcon')
            .toList();
        expect(setIcon, hasLength(1), reason: '$platform should set an icon');
        final iconArg = (setIcon.single.arguments as Map)['iconPath'] as String;
        expect(iconArg, contains('tray_icon.png'));
      }
    });

    test('setupTrayAndCloseBehavior survives plugin errors gracefully',
        () async {
      final mocks = registerChannelMocks();
      mocks['tray_manager']!.throwError = 'tray unavailable';
      await withDesktopPlatform(TargetPlatform.windows, () async {
        // Must not throw — tray failure must not crash the app.
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
      });
      // preventClose must still have been attempted...
      expect(
        _calledWith(mocks['window_manager']!.calls, 'setPreventClose'),
        isTrue,
      );
      // ...but the failure must roll the close-guard back so the window
      // still closes for real (no unreachable hidden window), and the
      // listeners must be detached.
      expect(
        mocks['window_manager']!.calls.any((c) =>
            c.method == 'setPreventClose' &&
            (c.arguments as Map)['isPreventClose'] == false),
        isTrue,
        reason: 'tray failure must re-enable close-to-quit as fallback',
      );
      expect(windowManager.listeners.contains(DesktopAppService.instance),
          isFalse);
      expect(trayManager.hasListeners, isFalse);
    });

    test('setupTrayAndCloseBehavior is a no-op on non-desktop platforms',
        () async {
      final mocks = registerChannelMocks();
      // Default test platform is Android — nothing may be called.
      await DesktopAppService.instance.setupTrayAndCloseBehavior();
      expect(mocks['window_manager']!.calls, isEmpty);
      expect(mocks['tray_manager']!.calls, isEmpty);
    });
  });

  group('DesktopAppService - window/tray behavior', () {
    test('closing the window hides it instead of quitting', () async {
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
        DesktopAppService.instance.onWindowClose();
        // The close handler is fire-and-forget — let it complete.
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      expect(_calledWith(mocks['window_manager']!.calls, 'hide'), isTrue);
    });

    test('clicking the tray icon restores and focuses the window', () async {
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
        DesktopAppService.instance.onTrayIconMouseDown();
        // The click handler is fire-and-forget — let it complete.
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      final calls = mocks['window_manager']!.calls;
      expect(_calledWith(calls, 'show'), isTrue);
      expect(_calledWith(calls, 'focus'), isTrue);
    });

    test('right-clicking the tray icon pops up the context menu', () async {
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
        DesktopAppService.instance.onTrayIconRightMouseDown();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      expect(
        _calledWith(mocks['tray_manager']!.calls, 'popUpContextMenu'),
        isTrue,
      );
    });

    test('menu item "show" restores the window', () async {
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
        final menu = DesktopAppService.instance.trayMenuForTesting!;
        final showItem = menu.getMenuItem('show')!;
        DesktopAppService.instance.onTrayMenuItemClick(showItem);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      final calls = mocks['window_manager']!.calls;
      expect(_calledWith(calls, 'show'), isTrue);
    });

    test('menu item "quit" destroys tray + window and exits', () async {
      final mocks = registerChannelMocks();
      final exitCodes = <int>[];
      DesktopAppService.exitApp = exitCodes.add;
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
        final menu = DesktopAppService.instance.trayMenuForTesting!;
        final quitItem = menu.getMenuItem('quit')!;
        DesktopAppService.instance.onTrayMenuItemClick(quitItem);
        // Let the fire-and-forget quit sequence complete.
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      expect(_calledWith(mocks['tray_manager']!.calls, 'destroy'), isTrue);
      expect(_calledWith(mocks['window_manager']!.calls, 'destroy'), isTrue);
      expect(exitCodes, [0]);
    });

    test('tray menu quit respects the injected quit confirmation', () async {
      final mocks = registerChannelMocks();
      final exitCodes = <int>[];
      DesktopAppService.exitApp = exitCodes.add;
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
        final menu = DesktopAppService.instance.trayMenuForTesting!;
        final quitItem = menu.getMenuItem('quit')!;

        // User cancels the confirmation → nothing is destroyed, no exit.
        DesktopAppService.instance.onQuitConfirmation = () async => false;
        DesktopAppService.instance.onTrayMenuItemClick(quitItem);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          mocks['window_manager']!.calls
              .where((c) => c.method == 'destroy'),
          isEmpty,
        );
        expect(exitCodes, isEmpty);

        // User confirms → destroys tray + window and exits.
        DesktopAppService.instance.onQuitConfirmation = () async => true;
        DesktopAppService.instance.onTrayMenuItemClick(quitItem);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(_calledWith(mocks['tray_manager']!.calls, 'destroy'), isTrue);
        expect(_calledWith(mocks['window_manager']!.calls, 'destroy'), isTrue);
        expect(exitCodes, [0]);
      });
      DesktopAppService.instance.onQuitConfirmation = null;
    });

    test('tray menu quit restores the window before confirming', () async {
      // 回归：关闭即最小化模式下窗口已隐藏到托盘，托盘「退出 Stroom」
      // 必须先恢复窗口，否则确认对话框显示在隐藏窗口上（不可见），
      // 且 _quitConfirmInProgress 会锁死后续所有退出尝试。
      final mocks = registerChannelMocks();
      final exitCodes = <int>[];
      DesktopAppService.exitApp = exitCodes.add;
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
        // 模拟窗口已隐藏到托盘。
        DesktopAppService.instance.onWindowClose();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        bool confirmCalled = false;
        DesktopAppService.instance.onQuitConfirmation = () async {
          confirmCalled = true;
          return false; // 取消退出
        };

        final menu = DesktopAppService.instance.trayMenuForTesting!;
        final quitItem = menu.getMenuItem('quit')!;
        DesktopAppService.instance.onTrayMenuItemClick(quitItem);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(confirmCalled, isTrue,
            reason: '隐藏窗口时托盘退出必须先恢复窗口再走确认流程');
        // 确认前必须调用 show（恢复窗口）。
        final showCalls =
            mocks['window_manager']!.calls.where((c) => c.method == 'show');
        expect(showCalls, isNotEmpty);
        // 用户取消 → 不退出。
        expect(exitCodes, isEmpty);
      });
      DesktopAppService.instance.onQuitConfirmation = null;
    });

    test('close hides to tray when the minimize pref read fails', () async {
      // isDesktopCloseMinimizeEnabled 读取失败时必须默认最小化，
      // 绝不因设置异常而意外退出应用。
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
        // 不 mock SharedPreferences → 读取抛异常 → 默认最小化。
        DesktopAppService.instance.onWindowClose();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      expect(_calledWith(mocks['window_manager']!.calls, 'hide'), isTrue);
      expect(_calledWith(mocks['window_manager']!.calls, 'destroy'), isFalse);
    });

    test('quitWithConfirmation falls through when the callback throws',
        () async {
      final mocks = registerChannelMocks();
      final exitCodes = <int>[];
      DesktopAppService.exitApp = exitCodes.add;
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
        // 确认回调抛异常：放行退出，绝不阻塞用户关闭窗口。
        DesktopAppService.instance.onQuitConfirmation = () async {
          throw StateError('provider unavailable');
        };
        await DesktopAppService.instance.quitWithConfirmation();
      });
      expect(_calledWith(mocks['window_manager']!.calls, 'destroy'), isTrue);
      expect(exitCodes, [0]);
    });

    test('after quit, further tray setup is a no-op', () async {
      final mocks = registerChannelMocks();
      DesktopAppService.exitApp = (_) {};
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
        DesktopAppService.instance.quitApplication();
        await DesktopAppService.instance.setupTrayAndCloseBehavior();
      });
      final setIconCount = mocks['tray_manager']!
          .calls
          .where((c) => c.method == 'setIcon')
          .length;
      expect(setIconCount, 1);
    });
  });
}
