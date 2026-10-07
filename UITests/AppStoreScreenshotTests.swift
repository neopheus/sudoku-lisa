import XCTest

/// Authentic App Store images from a dedicated, reset simulator installation.
@MainActor
final class AppStoreScreenshotTests: XCTestCase {
    private func button(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(.staticText, identifier: title).firstMatch
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

    func testFrenchAppStoreScreenshots() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Jouer"].waitForExistence(timeout: 15))
        XCTAssertTrue(button("C’est parti !", in: app).exists)
        capture("01-Accueil")

        // The daily puzzle uses the existing deterministic date seed.
        app.tabBars.buttons["Chaque jour"].tap()
        let daily = button("Jouer le défi", in: app)
        XCTAssertTrue(daily.waitForExistence(timeout: 10))
        daily.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["digit-9"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["cancelGeneration"].exists)
        capture("02-Grille-quotidienne")

        let hint = button("Indice", in: app)
        XCTAssertTrue(hint.isHittable)
        hint.tap()
        XCTAssertTrue(app.staticTexts["hintExplanation"].waitForExistence(timeout: 10))
        let next = button("Voir la suite", in: app)
        XCTAssertTrue(next.isHittable)
        next.tap()
        capture("03-Indice-explique")
        // Return to a clean game before opening the lesson library.
        app.buttons["Fermer"].tap()
        app.buttons["gameLearnButton"].tap()
        XCTAssertTrue(app.buttons["lesson-close"].waitForExistence(timeout: 10))
        let lesson = app.buttons["lesson-observation"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 10))
        lesson.tap()
        XCTAssertTrue(app.buttons["lesson-cell-0"].waitForExistence(timeout: 10))
        capture("04-Lecon-interactive")
        app.buttons["lesson-close"].tap()
        app.buttons["Sauvegarder et revenir à l’accueil"].tap()

        app.tabBars.buttons["Voyage"].tap()
        XCTAssertTrue(app.buttons["Étape 1, à jouer"].waitForExistence(timeout: 10))
        capture("05-Voyage")

        app.tabBars.buttons["Poulpi"].tap()
        XCTAssertTrue(app.otherElements["poulpiStage"].waitForExistence(timeout: 10))
        capture("06-Poulpi")
        app.terminate()
    }
}
