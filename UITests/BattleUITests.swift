import XCTest

@MainActor
final class BattleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

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

    func testPoulpiStaysVisibleWhileScrollingControls() {
        verifyStickyPoulpi(largeText: false)
    }

    func testPoulpiStaysVisibleAtAccessibilityTextSize() {
        verifyStickyPoulpi(largeText: true)
    }

    func testPoulpiStaysVisibleInLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        verifyStickyPoulpi(largeText: true, landscape: true)
    }

    func testPoulpiStickerGalleryAndWhatsAppUnavailable() {
        let app = launch(fixture: false)
        app.tabBars.buttons["Poulpi"].tap()
        app.buttons["openPoulpiStickers"].tap()
        let first = app.buttons["poulpiSticker.idle"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        attach(app, name: "Poulpi-Autocollants")
        first.tap()
        XCTAssertTrue(app.buttons["poulpiShareSticker"].waitForExistence(timeout: 5))
        attach(app, name: "Poulpi-Autocollant-Apercu")
        app.buttons["OK"].tap()
        let whatsapp = app.buttons["poulpiAddToWhatsApp"]
        for _ in 0..<16 {
            if whatsapp.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(whatsapp.isHittable)
        whatsapp.tap()
        XCTAssertTrue(app.alerts["WhatsApp introuvable"].waitForExistence(timeout: 5))
        attach(app, name: "Poulpi-WhatsApp-Simulateur")
        app.terminate()
    }

    private func verifyStickyPoulpi(largeText: Bool, landscape: Bool = false) {
        let app = launch(fixture: false, largeText: largeText)
        if landscape {
            XCTAssertTrue(app.frame.width > app.frame.height, "The landscape layout must actually be exercised")
        }
        app.tabBars.buttons["Poulpi"].tap()
        let stage = app.descendants(matching: .any)["poulpiStage"].firstMatch
        let controls = app.scrollViews["poulpiControlsScroll"]
        XCTAssertTrue(stage.waitForExistence(timeout: 5))
        XCTAssertTrue(controls.exists)
        let initial = stage.frame
        let lastAnimation = app.buttons["poulpiAnimation-superhero"]
        reveal(lastAnimation, in: app)
        XCTAssertTrue(lastAnimation.isHittable, "The last animation remains reachable below the fixed preview")
        XCTAssertTrue(stage.isHittable, "Poulpi stays visible while its controls scroll")
        XCTAssertEqual(stage.frame.minY, initial.minY, accuracy: 2)
        XCTAssertEqual(stage.frame.height, initial.height, accuracy: 2)
        lastAnimation.tap()
        XCTAssertTrue(lastAnimation.isSelected)
        attach(app, name: landscape ? "Poulpi-Sticky-Paysage" : (largeText ? "Poulpi-Sticky-Grand-Texte" : "Poulpi-Sticky"))
        app.terminate()
    }

    private func launch(fixture: Bool, largeText: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LISA_UI_TESTING"] = "1"
        app.launchArguments = ["--uitest-reset", "--uitest-finale", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
                               "-UIPreferredContentSizeCategoryName", largeText ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        if fixture { app.launchArguments.append("--uitest-battle") }
        app.launch()
        return app
    }

    private func openBattle(_ app: XCUIApplication) { tap(app.buttons["openBattle"], in: app) }
    private func tap(_ element: XCUIElement, in app: XCUIApplication) { reveal(element, in: app); if !element.isHittable { print(app.debugDescription) }; XCTAssertTrue(element.isHittable); element.tap() }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let controls = app.scrollViews["poulpiControlsScroll"]
        if controls.exists {
            for _ in 0..<24 {
                if element.exists && element.isHittable && controls.frame.insetBy(dx: 0, dy: 10).contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) { return }
                let upper = controls.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                let lower = controls.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                if element.exists && element.frame.midY < controls.frame.minY + 10 {
                    upper.press(forDuration: 0.05, thenDragTo: lower)
                } else {
                    lower.press(forDuration: 0.05, thenDragTo: upper)
                }
            }
            return
        }
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
