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

  // TODO(#540): BGContinuedProcessingTask does not ship in the current
  // Xcode SDK — the task-registration / submit / progress / complete
  // carrier is not built until the API ships (Dart-side is also gated).

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupContinuedTaskChannel(with: engineBridge.pluginRegistry)
    setupStorageChannel(with: engineBridge.pluginRegistry)
  }

  // ==========================================================================
  // 存储信息通道（磁盘剩余空间）
  // ==========================================================================
  //
  // 与 lib/services/backup_location_manager.dart 中的
  // com.johntsui.stroom/storage 通道对应，用于自动备份的空间预检
  // 与「剩余空间 < 5× 备份大小」的清理提醒。
  // 注意：通道名不可与原生插件包名冲突，这里使用与应用相同的
  // com.johntsui.stroom 前缀。

  private func setupStorageChannel(with registry: FlutterPluginRegistry) {
    let registrar = registry.registrar(forPlugin: "StorageBridge")
    let channel = FlutterMethodChannel(
      name: "com.johntsui.stroom/storage",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getFreeSpace":
        // 查询应用 Documents 所在文件系统的剩余空间
        let attrs = try? FileManager.default.attributesOfFileSystem(
          forPath: NSHomeDirectory()
        )
        let free = (attrs?[.systemFreeSize] as? NSNumber)?.int64Value ?? -1
        result(free)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Method channel skeleton — fully functional but every call is a no-op
  /// until the BGContinuedProcessingTask carrier ships (see TODO above).
  private func setupContinuedTaskChannel(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "IosContinuedTaskBridge") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard self != nil else {
        result(FlutterError(code: "unavailable", message: "AppDelegate deallocated", details: nil))
        return
      }
      switch call.method {
      case "submit", "updateProgress", "complete":
        result(nil as Void?)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
