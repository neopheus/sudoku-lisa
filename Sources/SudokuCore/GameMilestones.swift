/// One-shot celebrations for completed units and digits. No solution signal in zen mode.
public struct GameMilestones: Sendable {
    public private(set) var units: Set<Int> = []
    public private(set) var digits: Set<Int> = []

    public init() {}

    public struct Event: Equatable, Sendable {
        public var cells: Set<Int> = []
        public var digits: Set<Int> = []
        public var completedUnits: Set<Int> = []
        public var unitCount: Int { completedUnits.count }
        public var isEmpty: Bool { cells.isEmpty && digits.isEmpty }
        public init() {}
    }

    public mutating func record(before: [Int], after: [Int], solution: [Int], revealsCorrectness: Bool) -> Event {
        guard before.count == 81, after.count == 81, solution.count == 81, before != after else { return Event() }
        var event = Event()
        for unit in 0..<27 {
            let cells = Self.cells(in: unit)
            let wasComplete = cells.allSatisfy { before[$0] == solution[$0] }
            let complete = cells.allSatisfy { after[$0] == solution[$0] }
            if complete, !wasComplete, units.insert(unit).inserted, revealsCorrectness {
                event.cells.formUnion(cells)
                event.completedUnits.insert(unit)
            }
        }
        for digit in 1...9 {
            let cells = solution.indices.filter { solution[$0] == digit }
            if cells.allSatisfy({ after[$0] == digit }), !cells.allSatisfy({ before[$0] == digit }),
               digits.insert(digit).inserted, revealsCorrectness {
                event.digits.insert(digit)
            }
        }
        return event
    }

    private static func cells(in unit: Int) -> [Int] {
        if unit < 9 { return (0..<9).map { unit * 9 + $0 } }
        if unit < 18 { return (0..<9).map { $0 * 9 + unit - 9 } }
        let box = unit - 18
        return (0..<9).map { (box / 3 * 3 + $0 / 3) * 9 + box % 3 * 3 + $0 % 3 }
    }
}
