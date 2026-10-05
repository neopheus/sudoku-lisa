import Foundation

public enum Difficulty: String, CaseIterable, Codable, Sendable, Identifiable {
    case quick, easy, medium, hard, expert, master
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .quick: return "Express"
        case .easy: return "Facile"
        case .medium: return "Moyen"
        case .hard: return "Difficile"
        case .expert: return "Expert"
        case .master: return "Maître"
        }
    }
    public var targetClues: Int {
        switch self { case .quick: return 48; case .easy: return 42; case .medium: return 35; case .hard: return 30; case .expert: return 26; case .master: return 24 }
    }
}

public struct Puzzle: Codable, Sendable, Equatable {
    public let givens: [Int]
    public let solution: [Int]
    public let difficulty: Difficulty
    public let seed: UInt64
    public init(givens: [Int], solution: [Int], difficulty: Difficulty, seed: UInt64) {
        precondition(givens.count == 81 && solution.count == 81)
        precondition(givens.allSatisfy { (0...9).contains($0) })
        precondition(SudokuSolver.isValidSolution(solution))
        precondition(zip(givens, solution).allSatisfy { $0 == 0 || $0 == $1 })
        self.givens = givens; self.solution = solution; self.difficulty = difficulty; self.seed = seed
    }
    private enum CodingKeys: String, CodingKey { case givens, solution, difficulty, seed }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let givens = try container.decode([Int].self, forKey: .givens)
        let solution = try container.decode([Int].self, forKey: .solution)
        guard givens.count == 81, givens.allSatisfy({ (0...9).contains($0) }),
              SudokuSolver.isValidSolution(solution),
              zip(givens, solution).allSatisfy({ $0 == 0 || $0 == $1 }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid Sudoku puzzle"))
        }
        self.givens = givens; self.solution = solution
        self.difficulty = try container.decode(Difficulty.self, forKey: .difficulty)
        self.seed = try container.decode(UInt64.self, forKey: .seed)
    }
    public var clueCount: Int { givens.filter { $0 != 0 }.count }
}

public enum SudokuSolver {
    public static func peers(of index: Int) -> Set<Int> {
        guard (0..<81).contains(index) else { return [] }
        let row = index / 9, column = index % 9
        var result = Set<Int>()
        for n in 0..<9 {
            result.insert(row * 9 + n); result.insert(n * 9 + column)
            result.insert((row / 3 * 3 + n / 3) * 9 + column / 3 * 3 + n % 3)
        }
        result.remove(index)
        return result
    }
    public static func candidates(in board: [Int], at index: Int) -> Set<Int> {
        guard board.count == 81, (0..<81).contains(index), board[index] == 0 else { return [] }
        return Set(1...9).subtracting(peers(of: index).map { board[$0] })
    }
    public static func isValidSolution(_ board: [Int]) -> Bool {
        board.count == 81 && board.allSatisfy { (1...9).contains($0) } && valid(board)
    }
    private static func valid(_ board: [Int]) -> Bool {
        guard board.count == 81, board.allSatisfy({ (0...9).contains($0) }) else { return false }
        var rows = [Int](repeating: 0, count: 9), columns = rows, boxes = rows
        for i in 0..<81 where board[i] != 0 {
            let r = i / 9, c = i % 9, b = r / 3 * 3 + c / 3, bit = 1 << board[i]
            if (rows[r] | columns[c] | boxes[b]) & bit != 0 { return false }
            rows[r] |= bit; columns[c] |= bit; boxes[b] |= bit
        }
        return true
    }
    public static func solve(_ board: [Int]) -> [Int]? {
        search(board, limit: 1).first
    }
    public static func countSolutions(_ board: [Int], limit: Int = 2) -> Int {
        search(board, limit: max(1, limit)).count
    }
    private static func search(_ original: [Int], limit: Int) -> [[Int]] {
        guard valid(original) else { return [] }
        var board = original, solutions = [[Int]]()
        var rows = [Int](repeating: 0, count: 9), cols = rows, boxes = rows
        for i in 0..<81 where board[i] != 0 {
            let bit = 1 << board[i]
            rows[i / 9] |= bit; cols[i % 9] |= bit; boxes[i / 27 * 3 + i % 9 / 3] |= bit
        }
        func visit() {
            if solutions.count >= limit { return }
            var selected = -1, selectedMask = 0, smallest = 10
            for i in 0..<81 where board[i] == 0 {
                let mask = 0x3FE & ~(rows[i / 9] | cols[i % 9] | boxes[i / 27 * 3 + i % 9 / 3])
                let count = mask.nonzeroBitCount
                if count == 0 { return }
                if count < smallest { selected = i; selectedMask = mask; smallest = count }
                if count == 1 { break }
            }
            if selected == -1 { solutions.append(board); return }
            let r = selected / 9, c = selected % 9, b = selected / 27 * 3 + selected % 9 / 3
            for n in 1...9 where selectedMask & (1 << n) != 0 {
                let bit = 1 << n
                board[selected] = n; rows[r] |= bit; cols[c] |= bit; boxes[b] |= bit
                visit()
                board[selected] = 0; rows[r] &= ~bit; cols[c] &= ~bit; boxes[b] &= ~bit
                if solutions.count >= limit { return }
            }
        }
        visit()
        return solutions
    }
}

private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

public enum SudokuGenerator {
    /// Generates up to four unique-solution candidates and selects the closest
    /// supported logical rating. Expert/master favor the strongest candidate;
    /// clue density further distinguishes them. This is bounded best effort,
    /// not a guarantee of six strict human-technique grades.
    public static func generate(difficulty: Difficulty = .easy, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) -> Puzzle {
        let target: HumanTechniqueRating
        switch difficulty {
        case .quick, .easy: target = .nakedSingles
        case .medium: target = .hiddenSingles
        case .hard: target = .lockedCandidates
        case .expert, .master: target = .searchRequired
        }
        var selected: Puzzle?
        var selectedRating = HumanTechniqueRating.nakedSingles
        var bestDistance = Int.max
        for attempt in 0..<4 {
            let candidateSeed = seed &+ UInt64(attempt) &* 0x9E3779B97F4A7C15
            let candidate = makeCandidate(difficulty: difficulty, seed: seed, randomSeed: candidateSeed)
            let rating = SudokuSolver.humanTechniqueRating(candidate.givens) ?? .searchRequired
            let distance = abs(rating.rawValue - target.rawValue)
            let fewerClues = candidate.clueCount < (selected?.clueCount ?? 82)
            if distance < bestDistance || (distance == bestDistance && rating == selectedRating && fewerClues) {
                selected = candidate; selectedRating = rating; bestDistance = distance
            }
            if distance == 0 && difficulty != .expert && difficulty != .master { break }
        }
        return selected!
    }
    private static func makeCandidate(difficulty: Difficulty, seed: UInt64, randomSeed: UInt64) -> Puzzle {
        var random = SeededRandom(state: randomSeed)
        let digits = Array(1...9).shuffled(using: &random)
        let bands = Array(0..<3).shuffled(using: &random)
        let stacks = Array(0..<3).shuffled(using: &random)
        let rows = bands.flatMap { band in Array(0..<3).shuffled(using: &random).map { band * 3 + $0 } }
        let columns = stacks.flatMap { stack in Array(0..<3).shuffled(using: &random).map { stack * 3 + $0 } }
        let solution = rows.flatMap { row in columns.map { column in digits[(row * 3 + row / 3 + column) % 9] } }
        var givens = solution, clues = 81
        for index in Array(0..<81).shuffled(using: &random) {
            if clues <= difficulty.targetClues { break }
            let value = givens[index]; givens[index] = 0
            if SudokuSolver.countSolutions(givens) == 1 { clues -= 1 } else { givens[index] = value }
        }
        return Puzzle(givens: givens, solution: solution, difficulty: difficulty, seed: seed)
    }
}
