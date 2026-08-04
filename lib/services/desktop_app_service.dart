import 'dart:async';
import 'dart:io' show exit;

import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        debugPrint,
        defaultTargetPlatform,
        visibleForTesting;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'app_log_service.dart';
import 'background_service.dart' as background_service;

// ====================================================================
// DesktopAppService — 桌面端窗口与系统托盘驻留服务
// ====================================================================
//
// 目标：桌面端（Windows / macOS / Linux）关闭窗口时默认「最小化到托盘」，
// 应用继续在后台运行，并可从托盘图标恢复窗口或彻底退出。
//
// 实现：
// 1. [initialize] 在 runApp 之前调用（window_manager 要求在 Flutter
//    UI 启动前完成初始化）。
// 2. [setupTrayAndCloseBehavior] 在首帧后调用：设置 setPreventClose(true)
//    使点击关闭按钮时窗口不销毁（window_manager 拦截 WM_CLOSE /
//    delete-event / windowShouldClose），并注册托盘图标与右键菜单。
// 3. 关闭窗口 → [onWindowClose]：按用户设置决策 ——
//    - 「关闭时最小化」（默认）：隐藏窗口到托盘；
//    - 「关闭时退出」：先通过 [onQuitConfirmation] 确认（有任务运行时
//      弹窗提示），确认后销毁托盘与窗口并退出进程。
//    托盘点击 → 显示并聚焦窗口；托盘菜单「退出」→ 直接彻底退出。
//
// 安全兜底：如果托盘初始化失败（例如 Linux 缺少 appindicator 依赖），
// 会撤销 setPreventClose，恢复「关闭即退出」的默认行为，
// 避免出现窗口关闭后无法找回应用的「幽灵进程」。
// ====================================================================

/// 桌面端窗口管理 + 系统托盘驻留服务（单例）。
class DesktopAppService extends WindowListener with TrayListener {
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

  bool _initialized = false;
  bool _trayReady = false;
  bool _quitRequested = false;
  Menu? _menu;

  /// 当前是否运行在桌面平台（Windows / macOS / Linux）。
  ///
  /// 唯一实现位于 [background_service.isDesktopPlatform]，此处委托，
  /// 避免两处平台判断漂移。
  static bool get isDesktopPlatform => background_service.isDesktopPlatform();

  /// 测试用：暴露构建好的托盘菜单，便于模拟菜单点击。
  @visibleForTesting
  Menu? get trayMenuForTesting => _menu;

  /// 托盘是否已成功注册（用于 UI 展示真实状态）。
  bool get isTrayReady => _trayReady;

  /// 「关闭即退出」模式下的退出确认回调。
  ///
  /// 由 Application 注入（展示运行中任务的退出确认对话框）。
  /// 返回 `true` 表示用户确认退出；返回 `false` 取消退出。
  /// 未注入时视为已确认（直接退出）。
  Future<bool> Function()? onQuitConfirmation;

  /// 测试用：重置单例内部状态，避免用例之间相互污染。
  @visibleForTesting
  void resetForTesting() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _initialized = false;
    _trayReady = false;
    _quitRequested = false;
    _menu = null;
    onQuitConfirmation = null;
  }

  /// 在 runApp 之前调用，初始化窗口管理器。
  ///
  /// 非桌面平台为安全的 no-op。
  Future<void> initialize() async {
    if (!isDesktopPlatform || _initialized) return;
    try {
      await windowManager.ensureInitialized();
      _initialized = true;
      debugPrint('[DesktopAppService] Window manager initialized');
    } catch (e) {
      debugPrint('[DesktopAppService] Window manager init failed: $e');
      await AppLogService.error('DesktopAppService', '窗口管理器初始化失败', e);
    }
  }

  /// 设置「关闭窗口 → 最小化到托盘」行为并注册托盘图标。
  ///
  /// 应在应用首帧之后调用。幂等：重复调用不会重复注册托盘。
  /// 任何失败都会被捕获并记录，不会导致应用崩溃。
  ///
  /// 安全顺序：
  /// 1. 先 setPreventClose(true) 拦截关闭事件；
  /// 2. 注册托盘（带超时，防止 Linux DBus/appindicator 挂起）；
  /// 3. 托盘就绪后才注册事件监听 —— 若托盘失败回滚为「关闭即退出」，
  ///    期间到达的关闭事件只会让窗口保持打开（尚未隐藏），不会出现
  ///    「窗口已隐藏但无托盘可恢复」的幽灵进程。
  Future<void> setupTrayAndCloseBehavior() async {
    if (!isDesktopPlatform || _quitRequested || _trayReady) return;
    // 托盘注册超时：插件挂起（如 Linux 缺少 appindicator 服务）时
    // 走回滚路径，而不是让窗口永远无法关闭。
    const trayTimeout = Duration(seconds: 10);
    try {
      await initialize();
      if (!_initialized) return; // 初始化失败，保持默认关闭行为

      // 1. 先拦截窗口关闭事件。
      await windowManager.setPreventClose(true);

      // 2. 注册托盘图标与菜单。失败则回退为「关闭即退出」，
      //    避免窗口隐藏后应用无法找回。
      try {
        await trayManager
            .setIcon(
          defaultTargetPlatform == TargetPlatform.windows
              ? _trayIconIco
              : _trayIconPng,
        )
            .timeout(trayTimeout);
        // setToolTip 在 Linux 插件上未实现（会抛 MissingPluginException），
        // 单独捕获，避免拖垮整个托盘注册流程；同样受超时保护
        // （DBus/appindicator 挂起时不能无限期停留在无监听的拦截状态）。
        try {
          await trayManager
              .setToolTip('Stroom 正在后台运行')
              .timeout(trayTimeout);
        } catch (e) {
          debugPrint('[DesktopAppService] setToolTip unsupported: $e');
        }
        _menu = _buildMenu();
        await trayManager.setContextMenu(_menu!).timeout(trayTimeout);
        _trayReady = true;
        debugPrint('[DesktopAppService] Tray icon registered');
      } catch (e) {
        debugPrint('[DesktopAppService] Tray registration failed: $e');
        await AppLogService.error('DesktopAppService', '托盘注册失败', e);
        // 清理可能已半注册的托盘图标（例如 setIcon 成功但
        // setContextMenu 超时），避免残留死托盘条目。
        try {
          await trayManager.destroy();
        } catch (_) {}
        // 托盘不可用：撤销拦截，恢复「关闭即退出」。
        // 此时尚未注册监听，也不会有幽灵窗口。
        await windowManager.setPreventClose(false);
        return;
      }

      // 3. 托盘就绪后注册事件监听。
      windowManager.addListener(this);
      trayManager.addListener(this);
    } catch (e) {
      debugPrint('[DesktopAppService] Tray setup failed: $e');
      await AppLogService.error('DesktopAppService', '托盘设置失败', e);
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

  // ── 窗口事件 ──────────────────────────────────────────────────────

  /// 用户点击窗口关闭按钮：按用户设置最小化到托盘，或确认后退出。
  ///
  /// 每次读取最新的用户设置（而不是启动时缓存的标志）：
  /// 用户在「后台运行优化」页面切换开关后，无需重启应用即生效。
  @override
  void onWindowClose() {
    debugPrint('[DesktopAppService] Window close intercepted');
    unawaited(_handleWindowClose());
  }

  Future<void> _handleWindowClose() async {
    // 读取失败时默认最小化：绝不因设置读取异常而意外退出应用。
    var minimize = true;
    try {
      minimize = await background_service.isDesktopCloseMinimizeEnabled();
    } catch (e) {
      debugPrint('[DesktopAppService] 读取关闭行为设置失败，默认最小化: $e');
    }

    if (minimize) {
      await _hideWindow();
      return;
    }
    await quitWithConfirmation();
  }

  /// 带确认的退出：「关闭即退出」模式与「完全退出应用」按钮共用。
  ///
  /// 先征求 [onQuitConfirmation] 的同意（例如有任务运行时弹窗确认），
  /// 用户取消则什么都不做；确认后彻底退出（销毁托盘与窗口）。
  Future<void> quitWithConfirmation() async {
    // 托盘退出时窗口可能已隐藏到托盘：先恢复窗口，确认对话框才可见。
    // （窗口已可见时 _showWindow 是幂等 no-op；_quitRequested 时跳过。）
    await _showWindow();
    try {
      final confirm = onQuitConfirmation;
      if (confirm != null) {
        final confirmed = await confirm();
        if (!confirmed) {
          debugPrint('[DesktopAppService] 退出被用户取消，窗口保持打开');
          return;
        }
      }
    } catch (e) {
      // 确认逻辑异常（如 Provider 不可用）：放行退出，
      // 绝不阻塞用户关闭窗口。
      debugPrint('[DesktopAppService] 退出确认异常，放行退出: $e');
    }
    await quitApplication();
  }

  // ── 托盘事件 ──────────────────────────────────────────────────────

  /// 左键点击托盘图标：恢复并聚焦主窗口。
  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  /// 右键点击托盘图标：弹出菜单。
  @override
  void onTrayIconRightMouseDown() {
    // Linux 插件未实现 popUpContextMenu（菜单随左键自动弹出），
    // 异常通过 Future 异步抛出，必须用 catchError 兜住。
    unawaited(
      trayManager.popUpContextMenu().catchError((Object e) => debugPrint(
            '[DesktopAppService] popUpContextMenu unsupported: $e',
          )),
    );
  }

  /// 托盘菜单项点击。
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    if (key == _menuShowKey) {
      unawaited(_showWindow());
    } else if (key == _menuQuitKey) {
      // 与「关闭即退出」/「完全退出应用」共用确认逻辑：
      // 有任务运行时先弹窗确认，避免静默中断任务。
      unawaited(quitWithConfirmation());
    }
  }

  // ── 行为实现 ──────────────────────────────────────────────────────

  Future<void> _hideWindow() async {
    try {
      await windowManager.hide();
    } catch (e) {
      debugPrint('[DesktopAppService] Failed to hide window: $e');
    }
  }

  Future<void> _showWindow() async {
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
  Future<void> quitApplication() async {
    if (_quitRequested) return;
    _quitRequested = true;
    debugPrint('[DesktopAppService] Quitting from tray');
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
    // macOS 在最后一个窗口关闭后默认不退出，必须显式退出进程；
    // Windows/Linux 上 windowManager.destroy() 会结束消息循环，
    // 这里统一显式退出以保证确定性。
    exitApp(0);
  }
}
