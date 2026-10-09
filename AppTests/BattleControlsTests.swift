import XCTest
import SudokuCore
@testable import SudokuLisa

final class BattleControlsTests: XCTestCase {
    @MainActor func testDigitCanBeLockedBeforeSelectingCell() {
        let battle = BattleService()
        battle.prepareControlsTestRound()
        XCTAssertNil(battle.selection)
        battle.lockDigit(1)
        XCTAssertEqual(battle.lockedDigit, 1)
        battle.select(0)
        XCTAssertEqual(battle.selection, 0)
        XCTAssertEqual(battle.session?.values[0], 1)
        battle.unlockDigit()
        XCTAssertNil(battle.lockedDigit)
    }

    func testRemainingCountsIgnoreWrongEntriesAndFollowUndo() {
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var givens = solution
        givens[0] = 0
        givens[1] = 0
        var game = GameSession(puzzle: Puzzle(givens: givens, solution: solution, difficulty: .easy, seed: 42))

        XCTAssertEqual(BattleBoardSummary(game: game).remaining[0], 1)
        game.enter(2, at: 0)
        let wrong = BattleBoardSummary(game: game)
        XCTAssertEqual(wrong.remaining[0], 1)
        XCTAssertEqual(wrong.remaining[1], 1)
        XCTAssertTrue(wrong.duplicates.contains(0))

        game.enter(1, at: 0)
        let correct = BattleBoardSummary(game: game)
        XCTAssertEqual(correct.remaining[0], 0)
        XCTAssertFalse(correct.duplicates.contains(0))

        game.undo()
        XCTAssertEqual(BattleBoardSummary(game: game), wrong)
    }

    func testNotesDoNotConsumeDigitOrCreateConflicts() {
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var givens = solution
        givens[0] = 0
        var game = GameSession(puzzle: Puzzle(givens: givens, solution: solution, difficulty: .easy, seed: 42))
        let original = BattleBoardSummary(game: game)
        game.toggleNote(2, at: 0)
        XCTAssertEqual(BattleBoardSummary(game: game), original)
    }
}
