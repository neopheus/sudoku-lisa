import XCTest
import SwiftUI
@testable import SudokuLisa

@MainActor
final class EffectSchedulingTests: XCTestCase {
    func testPausedShimmerEmitsOnlyInitialEntry() {
        let start = Date(timeIntervalSinceReferenceDate: 813_572_412)
        let entries = LisaEffectSchedule(interval: 1 / 24, paused: true, shimmerPhase: 0.7)
            .entries(from: start, mode: .normal)
        XCTAssertEqual(Array(entries), [start])
    }

    func testCachedPathsMatchOriginalConstructionAndInvalidateWithGeometry() {
        let cache = LisaCelebrationGeometryCache()
        for width in [270.0, 337.25, 414.0, 270.0] {
            let value = cache.geometry(size: CGSize(width: width, height: width), token: 7,
                                       units: Set(0..<27), cells: Set(0..<81), originIndex: 40)
            XCTAssertEqual(value.metrics.side, width / 9)
            for (offset, cell) in value.metrics.cells.enumerated() {
                XCTAssertEqual(value.cellPaths[offset], Path(roundedRect: cell.rect, cornerRadius: 5))
            }
            for (offset, unit) in value.metrics.units.enumerated() {
                XCTAssertEqual(value.unitPaths[offset], Path(roundedRect: unit.rect.insetBy(dx: 1, dy: 1), cornerRadius: 6))
            }
        }
        let changed = cache.geometry(size: CGSize(width: 270, height: 270), token: 8,
                                     units: [9], cells: [80], originIndex: 80)
        XCTAssertEqual(changed.metrics.cells.map(\.index), [80])
        XCTAssertEqual(changed.metrics.units.map(\.index), [9])
        XCTAssertEqual(changed.metrics.cells.first?.delay, 0)
    }
}
