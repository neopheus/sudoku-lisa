import Foundation
import Combine
import SudokuCore

/// One serial executor for short logical analyses. No polling or global cache.
private actor HintAnalysisWorker {
    static let shared = HintAnalysisWorker()

    func analyse(_ game: GameSession) throws -> (SudokuHint?, [Set<Int>]) {
        try Task.checkCancellation()
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        let hint = try game.hint(cancellation: { Task.isCancelled || ContinuousClock.now >= deadline })
        let state = LogicalState(board: game.values, eliminations: game.candidateEliminations)
        let candidates = (0..<81).map { state.candidates(at: $0) }
        try Task.checkCancellation()
        return (hint, candidates)
    }
}

@MainActor
final class HintCoachModel: ObservableObject {
    @Published private(set) var hint: SudokuHint?
    @Published private(set) var isWorking = false
    @Published private(set) var candidates: [Set<Int>] = []
    private(set) var focusedCells: Set<Int> = []
    private(set) var marksByCell: [Int: [CandidateElimination]] = [:]
    private var snapshot: GameSession?
    private var requestID = UUID()
    private var task: Task<Void, Never>?

    func request(_ game: GameSession) {
        cancel()
        snapshot = game
        isWorking = true
        let id = requestID
        task = Task { [weak self] in
            do {
                let result = try await HintAnalysisWorker.shared.analyse(game)
                try Task.checkCancellation()
                guard let self, self.requestID == id else { return }
                self.focusedCells = Set(result.0?.focusCells ?? []).union((result.0?.eliminationMarks ?? []).map(\.index))
                self.marksByCell = Dictionary(grouping: result.0?.eliminationMarks ?? [], by: \.index)
                self.candidates = result.1
                self.isWorking = false
                self.hint = result.0
                self.task = nil
            } catch {
                guard let self, self.requestID == id else { return }
                self.isWorking = false
                self.task = nil
            }
        }
    }

    func matches(_ game: GameSession?) -> Bool {
        guard let snapshot, let game else { return false }
        return snapshot.puzzle == game.puzzle && snapshot.values == game.values
            && snapshot.candidateEliminations == game.candidateEliminations
    }

    func cancel() {
        task?.cancel()
        task = nil
        requestID = UUID()
        isWorking = false
        hint = nil
        candidates = []
        focusedCells = []
        marksByCell = [:]
        snapshot = nil
    }

    deinit { task?.cancel() }
}
