import XCTest
@testable import SudokuCore

final class CompanionFlightTests: XCTestCase {
    /// Independent Hermite evaluation protects the route when its implementation
    /// is optimized. Includes negative times, knots and several complete loops.
    func testRouteMatchesHermiteReferenceAcrossLoops() {
        let points: [(Double, Double, Double)] = [
            (0, 0.76, -1), (0.72, 0.35, 1.2), (0.68, -0.62, 0),
            (-0.58, -0.72, -1), (-0.74, 0.10, 1.5), (-0.35, 0.32, -5),
            (0.55, 0.58, -3), (0.10, 0.72, 4)
        ]
        func reference(_ time: Double) -> [Double] {
            let phase = (time - floor(time / 32) * 32) / 4
            let index = Int(phase), t = phase - floor(phase)
            let a = points[(index + 7) % 8], b = points[index]
            let c = points[(index + 1) % 8], d = points[(index + 2) % 8]
            func axis(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> [Double] {
                let m0 = (c - a) / 2, m1 = (d - b) / 2
                return [
                    (2*t*t*t - 3*t*t + 1)*b + (t*t*t - 2*t*t + t)*m0
                        + (-2*t*t*t + 3*t*t)*c + (t*t*t - t*t)*m1,
                    ((6*t*t - 6*t)*b + (3*t*t - 4*t + 1)*m0
                        + (-6*t*t + 6*t)*c + (3*t*t - 2*t)*m1) / 4
                ]
            }
            return axis(a.0, b.0, c.0, d.0) + axis(a.1, b.1, c.1, d.1) + axis(a.2, b.2, c.2, d.2)
        }
        for frame in -3840...7680 {
            let time = Double(frame) / 120
            let pose = CompanionFlight.sample(seconds: time)
            let actual = [pose.x, pose.dx, pose.y, pose.dy, pose.depth, pose.dz]
            for (value, expected) in zip(actual, reference(time)) {
                XCTAssertEqual(value, expected, accuracy: 1e-11, "time=\(time)")
            }
        }
    }

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
    func testOptimizedSwimmingRetainsTurnAndStroke() {
        for index in -3840...7680 {
            let time = Double(index) / 120
            let phase = time * Double.pi
            let routeTime = time + 0.18 * (1 - cos(phase))
            let previous = CompanionFlight.sample(seconds: routeTime - 0.08)
            let next = CompanionFlight.sample(seconds: routeTime + 0.08)
            let heading = atan2(previous.dx * next.dy - previous.dy * next.dx,
                                previous.dx * next.dx + previous.dy * next.dy)
            let swim = CompanionFlight.swimming(seconds: time)
            XCTAssertEqual(swim.turn, max(-1, min(1, heading * 5)), accuracy: 1e-12)
            XCTAssertEqual(swim.propulsion, (1 + sin(phase)) / 2, accuracy: 1e-12)
            XCTAssertEqual(swim.braking, max(0, -cos(phase)), accuracy: 1e-12)
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
