import XCTest
@testable import SudokuCore

final class AssistanceTests: XCTestCase {
    private func game() -> GameSession {
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var givens = solution
        for i in [0, 1, 9, 10, 40] { givens[i] = 0 }
        return GameSession(puzzle: Puzzle(givens: givens, solution: solution, difficulty: .quick, seed: 1))
    }

    func testFillPreservesNotesAndIsOneUndo() throws {
        var session = game()
        session.toggleNote(9, at: 0)
        _ = session.enter(session.puzzle.solution[40], at: 40)
        let before = session
        XCTAssertTrue(session.fillEmptyNotes())
        XCTAssertEqual(session.notes[0], [9])
        XCTAssertTrue(session.notes[40].isEmpty)
        XCTAssertTrue(session.notes[2].isEmpty)
        XCTAssertFalse(session.notes[1].isEmpty)
        XCTAssertEqual(session.values, before.values)
        XCTAssertEqual(session.hintsUsed, 0)
        XCTAssertFalse(session.usedLogicalAssistance)
        XCTAssertFalse(session.fillEmptyNotes())
        session.undo()
        XCTAssertEqual(session, before, "No-op fill must not add history")
    }

    func testCandidatesUseVisibleValuesAndIgnoreNotes() {
        var session = game()
        session.toggleNote(9, at: 0)
        let snapshot = AssistanceSnapshot(values: session.values, eliminations: [])
        XCTAssertEqual(snapshot.candidates[0], [1])
        // A wrong visible digit constrains candidates even though it differs from the solution.
        _ = session.enter(1, at: 1)
        let wrong = AssistanceSnapshot(values: session.values, eliminations: [], includeDeduction: true)
        XCTAssertFalse(wrong.candidates[0].contains(1))
        XCTAssertFalse(wrong.isConsistent)
        XCTAssertNil(wrong.deduction)
        XCTAssertFalse(session.fillEmptyNotes())
    }

    func testEliminationsRespectedAndStaleSnapshotRejected() {
        var session = game()
        let before = AssistanceSnapshot(values: session.values, eliminations: [])
        _ = session.enter(1, at: 0)
        XCTAssertFalse(session.fillEmptyNotes(using: before))
        let empty = Array(repeating: 0, count: 81)
        let snapshot = AssistanceSnapshot(values: empty, eliminations: [.init(index: 0, value: 3)])
        XCTAssertFalse(snapshot.candidates[0].contains(3))
        XCTAssertTrue(snapshot.candidates[1].contains(3))
    }

    func testFillKeepsValidatedEliminations() throws {
        let solution = game().puzzle.solution
        var session = GameSession(puzzle: Puzzle(givens: Array(repeating: 0, count: 81), solution: solution, difficulty: .quick, seed: 2))
        let removal = SudokuDeduction(techniqueID: .nakedPair, action: .eliminations([.init(index: 0, value: 2)]), focusCells: [0])
        XCTAssertTrue(session.applyDeduction(removal))
        let before = session
        XCTAssertTrue(session.fillEmptyNotes())
        XCTAssertFalse(session.notes[0].contains(2))
        XCTAssertTrue(session.notes[1].contains(2))
        session.undo()
        XCTAssertEqual(session, before)
    }

    func testAssistanceSurvivesUndoAndSaveAndLegacyDefaultsFalse() throws {
        var session = game()
        session.toggleNote(9, at: 0)
        let before = session.notes
        session.recordLogicalAssistance()
        XCTAssertTrue(session.fillEmptyNotes())
        let data = try JSONEncoder().encode(session)
        var restored = try JSONDecoder().decode(GameSession.self, from: data)
        restored.undo()
        XCTAssertEqual(restored.notes, before)
        XCTAssertTrue(restored.usedLogicalAssistance)
        XCTAssertEqual(restored.hintsUsed, 0)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "usedLogicalAssistance")
        let migrated = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertFalse(migrated.usedLogicalAssistance)
        XCTAssertEqual(migrated.notes, session.notes)
        XCTAssertFalse(game().usedLogicalAssistance)
    }

    func testCleanOnlyRemovesImpossibleNotesAndUndoIsAtomic() throws {
        var session = game()
        session.toggleNote(1, at: 0)
        session.toggleNote(9, at: 0)
        session.toggleNote(2, at: 1)
        session.toggleNote(8, at: 1)
        let before = session
        XCTAssertTrue(session.pruneImpossibleNotes())
        XCTAssertEqual(session.notes[0], [1])
        XCTAssertEqual(session.notes[1], [2])
        XCTAssertEqual(session.values, before.values)
        XCTAssertFalse(session.pruneImpossibleNotes(), "No-op must not add history")
        var restored = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(session))
        restored.undo()
        XCTAssertEqual(restored, before)
    }

    func testCleanRejectsStaleOrContradictoryAnalysis() {
        var session = game()
        session.toggleNote(1, at: 0)
        let stale = AssistanceSnapshot(values: session.values, eliminations: [])
        _ = session.enter(1, at: 1)
        let before = session
        XCTAssertFalse(session.pruneImpossibleNotes(using: stale))
        XCTAssertFalse(session.pruneImpossibleNotes())
        XCTAssertEqual(session, before)
    }

    func testCleanRespectsEliminationsWithoutAddingMissingNotes() {
        var session = GameSession(puzzle: Puzzle(givens: Array(repeating: 0, count: 81),
            solution: game().puzzle.solution, difficulty: .quick, seed: 2))
        XCTAssertTrue(session.applyDeduction(SudokuDeduction(techniqueID: .nakedPair,
            action: .eliminations([.init(index: 0, value: 2)]), focusCells: [0])))
        session.toggleNote(2, at: 0)
        session.toggleNote(3, at: 0)
        let before = session
        XCTAssertTrue(session.pruneImpossibleNotes())
        XCTAssertEqual(session.notes[0], [3])
        XCTAssertTrue(session.notes[1].isEmpty)
        XCTAssertEqual(session.candidateEliminations, before.candidateEliminations)
        session.undo()
        XCTAssertEqual(session, before)
    }

    func testClearNotesPreservesValuesAndEliminationsAndSurvivesSave() throws {
        var session = game()
        XCTAssertTrue(session.fillEmptyNotes())
        _ = session.enter(9, at: 40)
        let before = session
        XCTAssertTrue(session.clearNotes())
        XCTAssertTrue(session.notes.allSatisfy(\.isEmpty))
        XCTAssertEqual(session.values, before.values)
        XCTAssertEqual(session.candidateEliminations, before.candidateEliminations)
        XCTAssertEqual(session.hintsUsed, 0)
        XCTAssertFalse(session.usedLogicalAssistance)
        XCTAssertFalse(session.clearNotes())
        var restored = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(session))
        restored.undo()
        XCTAssertEqual(restored, before)
    }

    func testNoDeductionAndCancellationDoNotRevealSolution() {
        let empty = Array(repeating: 0, count: 81)
        XCTAssertNil(AssistanceSnapshot(values: empty, eliminations: [], includeDeduction: true).deduction)
        XCTAssertNil(AssistanceSnapshot(values: game().values, eliminations: [], includeDeduction: true, cancellation: { true }).deduction)
    }
}
