import XCTest
import UIKit

@MainActor
final class AdaptiveLayoutUITests: XCTestCase {
    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func launchFresh() -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
        XCTAssertTrue(button("C’est parti !", in: app).waitForExistence(timeout: 10))
        return app
    }

    private func button(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.containing(.staticText, identifier: title).firstMatch
    }

    private func rotate(_ orientation: UIDeviceOrientation, app: XCUIApplication) {
        XCUIDevice.shared.orientation = orientation
        let landscape = orientation == .landscapeLeft || orientation == .landscapeRight
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (app.frame.width > app.frame.height) == landscape
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 8), .completed)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        // Capture the display: app.screenshot() crops with stale portrait bounds
        // after rotation on the iOS 18 simulator paired with this Xcode.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testGameResizesWithoutLosingSelectionNotesOrUndo() {
        let app = launchFresh()
        button("C’est parti !", in: app).tap()
        button("Facile", in: app).tap()
        let empty = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Ligne ", ", vide")).firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 15))
        let coordinate = empty.label.components(separatedBy: ", vide")[0]
        empty.tap()
        button("Notes", in: app).tap()
        let one = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "1, ")).firstMatch
        one.tap()
        let noted = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", coordinate, "notes 1")).firstMatch
        XCTAssertTrue(noted.exists)
        capture(app, "Disposition-verticale")

        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(noted.isSelected, "Resizing must preserve the selected cell")
        XCTAssertTrue(button("Notes oui", in: app).exists, "Resizing must preserve input mode")
        let topRight = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ligne 1, colonne 9,")).firstMatch
        XCTAssertLessThan(topRight.frame.maxX, one.frame.minX, "On a wide viewport the keypad belongs beside the board")
        for value in 1...9 {
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(value), ")).firstMatch.isHittable)
        }
        capture(app, "Disposition-deux-colonnes")
        button("Annuler", in: app).tap()
        XCTAssertFalse(noted.exists)
        one.tap()
        XCTAssertTrue(noted.exists, "The same selected cell must still accept input")

        app.buttons["gameSettingsButton"].tap()
        XCTAssertTrue(app.switches["decorToggle"].waitForExistence(timeout: 5))
        app.buttons["Terminé"].tap()
        rotate(.landscapeRight, app: app)
        XCTAssertTrue(noted.isSelected)
        rotate(.portrait, app: app)
        XCTAssertTrue(noted.isSelected)
        XCTAssertTrue(button("Notes oui", in: app).exists)
        app.buttons["Mettre en pause"].tap()
        rotate(.landscapeLeft, app: app)
        XCTAssertTrue(button("Reprendre", in: app).isHittable, "Pause must remain dismissible on a short viewport")
        capture(app, "Pause-paysage")
        button("Reprendre", in: app).tap()
        XCTAssertTrue(noted.exists)
    }

    func testHomeAndPoulpiRemainUsableAfterRotation() {
        let app = launchFresh()
        rotate(.landscapeLeft, app: app)
        capture(app, "Accueil-large")
        let start = button("C’est parti !", in: app)
        if !start.isHittable { app.swipeUp() }
        XCTAssertTrue(start.isHittable)
        app.tabBars.buttons["Poulpi"].tap()
        let stage = app.otherElements["poulpiStage"]
        XCTAssertTrue(stage.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Recentrer"].isHittable)
        XCTAssertTrue(app.buttons["poulpiAnimation-happy"].isHittable)
        app.buttons["poulpiAnimation-happy"].tap()
        app.buttons["Rapprocher"].tap()
        let camera = stage.value as? String
        capture(app, "Poulpi-large")
        rotate(.portrait, app: app)
        XCTAssertEqual(stage.value as? String, camera, "The camera and pose must survive layout changes")
        XCTAssertTrue(app.buttons["Recentrer"].isHittable)
        capture(app, "Poulpi-vertical")
    }

    // Run on a large resizable destination. An iPad QA build is a layout
    // surrogate only; it does not validate Duo folds, cameras or safe areas.
    func testExpandedViewportUsesSpaceAndKeepsControlsReachable() throws {
        let app = launchFresh()
        try XCTSkipIf(app.frame.width < 600, "Requires an expanded viewport")
        capture(app, "Accueil-format-etendu")
        button("C’est parti !", in: app).tap()
        button("Facile", in: app).tap()
        let topLeft = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ligne 1, colonne 1,")).firstMatch
        XCTAssertTrue(topLeft.waitForExistence(timeout: 15))
        let bottomRight = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ligne 9, colonne 9,")).firstMatch
        let one = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "1, ")).firstMatch
        XCTAssertGreaterThan(bottomRight.frame.maxX - topLeft.frame.minX, 360)
        XCTAssertLessThan(bottomRight.frame.maxX, one.frame.minX)
        XCTAssertTrue(bottomRight.isHittable)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "9, ")).firstMatch.isHittable)
        capture(app, "Grille-format-etendu")
        app.buttons["gameSettingsButton"].tap()
        XCTAssertTrue(app.switches["decorToggle"].waitForExistence(timeout: 5))
        capture(app, "Reglages-format-etendu")
        app.buttons["Terminé"].tap()
        app.buttons["Sauvegarder et revenir à l’accueil"].tap()
        // The iPad surrogate uses the system's top tab strip; widen it to
        // expose the last tab without depending on platform-specific overflow.
        rotate(.landscapeLeft, app: app)
        app.buttons["Poulpi"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["poulpiStage"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["poulpiAnimation-happy"].isHittable)
        capture(app, "Poulpi-format-etendu")
    }
}
