import Flutter
import UIKit
import BackgroundTasks

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Method channel name — must match
  /// lib/services/ios_continued_task_service.dart.
  private static let channelName = "com.johntsui.stroom/ios_continued_task"

  /// Identifier of the BGContinuedProcessingTask. Must match the
  /// `BGTaskSchedulerPermittedIdentifiers` entry in Info.plist
  /// (`$(PRODUCT_BUNDLE_IDENTIFIER).continuedTask`).
  private var taskIdentifier: String {
    (Bundle.main.bundleIdentifier ?? "com.johntsui.stroom") + ".continuedTask"
  }

  /// Currently active continued processing task (one at a time).
  /// 只允许在主线程读写（launch handler 已跳回主队列）。
  private var continuedTask: BGContinuedProcessingTask?

  /// 已提交但系统尚未启动（launch handler 未回调）的挂起状态。
  /// 防止挂起窗口内重复提交产生错误日志噪音。
  private var taskSubmitted = false

  private var launchHandlerRegistered = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 注册 BGContinuedProcessingTask 的启动处理器（iOS 26+）。
    // 该 API 允许在应用启动完成后动态注册，但启动时注册最稳妥：
    // 后台拉起（任务恢复执行）时进程从 didFinishLaunching 开始。
    registerContinuedTaskLaunchHandler()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupContinuedTaskChannel(with: engineBridge.pluginRegistry)
  }

  // ==========================================================================
  // BGContinuedProcessingTask（iOS 26+ 常驻后台）
  // ==========================================================================
  //
  // 机制：任务在 App 前台由用户操作启动时，Dart 侧通过 MethodChannel
  // 提交一个「继续处理任务」。用户切到后台/锁屏后，系统保持进程运行，
  // Dart 任务执行器继续工作，并在系统 UI（灵动岛/锁屏）显示进度。
  // 全部任务结束后 Dart 侧调用 complete，此处调用 setTaskCompleted。
  //
  // 仅 iOS 26.0+ 可用；低版本调用方不会进入（Dart 侧已做版本门控），
  // 本文件所有 API 均以 #available 守卫，旧系统上完全无副作用。

  private func registerContinuedTaskLaunchHandler() {
    guard #available(iOS 26.0, *) else { return }
    guard !launchHandlerRegistered else { return }
    launchHandlerRegistered = true

    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: taskIdentifier,
      using: nil
    ) { [weak self] task in
      // launch handler 在系统后台队列执行，而 continuedTask 的读写
      // 全部发生在主线程（MethodChannel handler）。必须跳回主队列，
      // 否则与 updateProgress/complete 存在数据竞争。
      DispatchQueue.main.async {
        guard let self = self, let continued = task as? BGContinuedProcessingTask else {
          return
        }
        if !self.taskSubmitted {
          // 竞态：complete() 在挂起窗口已处理过本提交（cancel 未赶上，
          // 系统仍启动了本任务）。立即结束，避免无人完成的幽灵任务
          // 占用标识符、残留锁屏进度并阻塞后续提交。
          continued.setTaskCompleted(success: true)
          return
        }
        // 系统开始运行/恢复该任务：持有引用，等待 Dart 侧上报进度与完成。
        self.continuedTask = continued
        self.taskSubmitted = false
        continued.expirationHandler = {
          // 系统资源压力下任务被终止：同样在主队列清理引用
          //（expirationHandler 可能在任意队列回调）。
          DispatchQueue.main.async { [weak self] in
            self?.continuedTask = nil
          }
        }
      }
    }
  }

  private func setupContinuedTaskChannel(with registry: FlutterPluginRegistry) {
    let registrar = registry.registrar(forPlugin: "IosContinuedTaskBridge")
    guard let messenger = registrar.messenger?() else { return }
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate deallocated", details: nil))
        return
      }
      switch call.method {
      case "submit":
        let title = (call.arguments as? [String: Any])?["title"] as? String ?? "Stroom 后台任务"
        self.submitContinuedTask(title: title)
        result(nil as Void?)
      case "updateProgress":
        let percent = (call.arguments as? [String: Any])?["percent"] as? Int ?? 0
        self.updateContinuedTaskProgress(percent)
        result(nil as Void?)
      case "complete":
        self.completeContinuedTask()
        result(nil as Void?)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// 提交常驻后台任务请求。
  ///
  /// 幂等：已激活（continuedTask != nil）或已提交尚未启动
  /// （taskSubmitted）时跳过，避免重复提交被系统拒绝产生错误日志；
  /// 任务完成/过期后（两个标志都清空）下一次同步会自动重新提交。
  private func submitContinuedTask(title: String) {
    guard #available(iOS 26.0, *) else { return }
    guard continuedTask == nil && !taskSubmitted else { return }
    registerContinuedTaskLaunchHandler()
    let request = BGContinuedProcessingTaskRequest(
      identifier: taskIdentifier,
      title: title,
      subtitle: "后台任务运行中"
    )
    do {
      try BGTaskScheduler.shared.submit(request)
      taskSubmitted = true
    } catch {
      // 系统限制（例如后台状态下重新提交被拒）：不影响已有保护，仅记录。
      NSLog("[IosContinuedTask] submit failed: \(error)")
    }
  }

  /// 更新系统进度 UI（0–100）。
  private func updateContinuedTaskProgress(_ percent: Int) {
    guard #available(iOS 26.0, *), let task = continuedTask else { return }
    let clamped = max(0, min(100, percent))
    let progress = task.progress
    progress.totalUnitCount = 100
    progress.completedUnitCount = Int64(clamped)
    task.updateTitle("Stroom 后台任务", subtitle: "已完成 \(clamped)%")
  }

  /// 全部任务结束：通知系统本任务完成。
  ///
  /// 若任务尚在"已提交未启动"的挂起窗口（例如任务瞬间失败），
  /// 直接取消挂起请求，避免系统稍后启动一个无人完成的"幽灵任务"
  /// （锁屏残留进度 UI，且会阻塞后续提交）。
  private func completeContinuedTask() {
    guard #available(iOS 26.0, *) else { return }
    if let task = continuedTask {
      task.setTaskCompleted(success: true)
      continuedTask = nil
      return
    }
    if taskSubmitted {
      BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
      taskSubmitted = false
    }
  }
}
