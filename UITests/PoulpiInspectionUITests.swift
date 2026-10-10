import XCTest

@MainActor
final class PoulpiInspectionUITests: XCTestCase {
    func testInspectionCanPauseAndSelectEveryAngle() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--poulpi-inspection-sequence"]
        app.launch()
        let step = app.staticTexts["poulpiInspectionStep"]
        XCTAssertTrue(step.waitForExistence(timeout: 10))
        app.buttons["poulpiInspectionPause"].tap()
        XCTAssertTrue(step.label.hasPrefix("1/"))
        app.buttons["poulpiInspectionNext"].tap()
        app.buttons["poulpiInspectionPause"].tap()
        XCTAssertTrue(step.label.hasPrefix("2/"))
        app.buttons["poulpiInspectionNext"].tap()
        app.buttons["poulpiInspectionPause"].tap()
        XCTAssertTrue(step.label.hasPrefix("3/"))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Poulpi-inspection-angle"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
