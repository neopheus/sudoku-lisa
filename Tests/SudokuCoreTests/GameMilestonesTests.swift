import XCTest
@testable import SudokuCore

final class GameMilestonesTests: XCTestCase {
    private var solution: [Int] { (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 } }

    func testLastCellCompletesRowColumnBoxAndDigitTogether() {
        var before = solution
        before[0] = 0
        var tracker = GameMilestones()
        let event = tracker.record(before: before, after: solution, solution: solution, revealsCorrectness: true)
        XCTAssertEqual(event.unitCount, 3)
        XCTAssertEqual(event.completedUnits, [0, 9, 18])
        XCTAssertEqual(event.digits, [1])
        XCTAssertEqual(event.cells.count, 21)
        XCTAssertTrue(event.cells.contains(8))
        XCTAssertTrue(event.cells.contains(72))
        XCTAssertTrue(event.cells.contains(20))
        XCTAssertFalse(event.cells.contains(40))
    }

    func testIsolatedUnitsKeepTheirIdentity() {
        for unit in [4, 13, 22] {
            var before = Array(repeating: 0, count: 81)
            let cells: [Int]
            if unit < 9 { cells = (0..<9).map { unit * 9 + $0 } }
            else if unit < 18 { cells = (0..<9).map { $0 * 9 + unit - 9 } }
            else { cells = (0..<9).map { (3 + $0 / 3) * 9 + 3 + $0 % 3 } }
            for cell in cells.dropFirst() { before[cell] = solution[cell] }
            var after = before
            after[cells[0]] = solution[cells[0]]
            var tracker = GameMilestones()
            let event = tracker.record(before: before, after: after, solution: solution, revealsCorrectness: true)
            XCTAssertEqual(event.completedUnits, [unit])
            XCTAssertEqual(event.cells, Set(cells))
        }
    }

    func testIncorrectFullUnitAndNineCopiesDoNotCelebrate() {
        var before = solution
        before[0] = 0
        var after = solution
        after[0] = 2
        var tracker = GameMilestones()
        XCTAssertTrue(tracker.record(before: before, after: after, solution: solution, revealsCorrectness: true).isEmpty)
        XCTAssertTrue(tracker.units.isEmpty)
        XCTAssertTrue(tracker.digits.isEmpty)
    }

    func testZenModeNeverExposesCorrectnessAndDoesNotReplayOnSettingChange() {
        var before = solution
        before[0] = 0
        var tracker = GameMilestones()
        XCTAssertTrue(tracker.record(before: before, after: solution, solution: solution, revealsCorrectness: false).isEmpty)
        XCTAssertTrue(tracker.record(before: before, after: solution, solution: solution, revealsCorrectness: true).isEmpty)
    }

    func testUndoAndReentryDoNotFarmCelebrations() {
        var before = solution
        before[40] = 0
        var tracker = GameMilestones()
        XCTAssertFalse(tracker.record(before: before, after: solution, solution: solution, revealsCorrectness: true).isEmpty)
        XCTAssertTrue(tracker.record(before: solution, after: before, solution: solution, revealsCorrectness: true).isEmpty)
        XCTAssertTrue(tracker.record(before: before, after: solution, solution: solution, revealsCorrectness: true).isEmpty)
    }

    func testUnchangedAndMalformedBoardsDoNotEmitEvents() {
        var tracker = GameMilestones()
        XCTAssertTrue(tracker.record(before: solution, after: solution, solution: solution, revealsCorrectness: true).isEmpty)
        XCTAssertTrue(tracker.record(before: [], after: solution, solution: solution, revealsCorrectness: true).isEmpty)
    }
}
