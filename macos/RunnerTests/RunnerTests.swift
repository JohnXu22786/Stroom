import Cocoa
import FlutterMacOS
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  @MainActor
  func testLastWindowCloseAllowsApplicationToTerminate() {
    XCTAssertTrue(
      AppDelegate().applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared)
    )
  }

}
