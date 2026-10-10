import XCTest
@testable import SudokuLisa

final class PoulpiInspectionSequenceTests: XCTestCase {
    func testReferenceSequenceCoversEveryExpressionAtAllInspectionAngles() {
        let steps = PoulpiInspectionStep.reference
        for mood in LisaMascotMood.allCases {
            let matching = steps.filter { $0.mood == mood }
            XCTAssertEqual(Set(matching.map(\.yaw)), Set([-0.45, 0, 0.45]))
            XCTAssertEqual(matching.count, 3)
            XCTAssertTrue(matching.allSatisfy { $0.duration >= mood.reactionDuration })
            // The idle blink occurs towards the end of each four-second cycle.
            XCTAssertTrue(matching.allSatisfy { $0.duration >= 4.2 })
        }
        XCTAssertEqual(steps.count, LisaMascotMood.allCases.count * 3)
    }
}
