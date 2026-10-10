import XCTest
@testable import SudokuCore

final class PoulpiEyelidWeightsTests: XCTestCase {
    func testSparseWritesMatchOriginalMorphAcrossClosureAndReopening() {
        var state = PoulpiEyelidWeights()
        var applied = Array(repeating: Float(0), count: 16)
        var writes = 0
        // Includes every target boundary, smooth sweeps, and interrupted blinks.
        let samples = (0...1000).map { Float($0) / 1000 }
            + (0...1000).reversed().map { Float($0) / 1000 }
            + [0, 1, 0.625, 0.25, 0.9, 0, 0.5, 0.5]
        for closure in samples {
            let old = applied
            var changed: [Int] = []
            state.update(closure: closure) { index, weight in
                applied[index] = weight
                changed.append(index)
                writes += 1
            }
            let phase = closure * 16
            let segment = min(15, Int(phase)), progress = phase - Float(segment)
            let reference: [Float] = (0..<16).map {
                $0 == segment ? progress : ($0 == segment - 1 ? 1 - progress : 0)
            }
            XCTAssertEqual(applied, reference, "Different geometry at closure \(closure)")
            XCTAssertEqual(Set(changed), Set((0..<16).filter { old[$0] != reference[$0] }))
            XCTAssertLessThanOrEqual(changed.count, 4)
        }
        XCTAssertLessThan(writes, samples.count * 3)
    }

    func testRepeatedPoseDoesNotWriteAnyMorphWeights() {
        var state = PoulpiEyelidWeights()
        state.update(closure: 0.47) { _, _ in }
        var writes = 0
        for _ in 0..<120 { state.update(closure: 0.47) { _, _ in writes += 1 } }
        XCTAssertEqual(writes, 0)
    }
}
