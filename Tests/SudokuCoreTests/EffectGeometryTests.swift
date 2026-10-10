import XCTest
import CoreGraphics
@testable import SudokuCore

final class EffectGeometryTests: XCTestCase {
    func testDormantScheduleSkipsToNextSweepWithoutChangingAbsolutePhase() {
        let schedule = ShimmerFrameSequence(start: 12, phase: 0, interval: 1 / 24)
        var iterator = schedule.makeIterator()
        let frames = (0..<100).compactMap { _ in iterator.next() }
        XCTAssertEqual(frames.first, 12)
        XCTAssertTrue(frames.allSatisfy { time in
            let cycle = time.truncatingRemainder(dividingBy: 5.5)
            return cycle <= 1.6 + 0.000001
        })
        XCTAssertTrue(zip(frames, frames.dropFirst()).contains { $1 - $0 > 3.8 })
    }

    func testClosingFrameIsHiddenAtRealisticAbsoluteTimesAndPhaseOffsets() {
        for phase in [0.0, 0.2, 1.7, 4.9] {
            for start in [0.0, 12.0, 813_572_412.13] {
                var iterator = ShimmerFrameSequence(start: start, phase: phase, interval: 1 / 24).makeIterator()
                var previous = iterator.next()!
                for _ in 0..<500 {
                    let next = iterator.next()!
                    XCTAssertGreaterThan(next, previous)
                    let cycle = (previous + phase).truncatingRemainder(dividingBy: 5.5)
                    if next - previous > 1 {
                        XCTAssertGreaterThanOrEqual(cycle, 1.6, "Closing frame must hide the sweep")
                    } else if cycle < 1.6 && next - previous > 0.00001 {
                        XCTAssertLessThanOrEqual(next - previous, 1 / 24 + 0.000001)
                    }
                    previous = next
                }
            }
        }
    }

    func testSparseScheduleAlwaysAdvancesAcrossManyFractionalPhases() {
        for seed in 0..<100 {
            let phase = Double(seed * 7919 % 55000) / 10000
            let start = 813_572_412.0 + Double(seed * 3571 % 10000) / 10000
            var iterator = ShimmerFrameSequence(start: start, phase: phase, interval: 1 / 24).makeIterator()
            var previous = iterator.next()!
            for _ in 0..<1000 {
                let next = iterator.next()!
                XCTAssertGreaterThan(next, previous)
                if next - previous > 1 {
                    XCTAssertGreaterThanOrEqual((previous + phase).truncatingRemainder(dividingBy: 5.5), 1.6)
                }
                previous = next
            }
        }
    }

    func testNegativePhaseAndSubPrecisionIntervalCannotStallTheSequence() {
        for (start, phase, interval) in [(0.0, -4.0, 1.0 / 24),
                                         (-12.0, 0.0, 1.0 / 24),
                                         (813_572_412.0, 0.0, 0.000000001)] {
            var iterator = ShimmerFrameSequence(start: start, phase: phase, interval: interval).makeIterator()
            var previous = iterator.next()!
            for _ in 0..<1000 {
                let next = iterator.next()!
                XCTAssertGreaterThan(next, previous)
                previous = next
            }
        }
    }

    func testGeometryExactlyMatchesOriginalForEveryOriginAndCell() {
        for width in [270.0, 337.25, 414.0] {
            for origin in 0..<81 {
                let geometry = CelebrationGeometry(width: width, cells: Set(0..<81), units: Set(0..<27), originIndex: origin)
                let side = width / 9
                let point = CGPoint(x: (Double(origin % 9) + 0.5) * side, y: (Double(origin / 9) + 0.5) * side)
                XCTAssertEqual(geometry.origin, point)
                XCTAssertEqual(geometry.cells.map(\.index), Array(0..<81))
                for cell in geometry.cells {
                    let center = CGPoint(x: (Double(cell.index % 9) + 0.5) * side, y: (Double(cell.index / 9) + 0.5) * side)
                    XCTAssertEqual(cell.center, center)
                    XCTAssertEqual(cell.delay, hypot(center.x - point.x, center.y - point.y) / side * 0.025)
                    XCTAssertEqual(cell.rect, testRect(x: Double(center.x) - side / 2 + 2, y: Double(center.y) - side / 2 + 2, width: side - 4, height: side - 4))
                }
                for unit in geometry.units {
                    let i = unit.index
                    let expected: CGRect
                    if i < 9 { expected = testRect(x: 1, y: Double(i) * side + 1, width: side * 9 - 2, height: side - 2) }
                    else if i < 18 { expected = testRect(x: Double(i - 9) * side + 1, y: 1, width: side - 2, height: side * 9 - 2) }
                    else { let b = i - 18; expected = testRect(x: Double(b % 3 * 3) * side + 1, y: Double(b / 3 * 3) * side + 1, width: side * 3 - 2, height: side * 3 - 2) }
                    XCTAssertEqual(unit.rect, expected)
                }
            }
        }
    }
}

private func testRect(x: Double, y: Double, width: Double, height: Double) -> CGRect {
    CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
}
