import XCTest

/// App Store screenshots from the demo data (launch argument -demo). Each shot is attached to the test result and,
/// when SCREENSHOT_DIR is set (TEST_RUNNER_SCREENSHOT_DIR in CI), written there as a PNG.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private var pad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    func testScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        if pad { XCUIDevice.shared.orientation = .landscapeLeft }

        let studio = app.descendants(matching: .any).matching(identifier: "mac-Mac Studio").firstMatch
        XCTAssertTrue(studio.waitForExistence(timeout: 20))
        settle()
        shot("02-macs")

        studio.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "toggleRun").firstMatch.waitForExistence(timeout: 10))
        settle()
        shot("03-mac")

        // the limits, further down the same page
        app.swipeUp()
        app.swipeUp()
        settle()
        shot("04-limits")

        if !pad {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            settle()
        }
        let nodes = app.descendants(matching: .any).matching(identifier: "nodes").firstMatch
        if nodes.waitForExistence(timeout: 5) {
            nodes.tap()
            settle()
            shot("05-nodes")
        }
    }

    func testSignIn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-signin"]
        app.launch()
        if pad { XCUIDevice.shared.orientation = .landscapeLeft }
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "passkey").firstMatch.waitForExistence(timeout: 20))
        settle()
        shot("01-signin")
    }

    private func settle() { Thread.sleep(forTimeInterval: 1.2) }

    private func shot(_ name: String) {
        let image = XCUIScreen.main.screenshot()
        let a = XCTAttachment(screenshot: image)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? UIDevice.current.name
            let folder = URL(fileURLWithPath: dir).appendingPathComponent(device)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? image.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
        }
    }
}
