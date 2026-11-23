import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
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
