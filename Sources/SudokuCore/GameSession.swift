import Foundation

public struct SudokuHint: Codable, Sendable, Equatable {
    public let index: Int
    public let value: Int
    public let title: String
    public let detail: String
    public init(index: Int, value: Int, title: String, detail: String) {
        self.index = index; self.value = value; self.title = title; self.detail = detail
    }
}

public struct GameSession: Codable, Sendable, Equatable {
    public let puzzle: Puzzle
    public private(set) var values: [Int]
    public private(set) var notes: [Set<Int>]
    public private(set) var mistakes: Int = 0
    public var elapsedSeconds: Int = 0
    public private(set) var hintsUsed: Int = 0
    private var undoHistory: [[CellChange]] = []
    private struct CellChange: Codable, Sendable, Equatable {
        let index: Int
        let value: Int
        let notes: Set<Int>
    }
    private struct Snapshot: Codable {
        let values: [Int]
        let notes: [Set<Int>]
    }
    public init(puzzle: Puzzle) {
        self.puzzle = puzzle; self.values = puzzle.givens
        self.notes = Array(repeating: [], count: 81)
    }
    private enum CodingKeys: String, CodingKey { case puzzle, values, notes, mistakes, elapsedSeconds, hintsUsed, undoHistory, history }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        puzzle = try c.decode(Puzzle.self, forKey: .puzzle)
        values = try c.decode([Int].self, forKey: .values)
        notes = try c.decode([Set<Int>].self, forKey: .notes)
        mistakes = try c.decode(Int.self, forKey: .mistakes)
        elapsedSeconds = try c.decode(Int.self, forKey: .elapsedSeconds)
        hintsUsed = try c.decode(Int.self, forKey: .hintsUsed)
        let givens = puzzle.givens
        func valid(_ values: [Int], _ notes: [Set<Int>]) -> Bool {
            values.count == 81 && notes.count == 81 && values.allSatisfy { (0...9).contains($0) }
                && notes.allSatisfy { $0.allSatisfy { (1...9).contains($0) } }
                && zip(givens, values).allSatisfy { $0 == 0 || $0 == $1 }
        }
        let invalid = DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid saved Sudoku session"))
        guard valid(values, notes), mistakes >= 0, elapsedSeconds >= 0, hintsUsed >= 0 else { throw invalid }
        if c.contains(.undoHistory) {
            undoHistory = try c.decode([[CellChange]].self, forKey: .undoHistory)
            guard undoHistory.allSatisfy({ changes in
                changes.count <= 81 && Set(changes.map(\.index)).count == changes.count && changes.allSatisfy {
                    (0..<81).contains($0.index) && givens[$0.index] == 0
                        && (0...9).contains($0.value) && $0.notes.allSatisfy { (1...9).contains($0) }
                }
            }) else { throw invalid }
        } else {
            // Version 1 stored a complete board before each edit. Compare each
            // snapshot with the following state to retain only changed cells.
            let legacy = try c.decodeIfPresent([Snapshot].self, forKey: .history) ?? []
            guard legacy.allSatisfy({ valid($0.values, $0.notes) }) else { throw invalid }
            for index in legacy.indices {
                let before = legacy[index]
                let afterValues = index + 1 < legacy.count ? legacy[index + 1].values : values
                let afterNotes = index + 1 < legacy.count ? legacy[index + 1].notes : notes
                undoHistory.append((0..<81).compactMap { cell in
                    guard before.values[cell] != afterValues[cell] || before.notes[cell] != afterNotes[cell] else { return nil }
                    return CellChange(index: cell, value: before.values[cell], notes: before.notes[cell])
                })
            }
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(puzzle, forKey: .puzzle)
        try c.encode(values, forKey: .values)
        try c.encode(notes, forKey: .notes)
        try c.encode(mistakes, forKey: .mistakes)
        try c.encode(elapsedSeconds, forKey: .elapsedSeconds)
        try c.encode(hintsUsed, forKey: .hintsUsed)
        try c.encode(undoHistory, forKey: .undoHistory)
    }
    public var isComplete: Bool { values == puzzle.solution }
    public var canUndo: Bool { !isComplete && !undoHistory.isEmpty }
    public var filledCount: Int { values.filter { $0 != 0 }.count }
    public var progress: Double {
        let total = 81 - puzzle.clueCount
        guard total > 0 else { return 1 }
        let correct = (0..<81).filter { puzzle.givens[$0] == 0 && values[$0] == puzzle.solution[$0] }.count
        return Double(correct) / Double(total)
    }
    public func isEditable(_ index: Int) -> Bool {
        (0..<81).contains(index) && puzzle.givens[index] == 0 && !isComplete
    }
    public func isIncorrect(at index: Int) -> Bool {
        (0..<81).contains(index) && values[index] != 0 && values[index] != puzzle.solution[index]
    }
    /// Unlimited undo stores only cells changed by an edit, including pruned notes.
    private mutating func save(indices: [Int]) {
        undoHistory.append(indices.sorted().map { CellChange(index: $0, value: values[$0], notes: notes[$0]) })
    }
    /// Incorrect entries remain visible. Mistake count is cumulative across undo.
    @discardableResult public mutating func enter(_ value: Int, at index: Int) -> Bool {
        guard isEditable(index), (1...9).contains(value), values[index] != value else { return false }
        let affectedPeers = value == puzzle.solution[index]
            ? SudokuSolver.peers(of: index).filter { notes[$0].contains(value) } : []
        save(indices: [index] + affectedPeers)
        values[index] = value; notes[index] = []
        if value != puzzle.solution[index] { mistakes += 1; return false }
        for peer in affectedPeers { notes[peer].remove(value) }
        return true
    }
    public mutating func toggleNote(_ value: Int, at index: Int) {
        guard isEditable(index), values[index] == 0, (1...9).contains(value) else { return }
        save(indices: [index])
        if notes[index].contains(value) { notes[index].remove(value) } else { notes[index].insert(value) }
    }
    public mutating func erase(at index: Int) {
        guard isEditable(index), values[index] != 0 || !notes[index].isEmpty else { return }
        save(indices: [index]); values[index] = 0; notes[index] = []
    }
    public mutating func undo() {
        guard !isComplete, let changes = undoHistory.popLast() else { return }
        for change in changes { values[change.index] = change.value; notes[change.index] = change.notes }
    }
    public mutating func tick() { if !isComplete { elapsedSeconds += 1 } }
    public func hint() -> SudokuHint? {
        guard !isComplete else { return nil }
        if let wrong = (0..<81).first(where: { isIncorrect(at: $0) }) {
            return SudokuHint(index: wrong, value: puzzle.solution[wrong], title: L10n.text("Une case à revoir"), detail: L10n.text("La valeur en ligne %@, colonne %@ empêche de terminer la grille. La valeur correcte est %@.", String(describing: wrong / 9 + 1), String(describing: wrong % 9 + 1), String(describing: puzzle.solution[wrong])))
        }
        for index in 0..<81 where values[index] == 0 {
            let candidates = SudokuSolver.candidates(in: values, at: index)
            if candidates.count == 1, let digit = candidates.first {
                return SudokuHint(index: index, value: digit, title: L10n.text("Une seule possibilité"), detail: L10n.text("En ligne %@, colonne %@, tous les chiffres sauf %@ sont déjà présents dans la ligne, la colonne ou le bloc.", String(describing: index / 9 + 1), String(describing: index % 9 + 1), String(describing: digit)))
            }
        }
        for unit in 0..<27 {
            let indices: [Int]
            let name: String
            if unit < 9 { indices = (0..<9).map { unit * 9 + $0 }; name = L10n.text("cette ligne") }
            else if unit < 18 { indices = (0..<9).map { $0 * 9 + unit - 9 }; name = L10n.text("cette colonne") }
            else { let box = unit - 18; indices = (0..<9).map { (box / 3 * 3 + $0 / 3) * 9 + box % 3 * 3 + $0 % 3 }; name = L10n.text("ce bloc") }
            for digit in 1...9 {
                let positions = indices.filter { values[$0] == 0 && SudokuSolver.candidates(in: values, at: $0).contains(digit) }
                if positions.count == 1 {
                    return SudokuHint(index: positions[0], value: digit, title: L10n.text("La seule place"), detail: L10n.text("Dans %@, le %@ ne peut aller que dans cette case : les autres emplacements sont exclus par leurs lignes, colonnes ou blocs.", String(describing: name), String(describing: digit)))
                }
            }
        }
        guard let index = (0..<81).filter({ values[$0] == 0 }).min(by: { SudokuSolver.candidates(in: values, at: $0).count < SudokuSolver.candidates(in: values, at: $1).count }) else { return nil }
        return SudokuHint(index: index, value: puzzle.solution[index], title: L10n.text("Un petit coup de pouce"), detail: L10n.text("Cette étape demande une technique avancée. La solution vérifiée place un %@ en ligne %@, colonne %@.", String(describing: puzzle.solution[index]), String(describing: index / 9 + 1), String(describing: index % 9 + 1)))
    }
    /// Count help when it is displayed, even if the player enters it manually.
    public mutating func recordHintConsultation() {
        guard !isComplete else { return }
        hintsUsed += 1
    }
    @discardableResult public mutating func applyHint(countAsUsed: Bool = true) -> SudokuHint? {
        guard let suggestion = hint() else { return nil }
        if countAsUsed { recordHintConsultation() }
        _ = enter(suggestion.value, at: suggestion.index)
        return suggestion
    }
}
