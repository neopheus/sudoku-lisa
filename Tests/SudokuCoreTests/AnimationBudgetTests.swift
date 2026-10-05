import XCTest
@testable import SudokuCore

final class AnimationBudgetTests: XCTestCase {
    func testLoadReducesDetailBeforeCadence() {
        var budget = AnimationBudget()
        budget.sample(lateFraction: 0.2)
        XCTAssertEqual(budget.level, 1)
        XCTAssertEqual(AnimationBudget.frameRate(maximum: 120, level: budget.level, lowPower: false, hot: false), 120)
        budget.sample(lateFraction: 0.3)
        XCTAssertEqual(budget.level, 2)
        XCTAssertEqual(AnimationBudget.frameRate(maximum: 120, level: budget.level, lowPower: false, hot: false), 60)
        budget.sample(lateFraction: 1)
        XCTAssertEqual(budget.level, 2)
    }
    func testRecoveryRequiresSustainedHeadroom() {
        var budget = AnimationBudget()
        budget.sample(lateFraction: 0.5)
        for _ in 0..<7 { budget.sample(lateFraction: 0) }
        XCTAssertEqual(budget.level, 1)
        budget.sample(lateFraction: 0.1)
        budget.sample(lateFraction: 0)
        XCTAssertEqual(budget.level, 1)
        for _ in 0..<7 { budget.sample(lateFraction: 0) }
        XCTAssertEqual(budget.level, 0)
    }
    func testPowerThermalAndScreenLimits() {
        XCTAssertEqual(AnimationBudget.effectiveLevel(measured: 0, lowPower: true, hot: false), 1)
        XCTAssertEqual(AnimationBudget.effectiveLevel(measured: 0, lowPower: false, hot: true), 2)
        XCTAssertEqual(AnimationBudget.frameRate(maximum: 60, level: 0, lowPower: false, hot: false), 60)
        XCTAssertEqual(AnimationBudget.frameRate(maximum: 120, level: 0, lowPower: true, hot: false), 60)
        XCTAssertEqual(AnimationBudget.frameRate(maximum: 120, level: 0, lowPower: false, hot: true), 30)
    }
}
