import Foundation

/// The hardest implemented logical technique needed to solve this board.
/// `searchRequired` means the supported logical techniques stalled; it does not
/// imply that a human solver must guess (more advanced techniques may apply).
public enum HumanTechniqueRating: Int, Codable, Sendable, CaseIterable, Comparable {
    case nakedSingles = 0, hiddenSingles, lockedCandidates, nakedPairs, searchRequired
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    public var label: String {
        switch self {
        case .nakedSingles: return L10n.text("Candidats uniques")
        case .hiddenSingles: return L10n.text("Positions uniques")
        case .lockedCandidates: return L10n.text("Candidats verrouillés")
        case .nakedPairs: return L10n.text("Paires nues")
        case .searchRequired: return L10n.text("Techniques avancées")
        }
    }
}

extension SudokuSolver {
    /// Returns nil for a malformed or contradictory board. A rating describes
    /// this evaluator's solving path rather than a universal difficulty score.
    public static func humanTechniqueRating(_ original: [Int]) -> HumanTechniqueRating? {
        guard original.count == 81, original.allSatisfy({ (0...9).contains($0) }) else { return nil }
        for index in 0..<81 where original[index] != 0 {
            if peers(of: index).contains(where: { original[$0] == original[index] }) { return nil }
        }
        var board = original
        var possibilities = (0..<81).map { candidates(in: board, at: $0) }
        let units: [[Int]] = (0..<27).map { unit in
            if unit < 9 { return (0..<9).map { unit * 9 + $0 } }
            if unit < 18 { return (0..<9).map { $0 * 9 + unit - 9 } }
            let box = unit - 18
            return (0..<9).map { (box / 3 * 3 + $0 / 3) * 9 + box % 3 * 3 + $0 % 3 }
        }
        var rating: HumanTechniqueRating = .nakedSingles
        func place(_ value: Int, at index: Int) {
            board[index] = value; possibilities[index] = []
            for peer in peers(of: index) { possibilities[peer].remove(value) }
        }
        while board.contains(0) {
            if (0..<81).contains(where: { board[$0] == 0 && possibilities[$0].isEmpty }) { return nil }
            if let index = (0..<81).first(where: { board[$0] == 0 && possibilities[$0].count == 1 }),
               let value = possibilities[index].first {
                place(value, at: index); continue
            }
            var changed = false
            outerHidden: for unit in units {
                for value in 1...9 {
                    let locations = unit.filter { possibilities[$0].contains(value) }
                    if locations.count == 1 {
                        place(value, at: locations[0]); rating = max(rating, .hiddenSingles)
                        changed = true; break outerHidden
                    }
                }
            }
            if changed { continue }
            // An intersection between a block and row/column confines a digit,
            // allowing elimination from the rest of the intersecting unit.
            outerLocked: for (sourceIndex, source) in units.enumerated() {
                for value in 1...9 {
                    let locations = source.filter { possibilities[$0].contains(value) }
                    guard locations.count > 1 else { continue }
                    for (targetIndex, target) in units.enumerated() {
                        guard (sourceIndex >= 18) != (targetIndex >= 18), locations.allSatisfy({ target.contains($0) }) else { continue }
                        let excluded = target.filter { !source.contains($0) && possibilities[$0].contains(value) }
                        if !excluded.isEmpty {
                            for index in excluded { possibilities[index].remove(value) }
                            rating = max(rating, .lockedCandidates); changed = true; break outerLocked
                        }
                    }
                }
            }
            if changed { continue }
            outerPairs: for unit in units {
                let pairs = unit.filter { possibilities[$0].count == 2 }
                for first in pairs {
                    let matching = pairs.filter { possibilities[$0] == possibilities[first] }
                    guard matching.count == 2 else { continue }
                    let digits = possibilities[first]
                    let excluded = unit.filter { !matching.contains($0) && !possibilities[$0].isDisjoint(with: digits) }
                    if !excluded.isEmpty {
                        for index in excluded { possibilities[index].subtract(digits) }
                        rating = max(rating, .nakedPairs); changed = true; break outerPairs
                    }
                }
            }
            if !changed { return solve(original) == nil ? nil : .searchRequired }
        }
        return isValidSolution(board) ? rating : nil
    }
}
