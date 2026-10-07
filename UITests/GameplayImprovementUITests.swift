import XCTest

@MainActor
final class GameplayImprovementUITests: XCTestCase {
    private func launchFixture() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-finale", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        let resume = app.buttons.containing(.staticText, identifier: "Reprendre ma partie").firstMatch
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        resume.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 10))
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.isHittable { return }
            if element.exists, element.frame.minY < app.frame.minY + 100 {
                app.swipeDown()
            } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
    }

    private func titleButton(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(.staticText, identifier: title).firstMatch
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testHintTutorialReturnsToUnchangedBoardAndExplainsBeforeApplying() {
        let app = launchFixture()
        let original = app.buttons["cell-0"].label
        let hint = titleButton("Indice", in: app)
        reveal(hint, in: app); hint.tap()
        XCTAssertTrue(app.staticTexts["hintExplanation"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["applyHint"].exists)
        let tutorial = app.buttons["hintTutorial"]
        reveal(tutorial, in: app); tutorial.tap()
        XCTAssertTrue(app.buttons["lesson-close"].waitForExistence(timeout: 10))
        capture(app, "Tutoriel-depuis-indice")
        app.buttons["lesson-close"].tap()
        XCTAssertTrue(app.staticTexts["hintExplanation"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["cell-0"].label, original)
        for _ in 0..<2 {
            let next = titleButton("Voir la suite", in: app)
            reveal(next, in: app); next.tap()
        }
        let apply = app.buttons["applyHint"]
        reveal(apply, in: app)
        capture(app, "Indice-etape-finale")
        apply.tap()
        XCTAssertTrue(app.buttons["cell-0"].label.contains(", 1"))
    }

    func testNumberFirstEntryAndNotesRemainDistinct() {
        let app = launchFixture()
        app.buttons["gameSettingsButton"].tap()
        let setting = app.switches["numberFirstToggle"]
        reveal(setting, in: app)
        setting.switches.firstMatch.exists ? setting.switches.firstMatch.tap() : setting.tap()
        app.buttons["Terminé"].tap()
        let digit = app.buttons["digit-1"]
        reveal(digit, in: app); digit.tap()
        app.buttons["cell-0"].tap()
        XCTAssertTrue(app.buttons["cell-0"].label.contains(", 1"))
        let notes = titleButton("Notes", in: app)
        reveal(notes, in: app); notes.tap()
        XCTAssertTrue(app.staticTexts["notesModeBanner"].exists || app.otherElements["notesModeBanner"].exists)
        app.buttons["cell-40"].tap()
        XCTAssertTrue(app.buttons["cell-40"].label.contains("notes 1"))
        capture(app, "Saisie-chiffre-verrouille-et-notes")
    }

    func testDailyDoesNotReplaceJourneyAndNotesSurviveRelaunch() {
        let app = launchFixture()
        app.buttons["cell-0"].tap()
        let notes = titleButton("Notes", in: app)
        reveal(notes, in: app); notes.tap()
        app.buttons["digit-1"].tap()
        let savedCell = app.buttons["cell-0"].label
        app.buttons["Sauvegarder et revenir à l’accueil"].tap()
        app.tabBars.buttons["Chaque jour"].tap()
        let daily = titleButton("Jouer le défi", in: app)
        reveal(daily, in: app); daily.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        app.buttons["Sauvegarder et revenir à l’accueil"].tap()
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Voyage"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Voyage"].tap()
        let journey = app.buttons["Étape 5, à jouer"]
        reveal(journey, in: app); journey.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["cell-0"].label, savedCell)
        capture(app, "Voyage-repris-apres-defi-quotidien")
    }

    func testJourneyRewardAndDirectContinuation() {
        let app = launchFixture()
        for (cell, digit) in [(0, 1), (40, 9), (80, 8)] {
            app.buttons["cell-\(cell)"].tap()
            let key = app.buttons["digit-\(digit)"]
            reveal(key, in: app); key.tap()
        }
        let victoryVisible = app.staticTexts["Bien joué, vous !"].waitForExistence(timeout: 10)
        capture(app, "Victoire-avant-equipement")
        XCTAssertTrue(victoryVisible)
        let equip = app.buttons["equipVictoryStar"]
        reveal(equip, in: app); equip.tap()
        XCTAssertFalse(equip.isEnabled)
        capture(app, "Premiere-recompense-Poulpi")
        let next = app.buttons["victoryContinue"]
        reveal(next, in: app); next.tap()
        XCTAssertTrue(app.buttons["gameLearnButton"].waitForExistence(timeout: 10))
        let preparationFinished = NSPredicate(format: "exists == false")
        expectation(for: preparationFinished, evaluatedWith: app.buttons["cancelGeneration"])
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.buttons["victoryContinue"].exists)
        XCTAssertTrue(app.buttons["digit-1"].isEnabled, "Continuation must open a playable new puzzle")
        XCTAssertFalse(app.buttons["cell-80"].isSelected, "The new puzzle must not retain the old cell selection")
        capture(app, "Prochaine-etape-prete-a-jouer")
        app.buttons["Sauvegarder et revenir à l’accueil"].tap()
        app.tabBars.buttons["Poulpi"].tap()
        reveal(app.buttons["poulpiStarToggle"], in: app)
        XCTAssertEqual(app.buttons["poulpiStarToggle"].label, "Retirer")
        capture(app, "Poulpi-souvenir-equipe")
    }

    func testLibraryHasFiveLessonsAndObservationExerciseCompletes() {
        let app = launchFixture()
        app.buttons["gameLearnButton"].tap()
        XCTAssertTrue(app.buttons["lesson-close"].waitForExistence(timeout: 10))
        capture(app, "Bibliotheque-cinq-lecons")
        for id in ["observation", "nakedSingle", "hiddenSingle", "lockedCandidates", "nakedPair"] {
            XCTAssertTrue(app.buttons["lesson-" + id].exists)
        }
        let observation = app.buttons["lesson-observation"]
        reveal(observation, in: app); observation.tap()
        let demonstrate = titleButton("Voir la déduction", in: app)
        reveal(demonstrate, in: app); demonstrate.tap()
        XCTAssertTrue(app.buttons["lesson-cell-0"].label.contains(": 6"))
        capture(app, "Lecon-observation-demonstration")
        let guided = titleButton("Essayer avec Lisa", in: app)
        reveal(guided, in: app); guided.tap()
        let first = app.buttons["lesson-cell-0"]
        reveal(first, in: app); first.tap()
        let six = app.buttons["lesson-digit-6"]
        reveal(six, in: app); six.tap()
        let independent = titleButton("Essayer seul", in: app)
        XCTAssertTrue(independent.waitForExistence(timeout: 5))
        reveal(independent, in: app); independent.tap()
        let practice = app.buttons["lesson-cell-30"]
        reveal(practice, in: app); practice.tap()
        let one = app.buttons["lesson-digit-1"]
        reveal(one, in: app); one.tap()
        let complete = titleButton("J’ai compris !", in: app)
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        reveal(complete, in: app); complete.tap()
        let restart = app.buttons["Recommencer cette leçon"]
        XCTAssertTrue(restart.waitForExistence(timeout: 5))
        reveal(restart, in: app)
        capture(app, "Lecon-observation-exercice-autonome-reussi")
    }

}
