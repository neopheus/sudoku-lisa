import XCTest
@testable import SudokuCore

final class LogicalEngineTests: XCTestCase {
    func testWorkloadCountsTechniqueFrequencyAndConsecutiveEliminations() {
        func placement(_ technique: SudokuTechnique) -> SudokuDeduction {
            SudokuDeduction(techniqueID: technique, action: .placement(index: 0, value: 1), focusCells: [0])
        }
        func elimination(_ technique: SudokuTechnique, _ count: Int) -> SudokuDeduction {
            SudokuDeduction(techniqueID: technique, action: .eliminations((0..<count).map { CandidateElimination(index: $0, value: 2) }), focusCells: [0])
        }
        let trace = [placement(.nakedSingle), elimination(.lockedCandidates, 3), elimination(.nakedPair, 2),
                     placement(.hiddenSingle), elimination(.nakedPair, 4), elimination(.lockedCandidates, 1), elimination(.nakedPair, 2)]
        let analysis = LogicalAnalysis(deductions: trace, rating: .nakedPairs, isSolved: true, finalBoard: [])
        let workload = analysis.workload
        XCTAssertEqual(workload.placementCount, 2)
        XCTAssertEqual(workload.eliminationStepCount, 5)
        XCTAssertEqual(workload.eliminatedCandidateCount, 12)
        XCTAssertEqual(workload.hardestTechniqueCount, 3)
        XCTAssertEqual(workload.longestEliminationRun, 3)
        XCTAssertEqual(workload.techniqueCounts[.nakedPair], 3)
        XCTAssertEqual(workload.techniqueCounts[.lockedCandidates], 2)
        let empty = LogicalAnalysis(deductions: [], rating: .nakedSingles, isSolved: true, finalBoard: []).workload
        XCTAssertEqual(empty.placementCount + empty.eliminationStepCount + empty.longestEliminationRun + empty.hardestTechniqueCount, 0)
    }
    func testNotesUndoPreservesPreviouslyAppliedEliminations() throws {
        var game = GameSession(puzzle: SudokuGenerator.generate(difficulty: .hard, seed: 10))
        while let hint = game.hint(), let deduction = hint.deduction {
            XCTAssertTrue(game.applyDeduction(deduction))
            if case .eliminations = deduction.action {
                let before = game
                let empty = try XCTUnwrap(game.values.firstIndex(of: 0))
                game.toggleNote(9, at: empty)
                XCTAssertEqual(game.candidateEliminations, before.candidateEliminations)
                game = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(game))
                game.undo()
                XCTAssertEqual(game, before)
                return
            }
        }
        XCTFail("Hard trace must use eliminations")
    }

    func testAtomicTraceHintsAndRatingUseSameRules() throws {
        for difficulty in Difficulty.allCases {
            let puzzle = SudokuGenerator.generate(difficulty: difficulty, seed: 5)
            let analysis = try XCTUnwrap(SudokuSolver.logicalAnalysis(puzzle.givens))
            var game = GameSession(puzzle: puzzle), state = LogicalState(board: puzzle.givens)
            var hardest = HumanTechniqueRating.nakedSingles
            for expected in analysis.deductions {
                XCTAssertEqual(state.nextDeduction(), expected)
                XCTAssertEqual(game.hint()?.deduction, expected)
                let before = game.values
                XCTAssertTrue(game.applyDeduction(expected))
                XCTAssertTrue(state.apply(expected))
                if case let .eliminations(marks) = expected.action {
                    XCTAssertEqual(game.values, before, "Elimination does not smuggle in a later placement")
                    XCTAssertTrue(marks.allSatisfy { puzzle.solution[$0.index] != $0.value })
                    XCTAssertTrue(marks.allSatisfy { !game.candidates(at: $0.index).contains($0.value) })
                }
                XCTAssertTrue(state.isConsistent)
                XCTAssertEqual(state.board, game.values)
                hardest = max(hardest, expected.techniqueID.rating)
            }
            XCTAssertTrue(game.isComplete)
            XCTAssertEqual(hardest, analysis.rating)
        }
    }
    func testEliminationsPersistUndoAndInvalidateAfterBoardReplacement() throws {
        var game = GameSession(puzzle: SudokuGenerator.generate(difficulty: .hard, seed: 10))
        while let hint = game.hint(), let deduction = hint.deduction {
            if case let .eliminations(marks) = deduction.action {
                let mark = try XCTUnwrap(marks.first)
                game.toggleNote(mark.value, at: mark.index)
                let before = game
                XCTAssertTrue(game.applyDeduction(deduction))
                XCTAssertFalse(game.notes[mark.index].contains(mark.value))
                XCTAssertTrue(game.candidateEliminations.contains(mark))
                game = try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(game))
                let after = game
                game.undo()
                XCTAssertEqual(game, before)
                XCTAssertTrue(game.applyDeduction(deduction))
                XCTAssertEqual(game, after)
                let editable = try XCTUnwrap((0..<81).first { game.puzzle.givens[$0] == 0 && game.values[$0] != 0 })
                game.erase(at: editable)
                XCTAssertTrue(game.candidateEliminations.isEmpty)
                game.undo()
                XCTAssertEqual(game, after)
                return
            }
            XCTAssertTrue(game.applyDeduction(deduction))
        }
        XCTFail("Hard profile must contain an elimination")
    }
    func testEliminationRejectsSolutionDigitAndRepeatedStaleAction() throws {
        var game = GameSession(puzzle: SudokuGenerator.generate(difficulty: .hard, seed: 2))
        let empty = try XCTUnwrap(game.values.firstIndex(of: 0))
        let invalid = SudokuDeduction(techniqueID: .nakedPair, action: .eliminations([CandidateElimination(index: empty, value: game.puzzle.solution[empty])]), focusCells: [empty])
        XCTAssertFalse(game.applyDeduction(invalid))
        while let hint = game.hint(), let deduction = hint.deduction {
            if case .eliminations = deduction.action {
                XCTAssertTrue(game.applyDeduction(deduction))
                let after = game
                XCTAssertFalse(game.applyDeduction(deduction))
                XCTAssertEqual(game, after)
                return
            }
            XCTAssertTrue(game.applyDeduction(deduction))
        }
        XCTFail("Hard profile must contain an elimination")
    }
    func testHintCorrectionDoesNotExposeValueInObservation() {
        var game = GameSession(puzzle: SudokuGenerator.generate(seed: 17))
        let cell = game.values.firstIndex(of: 0)!
        game.enter(game.puzzle.solution[cell] % 9 + 1, at: cell)
        let hint = game.hint()!
        XCTAssertEqual(hint.deduction?.techniqueID, .correction)
        XCTAssertEqual(hint.detail, hint.deduction?.observation)
        XCTAssertFalse(hint.detail.contains("correcte est"))
    }
    func testInvalidStateAndEveryAlternateDeductionRemainSound() throws {
        XCTAssertNil(LogicalState(board: [Int](repeating: 999, count: 81)).nextDeduction())
        XCTAssertNil(try SudokuSolver.logicalAnalysis([1]))
        let board = PuzzleCorpus.entries(for: .master)[0].givens.map { Int(String($0))! }
        let solution = try XCTUnwrap(SudokuSolver.solve(board))
        let state = LogicalState(board: board)
        for technique in SudokuTechnique.allCases {
            for deduction in state.deductions(technique: technique) {
                switch deduction.action {
                case let .placement(index, value): XCTAssertEqual(value, solution[index])
                case let .eliminations(marks): XCTAssertFalse(marks.isEmpty); XCTAssertTrue(marks.allSatisfy { solution[$0.index] != $0.value })
                }
            }
        }
    }
}
