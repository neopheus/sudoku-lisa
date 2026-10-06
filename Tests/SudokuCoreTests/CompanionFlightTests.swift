import XCTest
@testable import SudokuCore

final class CompanionFlightTests: XCTestCase {
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
