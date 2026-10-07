import Foundation

extension Difficulty {
    /// A level is accepted only when a complete trace uses these techniques.
    /// Clue counts describe density; they do not establish difficulty.
    public var techniqueProfile: Set<HumanTechniqueRating> {
        switch self {
        case .quick: [.nakedSingles]
        case .easy: [.hiddenSingles]
        case .medium: [.lockedCandidates]
        case .hard: [.nakedPairs]
        case .expert: [.hiddenPairs, .nakedTriples]
        case .master: [.hiddenTriples, .xWing]
        }
    }
    public func accepts(_ analysis: LogicalAnalysis) -> Bool {
        analysis.isSolved && techniqueProfile.contains(analysis.rating)
    }
}

public enum PuzzleGenerationError: Error, Sendable, Equatable {
    case timedOut
}

public enum SudokuGenerator {
    /// Deterministic, bounded construction from independently generated,
    /// prevalidated boards. Sudoku symmetries preserve unique solutions. The
    /// transformed trace is checked because deduction order may change rating.
    public static func generate(difficulty: Difficulty = .easy, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) -> Puzzle {
        // This path has a fixed attempt count rather than a time dependent exit,
        // so seed reproduction also holds across differently loaded devices.
        try! generateCancellable(difficulty: difficulty, seed: seed, deadline: .distantFuture)
    }
    public static func generateCancellable(difficulty: Difficulty = .easy,
                                           seed: UInt64 = UInt64.random(in: 0...UInt64.max),
                                           deadline: Date = Date().addingTimeInterval(2),
                                           cancellation: @Sendable () -> Bool = { false }) throws -> Puzzle {
        if cancellation() { throw CancellationError() }
        if Date() >= deadline { throw PuzzleGenerationError.timedOut }
        var random = SeededRandom(state: seed)
        let corpus = PuzzleCorpus.entries(for: difficulty)
        let original = corpus[Int(random.next() % UInt64(corpus.count))]
        let givens = original.givens.map { Int(String($0))! }
        let solution = original.solution.map { Int(String($0))! }
        let fallback = Puzzle(givens: givens, solution: solution, difficulty: difficulty, seed: seed)
        for _ in 0..<12 {
            if cancellation() { throw CancellationError() }
            if Date() >= deadline { throw PuzzleGenerationError.timedOut }
            let digits = [0] + Array(1...9).shuffled(using: &random)
            let rows = Array(0..<3).shuffled(using: &random).flatMap { band in Array(0..<3).shuffled(using: &random).map { band * 3 + $0 } }
            let cols = Array(0..<3).shuffled(using: &random).flatMap { stack in Array(0..<3).shuffled(using: &random).map { stack * 3 + $0 } }
            let transposed = random.next() & 1 == 1
            let indices = (0..<81).map { cell in transposed ? cols[cell % 9] * 9 + rows[cell / 9] : rows[cell / 9] * 9 + cols[cell % 9] }
            let board = indices.map { digits[givens[$0]] }
            let final = indices.map { digits[solution[$0]] }
            do {
                let analysis = try SudokuSolver.logicalAnalysis(board, cancellation: { cancellation() || Date() >= deadline })
                if let analysis, difficulty.accepts(analysis) {
                    if cancellation() { throw CancellationError() }
                    if Date() >= deadline { throw PuzzleGenerationError.timedOut }
                    return Puzzle(givens: board, solution: final, difficulty: difficulty, seed: seed)
                }
            } catch is CancellationError {
                if cancellation() { throw CancellationError() }
                throw PuzzleGenerationError.timedOut
            }
        }
        if cancellation() { throw CancellationError() }
        if Date() >= deadline { throw PuzzleGenerationError.timedOut }
        return fallback
    }
}
