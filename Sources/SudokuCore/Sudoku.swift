import Foundation

public enum Difficulty: String, CaseIterable, Codable, Sendable, Identifiable {
    case quick, easy, medium, hard, expert, master
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .quick: return L10n.text("Express")
        case .easy: return L10n.text("Facile")
        case .medium: return L10n.text("Moyen")
        case .hard: return L10n.text("Difficile")
        case .expert: return L10n.text("Expert")
        case .master: return L10n.text("Maître")
        }
    }
    public var targetClues: Int {
        switch self { case .quick: return 48; case .easy: return 30; case .medium: return 28; case .hard: return 26; case .expert: return 26; case .master: return 24 }
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

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
