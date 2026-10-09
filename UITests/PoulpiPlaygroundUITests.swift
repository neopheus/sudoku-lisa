import XCTest
import UIKit

@MainActor
final class PoulpiPlaygroundUITests: XCTestCase {
    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testPlaybackControlsAndCompactPreviewInLandscape() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        app.launch()
        app.tabBars.buttons["Poulpi"].tap()

        let stage = app.descendants(matching: .any)["poulpiStage"].firstMatch
        let controls = app.scrollViews["poulpiControlsScroll"]
        XCTAssertTrue(stage.waitForExistence(timeout: 10))

        func reveal(_ element: XCUIElement, preferUp: Bool = true) {
            func scroll(up: Bool) {
                let start = controls.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: up ? 0.68 : 0.32))
                let end = controls.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: up ? 0.32 : 0.68))
                start.press(forDuration: 0.08, thenDragTo: end)
            }
            for _ in 0..<24 where !element.isHittable {
                let visible = controls.frame.intersection(app.frame)
                if element.exists ? element.frame.midY < visible.minY : !preferUp {
                    scroll(up: false)
                } else {
                    scroll(up: true)
                }
            }
            XCTAssertTrue(element.isHittable, "Control should remain reachable: \(element.identifier)")
        }

        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        func expectValue(_ value: String, on element: XCUIElement) {
            let changed = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value == %@", value), object: element
            )
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed,
                           "Expected \(element.identifier) to have value \(value); got \(String(describing: element.value))")
        }

        let happy = app.buttons["poulpiAnimation-happy"]
        reveal(happy)
        XCTAssertTrue(app.staticTexts["Émotions"].exists)
        happy.tap()
        XCTAssertTrue((stage.value as? String)?.contains("Coucou") == true)

        let replay = app.buttons["poulpiReplay"]
        reveal(replay, preferUp: false)
        replay.tap()
        XCTAssertTrue((stage.value as? String)?.contains("Coucou") == true)

        let loop = app.buttons["poulpiLoop"]
        reveal(loop)
        XCTAssertTrue(loop.isEnabled)
        loop.tap()
        expectValue("Activé", on: loop)
        let pause = app.buttons["poulpiPause"]
        reveal(pause)
        pause.tap()
        expectValue("En pause", on: pause)
        pause.tap()
        expectValue("En lecture", on: pause)
        let slow = app.buttons["poulpiSlowMotion"]
        reveal(slow)
        slow.tap()
        expectValue("Activé", on: slow)
        loop.tap()
        expectValue("Désactivé", on: loop)

        let compact = app.buttons["poulpiCompactPreview"]
        reveal(compact)
        let fullHeight = stage.frame.height
        compact.tap()
        expectValue("Activé", on: compact)
        XCTAssertLessThan(stage.frame.height, fullHeight)
        capture("Poulpi-bac-a-sable-portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 8), .completed)
        XCTAssertTrue(stage.isHittable)
        XCTAssertTrue((stage.value as? String)?.contains("Coucou") == true)
        reveal(compact)
        XCTAssertTrue(compact.isHittable)
        let superhero = app.buttons["poulpiAnimation-superhero"]
        reveal(superhero)
        superhero.tap()
        XCTAssertTrue((stage.value as? String)?.contains("Super Poulpi") == true)
        capture("Poulpi-bac-a-sable-paysage")
        reveal(happy, preferUp: false)
        XCTAssertTrue(happy.isHittable)
    }
}
