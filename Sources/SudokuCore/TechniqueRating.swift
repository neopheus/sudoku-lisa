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

struct LogicalMove {
    let index: Int
    let value: Int
    let focusCells: [Int]
    let eliminatedCandidates: [Int]
    let eliminationMarks: [CandidateElimination]
    let technique: String
    let observation: String
    let explanation: String
}

extension SudokuSolver {
    /// Describes the next deduction supported by the techniques used by the rating engine.
    static func nextLogicalMove(in board: [Int]) -> LogicalMove? {
        guard board.count == 81, board.contains(0), let solution = solve(board) else { return nil }
        let units: [[Int]] = (0..<27).map { unit in
            if unit < 9 { return (0..<9).map { unit * 9 + $0 } }
            if unit < 18 { return (0..<9).map { $0 * 9 + unit - 9 } }
            let box = unit - 18
            return (0..<9).map { (box / 3 * 3 + $0 / 3) * 9 + box % 3 * 3 + $0 % 3 }
        }
        var candidates = (0..<81).map { candidates(in: board, at: $0) }
        func move(_ index: Int, _ focus: [Int], _ technique: String, _ observation: String, _ explanation: String) -> LogicalMove? {
            guard let value = candidates[index].first(where: { board[index] == 0 && $0 == solution[index] }) else { return nil }
            return LogicalMove(index: index, value: value, focusCells: focus, eliminatedCandidates: [], eliminationMarks: [], technique: technique, observation: observation, explanation: explanation)
        }
        func solvedMove(focus: [Int], eliminated: [Int] = [], marks: [CandidateElimination] = [], technique: String, observation: String, explanation: String) -> LogicalMove? {
            for index in 0..<81 where board[index] == 0 && candidates[index].count == 1 {
                guard let value = candidates[index].first else { continue }
                return LogicalMove(index: index, value: value, focusCells: focus.isEmpty ? [index] : focus,
                                   eliminatedCandidates: Array(Set(eliminated)).sorted(), eliminationMarks: marks,
                                   technique: technique, observation: observation, explanation: explanation)
            }
            for (unitIndex, unit) in units.enumerated() {
                for digit in 1...9 {
                    let locations = unit.filter { board[$0] == 0 && candidates[$0].contains(digit) }
                    if locations.count == 1 {
                        return LogicalMove(index: locations[0], value: digit, focusCells: focus.isEmpty ? unit : focus, eliminatedCandidates: Array(Set(eliminated)).sorted(), eliminationMarks: marks,
                                            technique: technique, observation: observation, explanation: explanation)
                    }
                }
                _ = unitIndex
            }
            return nil
        }
        if let single = (0..<81).first(where: { board[$0] == 0 && candidates[$0].count == 1 }) {
            let row = single / 9, col = single % 9, box = 18 + row / 3 * 3 + col / 3
            return move(single, units[box], L10n.text("Candidats uniques"),
                        L10n.text("Repère la zone colorée et cherche les possibilités encore ouvertes."),
                        L10n.text("Les chiffres présents sur la ligne, la colonne et le bloc éliminent toutes les possibilités sauf une."))
        }
        for unit in units {
            for digit in 1...9 {
                let locations = unit.filter { board[$0] == 0 && candidates[$0].contains(digit) }
                if locations.count == 1 {
                    let index = locations[0]
                    return LogicalMove(index: index, value: digit, focusCells: unit, eliminatedCandidates: [], eliminationMarks: [], technique: L10n.text("Positions uniques"),
                                       observation: L10n.text("Repère la zone colorée et cherche les possibilités encore ouvertes."),
                                       explanation: L10n.text("Dans la zone colorée, ce chiffre ne peut aller que dans une case. Les autres emplacements sont bloqués par leur ligne, colonne ou bloc."))
                }
            }
        }
        // Locked candidates: a digit confined to one row/column of a box can be removed from the rest of that line.
        for boxIndex in 18..<27 {
            let box = units[boxIndex]
            for digit in 1...9 {
                let locations = box.filter { board[$0] == 0 && candidates[$0].contains(digit) }
                guard locations.count > 1 else { continue }
                for lineIndex in Set(locations.map({ $0 / 9 })) {
                    guard locations.allSatisfy({ $0 / 9 == lineIndex }) else { continue }
                    let removed = units[lineIndex].filter { !box.contains($0) && candidates[$0].contains(digit) }
                    guard !removed.isEmpty else { continue }
                    let marks = removed.map { CandidateElimination(index: $0, value: digit) }
                    removed.forEach { candidates[$0].remove(digit) }
                    if let result = solvedMove(focus: box + removed, eliminated: [digit], marks: marks, technique: L10n.text("Candidats verrouillés"),
                                               observation: L10n.text("Repère la zone colorée et cherche les possibilités encore ouvertes."),
                                               explanation: L10n.text("Dans le bloc coloré, ce chiffre reste sur une seule ligne ou colonne : élimine-le des autres cases de cette ligne ou colonne.")) { return result }
                }
                for lineIndex in Set(locations.map({ $0 % 9 })) {
                    guard locations.allSatisfy({ $0 % 9 == lineIndex }) else { continue }
                    let removed = units[9 + lineIndex].filter { !box.contains($0) && candidates[$0].contains(digit) }
                    guard !removed.isEmpty else { continue }
                    let marks = removed.map { CandidateElimination(index: $0, value: digit) }
                    removed.forEach { candidates[$0].remove(digit) }
                    if let result = solvedMove(focus: box + removed, eliminated: [digit], marks: marks, technique: L10n.text("Candidats verrouillés"),
                                               observation: L10n.text("Repère la zone colorée et cherche les possibilités encore ouvertes."),
                                               explanation: L10n.text("Dans le bloc coloré, ce chiffre reste sur une seule ligne ou colonne : élimine-le des autres cases de cette ligne ou colonne.")) { return result }
                }
            }
        }
        for unit in units {
            let pairs = unit.filter { board[$0] == 0 && candidates[$0].count == 2 }
            for first in pairs {
                let twins = pairs.filter { candidates[$0] == candidates[first] }
                guard twins.count == 2 else { continue }
                let digits = candidates[first]
                let removed = unit.filter { !twins.contains($0) && !candidates[$0].isDisjoint(with: digits) }
                guard !removed.isEmpty else { continue }
                let marks = removed.flatMap { index in candidates[index].intersection(digits).map { CandidateElimination(index: index, value: $0) } }
                for index in removed { candidates[index].subtract(digits) }
                if let result = solvedMove(focus: twins + removed, eliminated: Array(digits), marks: marks, technique: L10n.text("Paires nues"),
                                           observation: L10n.text("Repère la zone colorée et cherche les possibilités encore ouvertes."),
                                           explanation: L10n.text("Deux cases partagent les mêmes deux candidats. Ces chiffres sont réservés à cette paire ; retire-les des autres cases de la zone.")) { return result }
            }
        }
        // Be transparent when the current board requires a technique beyond the supported logical set.
        guard let index = (0..<81).filter({ board[$0] == 0 }).min(by: { candidates[$0].count < candidates[$1].count }) else { return nil }
        return LogicalMove(index: index, value: solution[index], focusCells: [index], eliminatedCandidates: [], eliminationMarks: [],
                           technique: L10n.text("Techniques avancées"),
                           observation: L10n.text("Repère la zone colorée et cherche les possibilités encore ouvertes."),
                           explanation: L10n.text("Cette grille demande une technique que Lisa n’a pas encore apprise. Tu peux voir la solution vérifiée à la dernière étape."))
    }

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
