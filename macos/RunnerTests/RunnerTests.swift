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

  func testPreferencesRequestWaitsUntilFlutterSignalsReadiness() {
    var requests = PreferencesRequestBuffer()

    requests.requestPreferences()
    XCTAssertFalse(requests.takePendingRequestIfReady())

    requests.markHandlerReady()
    XCTAssertTrue(requests.takePendingRequestIfReady())
    XCTAssertFalse(requests.takePendingRequestIfReady())
  }

}
