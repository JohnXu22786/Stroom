import Cocoa
import FlutterMacOS

struct PreferencesRequestBuffer {
  private(set) var isHandlerReady = false
  private(set) var hasPendingRequest = false

  mutating func requestPreferences() {
    hasPendingRequest = true
  }

  mutating func markHandlerReady() {
    isHandlerReady = true
  }

  mutating func takePendingRequestIfReady() -> Bool {
    guard isHandlerReady, hasPendingRequest else { return false }
    hasPendingRequest = false
    return true
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  private var preferencesRequests = PreferencesRequestBuffer()
  private weak var flutterViewController: FlutterViewController?
  private var menuChannel: FlutterMethodChannel?

  func registerFlutterViewController(_ viewController: FlutterViewController) {
    flutterViewController = viewController
    let channel = FlutterMethodChannel(
      name: "com.johntsui.stroom/menu",
      binaryMessenger: viewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "menuHandlerReady" else {
        result(FlutterMethodNotImplemented)
        return
      }

      self?.preferencesRequests.markHandlerReady()
      result(nil)
      DispatchQueue.main.async { [weak self] in
        self?.deliverPendingPreferencesRequest()
      }
    }
    menuChannel = channel
    deliverPendingPreferencesRequest()
  }

  @IBAction func openPreferences(_ sender: Any?) {
    preferencesRequests.requestPreferences()
    deliverPendingPreferencesRequest()
  }

  private func deliverPendingPreferencesRequest() {
    guard
      let flutterViewController,
      let window = flutterViewController.view.window,
      let menuChannel,
      preferencesRequests.takePendingRequestIfReady()
    else {
      return
    }

    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    menuChannel.invokeMethod("openSettings", arguments: nil)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // A ready tray keeps close-to-tray active by intercepting the window
    // close. When tray setup fails, the last window closes normally, so let
    // macOS terminate instead of leaving an unreachable background process.
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
