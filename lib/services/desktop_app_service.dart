import 'dart:async';
import 'dart:io' show exit;

import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        debugPrint,
        defaultTargetPlatform,
        kIsWeb,
        visibleForTesting;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'app_log_service.dart';

// ====================================================================
// DesktopAppService — 桌面端系统托盘服务
// ====================================================================
//
// 目标：桌面端（Windows / macOS / Linux）关闭窗口时默认「最小化到
// 托盘/后台」继续运行，并可从托盘图标/菜单恢复窗口或彻底退出。
//
// 职责划分：
// - 窗口关闭事件的拦截与「最小化 vs 退出」决策由 Application 层负责
//   （window_manager.setPreventClose + 用户偏好 + 退出确认对话框）。
// - 本服务只负责系统托盘：注册托盘图标与菜单、托盘事件处理
//   （点击恢复窗口 / 菜单退出），以及供 Application 调用的
//   [hideToTray] / [quitApplication]。
//
// 安全兜底：托盘初始化失败（例如 Linux 缺少 appindicator 依赖）时
// 仅记录日志并保持 _trayReady=false —— Application 层会降级为
// 「最小化到任务栏」，窗口始终可找回，不会出现隐藏后无法恢复的
// 「幽灵进程」。
// ====================================================================

/// 桌面端系统托盘服务（单例）。
class DesktopAppService extends TrayListener {
  DesktopAppService._();

  /// The shared instance.
  static final DesktopAppService instance = DesktopAppService._();

  /// 可替换的退出函数，测试中替换为记录器避免真的退出进程。
  @visibleForTesting
  static void Function(int code) exitApp = exit;

  static const _trayIconIco = 'assets/images/tray_icon.ico';
  static const _trayIconPng = 'assets/images/tray_icon.png';

  static const _menuShowKey = 'show';
  static const _menuQuitKey = 'quit';

  bool _trayReady = false;
  bool _quitRequested = false;
  Menu? _menu;

  /// 当前是否运行在桌面平台（Windows / macOS / Linux）。
  static bool get isDesktopPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// 托盘是否已成功注册（用于 UI / Application 展示真实状态）。
  bool get isTrayReady => _trayReady;

  /// 测试用：暴露构建好的托盘菜单，便于模拟菜单点击。
  @visibleForTesting
  Menu? get trayMenuForTesting => _menu;

  /// 测试用：重置单例内部状态，避免用例之间相互污染。
  @visibleForTesting
  void resetForTesting() {
    trayManager.removeListener(this);
    _trayReady = false;
    _quitRequested = false;
    _menu = null;
  }

  /// 注册系统托盘图标与菜单（应用首帧后调用）。
  ///
  /// 幂等：重复调用不会重复注册。任何失败都会被捕获并记录，
  /// 不会导致应用崩溃（Application 层会降级为任务栏最小化）。
  Future<void> setupTray() async {
    if (!isDesktopPlatform || _quitRequested || _trayReady) return;
    try {
      trayManager.addListener(this);

      await trayManager.setIcon(
        defaultTargetPlatform == TargetPlatform.windows
            ? _trayIconIco
            : _trayIconPng,
      );
      // setToolTip 在 Linux 插件上未实现（会抛 MissingPluginException），
      // 单独捕获，避免拖垮整个托盘注册流程。
      try {
        await trayManager.setToolTip('Stroom 正在后台运行');
      } catch (e) {
        debugPrint('[DesktopAppService] setToolTip unsupported: $e');
      }
      _menu = _buildMenu();
      await trayManager.setContextMenu(_menu!);
      _trayReady = true;
      debugPrint('[DesktopAppService] Tray icon registered');
    } catch (e) {
      debugPrint('[DesktopAppService] Tray registration failed: $e');
      await AppLogService.error('DesktopAppService', '托盘注册失败', e);
      trayManager.removeListener(this);
    }
  }

  Menu _buildMenu() {
    // 注意：托盘菜单项的点击回调统一走 [onTrayMenuItemClick] 按键路由，
    // 不要在 MenuItem.onClick 中重复绑定，否则每次点击会执行两次
    // （tray_manager 会同时触发 item.onClick 和 listener.onTrayMenuItemClick）。
    return Menu(
      items: [
        MenuItem(key: _menuShowKey, label: '显示主窗口'),
        MenuItem.separator(),
        MenuItem(key: _menuQuitKey, label: '退出 Stroom'),
      ],
    );
  }

  // ── 托盘事件 ──────────────────────────────────────────────────────

  /// 左键点击托盘图标：恢复并聚焦主窗口。
  @override
  void onTrayIconMouseDown() {
    unawaited(showWindow());
  }

  /// 右键点击托盘图标：弹出菜单。
  @override
  void onTrayIconRightMouseDown() {
    // Linux 插件未实现 popUpContextMenu（菜单随左键自动弹出），
    // 异常通过 Future 异步抛出，必须用 catchError 兜住。
    unawaited(
      trayManager
          .popUpContextMenu()
          .catchError((Object e) => debugPrint(
                '[DesktopAppService] popUpContextMenu unsupported: $e',
              )),
    );
  }

  /// 托盘菜单项点击。
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key == _menuShowKey) {
      unawaited(showWindow());
    } else if (key == _menuQuitKey) {
      unawaited(quitApplication());
    }
  }

  // ── 行为实现 ──────────────────────────────────────────────────────

  /// 将窗口隐藏到系统托盘（关闭窗口时最小化）。仅当托盘就绪时调用。
  Future<void> hideToTray() async {
    try {
      await windowManager.hide();
    } catch (e) {
      debugPrint('[DesktopAppService] Failed to hide window: $e');
    }
  }

  /// 从托盘恢复并聚焦主窗口。
  Future<void> showWindow() async {
    if (_quitRequested) return;
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (e) {
      debugPrint('[DesktopAppService] Failed to show window: $e');
    }
  }

  /// 从托盘彻底退出：销毁托盘图标与窗口，然后退出进程。
  ///
  /// 幂等：重复调用（例如菜单连点）只执行一次。
  /// macOS 在最后一个窗口关闭后默认不退出，必须显式退出进程；
  /// Windows/Linux 上 windowManager.destroy() 会结束消息循环，
  /// 这里统一显式退出以保证确定性。
  Future<void> quitApplication() async {
    if (_quitRequested) return;
    _quitRequested = true;
    debugPrint('[DesktopAppService] Quitting');
    try {
      await trayManager.destroy();
    } catch (e) {
      debugPrint('[DesktopAppService] Failed to destroy tray: $e');
    }
    try {
      await windowManager.destroy();
    } catch (e) {
      debugPrint('[DesktopAppService] Failed to destroy window: $e');
    }
    exitApp(0);
  }
}
