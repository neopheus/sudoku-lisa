import XCTest

@MainActor
final class BattleUITests: XCTestCase {
    func testBattleCountdownInputPodiumAndSoloPreserved() {
        let app = launch(fixture: true)
        openBattle(app)
        XCTAssertTrue(app.staticTexts["battleCountdown"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["battleCell-0"].exists, "Puzzle must stay hidden before the common start")
        let first = app.buttons["battleCell-0"]
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        tap(first, in: app)
        tap(app.buttons["battleDigit-2"], in: app)
        tap(app.buttons["battleUndo"], in: app)
        XCTAssertTrue(first.label.contains("vide"))
        tap(app.buttons["battleNotes"], in: app)
        tap(app.buttons["battleDigit-1"], in: app)
        XCTAssertTrue(first.label.contains("vide"), "A note must not fill the cell")
        tap(app.buttons["battleNotes"], in: app)
        for (index, value) in [(0, 1), (40, 9), (80, 8)] {
            tap(app.buttons["battleCell-\(index)"], in: app)
            tap(app.buttons["battleDigit-\(value)"], in: app)
        }
        XCTAssertTrue(app.staticTexts["battlePodium"].waitForExistence(timeout: 5))
        attach(app, name: "Battle-Podium-local-fixture")
        app.buttons["leaveBattle"].tap()
        let resume = app.buttons["Reprendre ma partie"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        tap(resume, in: app)
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cell-0"].label.contains("vide"), "Battle must not edit the original solo grid")
        app.buttons["Sauvegarder et revenir à l’accueil"].tap()
        app.tabBars.buttons["Poulpi"].tap()
        let headband = app.buttons["poulpiAccessory-headband"]
        tap(headband, in: app)
        XCTAssertTrue(headband.isEnabled, "A finished battle unlocks its cosmetic reward")
    }

    func testBattleWelcomeWithoutGameCenterAndPoulpiColorPersists() {
        let app = launch(fixture: false)
        openBattle(app)
        XCTAssertTrue(app.buttons["battleInvite"].waitForExistence(timeout: 5))
        attach(app, name: "Battle-Accueil")
        app.buttons["leaveBattle"].tap()
        app.tabBars.buttons["Poulpi"].tap()
        let color = app.buttons["poulpiColor-lagoon"]
        tap(color, in: app)
        XCTAssertTrue(color.isSelected)
        attach(app, name: "Poulpi-Personnalisation")
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        app.tabBars.buttons["Poulpi"].tap()
        reveal(color, in: app)
        XCTAssertTrue(color.isSelected, "Chosen color survives relaunch")
        let crown = app.buttons["poulpiAccessory-crown"]
        reveal(crown, in: app)
        XCTAssertFalse(crown.isEnabled, "Locked cosmetics cannot be equipped")
    }

    func testBattleAtAccessibilityTextSize() {
        let app = launch(fixture: true, largeText: true)
        openBattle(app)
        XCTAssertTrue(app.buttons["battleCell-0"].waitForExistence(timeout: 8))
        tap(app.buttons["battleCell-0"], in: app)
        tap(app.buttons["battleDigit-1"], in: app)
        reveal(app.buttons["battleCell-0"], in: app)
        XCTAssertFalse(app.buttons["battleCell-0"].label.contains("vide"))
        attach(app, name: "Battle-Accessibilite")
    }

    private func launch(fixture: Bool, largeText: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-finale", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
                               "-UIPreferredContentSizeCategoryName", largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        if fixture { app.launchArguments.append("--uitest-battle") }
        app.launch()
        return app
    }

    private func openBattle(_ app: XCUIApplication) { tap(app.buttons["openBattle"], in: app) }
    private func tap(_ element: XCUIElement, in app: XCUIApplication) { reveal(element, in: app); if !element.isHittable { print(app.debugDescription) }; XCTAssertTrue(element.isHittable); element.tap() }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable { return }
            if element.exists {
                let frame = element.frame
                if frame.midY > app.frame.minY + 120 && frame.midY < app.frame.maxY - 110 { return }
                if frame.midY < app.frame.midY { app.swipeDown() } else { app.swipeUp() }
            } else { app.swipeUp() }
        }
    }
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
