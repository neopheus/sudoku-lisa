import XCTest
import UIKit

@MainActor
final class SceneryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    private func launch(_ stop: String, extra: [String] = []) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["LISA_UI_TESTING"] = "1"
        app.launchArguments = ["--uitest-reset", "--uitest-finale", "--uitest-scenery", stop,
                               "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"] + extra
        app.launch()
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.isHittable { return }
            if element.exists && element.frame.minY < app.frame.minY + 80 { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ title: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = title; image.lifetime = .keepAlways; add(image)
    }
    func testFiveWorldsOnSmallScreenLightDarkAndLandscape() {
        for stop in ["garden-1", "candyForest-2", "lagoon-3", "frost-4", "stars-4"] {
            for dark in [false, true] {
                XCUIDevice.shared.orientation = .portrait
                let app = launch(stop, extra: dark ? ["--uitest-dark"] : [])
                XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 10))
                XCTAssertTrue(app.buttons["cell-80"].isHittable)
                XCTAssertTrue(app.buttons["gameSettingsButton"].isHittable)
                capture(app, "\(stop)-\(dark ? "dark" : "light")-portrait")
                XCUIDevice.shared.orientation = .landscapeLeft
                let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    app.buttons["digit-9"].isHittable && app.buttons["cell-80"].isHittable
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
                capture(app, "\(stop)-\(dark ? "dark" : "light")-landscape")
                app.terminate()
            }
        }
    }
    func testArrivalFinishesAndNeverReplaysAfterResume() {
        let app = launch("lagoon-1", extra: ["--uitest-introduction"])
        let skip = app.buttons["skipSceneryIntroduction"]
        if skip.waitForExistence(timeout: 1) { skip.tap() }
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 4))
        XCTAssertFalse(skip.exists)
        app.buttons["Sauvegarder et revenir à l’accueil"].tap()
        let resume = app.buttons.containing(.staticText, identifier: "Reprendre ma partie").firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 5)); resume.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
        XCTAssertFalse(skip.exists)
    }
    func testPaperAndDisabledDecorBypassArrival() {
        for setting in ["--uitest-paper", "--uitest-static"] {
            let app = launch("stars-3", extra: ["--uitest-introduction", setting])
            XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["skipSceneryIntroduction"].exists)
            capture(app, setting)
            app.terminate()
        }
    }
    func testVictoryContinueImmediatelyAvailableAndNextStopPreview() {
        let app = launch("garden-4")
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 10))
        for (cell, digit) in [(0, 1), (40, 9), (80, 8)] {
            let square = app.buttons["cell-\(cell)"]
            reveal(square, in: app); square.tap()
            let key = app.buttons["digit-\(digit)"]
            reveal(key, in: app); key.tap()
        }
        let next = app.buttons["victoryContinue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5)); XCTAssertTrue(next.isHittable)
        capture(app, "victory-continue-small-screen")
        let preview = app.descendants(matching: .any).matching(identifier: "nextSceneryPreview").firstMatch
        reveal(preview, in: app)
        XCTAssertTrue(preview.exists)
        capture(app, "victory-next-world-preview")
        next.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 10))
    }
    func testArrivalSkipInLandscapeLargeTextAndBackground() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled, "This inspection requires motion enabled; reduced motion bypasses the introduction.")
        let app = launch("stars-4", extra: ["--uitest-introduction", "--uitest-hold-introduction",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let skip = app.buttons["skipSceneryIntroduction"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(skip.isHittable)
        capture(app, "arrival-landscape-accessibility")
        skip.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
        XCTAssertFalse(skip.exists)
        app.terminate()
        let second = launch("garden-1", extra: ["--uitest-introduction", "--uitest-hold-introduction"])
        XCTAssertTrue(second.buttons["skipSceneryIntroduction"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        second.activate()
        XCTAssertFalse(second.buttons["skipSceneryIntroduction"].exists)
    }

}
