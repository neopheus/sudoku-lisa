import XCTest

@MainActor
final class FirstJourneyUITests: XCTestCase {
    private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["LISA_UI_TESTING"] = "1"
        app.launchArguments = ["--uitest-reset", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"] + extra
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            let safe = app.frame.insetBy(dx: 0, dy: 125)
            if element.exists && element.isHittable && safe.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOneTapFirstJourneyAndResume() {
        let app = launch()
        let play = app.buttons["homeJourneyPlay"]
        XCTAssertTrue(play.waitForExistence(timeout: 15))
        capture(app, "first-journey-home")
        play.tap()
        let back = app.buttons["Sauvegarder et revenir à l’accueil"]
        XCTAssertTrue(back.waitForExistence(timeout: 20))
        let cells = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ligne "))
        XCTAssertEqual(cells.count, 81)
        let before = cells.allElementsBoundByIndex.map(\.label)
        capture(app, "first-journey-express")
        back.tap()
        let resume = app.buttons["homeResume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertEqual(cells.allElementsBoundByIndex.map(\.label), before)
    }

    func testFirstJourneyActionIsVisibleWithLargestText() {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let play = app.buttons["homeJourneyPlay"]
        XCTAssertTrue(play.waitForExistence(timeout: 15))
        XCTAssertTrue(play.isHittable)
        XCTAssertTrue(app.frame.contains(play.frame))
        capture(app, "first-journey-largest-text")
        play.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["digit-9"].isHittable)
    }

    func testAlbumReflectsExistingProgressAndShowsUnlockedArtwork() {
        let app = launch(["--uitest-finale"])
        XCTAssertTrue(app.tabBars.buttons["Voyage"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Voyage"].tap()
        let album = app.buttons["openJourneyAlbum"]
        reveal(album, in: app)
        XCTAssertTrue(album.isHittable)
        album.tap()
        let first = app.buttons["souvenir-garden-0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.isEnabled)
        capture(app, "journey-souvenirs")
        first.tap()
        XCTAssertTrue(app.navigationBars["Prairie guimauve"].waitForExistence(timeout: 5))
        capture(app, "journey-souvenir-detail")
    }

    func testLocalReportCanBePreparedWithoutSendingAnything() {
        let app = launch()
        XCTAssertTrue(app.buttons["Réglages"].waitForExistence(timeout: 15))
        app.buttons["Réglages"].tap()
        let report = app.buttons["openPlayStudy"]
        reveal(report, in: app)
        XCTAssertTrue(report.isHittable)
        report.tap()
        XCTAssertTrue(app.switches["playStudyEnabled"].waitForExistence(timeout: 5))
        let prepare = app.buttons["preparePlayStudyExport"]
        reveal(prepare, in: app)
        prepare.tap()
        XCTAssertTrue(app.buttons["sharePlayStudy"].waitForExistence(timeout: 5))
        capture(app, "local-playtest-report")
    }
}
