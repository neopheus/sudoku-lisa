import XCTest
@testable import SudokuCore

final class SudokuCoreTests: XCTestCase {
    func testGeneratedPuzzlesHaveExactlyOneValidSolution() {
        for difficulty in Difficulty.allCases {
            for seed: UInt64 in [0, 42, 20261005] {
                let puzzle = SudokuGenerator.generate(difficulty: difficulty, seed: seed)
                XCTAssertTrue(SudokuSolver.isValidSolution(puzzle.solution))
                XCTAssertEqual(SudokuSolver.countSolutions(puzzle.givens), 1)
                XCTAssertEqual(SudokuSolver.solve(puzzle.givens), puzzle.solution)
                XCTAssertEqual(puzzle, SudokuGenerator.generate(difficulty: difficulty, seed: seed))
                XCTAssertGreaterThanOrEqual(puzzle.clueCount, difficulty.targetClues)
            }
        }
    }
    func testDailySeedsReproduceAndDifferentDaysDiffer() {
        let today = SudokuGenerator.generate(difficulty: .medium, seed: 20261005)
        let todayAgain = SudokuGenerator.generate(difficulty: .medium, seed: 20261005)
        let tomorrow = SudokuGenerator.generate(difficulty: .medium, seed: 20261006)
        XCTAssertEqual(today, todayAgain)
        XCTAssertNotEqual(today.givens, tomorrow.givens)
    }
    func testRepeatedWrongInputAndUndoDoNotEraseMistakeHistory() {
        var session = GameSession(puzzle: SudokuGenerator.generate(seed: 12))
        let index = session.puzzle.givens.firstIndex(of: 0)!
        let wrong = session.puzzle.solution[index] % 9 + 1
        session.enter(wrong, at: index)
        session.enter(wrong, at: index)
        XCTAssertEqual(session.mistakes, 1, "A repeated key without any change is not a new move")
        session.erase(at: index)
        session.enter(wrong, at: index)
        XCTAssertEqual(session.mistakes, 2)
        session.undo()
        XCTAssertEqual(session.mistakes, 2)
    }
    func testHintsCorrectErrorsBeforeAdvancingAndMatchSolution() {
        var session = GameSession(puzzle: SudokuGenerator.generate(difficulty: .master, seed: 16))
        let index = session.puzzle.givens.firstIndex(of: 0)!
        session.enter(session.puzzle.solution[index] % 9 + 1, at: index)
        XCTAssertEqual(session.hint()?.index, index)
        while !session.isComplete {
            guard let hint = session.applyHint() else { return XCTFail("Unfinished game must offer a hint") }
            XCTAssertEqual(hint.value, session.puzzle.solution[hint.index])
            XCTAssertEqual(SudokuSolver.countSolutions(session.values), 1)
        }
        XCTAssertTrue(SudokuSolver.isValidSolution(session.values))
    }
    func testMasterGenerationBatchPerformance() {
        var worst = 0.0
        let start = Date()
        for seed: UInt64 in 0..<30 {
            let itemStart = Date()
            let puzzle = SudokuGenerator.generate(difficulty: .master, seed: seed)
            worst = max(worst, Date().timeIntervalSince(itemStart))
            XCTAssertEqual(SudokuSolver.countSolutions(puzzle.givens), 1)
        }
        print("MASTER_BATCH samples=30 totalSeconds=\(Date().timeIntervalSince(start)) worstGenerationSeconds=\(worst)")
        XCTAssertLessThan(worst, 3.0)
    }
    func testCompletedSessionCannotBeReopenedByUndo() {
        var session = GameSession(puzzle: SudokuGenerator.generate(seed: 99))
        while !session.isComplete { session.applyHint() }
        XCTAssertFalse(session.canUndo)
        let completed = session
        session.undo()
        XCTAssertEqual(session, completed)
    }
    func testHumanRatingHandlesSinglesAndInvalidBoards() {
        let puzzle = SudokuGenerator.generate(seed: 42)
        var nearlyComplete = puzzle.solution
        nearlyComplete[0] = 0
        XCTAssertEqual(SudokuSolver.humanTechniqueRating(nearlyComplete), .nakedSingles)
        XCTAssertEqual(SudokuSolver.humanTechniqueRating(puzzle.solution), .nakedSingles)
        nearlyComplete[0] = nearlyComplete[1]
        XCTAssertNil(SudokuSolver.humanTechniqueRating(nearlyComplete))
        XCTAssertNil(SudokuSolver.humanTechniqueRating([0]))
    }
    func testHumanRatingDistribution() {
        for difficulty in Difficulty.allCases {
            var counts = [String: Int]()
            for seed: UInt64 in 0..<12 {
                let puzzle = SudokuGenerator.generate(difficulty: difficulty, seed: seed)
                guard let rating = SudokuSolver.humanTechniqueRating(puzzle.givens) else { return XCTFail("Valid puzzle has no rating") }
                counts[rating.label, default: 0] += 1
            }
            print("RATING \(difficulty.rawValue): \(counts)")
        }
    }
    func testHintConsultationAndApplicationCountOnlyOnce() {
        var session = GameSession(puzzle: SudokuGenerator.generate(seed: 17))
        XCTAssertNotNil(session.hint())
        XCTAssertEqual(session.hintsUsed, 0)
        session.recordHintConsultation()
        XCTAssertEqual(session.hintsUsed, 1)
        session.applyHint(countAsUsed: false)
        XCTAssertEqual(session.hintsUsed, 1)
        session.applyHint()
        XCTAssertEqual(session.hintsUsed, 2)
    }
    func testAdvancedGenerationUsesLogicalRatingToChooseStrongerPuzzles() {
        let expert = SudokuGenerator.generate(difficulty: .expert, seed: 0)
        let master = SudokuGenerator.generate(difficulty: .master, seed: 0)
        XCTAssertGreaterThanOrEqual(SudokuSolver.humanTechniqueRating(expert.givens)!, .hiddenSingles)
        XCTAssertGreaterThanOrEqual(SudokuSolver.humanTechniqueRating(master.givens)!, .hiddenSingles)
        XCTAssertEqual(expert.seed, 0)
        XCTAssertEqual(master.seed, 0)
    }
    func testUnlimitedUndoUsesCompactDeltasAndRoundTrips() throws {
        var session = GameSession(puzzle: SudokuGenerator.generate(seed: 20))
        let original = session
        let index = session.puzzle.givens.firstIndex(of: 0)!
        for _ in 0..<601 { session.toggleNote(3, at: index) }
        let data = try JSONEncoder().encode(session)
        XCTAssertLessThan(data.count, 50_000, "Single-cell edits should not store full boards")
        session = try JSONDecoder().decode(GameSession.self, from: data)
        for _ in 0..<601 {
            XCTAssertTrue(session.canUndo)
            session.undo()
        }
        XCTAssertFalse(session.canUndo)
        XCTAssertEqual(session, original)
    }
    func testLegacySnapshotsMigrateToEquivalentUndoDeltas() throws {
        var session = GameSession(puzzle: SudokuGenerator.generate(seed: 21))
        let index = session.puzzle.givens.firstIndex(of: 0)!
        let value = session.puzzle.solution[index]
        let peer = SudokuSolver.peers(of: index).first { session.puzzle.givens[$0] == 0 }!
        var snapshots = [[String: Any]]()
        func snapshot(_ game: GameSession) -> [String: Any] {
            ["values": game.values, "notes": game.notes.map { Array($0) }]
        }
        snapshots.append(snapshot(session))
        session.toggleNote(value, at: peer)
        snapshots.append(snapshot(session))
        session.enter(value, at: index)
        snapshots.append(snapshot(session))
        session.erase(at: index)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        object.removeValue(forKey: "undoHistory")
        object["history"] = snapshots
        var migrated = try JSONDecoder().decode(GameSession.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(migrated, session)
        for expected in snapshots.reversed() {
            migrated.undo()
            XCTAssertEqual(migrated.values, expected["values"] as? [Int])
            XCTAssertEqual(migrated.notes, (expected["notes"] as! [[Int]]).map { Set($0) })
        }
        XCTAssertFalse(migrated.canUndo)
    }
    func testInvalidDeltaIndexIsRejected() throws {
        let session = GameSession(puzzle: SudokuGenerator.generate(seed: 22))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any])
        object["undoHistory"] = [[ ["index": 81, "value": 0, "notes": []] ]]
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try JSONDecoder().decode(GameSession.self, from: data))
    }
    func testInvalidBoardsRejected() {
        XCTAssertNil(SudokuSolver.solve([0]))
        var board = [Int](repeating: 0, count: 81)
        board[0] = 1; board[1] = 1
        XCTAssertEqual(SudokuSolver.countSolutions(board), 0)
        XCTAssertFalse(SudokuSolver.isValidSolution(board))
    }
    func testNotesEntryUndoAndMistakes() {
        let puzzle = SudokuGenerator.generate(seed: 42)
        var session = GameSession(puzzle: puzzle)
        let index = puzzle.givens.firstIndex(of: 0)!
        session.toggleNote(3, at: index)
        XCTAssertEqual(session.notes[index], [3])
        session.toggleNote(4, at: index)
        session.undo()
        XCTAssertEqual(session.notes[index], [3])
        let wrong = puzzle.solution[index] % 9 + 1
        XCTAssertFalse(session.enter(wrong, at: index))
        XCTAssertEqual(session.mistakes, 1)
        XCTAssertTrue(session.isIncorrect(at: index))
        session.undo()
        XCTAssertEqual(session.values[index], 0)
        XCTAssertEqual(session.notes[index], [3])
        XCTAssertEqual(session.mistakes, 1)
        XCTAssertTrue(session.enter(puzzle.solution[index], at: index))
        session.erase(at: index)
        XCTAssertEqual(session.values[index], 0)
    }
    func testGivenCellsAndInvalidInputCannotChange() {
        let puzzle = SudokuGenerator.generate(seed: 2)
        var session = GameSession(puzzle: puzzle)
        let index = puzzle.givens.firstIndex(where: { $0 != 0 })!
        session.erase(at: index); session.enter(5, at: index); session.toggleNote(4, at: index)
        session.enter(22, at: -1); session.erase(at: 81)
        XCTAssertEqual(session.values, puzzle.givens)
        XCTAssertFalse(session.canUndo)
    }
    func testHintsFinishPuzzleAndSessionRoundTrips() throws {
        var session = GameSession(puzzle: SudokuGenerator.generate(difficulty: .hard, seed: 5))
        session.tick()
        XCTAssertEqual(session.elapsedSeconds, 1)
        while !session.isComplete {
            let hint = try XCTUnwrap(session.applyHint())
            XCTAssertEqual(session.values[hint.index], hint.value)
        }
        XCTAssertEqual(session.progress, 1)
        XCTAssertNil(session.hint())
        session.tick()
        XCTAssertEqual(session.elapsedSeconds, 1)
        let data = try JSONEncoder().encode(session)
        XCTAssertEqual(try JSONDecoder().decode(GameSession.self, from: data), session)
    }
    func testCorruptSavedSessionIsRejected() throws {
        let session = GameSession(puzzle: SudokuGenerator.generate(seed: 7))
        let encoded = try JSONEncoder().encode(session)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["values"] = [0, 1]
        let corrupted = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try JSONDecoder().decode(GameSession.self, from: corrupted))
        var puzzle = try XCTUnwrap(object["puzzle"] as? [String: Any])
        puzzle["solution"] = [1]
        let brokenPuzzle = try JSONSerialization.data(withJSONObject: puzzle)
        XCTAssertThrowsError(try JSONDecoder().decode(Puzzle.self, from: brokenPuzzle))
    }
    func testCorrectEntriesPrunePeerNotesAndUndoRestoresThem() {
        let puzzle = SudokuGenerator.generate(seed: 42)
        var session = GameSession(puzzle: puzzle)
        let index = puzzle.givens.firstIndex(of: 0)!
        let peer = SudokuSolver.peers(of: index).first { puzzle.givens[$0] == 0 }!
        let value = puzzle.solution[index]
        session.toggleNote(value, at: peer)
        session.enter(value, at: index)
        XCTAssertFalse(session.notes[peer].contains(value))
        session.undo()
        XCTAssertTrue(session.notes[peer].contains(value))
    }
}
