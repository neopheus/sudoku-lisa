import XCTest

/// Authentic App Store images from a dedicated, reset simulator installation.
@MainActor
final class AppStoreScreenshotTests: XCTestCase {
    private func button(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons[title].firstMatch
    }

    private func settle() {
        let settled = expectation(description: "Navigation animation completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { settled.fulfill() }
        waitForExpectations(timeout: 3)
    }

    private func capture(_ name: String) {
        settle()
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // XCTest rounds this simulator's 393-point screen to 1178 pixels.
        // A host capture can read the native 1179-pixel framebuffer here.
        if ProcessInfo.processInfo.environment["LISA_NATIVE_CAPTURE"] == "1" {
            FileHandle.standardOutput.write(Data("APPSTORE_CAPTURE_READY:\(name)\n".utf8))
            let captured = expectation(description: "Native framebuffer capture window")
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { captured.fulfill() }
            waitForExpectations(timeout: 6)
        }
    }

    func testFrenchAppStoreScreenshots() { captureStore(language: "fr", locale: "fr_FR") }
    func testEnglishAppStoreScreenshots() { captureStore(language: "en", locale: "en_US") }
    func testGermanAppStoreScreenshots() { captureStore(language: "de", locale: "de_DE") }
    func testSpanishAppStoreScreenshots() { captureStore(language: "es", locale: "es_ES") }
    func testRussianAppStoreScreenshots() { captureStore(language: "ru", locale: "ru_RU") }

    private func localized(_ french: String, language: String) -> String {
        let labels: [String: [String: String]] = [
            "en": [
                "Jouer": "Play",
                "Choisir mon niveau": "Choose my level",
                "Chaque jour": "Every day",
                "Jouer le défi": "Play the challenge",
                "Indice": "Hint",
                "Voir la suite": "Next step",
                "Fermer": "Close",
                "Sauvegarder et revenir à l’accueil": "Save and return home",
                "Voyage": "Journey",
                "Étape 1, à jouer": "Stage 1, ready to play",
            ],
            "de": [
                "Jouer": "Spielen",
                "Choisir mon niveau": "Schwierigkeit wählen",
                "Chaque jour": "Jeden Tag",
                "Jouer le défi": "Aufgabe spielen",
                "Indice": "Hinweis",
                "Voir la suite": "Nächster Schritt",
                "Fermer": "Schließen",
                "Sauvegarder et revenir à l’accueil": "Speichern und zur Startseite",
                "Voyage": "Reise",
                "Étape 1, à jouer": "Etappe 1, spielbereit",
            ],
            "es": [
                "Jouer": "Jugar",
                "Choisir mon niveau": "Elegir mi nivel",
                "Chaque jour": "Cada día",
                "Jouer le défi": "Jugar el reto",
                "Indice": "Pista",
                "Voir la suite": "Siguiente paso",
                "Fermer": "Cerrar",
                "Sauvegarder et revenir à l’accueil": "Guardar y volver al inicio",
                "Voyage": "Viaje",
                "Étape 1, à jouer": "Etapa 1, disponible",
            ],
            "ru": [
                "Jouer": "Играть",
                "Choisir mon niveau": "Выбрать уровень",
                "Chaque jour": "Каждый день",
                "Jouer le défi": "Начать задание",
                "Indice": "Подсказка",
                "Voir la suite": "Дальше",
                "Fermer": "Закрыть",
                "Sauvegarder et revenir à l’accueil": "Сохранить и вернуться на главный экран",
                "Voyage": "Путешествие",
                "Étape 1, à jouer": "Этап 1, можно играть",
            ],
        ]
        return labels[language]?[french] ?? french
    }

    private func captureStore(language: String, locale: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.buttons[localized("Jouer", language: language)].waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(button(localized("Choisir mon niveau", language: language), in: app).exists)
        capture("\(language)-01-Accueil")

        // The daily puzzle uses the existing deterministic date seed.
        app.buttons[localized("Chaque jour", language: language)].tap()
        let daily = button(localized("Jouer le défi", language: language), in: app)
        XCTAssertTrue(daily.waitForExistence(timeout: 10))
        daily.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["digit-9"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["cancelGeneration"].exists)
        capture("\(language)-02-Grille-quotidienne")

        let hint = app.buttons[localized("Indice", language: language)]
        XCTAssertTrue(hint.isHittable)
        hint.tap()
        XCTAssertTrue(app.staticTexts["hintExplanation"].waitForExistence(timeout: 10))
        let next = button(localized("Voir la suite", language: language), in: app)
        XCTAssertTrue(next.isHittable)
        next.tap()
        capture("\(language)-03-Indice-explique")
        // Return to a clean game before opening the lesson library.
        app.buttons[localized("Fermer", language: language)].tap()
        app.buttons["gameLearnButton"].tap()
        XCTAssertTrue(app.buttons["lesson-close"].waitForExistence(timeout: 10))
        let lesson = app.buttons["lesson-observation"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 10))
        lesson.tap()
        XCTAssertTrue(app.buttons["lesson-cell-0"].waitForExistence(timeout: 10))
        capture("\(language)-04-Lecon-interactive")
        app.buttons["lesson-close"].tap()
        app.buttons[localized("Sauvegarder et revenir à l’accueil", language: language)].tap()

        app.buttons[localized("Voyage", language: language)].tap()
        XCTAssertTrue(app.buttons[localized("Étape 1, à jouer", language: language)].waitForExistence(timeout: 10))
        capture("\(language)-05-Voyage")

        app.buttons["Poulpi"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["poulpiStage"].firstMatch.waitForExistence(timeout: 10))
        capture("\(language)-06-Poulpi")
        app.terminate()
    }
}
