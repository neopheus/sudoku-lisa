import XCTest
import UIKit

@MainActor
final class LisaUITests: XCTestCase {
    private func launchFresh(metrics: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        if metrics { app.launchEnvironment["LISA_RENDER_METRICS"] = "1" }
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
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
        app.buttons[title].firstMatch
    }

    func testPoulpiAnimationsRotationZoomAndAutoplay() {
        let app = launchFresh()
        app.tabBars.buttons["Poulpi"].tap()
        let stage = app.descendants(matching: .any)["poulpiStage"].firstMatch
        XCTAssertTrue(stage.waitForExistence(timeout: 10), app.debugDescription)
        let happy = app.buttons["poulpiAnimation-happy"]
        for _ in 0..<6 {
            if happy.isHittable && app.frame.contains(happy.frame) { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        happy.tap()
        for _ in 0..<6 {
            if stage.isHittable { break }
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue((stage.value as? String)?.contains("Coucou") == true, "Stage value: \(String(describing: stage.value)); \(app.debugDescription)")
        let before = stage.value as? String
        stage.swipeLeft()
        XCTAssertNotEqual(stage.value as? String, before)
        app.buttons["Recentrer"].tap()
        XCTAssertTrue((stage.value as? String)?.contains("rotation 0 degrés, zoom 100") == true)
        attach(app, name: "Poulpi-accueil")
        app.buttons["Rapprocher"].tap()
        XCTAssertTrue((stage.value as? String)?.contains("zoom 114") == true || (stage.value as? String)?.contains("zoom 115") == true)
        app.buttons["Recentrer"].tap()
        let auto = app.buttons["poulpiAutoplay"]
        auto.tap()
        XCTAssertEqual(auto.value as? String, "Activé")
        expectation(for: NSPredicate(format: "NOT (value BEGINSWITH %@)", "Coucou"), evaluatedWith: stage)
        waitForExpectations(timeout: 8)
        auto.tap()
        XCTAssertEqual(auto.value as? String, "Désactivé")
        let superhero = app.buttons["poulpiAnimation-superhero"]
        for _ in 0..<6 {
            if superhero.isHittable { break }
            let animationList = app.scrollViews["poulpiAnimationList"]
            let list = animationList.exists ? animationList : app.scrollViews.firstMatch
            let visible = list.frame.intersection(app.frame)
            print("Poulpi list frame: \(list.frame), visible: \(visible)")
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: visible.midX, dy: min(visible.maxY - 55, app.frame.maxY - 100)))
            let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: visible.midX, dy: visible.minY + 20))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(superhero.isHittable)
        superhero.tap()
        // The accessible layout scrolls the whole page, including the stage.
        for _ in 0..<6 {
            if stage.isHittable && auto.isHittable { break }
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue((stage.value as? String)?.contains("Super Poulpi") == true)
        attach(app, name: "Poulpi-interactif")
        auto.tap()
        app.tabBars.buttons["Jouer"].tap()
        app.tabBars.buttons["Poulpi"].tap()
        XCTAssertEqual(auto.value as? String, "Désactivé")
    }

    func testPoulpiManualCameraWithAnimationsDisabled() {
        let app = launchFresh()
        app.buttons["Réglages"].tap()
        let decor = app.switches["decorToggle"]
        XCTAssertTrue(decor.waitForExistence(timeout: 5))
        if decor.value as? String == "1" { decor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        XCTAssertEqual(decor.value as? String, "0")
        app.buttons["Terminé"].tap()
        app.tabBars.buttons["Poulpi"].tap()
        let stage = app.descendants(matching: .any)["poulpiStage"].firstMatch
        XCTAssertTrue(stage.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["poulpiAutoplay"].isEnabled)
        XCTAssertFalse(app.buttons["poulpiAnimation-happy"].isEnabled)
        let before = stage.value as? String
        stage.swipeRight()
        XCTAssertNotEqual(stage.value as? String, before)
        app.buttons["Rapprocher"].tap()
        app.buttons["Recentrer"].tap()
        XCTAssertTrue((stage.value as? String)?.contains("rotation 0 degrés, zoom 100") == true)
        attach(app, name: "Poulpi-animations-désactivées")
    }

    func testPlayNotesUndoPauseAndResume() {
        let app = launchFresh()
        attach(app, name: "01-Accueil")
        let start = button("C’est parti !", in: app)
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let easy = app.buttons["Facile"]
        XCTAssertTrue(easy.waitForExistence(timeout: 5))
        easy.tap()

        let empty = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Ligne ", ", vide")).firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 15))
        let nine = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "9, ")).firstMatch
        XCTAssertTrue(nine.isHittable, "All nine digits must be reachable without scrolling away from the board")
        let coordinate = empty.label.components(separatedBy: ", vide")[0]
        empty.tap()
        let notes = app.buttons["Notes"]
        XCTAssertTrue(notes.exists)
        notes.tap()
        let one = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "1, ")).firstMatch
        if !one.isHittable { app.swipeUp() }
        one.tap()
        let notedCell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", coordinate, "notes 1")).firstMatch
        XCTAssertTrue(notedCell.waitForExistence(timeout: 5), "Adding a candidate must update the actual board cell")
        app.buttons["Annuler"].tap()
        XCTAssertFalse(notedCell.exists, "Undo must remove the candidate")

        app.buttons["Notes oui"].tap()
        one.tap()
        let filledCell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", coordinate + ", 1")).firstMatch
        XCTAssertTrue(filledCell.waitForExistence(timeout: 5), "A number input must change the selected cell")
        if !app.buttons["Mettre en pause"].isHittable { app.swipeDown() }
        attach(app, name: "02-Partie")
        app.buttons["Mettre en pause"].tap()
        XCTAssertTrue(app.staticTexts["Votre grille vous attend."].waitForExistence(timeout: 5))
        app.buttons["Réveiller doucement Poulpi"].tap()
        XCTAssertTrue(app.staticTexts["Votre grille vous attend."].exists, "Playing with Poulpi must not resume the game")
        attach(app, name: "Pause-animée")
        button("Reprendre", in: app).tap()
        XCTAssertFalse(app.staticTexts["Votre grille vous attend."].exists)
        app.buttons["Sauvegarder et revenir à l’accueil"].tap()
        let resume = button("Reprendre ma partie", in: app)
        XCTAssertTrue(resume.waitForExistence(timeout: 5))

        // Relaunch without resetting: prove persistence across process termination.
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        resume.tap()
        XCTAssertTrue(filledCell.waitForExistence(timeout: 5))
        attach(app, name: "03-Reprise-persistée")
    }

    func testTimerPauseAndPersistence() {
        let app = launchFresh()
        button("C’est parti !", in: app).tap()
        app.buttons["Facile"].tap()
        let timer = app.staticTexts["gameTimer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 15))
        let initial = timer.label
        expectation(for: NSPredicate(format: "label != %@", initial), evaluatedWith: timer)
        waitForExpectations(timeout: 5)
        func seconds(_ label: String) -> Int {
            let parts = label.split(separator: ":").compactMap { Int($0) }
            XCTAssertEqual(parts.count, 2)
            return parts.count == 2 ? parts[0] * 60 + parts[1] : 0
        }
        let beforePause = seconds(timer.label)
        let pausingAt = Date()
        app.buttons["Mettre en pause"].tap()
        XCTAssertTrue(app.staticTexts["Votre grille vous attend."].waitForExistence(timeout: 5))
        let pausedAt = Date()
        // Covered game content is deliberately absent from the accessibility tree.
        XCTAssertFalse(timer.exists)
        let pause = expectation(description: "Time while paused")
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { pause.fulfill() }
        waitForExpectations(timeout: 10)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["Votre grille vous attend."].waitForExistence(timeout: 5))
        XCTAssertFalse(timer.exists)
        let resumingAt = Date()
        button("Reprendre", in: app).tap()
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        let pausedTime = timer.label
        let activeAllowance = Int(ceil(pausedAt.timeIntervalSince(pausingAt) + Date().timeIntervalSince(resumingAt))) + 2
        XCTAssertGreaterThanOrEqual(seconds(pausedTime), beforePause)
        XCTAssertLessThanOrEqual(seconds(pausedTime) - beforePause, activeAllowance,
                                "The eight paused seconds and background time must not advance the clock")
        app.buttons["Sauvegarder et revenir à l’accueil"].tap()
        XCTAssertTrue(button("Reprendre ma partie", in: app).waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        button("Reprendre ma partie", in: app).tap()
        XCTAssertTrue(timer.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(timer.label, pausedTime)
        XCTAssertNotEqual(timer.label, "00:00")
    }

    func testSpatialCompanionDoesNotBlockBoard() {
        let app = launchFresh()
        button("C’est parti !", in: app).tap()
        app.buttons["Facile"].tap()
        let empty = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "Ligne ", ", vide")).firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 15))
        let coordinate = empty.label.components(separatedBy: ", vide")[0]
        empty.tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "1, ")).firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", coordinate + ", 1")).firstMatch.waitForExistence(timeout: 5))
        attach(app, name: "Vol-spatial-départ")
        let flight = expectation(description: "One complete depth flight")
        DispatchQueue.main.asyncAfter(deadline: .now() + 33) { flight.fulfill() }
        waitForExpectations(timeout: 36)
        attach(app, name: "Vol-spatial-retour")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "9, ")).firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", coordinate + ", 9")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["Mettre en pause"].tap()
        XCTAssertTrue(app.staticTexts["Votre grille vous attend."].waitForExistence(timeout: 5))
    }

    func testAdaptiveEffectsAndPause() {
        let app = launchFresh(metrics: true)
        button("C’est parti !", in: app).tap()
        app.buttons["Facile"].tap()
        let companion = app.buttons["Faire rire Lisa"]
        XCTAssertTrue(companion.waitForExistence(timeout: 15))
        if UIAccessibility.isReduceMotionEnabled {
            XCTAssertFalse(companion.isEnabled)
        } else {
            companion.tap()
            expectation(for: NSPredicate(format: "value == %@", "Reviens, papillon !"), evaluatedWith: companion)
            waitForExpectations(timeout: 5)
            attach(app, name: "Poulpe-perspective")
            // Passing the element itself makes XCTest collect a full debug
            // hierarchy after every false poll; on SE this stalls the UI for
            // several seconds. Poll only the value, with the same deadline.
            let resting = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                companion.value as? String == "Au repos"
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [resting], timeout: 10), .completed)
            // Collect steady-state render windows without driving the UI.
            let observation = expectation(description: "Observe steady-state cadence")
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) { observation.fulfill() }
            waitForExpectations(timeout: 15)
        }
        app.buttons["Mettre en pause"].tap()
        XCTAssertTrue(app.staticTexts["Votre grille vous attend."].waitForExistence(timeout: 5))
        button("Reprendre", in: app).tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "9, ")).firstMatch.isHittable)
    }

    func testPlayfulCompanion() {
        let app = launchFresh()
        button("C’est parti !", in: app).tap()
        app.buttons["Facile"].tap()
        let companion = app.buttons["Faire rire Lisa"]
        XCTAssertTrue(companion.waitForExistence(timeout: 15))
        if UIAccessibility.isReduceMotionEnabled {
            XCTAssertFalse(companion.isEnabled)
            return
        }
        XCTAssertTrue(companion.isEnabled)
        for message in ["Reviens, papillon !", "Marche arrière !", "Un, deux… oups !", "Vous me voyez ?", "A… a… atchoum !", "Même pas le vertige !", "Ça tient… presque !", "Qui a tourné le décor ?", "Super Poulpe arrive !", "Tadaaa !", "Huit bras, quel talent !", "Coucou !", "Tout mou !", "Plouf, plouf !", "À votre service !", "Oh, par ici !", "Hi hi hi !", "Décollage !"] {
            companion.tap()
            let shown = NSPredicate(format: "value == %@", message)
            expectation(for: shown, evaluatedWith: companion)
            waitForExpectations(timeout: 3)
            attach(app, name: message)
            expectation(for: NSPredicate(format: "value == %@", "Au repos"), evaluatedWith: companion)
            waitForExpectations(timeout: 10)
        }
        app.buttons["Mettre en pause"].tap()
        XCTAssertTrue(app.staticTexts["Votre grille vous attend."].waitForExistence(timeout: 5))
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

    func testCompanionAndAtmosphereSettingsPersist() {
        let app = launchFresh()
        let companion = app.buttons["Faire coucou à Lisa"]
        XCTAssertTrue(companion.waitForExistence(timeout: 5))
        companion.tap()
        attach(app, name: "06-Lisa-coucou")
        app.buttons["Réglages"].tap()
        let music = app.switches["musicToggle"]
        let decor = app.switches["decorToggle"]
        XCTAssertTrue(music.waitForExistence(timeout: 5))
        XCTAssertEqual(music.value as? String, "0", "Music starts opt-in")
        XCTAssertEqual(decor.value as? String, "1")
        // SwiftUI exposes the whole Form row as the switch; target the actual thumb.
        music.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(music.value as? String, "1")
        decor.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(decor.value as? String, "0")
        attach(app, name: "07-Ambiance-réglages")
        app.buttons["Terminé"].tap()
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        app.buttons["Réglages"].tap()
        XCTAssertTrue(music.waitForExistence(timeout: 5))
        XCTAssertEqual(music.value as? String, "1")
        XCTAssertEqual(decor.value as? String, "0")
        music.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.buttons["Terminé"].tap()
    }

    func testVictoryRewardsAndNextJourneyChapter() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-finale", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let resume = button("Reprendre ma partie", in: app)
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        resume.tap()
        for (row, column, value) in [(1, 1, 1), (5, 5, 9), (9, 9, 8)] {
            let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ligne \(row), colonne \(column), vide")).firstMatch
            XCTAssertTrue(cell.waitForExistence(timeout: 5))
            cell.tap()
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(value), ")).firstMatch.tap()
            if row < 9 {
                XCTAssertTrue(app.staticTexts["Combo ×3 !"].waitForExistence(timeout: 2))
                attach(app, name: "Combo-ligne-colonne-carré-\(row)")
            }
        }
        XCTAssertTrue(app.staticTexts["Bien joué, vous !"].waitForExistence(timeout: 8))
        let reward = app.staticTexts["5 / 25 étoiles"]
        if !reward.isHittable { app.swipeUp() }
        XCTAssertTrue(reward.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Prochaine étape · La forêt des sucettes"].exists)
        attach(app, name: "08-Victoire-récompense")
        let next = app.buttons["victoryContinue"]
        for _ in 0..<4 {
            if next.isHittable { break }
            app.swipeUp()
        }
        XCTAssertEqual(next.label, "Prochaine étape")
        next.tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["Bien joué, vous !"].exists)
        app.buttons["Sauvegarder et revenir à l’accueil"].tap()
        XCTAssertTrue(app.tabBars.buttons["Voyage"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Voyage"].tap()
        XCTAssertTrue(app.staticTexts["5 / 25 étoiles"].waitForExistence(timeout: 5))
        attach(app, name: "09-Nouvelle-escale")
    }

    func testZenModeStillAllowsVictory() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-finale", "--uitest-zen", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        // Also verify the app observes the real accessibility setting when the QA device enables it.
        if UIAccessibility.isReduceMotionEnabled { app.launchArguments.append("--uitest-reduce-motion") }
        let motion = XCTAttachment(string: "System Reduce Motion: \(UIAccessibility.isReduceMotionEnabled)")
        motion.name = "System accessibility setting"
        motion.lifetime = .keepAlways
        add(motion)
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        let resume = button("Reprendre ma partie", in: app)
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        resume.tap()
        XCTAssertTrue(app.staticTexts["Mode zen"].waitForExistence(timeout: 5))
        for (row, column, value) in [(1, 1, 1), (5, 5, 9), (9, 9, 8)] {
            let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ligne \(row), colonne \(column), vide")).firstMatch
            XCTAssertTrue(cell.waitForExistence(timeout: 5))
            cell.tap()
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(value), ")).firstMatch.tap()
            if row < 9 {
                XCTAssertFalse(app.staticTexts["Combo ×3 !"].exists)
                XCTAssertFalse(app.staticTexts["Chiffre terminé !"].exists)
            }
        }
        XCTAssertTrue(app.staticTexts["Bien joué, vous !"].waitForExistence(timeout: 5))
        let reward = app.staticTexts["5 / 25 étoiles"]
        if !reward.isHittable { app.swipeUp() }
        XCTAssertTrue(reward.waitForExistence(timeout: 5))
        attach(app, name: "10-Victoire-zen")
    }

    func testLivingJourneyWorldsAndLevelTap() {
        let app = launchFresh()
        app.tabBars.buttons["Voyage"].tap()
        let names = ["Les jardins guimauve", "La forêt des sucettes", "Le lagon pétillant", "Les sommets givrés", "La voie des étoiles"]
        for (index, name) in names.enumerated() {
            let title = app.staticTexts[name]
            for _ in 0..<10 {
                if title.exists && title.isHittable { break }
                scrollJourney(app, forward: true)
            }
            if !title.exists || !title.isHittable { attach(app, name: "World-heading-not-visible-\(index)") }
            XCTAssertTrue(title.isHittable, "Every animated world remains reachable")
            // Bring the world heading near the top so its scenery is visible in the evidence.
            let heading = title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.17))
            if title.frame.midY > app.frame.height * 0.3 {
                heading.press(forDuration: 0.05, thenDragTo: top, withVelocity: .slow, thenHoldForDuration: 0.2)
            }
            attach(app, name: "Wow-Monde-\(index + 1)")
        }
        let first = app.buttons["Étape 1, à jouer"]
        for _ in 0..<30 {
            if first.exists && first.isHittable { break }
            scrollJourney(app, forward: false)
        }
        XCTAssertTrue(first.isHittable)
        first.tap()
        XCTAssertTrue(app.buttons["Mettre en pause"].waitForExistence(timeout: 15), "Moving scenery must never intercept level taps")
    }

    private func scrollJourney(_ app: XCUIApplication, forward: Bool) {
        // Short held drags avoid flinging past an entire heading on a compact screen.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: forward ? 0.75 : 0.40))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: forward ? 0.40 : 0.75))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
    }
}
