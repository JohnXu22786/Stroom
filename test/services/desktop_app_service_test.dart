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
  final messenger = TestDefaultBinaryMessengerBinding.instance
      .defaultBinaryMessenger;
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

    test('setupTray is a no-op on non-desktop platforms', () async {
      final mocks = registerChannelMocks();
      await DesktopAppService.instance.setupTray();
      expect(mocks['tray_manager']!.calls, isEmpty);
    });
  });

  group('DesktopAppService - tray setup', () {
    test('setupTray registers icon, tooltip and menu', () async {
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTray();
      });

      final trayCalls = mocks['tray_manager']!.calls;

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

      expect(DesktopAppService.instance.isTrayReady, isTrue);
    });

    test('setupTray is idempotent', () async {
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTray();
        await DesktopAppService.instance.setupTray();
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
          await DesktopAppService.instance.setupTray();
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

    test('setupTray survives plugin errors gracefully', () async {
      final mocks = registerChannelMocks();
      mocks['tray_manager']!.throwError = 'tray unavailable';
      await withDesktopPlatform(TargetPlatform.windows, () async {
        // Must not throw — tray failure must not crash the app.
        await DesktopAppService.instance.setupTray();
      });
      // The failure must leave the service NOT tray-ready so the
      // Application layer falls back to taskbar minimize (never an
      // unreachable hidden window), and the listener must be detached.
      expect(DesktopAppService.instance.isTrayReady, isFalse);
      expect(trayManager.hasListeners, isFalse);
    });
  });

  group('DesktopAppService - window/tray behavior', () {
    test('hideToTray hides the window', () async {
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.hideToTray();
      });
      expect(_calledWith(mocks['window_manager']!.calls, 'hide'), isTrue);
    });

    test('clicking the tray icon restores and focuses the window', () async {
      final mocks = registerChannelMocks();
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTray();
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
        await DesktopAppService.instance.setupTray();
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
        await DesktopAppService.instance.setupTray();
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
        await DesktopAppService.instance.setupTray();
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

    test('after quit, further tray setup is a no-op', () async {
      final mocks = registerChannelMocks();
      DesktopAppService.exitApp = (_) {};
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTray();
        DesktopAppService.instance.quitApplication();
        await DesktopAppService.instance.setupTray();
      });
      final setIconCount = mocks['tray_manager']!
          .calls
          .where((c) => c.method == 'setIcon')
          .length;
      expect(setIconCount, 1);
    });

    test('showWindow is a no-op after quit was requested', () async {
      final mocks = registerChannelMocks();
      DesktopAppService.exitApp = (_) {};
      await withDesktopPlatform(TargetPlatform.windows, () async {
        await DesktopAppService.instance.setupTray();
        DesktopAppService.instance.quitApplication();
        await DesktopAppService.instance.showWindow();
      });
      final calls = mocks['window_manager']!.calls;
      expect(_calledWith(calls, 'show'), isFalse);
    });
  });
}
