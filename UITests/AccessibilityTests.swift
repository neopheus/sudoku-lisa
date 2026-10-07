import XCTest

@MainActor
final class AccessibilityTests: XCTestCase {
    private func launch(largeText: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launchArguments += ["-UIPreferredContentSizeCategoryName",
                                largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Jouer"].waitForExistence(timeout: 15))
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable { return }
            if element.exists && element.frame.maxY < 150 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, "Control must remain reachable with large text: \(element)")
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLargestTextHomeSettingsAndPoulpiControls() {
        let app = launch(largeText: true)
        capture("AX-largest-home", app: app)
        app.buttons["Réglages"].tap()
        XCTAssertTrue(app.buttons["Terminé"].waitForExistence(timeout: 5))
        capture("AX-largest-settings", app: app)
        app.buttons["Terminé"].tap()
        app.tabBars.buttons["Poulpi"].tap()
        let closer = app.buttons["Rapprocher"]
        reveal(closer, in: app)
        closer.tap()
        capture("AX-largest-poulpi-controls", app: app)
        let reset = app.buttons["Recentrer"]
        // Move back up after the zoom control was revealed.
        for _ in 0..<5 { if reset.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(reset.isHittable)
        reset.tap()
    }

    func testDarkInterfaceGameAndProgressiveHint() {
        let app = launch()
        app.buttons["Réglages"].tap()
        app.buttons["themePicker"].tap()
        app.buttons["Nuit"].tap()
        app.buttons["Terminé"].tap()
        capture("AX-dark-home", app: app)
        app.tabBars.buttons["Chaque jour"].tap()
        let daily = app.buttons.containing(.staticText, identifier: "Jouer le défi").firstMatch
        reveal(daily, in: app)
        daily.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 15))
        capture("AX-dark-game", app: app)
        let hint = app.buttons["Indice"]
        reveal(hint, in: app)
        hint.tap()
        XCTAssertTrue(app.staticTexts["hintExplanation"].waitForExistence(timeout: 10))
        capture("AX-dark-hint", app: app)
        let next = app.buttons.containing(.staticText, identifier: "Voir la suite").firstMatch
        reveal(next, in: app)
        next.tap()
        XCTAssertTrue(app.buttons["hintTutorial"].exists)
        app.buttons["Fermer"].tap()
    }

    func testLargestTextGameEntryAndVictory() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-finale", "--uitest-zen", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let resume = app.buttons.containing(.staticText, identifier: "Reprendre ma partie").firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 15))
        reveal(resume, in: app)
        resume.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 15))
        for (index, value) in [(0, 1), (40, 9), (80, 8)] {
            let cell = app.buttons["cell-\(index)"]
            reveal(cell, in: app)
            cell.tap()
            let digit = app.buttons["digit-\(value)"]
            reveal(digit, in: app)
            if index == 0 { capture("AX-largest-game-keypad", app: app) }
            digit.tap()
            if index != 80 { XCTAssertTrue(cell.label.contains(", \(value)")) }
        }
        XCTAssertTrue(app.staticTexts["Bien joué, vous !"].waitForExistence(timeout: 10))
        capture("AX-largest-victory", app: app)
        let next = app.buttons["victoryContinue"]
        reveal(next, in: app)
        next.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 15))
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts["Bien joué, vous !"])
        waitForExpectations(timeout: 10)
    }

    func testLargestTextLessonCandidatesRemainReachable() {
        let app = launch(largeText: true)
        let learn = app.buttons.containing(.staticText, identifier: "Le déclic commence ici").firstMatch
        reveal(learn, in: app)
        learn.tap()
        let lesson = app.buttons["lesson-observation"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 10))
        reveal(lesson, in: app)
        lesson.tap()
        let cell = app.buttons["lesson-cell-0"]
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        reveal(cell, in: app)
        XCTAssertTrue(cell.label.contains("Ligne 1, colonne 1"))
        cell.tap()
        let guided = app.buttons.containing(.staticText, identifier: "Essayer avec Lisa").firstMatch
        reveal(guided, in: app)
        guided.tap()
        let digit = app.buttons["lesson-digit-1"]
        reveal(digit, in: app)
        capture("AX-largest-lesson-pad", app: app)
        XCTAssertTrue(app.buttons["lesson-close"].isHittable)
        app.buttons["lesson-close"].tap()
    }
}
