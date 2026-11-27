import Flutter
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testLaunchScreenBackgroundMatchesBootstrapSurface() throws {
    let storyboard = UIStoryboard(name: "LaunchScreen", bundle: Bundle.main)
    let launchController = try XCTUnwrap(storyboard.instantiateInitialViewController())
    let backgroundColor = try XCTUnwrap(launchController.view.backgroundColor)
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    XCTAssertTrue(backgroundColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
    XCTAssertEqual(red, 30.0 / 255.0, accuracy: 0.000001)
    XCTAssertEqual(green, 30.0 / 255.0, accuracy: 0.000001)
    XCTAssertEqual(blue, 46.0 / 255.0, accuracy: 0.000001)
    XCTAssertEqual(alpha, 1.0, accuracy: 0.000001)
  }
}
