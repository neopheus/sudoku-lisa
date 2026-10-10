import XCTest

@MainActor
final class SaveRecoveryUITests: XCTestCase {
    func testUnreadableSaveOffersRetryExactExportAndPersistentRecoveryAccess() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-unreadable-save", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        let retry = app.buttons["saveRecoveryRetry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["saveRecoveryExport"].exists)
        // A failed retry leaves recovery available rather than enabling writes.
        retry.tap()
        let status = app.staticTexts["saveRecoveryStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("reste illisible"))
        app.buttons["saveRecoveryExport"].tap()
        XCTAssertTrue(app.buttons["saveRecoveryShare"].waitForExistence(timeout: 5))
        app.buttons["saveRecoveryClose"].tap()
        let reopen = app.buttons["saveRecoveryOpen"]
        XCTAssertTrue(reopen.waitForExistence(timeout: 5))
        reopen.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Sauvegarde-protegee"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
