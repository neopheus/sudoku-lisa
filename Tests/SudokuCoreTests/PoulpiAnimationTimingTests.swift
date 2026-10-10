import XCTest
@testable import SudokuCore

final class PoulpiAnimationTimingTests: XCTestCase {
    func testClockContinuesAcrossActionLoopsAndFormerPhaseReset() {
        var clock = PoulpiAnimationClock()
        XCTAssertEqual(clock.advance(actionTime: 23.98), 23.98, accuracy: 0.000001)
        XCTAssertEqual(clock.advance(actionTime: 0.02), 0.04, accuracy: 0.000001)
        XCTAssertEqual(clock.totalTime, 24.02, accuracy: 0.000001)
        for frame in 1...2400 {
            let age = 24.02 + Double(frame) / 60
            XCTAssertEqual(clock.advance(actionTime: age.truncatingRemainder(dividingBy: 24)), 1.0 / 60, accuracy: 0.000001)
            XCTAssertEqual(clock.totalTime, age, accuracy: 0.000001)
        }
        XCTAssertGreaterThan(clock.totalTime, 62.8)
    }

    func testClockPreservesInclusiveLoopEndpointAndIgnoresInvalidSamples() {
        var clock = PoulpiAnimationClock()
        XCTAssertEqual(clock.advance(actionTime: 24), 24)
        XCTAssertEqual(clock.advance(actionTime: 0), 0)
        XCTAssertEqual(clock.advance(actionTime: 24), 24)
        XCTAssertEqual(clock.totalTime, 48)
        XCTAssertEqual(clock.advance(actionTime: .nan), 0)
        XCTAssertEqual(clock.advance(actionTime: .infinity), 0)
        XCTAssertEqual(clock.advance(actionTime: -1), 0)
        XCTAssertEqual(clock.totalTime, 48)
        XCTAssertEqual(clock.previousActionTime, 24)
    }

    func testBlinkFullyClosesAtThirtyAndSixtyFramesPerSecond() {
        for frameRate in [30, 60] {
            let values = (0..<(frameRate * 4)).map { PoulpiAnimationTiming.blink(at: Double($0) / Double(frameRate)) }
            XCTAssertTrue(values.contains(1), "No closed eyelid at \(frameRate) fps")
            XCTAssertTrue(values.allSatisfy { (0...1).contains($0) })
        }
        XCTAssertEqual(PoulpiAnimationTiming.blink(at: 3.775), 1)
        XCTAssertEqual(PoulpiAnimationTiming.blink(at: 4), 0)
        XCTAssertEqual(PoulpiAnimationTiming.blink(at: 63.775), 1)
        XCTAssertLessThan(PoulpiAnimationTiming.blink(at: 3.95), 0.5)
    }

    func testReactionPhaseDependsOnlyOnElapsedReactionTime() {
        XCTAssertEqual(PoulpiAnimationTiming.reactionPhase(elapsed: -0.1, duration: 1), 0)
        XCTAssertEqual(PoulpiAnimationTiming.reactionPhase(elapsed: 0.25, duration: 1), 0.25)
        XCTAssertEqual(PoulpiAnimationTiming.reactionPhase(elapsed: 1.5, duration: 1), 1)
        for sceneAge in [0.0, 24.0, 62.8, 1000.0] {
            let elapsed = (sceneAge + 0.5) - sceneAge
            XCTAssertEqual(PoulpiAnimationTiming.reactionPhase(elapsed: elapsed, duration: 2), 0.25, accuracy: 0.000001)
        }
    }

    func testSmoothingMatchesElapsedTimeAcrossFrameRatesAndLongFrame() {
        for frameRate in [15, 30, 60, 120] {
            var value: Float = 0
            for _ in 0..<frameRate {
                value += (1 - value) * PoulpiAnimationTiming.smoothing(elapsed: 1 / Double(frameRate))
            }
            XCTAssertEqual(value, 0.9995437, accuracy: 0.000002)
        }
        XCTAssertEqual(PoulpiAnimationTiming.smoothing(elapsed: 0.13), 0.63212055, accuracy: 0.000001)
        XCTAssertEqual(PoulpiAnimationTiming.smoothing(elapsed: 0), 0)
        XCTAssertEqual(PoulpiAnimationTiming.smoothing(elapsed: -1), 0)
    }

    func testSneezeHasOnePeakAndQuietEnds() {
        let values = (0...100).map { PoulpiAnimationTiming.sneezeImpulse(phase: Float($0) / 100) }
        XCTAssertTrue(values.prefix(46).allSatisfy { $0 == 0 })
        XCTAssertTrue(values.suffix(36).allSatisfy { $0 == 0 })
        XCTAssertEqual(values[55], 1, accuracy: 0.000001)
        for index in 46...55 { XCTAssertGreaterThanOrEqual(values[index], values[index - 1]) }
        for index in 56...65 { XCTAssertLessThanOrEqual(values[index], values[index - 1]) }
    }
}
