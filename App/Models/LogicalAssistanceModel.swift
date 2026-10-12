import Foundation
import Combine
import SudokuCore

/// Ephemeral overlays; only the fact that a trail was seen belongs in a save.
@MainActor
final class LogicalAssistanceModel: ObservableObject {
    @Published var candidatesEnabled = false
    @Published var focusPickerPresented = false
    @Published var focusDigit: Int?
    @Published var trailEnabled = false
    @Published private(set) var snapshot: AssistanceSnapshot?
    @Published private(set) var isWorking = false
    @Published private(set) var failed = false
    private var gameID: UUID?
    private var requestID = UUID()
    private var task: Task<Void, Never>?

    var isActive: Bool { candidatesEnabled || focusDigit != nil || trailEnabled }
    var focusCells: Set<Int> { Set(snapshot?.deduction?.focusCells ?? []) }

    func matches(_ game: GameSession, id: UUID) -> Bool {
        gameID == id && snapshot?.values == game.values && snapshot?.eliminations == game.candidateEliminations
    }

    func request(_ game: GameSession, id: UUID) {
        cancel()
        gameID = id
        isWorking = true
        let token = requestID
        let includeDeduction = trailEnabled
        task = Task { [weak self] in
            do {
                let result = try await HintAnalysisWorker.shared.assistance(values: game.values,
                    eliminations: game.candidateEliminations, includeDeduction: includeDeduction)
                try Task.checkCancellation()
                guard let self, self.requestID == token else { return }
                self.snapshot = result
                self.isWorking = false
                self.task = nil
            } catch {
                guard let self, self.requestID == token else { return }
                self.isWorking = false
                self.failed = true
                self.task = nil
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        requestID = UUID()
        snapshot = nil
        gameID = nil
        isWorking = false
        failed = false
    }

    func hideOverlays() {
        candidatesEnabled = false
        focusDigit = nil
        trailEnabled = false
    }

    func hide() {
        focusPickerPresented = false
        hideOverlays()
        cancel()
    }

    deinit { task?.cancel() }
}

struct AssistanceRequest: Equatable {
    let id: UUID
    let values: [Int]
    let eliminations: Set<CandidateElimination>
    let trail: Bool
    let active: Bool
}
