import XCTest
import SceneKit
@testable import SudokuLisa

@MainActor
final class PoulpiTimingRegressionTests: XCTestCase {
    private func closure(_ rig: PoulpiRig, side: String = "left") throws -> Float {
        let lid = try XCTUnwrap(rig.node.childNode(withName: "poulpi-lids-\(side)", recursively: true))
        let value = try XCTUnwrap(lid.geometry?.firstMaterial?.value(forKey: "lidClosure") as? NSNumber)
        return value.floatValue
    }

    func testChangingExpressionDuringBlinkStillClosesBothEyelidsFully() throws {
        let rig = PoulpiRig()
        rig.play(.idle, animated: false)
        rig.play(.idle, animated: true)
        rig.animate(3.65)
        rig.play(.happy, animated: true)
        // This falls within both the live blink and the expression crossfade.
        rig.animate(3.775)
        XCTAssertEqual(try closure(rig), 1, accuracy: 0.0001)
        XCTAssertEqual(try closure(rig, side: "right"), 1, accuracy: 0.0001)
    }

    func testExpressionTransitionDoesNotCaptureAndProlongThePreviousBlink() throws {
        let rig = PoulpiRig()
        rig.play(.idle, animated: false)
        rig.play(.idle, animated: true)
        rig.animate(3.79)
        rig.play(.idle, animated: true)
        rig.animate(4.001)
        XCTAssertEqual(try closure(rig), 0, accuracy: 0.0001)
        XCTAssertEqual(try closure(rig, side: "right"), 0, accuracy: 0.0001)
    }

    func testBlinkCadenceSurvivesTheOldSixtyThreeSecondPhaseBoundary() throws {
        let rig = PoulpiRig()
        rig.play(.idle, animated: false)
        rig.play(.idle, animated: true)
        // Advance the actual repeated SceneKit action clock, not a wall clock.
        rig.animate(24)
        rig.animate(24)
        rig.animate(0)
        rig.animate(24)
        rig.animate(0)
        rig.animate(15.775) // Total 63.775 seconds: the sixteenth blink.
        XCTAssertEqual(try closure(rig), 1, accuracy: 0.0001)
    }
}
