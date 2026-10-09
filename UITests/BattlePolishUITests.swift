import XCTest

@MainActor
final class BattlePolishUITests: XCTestCase {
    func testFourParticipantsProgressAndDigitInformation() {
        let app = launch()
        let selectedPlayer = app.buttons["battleParticipant-peer-fixture"]
        XCTAssertTrue(selectedPlayer.waitForExistence(timeout: 8))
        for id in ["peer-fixture", "peer-fixture-2", "peer-fixture-3"] {
            XCTAssertTrue(app.buttons["battleParticipant-\(id)"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["battleStats-\(id)"].exists)
        }
        attach(app, "Battle-4-Pastilles")
        selectedPlayer.tap()
        let playerStats = app.descendants(matching: .any)["battleStats-peer-fixture"]
        XCTAssertTrue(playerStats.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["battleProgress-peer-fixture"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["battleMistakes-peer-fixture"].exists)
        selectedPlayer.tap()
        tap(app.buttons["battleCell-0"], in: app)
        let one = app.buttons["battleDigit-1"]
        reveal(one, in: app)
        XCTAssertTrue(one.label.contains("restant"))
        attach(app, "Battle-Clavier-Compteurs")
        one.tap()
        selectedPlayer.tap()
        let updatedStats = app.descendants(matching: .any)["battleStats-peer-fixture"]
        XCTAssertTrue(updatedStats.waitForExistence(timeout: 2))
        let updatedProgress = app.staticTexts["battleProgress-peer-fixture"]
        XCTAssertTrue(updatedProgress.label.contains("8"), "A simulated opponent update must reach the selected player's stats")
        attach(app, "Battle-Stats-Joueur")
        attach(app, "Battle-Progression-Adverse")
        app.terminate()
    }

    func testDigitLockNotesAndGivenProtection() {
        let app = launch()
        let digit = app.buttons["battleDigit-1"]
        reveal(digit, in: app)
        digit.press(forDuration: 0.8)
        let unlock = app.buttons["battleUnlockDigit"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 3))
        tap(app.buttons["battleCell-1"], in: app)
        XCTAssertTrue(app.buttons["battleCell-1"].label.contains("chiffre donné"))
        tap(app.buttons["battleCell-0"], in: app)
        XCTAssertFalse(app.buttons["battleCell-0"].label.contains("vide"))
        tap(unlock, in: app)
        tap(app.buttons["battleUndo"], in: app)
        tap(app.buttons["battleNotes"], in: app)
        tap(digit, in: app)
        let cell = app.buttons["battleCell-0"]
        reveal(cell, in: app)
        XCTAssertTrue(cell.label.contains("vide"))
        XCTAssertTrue(cell.label.contains("notes"))
        app.terminate()
    }

    func testFourParticipantsAtAccessibilitySize() {
        let app = launch(large: true)
        let lastPlayer = app.buttons["battleParticipant-peer-fixture-3"]
        reveal(lastPlayer, in: app)
        XCTAssertTrue(lastPlayer.isHittable)
        lastPlayer.tap()
        let last = app.descendants(matching: .any)["battleStats-peer-fixture-3"]
        reveal(last, in: app)
        XCTAssertTrue(last.isHittable)
        XCTAssertLessThanOrEqual(last.frame.maxX, app.frame.width)
        attach(app, "Battle-Pastilles-Grand-Texte")
        let digit = app.buttons["battleDigit-1"]
        reveal(digit, in: app)
        XCTAssertTrue(digit.isHittable)
        XCTAssertTrue(digit.label.contains("restant"))
        attach(app, "Battle-Clavier-Grand-Texte")
        app.terminate()
    }

    private func launch(large: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-finale", "--uitest-battle", "--uitest-battle-four", "--uitest-battle-progress",
            "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR", "-UIPreferredContentSizeCategoryName",
            large ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        if large { app.launchArguments.append("--uitest-battle-long-names") }
        app.launch()
        app.buttons["openBattle"].tap()
        XCTAssertTrue(app.buttons["battleCell-0"].waitForExistence(timeout: 10))
        return app
    }
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        reveal(element, in: app)
        XCTAssertTrue(element.isHittable)
        element.tap()
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<30 {
            if element.isHittable { return }
            if element.exists && element.frame.midY < app.frame.midY { app.swipeDown() }
            else { app.swipeUp() }
        }
    }
    private func attach(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
