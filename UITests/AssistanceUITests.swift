import XCTest
import UIKit

@MainActor
final class AssistanceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }
    private func launch(large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["LISA_UI_TESTING"] = "1"
        app.launchArguments = ["--uitest-reset", "--uitest-finale", "--uitest-scenery", "garden-0", "--uitest-static",
                               "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 15))
        return app
    }
    private func tap(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { element.tap(); return }
            let panel = app.scrollViews["assistanceScroll"]
            if panel.exists { panel.swipeUp() } else { app.swipeUp() }
        }
        XCTFail("The requested control could not be brought into its visible viewport")
    }
    private func closeAids(_ app: XCUIApplication) {
        tap(app.buttons["assistanceClose"], app)
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testLayersPreservePersonalNotesAndExplainTrail() {
        let app = launch()
        tap(app.buttons["cell-0"], app)
        tap(app.buttons["Notes"].firstMatch, app)
        tap(app.buttons["digit-9"], app)
        XCTAssertTrue(app.buttons["cell-0"].label.contains("notes 9"))
        tap(app.buttons["assistanceToggle"], app)
        tap(app.switches["assistanceCandidates"], app)
        tap(app.switches["assistanceTrail"], app)
        let explain = app.buttons["assistanceExplain"]
        XCTAssertTrue(explain.waitForExistence(timeout: 5))
        tap(app.buttons["assistanceFocus"], app)
        tap(app.buttons["assistanceFocus-1"], app)
        capture(app, "Aides-panneau-SE")
        closeAids(app)
        XCTAssertTrue(app.buttons["cell-0"].label.contains("notes 1"))
        XCTAssertTrue(app.buttons["cell-0"].label.contains("vide"))
        XCTAssertTrue(app.buttons["cell-0"].label.contains("case de la piste"))
        capture(app, "Aides-grille-SE")
        tap(app.buttons["assistanceToggle"], app)
        tap(explain, app)
        XCTAssertTrue(app.staticTexts["hintExplanation"].waitForExistence(timeout: 5))
        tap(app.buttons["Fermer"].firstMatch, app)
        tap(app.buttons["assistanceToggle"], app)
        tap(app.buttons["assistanceHide"], app)
        XCTAssertTrue(app.buttons["cell-0"].label.contains("notes 9"))
        tap(app.buttons["assistanceToggle"], app)
        tap(app.buttons["assistanceFill"], app)
        XCTAssertTrue(app.buttons["cell-0"].label.contains("notes 9"))
        XCTAssertTrue(app.buttons["cell-40"].label.contains("notes 9"))
        tap(app.buttons["Annuler"].firstMatch, app)
        XCTAssertFalse(app.buttons["cell-40"].label.contains("notes"))
    }
    func testManualNotesDisableCandidatesAndLandscape() {
        let app = launch()
        tap(app.buttons["assistanceToggle"], app)
        tap(app.switches["assistanceCandidates"], app)
        closeAids(app)
        tap(app.buttons["Notes"].firstMatch, app)
        tap(app.buttons["assistanceToggle"], app)
        XCTAssertEqual(app.switches["assistanceCandidates"].value as? String, "0")
        tap(app.buttons["assistanceFocus"], app)
        tap(app.buttons["assistanceFocus-2"], app)
        closeAids(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.scrollViews["gameControlsScroll"].waitForExistence(timeout: 5))
        tap(app.buttons["assistanceToggle"], app)
        XCTAssertEqual(app.buttons["assistanceFocus"].value as? String, "2")
        closeAids(app)
        XCTAssertTrue(app.buttons["cell-0"].label.contains("vide"))
        capture(app, "Aides-paysage-SE")
        XCTAssertEqual(app.buttons["assistanceToggle"].label, "Aides actives")
        tap(app.buttons["Sauvegarder et revenir à l’accueil"], app)
        XCTAssertTrue(app.tabBars.buttons["Jouer"].waitForExistence(timeout: 5))
        tap(app.buttons["homeResume"], app)
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["assistanceToggle"].label, "Aides")
        XCTAssertFalse(app.switches["assistanceCandidates"].exists)
    }
    func testOpeningAssistanceKeepsBoardAndKeypadInPlace() {
        let app = launch()
        let board = app.buttons["cell-0"].frame
        let keypad = app.buttons["digit-1"].frame
        XCTAssertTrue(app.buttons["digit-9"].isHittable)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(app.buttons["digit-9"].frame))
        tap(app.buttons["assistanceToggle"], app)
        tap(app.switches["assistanceCandidates"], app)
        closeAids(app)
        XCTAssertEqual(app.buttons["cell-0"].frame, board)
        XCTAssertEqual(app.buttons["digit-1"].frame, keypad)
        XCTAssertTrue(app.buttons["digit-9"].isHittable)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(app.buttons["digit-9"].frame))
        tap(app.buttons["assistanceToggle"], app)
        tap(app.buttons["assistanceHide"], app)
        XCTAssertEqual(app.buttons["cell-0"].frame, board)
        XCTAssertEqual(app.buttons["digit-1"].frame, keypad)
    }
    func testAutomaticNotesCleanClearAndUndo() {
        let app = launch()
        tap(app.buttons["cell-0"], app)
        tap(app.buttons["Notes"].firstMatch, app)
        tap(app.buttons["digit-9"], app)
        tap(app.buttons["assistanceToggle"], app)
        tap(app.switches["assistanceCandidates"], app)
        tap(app.buttons["assistanceFill"], app)
        XCTAssertTrue(app.buttons["cell-0"].label.contains("notes 9"), "Filled notes must be visible instead of the live overlay")
        XCTAssertTrue(app.buttons["cell-40"].label.contains("notes 9"))
        tap(app.buttons["assistanceToggle"], app)
        tap(app.buttons["Gérer les notes"].firstMatch, app)
        capture(app, "Gestion-des-notes")
        tap(app.buttons["assistanceClean"], app)
        XCTAssertFalse(app.buttons["cell-0"].label.contains("notes"))
        XCTAssertTrue(app.buttons["cell-40"].label.contains("notes 9"))
        tap(app.buttons["Annuler"].firstMatch, app)
        XCTAssertTrue(app.buttons["cell-0"].label.contains("notes 9"))
        tap(app.buttons["assistanceToggle"], app)
        tap(app.buttons["Gérer les notes"].firstMatch, app)
        tap(app.buttons["assistanceClear"], app)
        XCTAssertFalse(app.buttons["cell-0"].label.contains("notes"))
        XCTAssertFalse(app.buttons["cell-40"].label.contains("notes"))
        tap(app.buttons["Annuler"].firstMatch, app)
        XCTAssertTrue(app.buttons["cell-0"].label.contains("notes 9"))
        XCTAssertTrue(app.buttons["cell-40"].label.contains("notes 9"))
    }
    func testLargeTextPalette() {
        let app = launch(large: true)
        tap(app.buttons["assistanceToggle"], app)
        tap(app.buttons["assistanceFocus"], app)
        tap(app.buttons["assistanceFocus-9"], app)
        capture(app, "Aides-texte-accessibilité")
        tap(app.buttons["assistanceHide"], app)
    }
}
