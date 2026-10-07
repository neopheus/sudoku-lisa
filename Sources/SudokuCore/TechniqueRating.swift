import Foundation

/// Persisted raw values 0...4 retain their original meanings.
public enum HumanTechniqueRating: Int, Codable, Sendable, CaseIterable, Comparable {
    case nakedSingles = 0, hiddenSingles = 1, lockedCandidates = 2, nakedPairs = 3, searchRequired = 4
    case hiddenPairs = 5, nakedTriples = 6, hiddenTriples = 7, xWing = 8
    public var rank: Int {
        switch self { case .nakedSingles: 0; case .hiddenSingles: 1; case .lockedCandidates: 2; case .nakedPairs: 3; case .hiddenPairs: 4; case .nakedTriples: 5; case .hiddenTriples: 6; case .xWing: 7; case .searchRequired: 8 }
    }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
    public var label: String {
        switch self {
        case .nakedSingles: L10n.text("Candidats uniques")
        case .hiddenSingles: L10n.text("Positions uniques")
        case .lockedCandidates: L10n.text("Candidats verrouillés")
        case .nakedPairs: L10n.text("Paires nues")
        case .hiddenPairs: L10n.text("Paires cachées")
        case .nakedTriples: L10n.text("Triplets nus")
        case .hiddenTriples: L10n.text("Triplets cachés")
        case .xWing: L10n.text("X-Wing")
        case .searchRequired: L10n.text("Techniques non prises en charge")
        }
    }
}

public enum SudokuTechnique: String, Codable, Sendable, CaseIterable, Identifiable {
    case observation, nakedSingle, hiddenSingle, lockedCandidates, nakedPair, hiddenPair, nakedTriple, hiddenTriple, xWing, correction, solutionReveal
    public var id: String { rawValue }
    public var rating: HumanTechniqueRating {
        switch self {
        case .observation, .nakedSingle, .correction: .nakedSingles
        case .hiddenSingle: .hiddenSingles
        case .lockedCandidates: .lockedCandidates
        case .nakedPair: .nakedPairs
        case .hiddenPair: .hiddenPairs
        case .nakedTriple: .nakedTriples
        case .hiddenTriple: .hiddenTriples
        case .xWing: .xWing
        case .solutionReveal: .searchRequired
        }
    }
    public var label: String {
        switch self { case .observation: L10n.text("Observer la grille"); case .correction: L10n.text("Une case à revoir"); case .solutionReveal: L10n.text("Voir une valeur de la solution"); default: rating.label }
    }
    public var explanation: String {
        switch self {
        case .observation: L10n.text("Chaque ligne, colonne et bloc contient les chiffres de 1 à 9 une seule fois.")
        case .nakedSingle: L10n.text("Les chiffres présents sur la ligne, la colonne et le bloc éliminent toutes les possibilités sauf une.")
        case .hiddenSingle: L10n.text("Dans la zone colorée, ce chiffre ne peut aller que dans une case. Les autres emplacements sont bloqués par leur ligne, colonne ou bloc.")
        case .lockedCandidates: L10n.text("Un chiffre est limité à l’intersection d’un bloc et d’une ligne ou colonne. Retire-le du reste de la zone qui la croise.")
        case .nakedPair: L10n.text("Deux cases partagent les mêmes deux candidats. Ces chiffres sont réservés à cette paire ; retire-les des autres cases de la zone.")
        case .hiddenPair: L10n.text("Deux chiffres ne peuvent aller que dans les mêmes deux cases d’une zone. Retire les autres candidats de ces deux cases.")
        case .nakedTriple: L10n.text("Trois cases partagent trois candidats au total. Retire ces candidats des autres cases de leur zone.")
        case .hiddenTriple: L10n.text("Trois chiffres sont limités aux mêmes trois cases d’une zone. Retire les autres candidats de ces cases.")
        case .xWing: L10n.text("Un chiffre a deux positions dans chacune de deux lignes, sur les mêmes colonnes. Il peut être retiré des autres cases de ces colonnes, et inversement.")
        case .correction: L10n.text("Cette case est en erreur. Remplace son chiffre pour débloquer la grille.")
        case .solutionReveal: L10n.text("Les techniques prises en charge ne donnent plus de déduction. Cette valeur vient de la solution vérifiée, sans explication logique.")
        }
    }
}

public enum DeductionAction: Codable, Sendable, Equatable {
    case placement(index: Int, value: Int)
    case eliminations([CandidateElimination])
}
public struct SudokuDeduction: Codable, Sendable, Equatable {
    public let techniqueID: SudokuTechnique
    public let action: DeductionAction
    public let focusCells: [Int]
    public var observation: String { L10n.text("Repère la zone colorée et cherche les possibilités encore ouvertes.") }
    public var explanation: String { techniqueID.explanation }
    public init(techniqueID: SudokuTechnique, action: DeductionAction, focusCells: [Int]) {
        self.techniqueID = techniqueID; self.action = action; self.focusCells = Array(Set(focusCells)).sorted()
    }
}

/// Automatic candidates are independent of handwritten notes. Every deduction
/// removes candidates or places one digit, and never performs a search.
public struct LogicalState: Sendable, Equatable {
    public private(set) var board: [Int]
    private var masks: [Int]
    public static let units: [[Int]] = (0..<27).map { unit in
        if unit < 9 { return (0..<9).map { unit * 9 + $0 } }
        if unit < 18 { return (0..<9).map { $0 * 9 + unit - 9 } }
        let box = unit - 18
        return (0..<9).map { (box / 3 * 3 + $0 / 3) * 9 + box % 3 * 3 + $0 % 3 }
    }
    private static let peers = (0..<81).map { SudokuSolver.peers(of: $0).sorted() }
    public init(board: [Int], eliminations: Set<CandidateElimination> = []) {
        self.board = board
        masks = board.count == 81 && board.allSatisfy({ (0...9).contains($0) }) ? (0..<81).map { index in
            guard board[index] == 0 else { return 0 }
            return Self.peers[index].reduce(0x3FE) { $0 & ~(1 << board[$1]) }
        } : []
        for mark in eliminations where (0..<81).contains(mark.index) && (1...9).contains(mark.value) && masks.count == 81 {
            masks[mark.index] &= ~(1 << mark.value)
        }
    }
    public func candidates(at index: Int) -> Set<Int> {
        guard masks.indices.contains(index) else { return [] }
        return Set((1...9).filter { masks[index] & (1 << $0) != 0 })
    }
    public var isConsistent: Bool {
        guard board.count == 81, board.allSatisfy({ (0...9).contains($0) }) else { return false }
        for i in 0..<81 {
            if board[i] == 0 { if masks[i] == 0 { return false } }
            else if Self.peers[i].contains(where: { board[$0] == board[i] }) { return false }
        }
        for unit in Self.units {
            for digit in 1...9 where !unit.contains(where: { board[$0] == digit }) {
                if !unit.contains(where: { masks[$0] & (1 << digit) != 0 }) { return false }
            }
        }
        return true
    }
    @discardableResult public mutating func apply(_ deduction: SudokuDeduction) -> Bool {
        switch deduction.action {
        case let .placement(index, value):
            guard board.indices.contains(index), (1...9).contains(value), board[index] == 0, masks[index] & (1 << value) != 0 else { return false }
            board[index] = value; masks[index] = 0
            for peer in Self.peers[index] { masks[peer] &= ~(1 << value) }
        case let .eliminations(marks):
            guard !marks.isEmpty, marks.allSatisfy({ board.indices.contains($0.index) && (1...9).contains($0.value) && board[$0.index] == 0 && masks[$0.index] & (1 << $0.value) != 0 }) else { return false }
            for mark in marks { masks[mark.index] &= ~(1 << mark.value) }
        }
        return true
    }
    public func nextDeduction(technique requested: SudokuTechnique? = nil) -> SudokuDeduction? {
        findDeduction(technique: requested, accepting: { _ in true })
    }
    public func deductions(technique: SudokuTechnique) -> [SudokuDeduction] {
        var result = [SudokuDeduction]()
        _ = findDeduction(technique: technique, accepting: { deduction in
            if !result.contains(deduction) { result.append(deduction) }
            return false
        })
        return result
    }
    private func findDeduction(technique requested: SudokuTechnique?, accepting accept: (SudokuDeduction) -> Bool) -> SudokuDeduction? {
        guard isConsistent, board.contains(0) else { return nil }
        func allowed(_ technique: SudokuTechnique) -> Bool { requested == nil || requested == technique }
        func removal(_ technique: SudokuTechnique, _ focus: [Int], _ marks: [CandidateElimination]) -> SudokuDeduction? {
            guard !marks.isEmpty else { return nil }
            let sorted = Array(Set(marks)).sorted { $0.index == $1.index ? $0.value < $1.value : $0.index < $1.index }
            let deduction = SudokuDeduction(techniqueID: technique, action: .eliminations(sorted), focusCells: focus)
            return accept(deduction) ? deduction : nil
        }
        if allowed(.nakedSingle) {
            for i in 0..<81 where masks[i].nonzeroBitCount == 1 {
                let deduction = SudokuDeduction(techniqueID: .nakedSingle, action: .placement(index: i, value: masks[i].trailingZeroBitCount), focusCells: [i] + Self.peers[i])
                if accept(deduction) { return deduction }
            }
        }
        if allowed(.hiddenSingle) {
            for unit in Self.units {
                for digit in 1...9 {
                    let cells = unit.filter { masks[$0] & (1 << digit) != 0 }
                    if cells.count == 1 {
                        let deduction = SudokuDeduction(techniqueID: .hiddenSingle, action: .placement(index: cells[0], value: digit), focusCells: unit)
                        if accept(deduction) { return deduction }
                    }
                }
            }
        }
        if allowed(.lockedCandidates) {
            for (sourceID, source) in Self.units.enumerated() {
                for digit in 1...9 {
                    let cells = source.filter { masks[$0] & (1 << digit) != 0 }
                    guard cells.count > 1 else { continue }
                    for (targetID, target) in Self.units.enumerated() where (sourceID >= 18) != (targetID >= 18) {
                        guard cells.allSatisfy({ target.contains($0) }) else { continue }
                        let marks = target.filter { !source.contains($0) && masks[$0] & (1 << digit) != 0 }.map { CandidateElimination(index: $0, value: digit) }
                        if let deduction = removal(.lockedCandidates, cells, marks) { return deduction }
                    }
                }
            }
        }
        for size in 2...3 {
            let technique: SudokuTechnique = size == 2 ? .nakedPair : .nakedTriple
            // Hidden pairs precede naked triples in the supported ordering.
            if size == 3, allowed(.hiddenPair), let result = hiddenSubset(size: 2, accepting: accept) { return result }
            if allowed(technique) {
                for unit in Self.units {
                    let cells = unit.filter { (2...size).contains(masks[$0].nonzeroBitCount) }
                    for combination in Self.combinations(cells, size: size) {
                        let union = combination.reduce(0) { $0 | masks[$1] }
                        guard union.nonzeroBitCount == size else { continue }
                        let marks = unit.filter { !combination.contains($0) }.flatMap { cell in
                            (1...9).filter { masks[cell] & union & (1 << $0) != 0 }.map { CandidateElimination(index: cell, value: $0) }
                        }
                        if let deduction = removal(technique, combination, marks) { return deduction }
                    }
                }
            }
        }
        if allowed(.hiddenTriple), let result = hiddenSubset(size: 3, accepting: accept) { return result }
        if allowed(.xWing) {
            for transpose in [false, true] {
                func index(_ line: Int, _ crossing: Int) -> Int { transpose ? crossing * 9 + line : line * 9 + crossing }
                for digit in 1...9 {
                    let positions = (0..<9).map { line in (0..<9).filter { masks[index(line, $0)] & (1 << digit) != 0 } }
                    for first in 0..<8 where positions[first].count == 2 {
                        for second in (first + 1)..<9 where positions[second] == positions[first] {
                            let focus = [index(first, positions[first][0]), index(first, positions[first][1]), index(second, positions[first][0]), index(second, positions[first][1])]
                            let marks = (0..<9).filter { $0 != first && $0 != second }.flatMap { line in positions[first].compactMap { crossing -> CandidateElimination? in
                                let cell = index(line, crossing)
                                return masks[cell] & (1 << digit) != 0 ? CandidateElimination(index: cell, value: digit) : nil
                            } }
                            if let result = removal(.xWing, focus, marks) { return result }
                        }
                    }
                }
            }
        }
        return nil
    }
    private func hiddenSubset(size: Int, accepting accept: (SudokuDeduction) -> Bool) -> SudokuDeduction? {
        for unit in Self.units {
            let digits = (1...9).filter { digit in let count = unit.filter { masks[$0] & (1 << digit) != 0 }.count; return (2...size).contains(count) }
            for combination in Self.combinations(digits, size: size) {
                let digitMask = combination.reduce(0) { $0 | (1 << $1) }
                let cells = unit.filter { masks[$0] & digitMask != 0 }
                guard cells.count == size else { continue }
                let marks = cells.flatMap { cell in (1...9).filter { masks[cell] & ~digitMask & (1 << $0) != 0 }.map { CandidateElimination(index: cell, value: $0) } }
                if !marks.isEmpty {
                    let deduction = SudokuDeduction(techniqueID: size == 2 ? .hiddenPair : .hiddenTriple, action: .eliminations(marks), focusCells: cells)
                    if accept(deduction) { return deduction }
                }
            }
        }
        return nil
    }
    private static func combinations(_ values: [Int], size: Int) -> [[Int]] {
        guard values.count >= size else { return [] }
        var result = [[Int]]()
        func visit(_ start: Int, _ selected: [Int]) {
            if selected.count == size { result.append(selected); return }
            guard start <= values.count - (size - selected.count) else { return }
            for index in start...(values.count - (size - selected.count)) { visit(index + 1, selected + [values[index]]) }
        }
        visit(0, []); return result
    }
}

/// Describes this deterministic trace, rather than a universal human effort score.
public struct LogicalWorkload: Sendable, Equatable {
    public let placementCount: Int
    public let eliminationStepCount: Int
    public let eliminatedCandidateCount: Int
    public let hardestTechniqueCount: Int
    public let longestEliminationRun: Int
    public let techniqueCounts: [SudokuTechnique: Int]
}

public struct LogicalAnalysis: Sendable, Equatable {
    public let deductions: [SudokuDeduction]
    public let rating: HumanTechniqueRating
    public let isSolved: Bool
    public let finalBoard: [Int]
    /// One linear pass over the already computed trace; no solving is repeated.
    public var workload: LogicalWorkload {
        var placements = 0, eliminationSteps = 0, eliminatedCandidates = 0
        var hardestCount = 0, run = 0, longestRun = 0
        var counts = [SudokuTechnique: Int]()
        for deduction in deductions {
            counts[deduction.techniqueID, default: 0] += 1
            if deduction.techniqueID.rating == rating { hardestCount += 1 }
            switch deduction.action {
            case .placement:
                placements += 1
                run = 0
            case let .eliminations(marks):
                eliminationSteps += 1
                eliminatedCandidates += marks.count
                run += 1
                longestRun = max(longestRun, run)
            }
        }
        return LogicalWorkload(placementCount: placements, eliminationStepCount: eliminationSteps,
                               eliminatedCandidateCount: eliminatedCandidates, hardestTechniqueCount: hardestCount,
                               longestEliminationRun: longestRun, techniqueCounts: counts)
    }
    public var placementCount: Int { workload.placementCount }
    public var eliminationStepCount: Int { workload.eliminationStepCount }
    public var hardestTechniqueCount: Int { workload.hardestTechniqueCount }
    public var longestEliminationRun: Int { workload.longestEliminationRun }
}
extension SudokuSolver {
    public static func logicalAnalysis(_ original: [Int], cancellation: @Sendable () -> Bool = { false }) throws -> LogicalAnalysis? {
        var state = LogicalState(board: original)
        guard state.isConsistent else { return nil }
        var deductions = [SudokuDeduction](), rating = HumanTechniqueRating.nakedSingles
        // Each step consumes one of at most 729 candidates or fills a cell.
        for _ in 0..<810 {
            if cancellation() { throw CancellationError() }
            if !state.board.contains(0) { return LogicalAnalysis(deductions: deductions, rating: rating, isSolved: isValidSolution(state.board), finalBoard: state.board) }
            guard state.isConsistent else { return nil }
            guard let deduction = state.nextDeduction() else { return LogicalAnalysis(deductions: deductions, rating: .searchRequired, isSolved: false, finalBoard: state.board) }
            guard state.apply(deduction) else { return nil }
            deductions.append(deduction); rating = max(rating, deduction.techniqueID.rating)
        }
        return nil
    }
    public static func humanTechniqueRating(_ original: [Int]) -> HumanTechniqueRating? {
        guard let analysis = try? logicalAnalysis(original) else { return nil }
        if !analysis.isSolved && solve(original) == nil { return nil }
        return analysis.rating
    }
}
