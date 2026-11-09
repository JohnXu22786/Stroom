import Cocoa
import FlutterMacOS
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  @MainActor
  func testLastWindowCloseKeepsApplicationRunningInBackground() {
    XCTAssertFalse(
      AppDelegate().applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
    )
  }

}
