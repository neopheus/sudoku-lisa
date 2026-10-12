import Foundation

/// No solution or personal notes enter the assistance calculation.
public struct AssistanceSnapshot: Sendable, Equatable {
    public let values: [Int]
    public let eliminations: Set<CandidateElimination>
    public let candidates: [Set<Int>]
    public let isConsistent: Bool
    public let deduction: SudokuDeduction?

    public init(values: [Int], eliminations: Set<CandidateElimination>,
                includeDeduction: Bool = false, cancellation: () -> Bool = { false }) {
        self.values = values
        self.eliminations = eliminations
        let state = LogicalState(board: values, eliminations: eliminations)
        candidates = (0..<81).map { state.candidates(at: $0) }
        isConsistent = state.isConsistent
        deduction = includeDeduction && isConsistent && !cancellation()
            ? state.nextDeduction(cancellation: cancellation) : nil
    }
}
