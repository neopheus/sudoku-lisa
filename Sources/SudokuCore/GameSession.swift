import Foundation

public struct SudokuHint: Codable, Sendable, Equatable {
    public let deduction: SudokuDeduction?
    public let index: Int
    public let value: Int
    public let title: String
    public let detail: String
    public let focusCells: [Int]
    public let eliminatedCandidates: [Int]
    public let eliminationMarks: [CandidateElimination]
    public let technique: String
    public let explanation: String
    public init(index: Int, value: Int, title: String, detail: String, focusCells: [Int] = [], eliminatedCandidates: [Int] = [], eliminationMarks: [CandidateElimination] = [], technique: String = "", explanation: String = "", deduction: SudokuDeduction? = nil) {
        self.deduction = deduction
        self.index = index; self.value = value; self.title = title; self.detail = detail
        self.focusCells = focusCells; self.eliminatedCandidates = eliminatedCandidates; self.eliminationMarks = eliminationMarks
        self.technique = technique; self.explanation = explanation
    }
}

public struct CandidateElimination: Codable, Sendable, Equatable, Hashable {
    public let index: Int
    public let value: Int
    public init(index: Int, value: Int) { self.index = index; self.value = value }
}

public struct GameSession: Codable, Sendable, Equatable {
    public let puzzle: Puzzle
    public private(set) var values: [Int]
    public private(set) var notes: [Set<Int>]
    public private(set) var mistakes: Int = 0
    public var elapsedSeconds: Int = 0
    public private(set) var hintsUsed: Int = 0
    public private(set) var candidateEliminations: Set<CandidateElimination> = []
    private var eliminationHistory: [Set<CandidateElimination>?] = []
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
    private enum CodingKeys: String, CodingKey { case puzzle, values, notes, mistakes, elapsedSeconds, hintsUsed, undoHistory, history, candidateEliminations, eliminationHistory }
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
        candidateEliminations = try c.decodeIfPresent(Set<CandidateElimination>.self, forKey: .candidateEliminations) ?? []
        eliminationHistory = try c.decodeIfPresent([Set<CandidateElimination>?].self, forKey: .eliminationHistory) ?? Array(repeating: nil, count: undoHistory.count)
        func validMarks(_ marks: Set<CandidateElimination>) -> Bool {
            marks.allSatisfy { (0..<81).contains($0.index) && (1...9).contains($0.value) && puzzle.solution[$0.index] != $0.value }
        }
        guard eliminationHistory.count == undoHistory.count, validMarks(candidateEliminations), eliminationHistory.allSatisfy({ $0.map(validMarks) ?? true }) else { throw invalid }
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
        try c.encode(candidateEliminations, forKey: .candidateEliminations)
        try c.encode(eliminationHistory, forKey: .eliminationHistory)
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
    private mutating func save(indices: [Int], savesEliminations: Bool = false) {
        eliminationHistory.append(savesEliminations ? candidateEliminations : nil)
        undoHistory.append(Array(Set(indices)).sorted().map { CellChange(index: $0, value: values[$0], notes: notes[$0]) })
    }
    /// Incorrect entries remain visible. Mistake count is cumulative across undo.
    @discardableResult public mutating func enter(_ value: Int, at index: Int) -> Bool {
        guard isEditable(index), (1...9).contains(value), values[index] != value else { return false }
        let affectedPeers = value == puzzle.solution[index]
            ? SudokuSolver.peers(of: index).filter { notes[$0].contains(value) } : []
        save(indices: [index] + affectedPeers, savesEliminations: values[index] != 0 || value != puzzle.solution[index])
        if values[index] != 0 || value != puzzle.solution[index] { candidateEliminations.removeAll() }
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
        save(indices: [index], savesEliminations: values[index] != 0)
        if values[index] != 0 { candidateEliminations.removeAll() }
        values[index] = 0; notes[index] = []
    }
    public mutating func undo() {
        guard !isComplete, let changes = undoHistory.popLast() else { return }
        if let saved = eliminationHistory.popLast(), let marks = saved { candidateEliminations = marks }
        for change in changes { values[change.index] = change.value; notes[change.index] = change.notes }
    }
    public mutating func tick() { if !isComplete { elapsedSeconds += 1 } }
    public func candidates(at index: Int) -> Set<Int> {
        LogicalState(board: values, eliminations: candidateEliminations).candidates(at: index)
    }
    public func hint() -> SudokuHint? { try? hint(cancellation: { false }) }
    public func hint(cancellation: @Sendable () -> Bool) throws -> SudokuHint? {
        if cancellation() { throw CancellationError() }
        guard !isComplete else { return nil }
        let deduction: SudokuDeduction
        if let wrong = (0..<81).first(where: { isIncorrect(at: $0) }) {
            deduction = SudokuDeduction(techniqueID: .correction, action: .placement(index: wrong, value: puzzle.solution[wrong]), focusCells: [wrong])
        } else if let next = LogicalState(board: values, eliminations: candidateEliminations).nextDeduction() {
            deduction = next
        } else {
            // Compatibility for older games which exceed our logical engine.
            // The provenance is explicit and never misrepresented as a deduction.
            guard let cell = values.firstIndex(of: 0) else { return nil }
            deduction = SudokuDeduction(techniqueID: .solutionReveal, action: .placement(index: cell, value: puzzle.solution[cell]), focusCells: [cell])
        }
        if cancellation() { throw CancellationError() }
        let index: Int, value: Int, marks: [CandidateElimination]
        switch deduction.action {
        case let .placement(cell, digit): index = cell; value = digit; marks = []
        case let .eliminations(eliminations): index = eliminations.first?.index ?? 0; value = 0; marks = eliminations
        }
        return SudokuHint(index: index, value: value, title: deduction.techniqueID == .correction ? L10n.text("Une case à revoir") : L10n.text("Regarde cette zone"),
                          detail: deduction.observation, focusCells: deduction.focusCells,
                          eliminatedCandidates: Array(Set(marks.map(\.value))).sorted(), eliminationMarks: marks,
                          technique: deduction.techniqueID.label, explanation: deduction.explanation, deduction: deduction)
    }
    /// Applies the already displayed atomic action. Candidate notes are only
    /// pruned where they exist; automatic candidates remain a separate state.
    @discardableResult public mutating func applyDeduction(_ deduction: SudokuDeduction, countAsUsed: Bool = false) -> Bool {
        guard !isComplete else { return false }
        switch deduction.action {
        case let .placement(index, value):
            guard isEditable(index), value == puzzle.solution[index], values[index] != value else { return false }
            if countAsUsed { recordHintConsultation() }
            return enter(value, at: index)
        case let .eliminations(marks):
            let state = LogicalState(board: values, eliminations: candidateEliminations)
            guard !marks.isEmpty, marks.allSatisfy({ mark in
                isEditable(mark.index) && values[mark.index] == 0 && (1...9).contains(mark.value)
                    && puzzle.solution[mark.index] != mark.value && state.candidates(at: mark.index).contains(mark.value)
            }) else { return false }
            if countAsUsed { recordHintConsultation() }
            save(indices: marks.map(\.index), savesEliminations: true)
            candidateEliminations.formUnion(marks)
            for mark in marks { notes[mark.index].remove(mark.value) }
            return true
        }
    }
    /// Count help when it is displayed, even if the player enters it manually.
    public mutating func recordHintConsultation() {
        guard !isComplete else { return }
        hintsUsed += 1
    }
    @discardableResult public mutating func applyHint(countAsUsed: Bool = true) -> SudokuHint? {
        guard let suggestion = hint(), let deduction = suggestion.deduction,
              applyDeduction(deduction, countAsUsed: countAsUsed) else { return nil }
        return suggestion
    }
}
