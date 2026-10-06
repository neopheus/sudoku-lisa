import XCTest
@testable import SudokuCore

final class CompanionFlightTests: XCTestCase {
    func testSwimmingVelocityMatchesActualDisplacement() {
        let step = 0.00001
        for index in 0...640 {
            let time = Double(index) / 20
            let current = CompanionFlight.swimming(seconds: time)
            let before = CompanionFlight.swimming(seconds: time - step).pose
            let after = CompanionFlight.swimming(seconds: time + step).pose
            XCTAssertEqual(current.pose.dx, (after.x - before.x) / (2 * step), accuracy: 0.0001)
            XCTAssertEqual(current.pose.dy, (after.y - before.y) / (2 * step), accuracy: 0.0001)
            XCTAssertEqual(current.pose.dz, (after.depth - before.depth) / (2 * step), accuracy: 0.0001)
            XCTAssertTrue((0...1).contains(current.propulsion))
            XCTAssertTrue((0...1).contains(current.braking))
            XCTAssertTrue((0...1).contains(current.effort))
            XCTAssertTrue((-1...1).contains(current.turn))
        }
    }
    func testSwimmingLoopClosesWithoutPoseOrStrokeJump() {
        let before = CompanionFlight.swimming(seconds: 32 - 0.00001)
        let after = CompanionFlight.swimming(seconds: 0.00001)
        XCTAssertEqual(before.pose.x, after.pose.x, accuracy: 0.0001)
        XCTAssertEqual(before.pose.y, after.pose.y, accuracy: 0.0001)
        XCTAssertEqual(before.pose.depth, after.pose.depth, accuracy: 0.0001)
        XCTAssertEqual(before.pose.dx, after.pose.dx, accuracy: 0.0001)
        XCTAssertEqual(before.pose.dy, after.pose.dy, accuracy: 0.0001)
        XCTAssertEqual(before.pose.dz, after.pose.dz, accuracy: 0.0001)
        XCTAssertEqual(before.propulsion, after.propulsion, accuracy: 0.0001)
        XCTAssertEqual(before.braking, after.braking, accuracy: 0.0001)
        XCTAssertEqual(before.turn, after.turn, accuracy: 0.0001)
    }
    func testRouteCoversScreenAndDepthWithinBounds() {
        let samples = (0...3200).map { CompanionFlight.sample(seconds: Double($0) / 100) }
        XCTAssertLessThan(samples.map(\.x).min()!, -0.7)
        XCTAssertGreaterThan(samples.map(\.x).max()!, 0.7)
        XCTAssertLessThan(samples.map(\.y).min()!, -0.7)
        XCTAssertGreaterThan(samples.map(\.y).max()!, 0.7)
        XCTAssertLessThan(samples.map(\.depth).min()!, -4.9)
        XCTAssertGreaterThan(samples.map(\.depth).max()!, 3.9)
        for p in samples {
            XCTAssertLessThan(abs(p.x), 0.9)
            XCTAssertLessThan(abs(p.y), 0.9)
            XCTAssertTrue(p.dx.isFinite && p.dy.isFinite && p.dz.isFinite)
        }
    }
    func testJoinsAndLoopHaveContinuousPositionAndVelocity() {
        for second in stride(from: 0, through: 32, by: 4) {
            let a = CompanionFlight.sample(seconds: Double(second) - 0.0001)
            let b = CompanionFlight.sample(seconds: Double(second) + 0.0001)
            XCTAssertEqual(a.x, b.x, accuracy: 0.001)
            XCTAssertEqual(a.y, b.y, accuracy: 0.001)
            XCTAssertEqual(a.depth, b.depth, accuracy: 0.001)
            XCTAssertEqual(a.dx, b.dx, accuracy: 0.001)
            XCTAssertEqual(a.dy, b.dy, accuracy: 0.001)
            XCTAssertEqual(a.dz, b.dz, accuracy: 0.001)
        }
    }
}
