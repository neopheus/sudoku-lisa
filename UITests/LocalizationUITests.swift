import XCTest

@MainActor
final class LocalizationUITests: XCTestCase {
    func testAllFiveLanguages() {
        continueAfterFailure = false
        let cases = [
            ("fr", "fr_FR", "Jouer", "Chaque jour", "Voyage", "Mes progrès", "Réglages", "À votre goût", "Langue", "Terminé", "C’est parti !", "Facile", "Gommer"),
            ("en", "en_US", "Play", "Every day", "Journey", "My progress", "Settings", "Make it yours", "Language", "Done", "Let's play!", "Easy", "Erase"),
            ("ru", "ru_RU", "Играть", "Каждый день", "Путешествие", "Мои успехи", "Настройки", "На ваш вкус", "Язык", "Готово", "Начнём!", "Лёгкий", "Стереть"),
            ("de", "de_DE", "Spielen", "Jeden Tag", "Reise", "Mein Fortschritt", "Einstellungen", "Dein Stil", "Sprache", "Fertig", "Los geht’s!", "Leicht", "Radieren"),
            ("es", "es_ES", "Jugar", "Cada día", "Viaje", "Mi progreso", "Ajustes", "A tu gusto", "Idioma", "Listo", "¡Vamos allá!", "Fácil", "Borrar")
        ]
        for (language, locale, play, daily, journey, progress, settings, settingsTitle, languageTitle, done, start, easy, erase) in cases {
            let app = XCUIApplication()
            app.launchArguments = ["--uitest-reset", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
            app.launch()
            for title in [play, daily, journey, progress] {
                XCTAssertTrue(app.tabBars.buttons[title].waitForExistence(timeout: 15), "\(language): \(title)")
            }
            screenshot(app, "\(language)-home")
            app.buttons[settings].tap()
            XCTAssertTrue(app.navigationBars[settingsTitle].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[languageTitle].firstMatch.exists)
            screenshot(app, "\(language)-settings")
            app.buttons[done].tap()
            app.buttons.containing(.staticText, identifier: start).firstMatch.tap()
            app.buttons.containing(.staticText, identifier: easy).firstMatch.tap()
            XCTAssertTrue(app.buttons.containing(.staticText, identifier: erase).firstMatch.waitForExistence(timeout: 20))
            screenshot(app, "\(language)-game")
            app.terminate()
        }
    }

    func testGermanSettingsTitle() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        XCTAssertTrue(app.buttons["Einstellungen"].waitForExistence(timeout: 15))
        app.buttons["Einstellungen"].tap()
        XCTAssertTrue(app.navigationBars["Dein Stil"].waitForExistence(timeout: 5))
        screenshot(app, "de-settings-short-title")
        app.terminate()
    }

    func testManualLanguageSelectionPersistsAndPreservesGame() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        XCTAssertTrue(app.buttons["Réglages"].waitForExistence(timeout: 15))
        app.buttons["Réglages"].tap()
        for (name, title) in [("English", "Make it yours"), ("Deutsch", "Dein Stil"), ("Русский", "На ваш вкус"), ("Español", "A tu gusto"), ("Français", "À votre goût"), ("English", "Make it yours")] {
            app.buttons["languagePicker"].tap()
            app.buttons[name].tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), name)
        }
        screenshot(app, "manual-language-picker")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.tabBars.buttons["Play"].waitForExistence(timeout: 5))
        app.buttons.containing(.staticText, identifier: "Let's play!").firstMatch.tap()
        app.buttons.containing(.staticText, identifier: "Easy").firstMatch.tap()
        XCTAssertTrue(app.buttons["gameSettingsButton"].waitForExistence(timeout: 20))
        app.buttons["gameSettingsButton"].tap()
        app.buttons["languagePicker"].tap()
        app.buttons["Русский"].tap()
        XCTAssertTrue(app.buttons["Готово"].waitForExistence(timeout: 5))
        app.buttons["Готово"].tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Стереть").firstMatch.waitForExistence(timeout: 5))
        let firstCell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Строка 1, столбец 1,")).firstMatch
        XCTAssertTrue(firstCell.exists)
        let savedCell = firstCell.label
        screenshot(app, "manual-language-active-game")
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Играть"].waitForExistence(timeout: 15))
        app.buttons.containing(.staticText, identifier: "Продолжить игру").firstMatch.tap()
        XCTAssertTrue(firstCell.waitForExistence(timeout: 10))
        XCTAssertEqual(firstCell.label, savedCell)
        app.buttons["gameSettingsButton"].tap()
        app.buttons["languagePicker"].tap()
        app.buttons["Язык iPhone"].tap()
        XCTAssertTrue(app.navigationBars["À votre goût"].waitForExistence(timeout: 5))
        app.buttons["Terminé"].tap()
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Gommer").firstMatch.waitForExistence(timeout: 5))
        app.terminate()
    }

    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
