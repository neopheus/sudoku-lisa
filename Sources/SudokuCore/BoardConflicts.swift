/// Duplicate cells, computed once for a board edit instead of scanning the
/// entire board separately for each rendered cell.
public enum BoardConflicts {
    public static func indices(in values: [Int]) -> Set<Int> {
        guard values.count == 81 else { return [] }
        var first = Array(repeating: -1, count: 27 * 9)
        var conflicts: Set<Int> = []
        for (index, value) in values.enumerated() where (1...9).contains(value) {
            let row = index / 9
            let column = index % 9
            let box = row / 3 * 3 + column / 3
            for unit in [row, 9 + column, 18 + box] {
                let slot = unit * 9 + value - 1
                if first[slot] >= 0 {
                    conflicts.insert(first[slot])
                    conflicts.insert(index)
                } else { first[slot] = index }
            }
        }
        return conflicts
    }
}
