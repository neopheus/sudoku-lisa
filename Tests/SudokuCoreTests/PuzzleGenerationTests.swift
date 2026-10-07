import XCTest
@testable import SudokuCore

final class PuzzleGenerationTests: XCTestCase {
    private final class CancellationProbe: @unchecked Sendable {
        private let lock = NSLock()
        private var calls = 0
        func shouldCancel() -> Bool {
            lock.lock(); defer { lock.unlock() }
            calls += 1
            return calls >= 15
        }
    }
    func testCancellationInterruptsAnInProgressTrace() {
        let probe = CancellationProbe()
        XCTAssertThrowsError(try SudokuGenerator.generateCancellable(difficulty: .master, seed: 12, deadline: .distantFuture, cancellation: { probe.shouldCancel() })) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testEveryOriginalHasUniqueSolutionAndExactSupportedProfile() throws {
        for difficulty in Difficulty.allCases {
            let originals = PuzzleCorpus.entries(for: difficulty)
            XCTAssertEqual(originals.count, difficulty == .expert || difficulty == .master ? 16 : 8)
            XCTAssertEqual(Set(originals.map(\.givens)).count, originals.count)
            for original in originals {
                let board = original.givens.map { Int(String($0))! }
                let solution = original.solution.map { Int(String($0))! }
                XCTAssertEqual(SudokuSolver.countSolutions(board), 1)
                XCTAssertEqual(SudokuSolver.solve(board), solution)
                let analysis = try XCTUnwrap(SudokuSolver.logicalAnalysis(board))
                XCTAssertTrue(difficulty.accepts(analysis), "\(difficulty): \(analysis.rating)")
                XCTAssertEqual(analysis.finalBoard, solution)
                XCTAssertFalse(analysis.deductions.contains { $0.techniqueID == .solutionReveal })
            }
        }
    }
    func testDeadlineAndCancellationThrowWithoutChangingSeedResult() throws {
        for difficulty in Difficulty.allCases {
            XCTAssertThrowsError(try SudokuGenerator.generateCancellable(difficulty: difficulty, seed: 19, deadline: .distantPast)) { error in
                XCTAssertEqual(error as? PuzzleGenerationError, .timedOut)
            }
            let fixed = SudokuGenerator.generate(difficulty: difficulty, seed: 19)
            XCTAssertEqual(try SudokuGenerator.generateCancellable(difficulty: difficulty, seed: 19), fixed)
            XCTAssertEqual(fixed.seed, 19)
        }
        XCTAssertThrowsError(try SudokuGenerator.generateCancellable(cancellation: { true })) { error in
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertThrowsError(try SudokuSolver.logicalAnalysis([Int](repeating: 0, count: 81), cancellation: { true }))
    }
    func testTransformedCorpusDistributionAndReproducibility() throws {
        var duration = [Double](), hintDuration = [Double]()
        for difficulty in Difficulty.allCases {
            var distribution = [Int: Int](), boards = Set<[Int]>()
            var workloads = [LogicalWorkload]()
            for seed: UInt64 in 0..<40 {
                let begin = ContinuousClock.now
                let puzzle = SudokuGenerator.generate(difficulty: difficulty, seed: seed)
                let generationElapsed = begin.duration(to: .now)
                duration.append(Double(generationElapsed.components.seconds) + Double(generationElapsed.components.attoseconds) / 1e18)
                let analysis = try XCTUnwrap(SudokuSolver.logicalAnalysis(puzzle.givens))
                XCTAssertTrue(difficulty.accepts(analysis), "No silent label degradation allowed")
                workloads.append(analysis.workload)
                XCTAssertEqual(analysis.finalBoard, puzzle.solution)
                XCTAssertEqual(SudokuSolver.countSolutions(puzzle.givens), 1)
                XCTAssertEqual(puzzle, SudokuGenerator.generate(difficulty: difficulty, seed: seed))
                boards.insert(puzzle.givens)
                distribution[analysis.rating.rank, default: 0] += 1
                let game = GameSession(puzzle: puzzle), hintBegin = ContinuousClock.now
                XCTAssertNotNil(try game.hint(cancellation: { false }))
                let elapsed = hintBegin.duration(to: .now)
                hintDuration.append(Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
            }
            XCTAssertGreaterThan(boards.count, 30)
            print("PROFILE difficulty=\(difficulty.rawValue) samples=40 ratingsByRank=\(distribution) uniqueBoards=\(boards.count)")
            func range(_ values: [Int]) -> String { "\(values.min()!)...\(values.max()!)" }
            func histogram(_ values: [Int]) -> String {
                let frequencies = Dictionary(grouping: values, by: { $0 }).mapValues(\.count)
                return frequencies.keys.sorted().map { "\($0):\(frequencies[$0]!)" }.joined(separator: ",")
            }
            print("WORKLOAD difficulty=\(difficulty.rawValue) samples=40 placementRange=\(range(workloads.map(\.placementCount))) eliminationStepRange=\(range(workloads.map(\.eliminationStepCount))) eliminatedCandidateRange=\(range(workloads.map(\.eliminatedCandidateCount))) hardestCountRange=\(range(workloads.map(\.hardestTechniqueCount))) longestEliminationRunRange=\(range(workloads.map(\.longestEliminationRun))) hardestCountDistribution=[\(histogram(workloads.map(\.hardestTechniqueCount)))] longestEliminationRunDistribution=[\(histogram(workloads.map(\.longestEliminationRun)))]")
        }
        duration.sort(); hintDuration.sort()
        print("LOGICAL_PERFORMANCE samples=240 generationP50Seconds=\(duration[120]) generationMaxSeconds=\(duration.last!) hintP50Seconds=\(hintDuration[120]) hintMaxSeconds=\(hintDuration.last!)")
        XCTAssertLessThan(duration.last!, 2.0)
        XCTAssertLessThan(hintDuration.last!, 0.5)
    }
}
