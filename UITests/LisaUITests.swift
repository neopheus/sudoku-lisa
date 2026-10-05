import XCTest

@MainActor
final class LisaUITests: XCTestCase {
    private func launchFresh() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Jouer"].waitForExistence(timeout: 10))
        return app
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func button(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(.staticText, identifier: title).firstMatch
    }

    func testPlayNotesUndoPauseAndResume() {
        let app = launchFresh()
        attach(app, name: "01-Accueil")
        let start = button("C’est parti !", in: app)
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let easy = app.buttons.containing(.staticText, identifier: "Facile").firstMatch
        XCTAssertTrue(easy.waitForExistence(timeout: 5))
        easy.tap()

        let empty = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Ligne ", ", vide")).firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 15))
        let nine = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "9, ")).firstMatch
        XCTAssertTrue(nine.isHittable, "All nine digits must be reachable without scrolling away from the board")
        let coordinate = empty.label.components(separatedBy: ", vide")[0]
        empty.tap()
        let notes = button("Notes", in: app)
        XCTAssertTrue(notes.exists)
        notes.tap()
        let one = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "1, ")).firstMatch
        if !one.isHittable { app.swipeUp() }
        one.tap()
        let notedCell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", coordinate, "notes 1")).firstMatch
        XCTAssertTrue(notedCell.waitForExistence(timeout: 5), "Adding a candidate must update the actual board cell")
        button("Annuler", in: app).tap()
        XCTAssertFalse(notedCell.exists, "Undo must remove the candidate")

        button("Notes oui", in: app).tap()
        one.tap()
        let filledCell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", coordinate + ", 1")).firstMatch
        XCTAssertTrue(filledCell.waitForExistence(timeout: 5), "A number input must change the selected cell")
        if !app.buttons["Mettre en pause"].isHittable { app.swipeDown() }
        attach(app, name: "02-Partie")
        app.buttons["Mettre en pause"].tap()
        XCTAssertTrue(app.staticTexts["Votre grille vous attend."].waitForExistence(timeout: 5))
        button("Reprendre", in: app).tap()
        XCTAssertFalse(app.staticTexts["Votre grille vous attend."].exists)
        app.buttons["Sauvegarder et revenir à l’accueil"].tap()
        let resume = button("Reprendre ma partie", in: app)
        XCTAssertTrue(resume.waitForExistence(timeout: 5))

        // Relaunch without resetting: prove persistence across process termination.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        resume.tap()
        XCTAssertTrue(filledCell.waitForExistence(timeout: 5))
        attach(app, name: "03-Reprise-persistée")
    }

    func testDailyCalendarAndNightSetting() {
        let app = launchFresh()
        app.tabBars.buttons["Chaque jour"].tap()
        let daily = button("Jouer le défi", in: app)
        XCTAssertTrue(daily.waitForExistence(timeout: 5))
        attach(app, name: "04-Calendrier")
        // The calendar is scrollable on compact phones. Bring the whole glossy
        // button above the tab bar rather than tapping a partially exposed rim.
        if daily.frame.maxY > app.tabBars.firstMatch.frame.minY - 8 { app.swipeUp() }
        daily.tap()
        XCTAssertTrue(app.buttons["Mettre en pause"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Quotidien"].exists)
        app.buttons["Sauvegarder et revenir à l’accueil"].tap()
        app.tabBars.buttons["Jouer"].tap()
        app.buttons["Réglages"].tap()
        let theme = app.buttons["themePicker"]
        XCTAssertTrue(theme.waitForExistence(timeout: 5))
        theme.tap()
        let night = app.buttons["Nuit"]
        XCTAssertTrue(night.waitForExistence(timeout: 5))
        night.tap()
        XCTAssertTrue(theme.label.contains("Nuit") || (theme.value as? String)?.contains("Nuit") == true || app.staticTexts["Nuit"].exists)
        attach(app, name: "05-Réglages-nuit")
        app.buttons["Terminé"].tap()
        app.buttons["Réglages"].tap()
        XCTAssertTrue(theme.waitForExistence(timeout: 5))
        XCTAssertTrue(theme.label.contains("Nuit") || (theme.value as? String)?.contains("Nuit") == true || app.staticTexts["Nuit"].exists, "Night setting must survive closing settings")
    }
}
