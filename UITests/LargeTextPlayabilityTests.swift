import XCTest

@MainActor
final class LargeTextPlayabilityTests: XCTestCase {
    @objc func testLargestTextKeepsBoardAndEveryDigitVisibleDuringEntry() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-finale", "--uitest-zen",
                               "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let resume = app.buttons.containing(.staticText, identifier: "Reprendre ma partie").firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 15))
        for _ in 0..<10 { if resume.isHittable { break }; app.swipeUp() }
        resume.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 15))

        // No scrolling is allowed between selecting a case and entering a digit.
        for index in [0, 40, 80] { XCTAssertTrue(app.buttons["cell-\(index)"].isHittable) }
        for digit in 1...9 {
            let button = app.buttons["digit-\(digit)"]
            XCTAssertTrue(button.isHittable)
            XCTAssertTrue(app.frame.contains(button.frame), "Digit must be entirely visible: \(digit)")
        }
        for index in [0, 40, 80] {
            XCTAssertTrue(app.frame.contains(app.buttons["cell-\(index)"].frame))
        }
        XCTAssertTrue(app.buttons["Notes"].isHittable)
        XCTAssertTrue(app.buttons["Indice"].isHittable)
        app.buttons["cell-0"].tap()
        app.buttons["digit-1"].tap()
        XCTAssertTrue(app.buttons["cell-0"].label.contains(", 1"))
        XCTAssertTrue(app.buttons["cell-80"].isHittable)
        XCTAssertTrue(app.buttons["digit-9"].isHittable)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Largest-text-playable-board-and-keypad"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        app.buttons["gameDetailsButton"].tap()
        XCTAssertTrue(app.staticTexts["selectedCellDetail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["selectedCellDetail"].label.contains("Ligne 1, colonne 1"))
        app.buttons["Terminé"].tap()
        XCTAssertTrue(app.buttons["digit-9"].isHittable)
    }
}
