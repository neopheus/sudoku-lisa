import Foundation

/// A bounded 4 × 4 game. Clues are a subset of a valid Latin square with 2 × 2 boxes.
struct MiniSudoku {
    let solution: [Int]
    let clues: [Int]
    private(set) var cells: [Int]
    private(set) var history: [[Int]] = []

    init() {
        let digits = Array(1...4).shuffled()
        let base = [1,2,3,4,3,4,1,2,2,1,4,3,4,3,2,1]
        let solution = base.map { digits[$0 - 1] }
        self.solution = solution
        // Nine clues give a unique solution; the complementary cells are deliberately spread across boxes.
        let fixed: Set<Int> = [0,2,3,5,6,9,10,12,15]
        clues = solution.enumerated().map { fixed.contains($0.offset) ? $0.element : 0 }
        cells = clues
    }

    var isComplete: Bool { cells == solution }
    func isEditable(_ index: Int) -> Bool { cells.indices.contains(index) && clues[index] == 0 }
    func hasConflict(_ index: Int) -> Bool {
        guard cells.indices.contains(index), cells[index] != 0 else { return false }
        let row = index / 4, column = index % 4
        return cells.indices.contains { other in
            guard other != index, cells[other] == cells[index] else { return false }
            return other / 4 == row || other % 4 == column || (other / 8 == index / 8 && other % 4 / 2 == column / 2)
        }
    }
    mutating func set(_ value: Int, at index: Int) {
        guard isEditable(index), (0...4).contains(value), cells[index] != value else { return }
        history.append(cells)
        if history.count > 100 { history.removeFirst() }
        cells[index] = value
    }
    mutating func undo() { if let previous = history.popLast() { cells = previous } }
}
