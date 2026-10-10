import os
import Foundation
import SwiftUI
import UIKit
import SudokuCore
@preconcurrency import GameKit

/// Prepared after each board edit so rendering never scans the grid per cell.
struct BattleBoardSummary: Equatable {
    let remaining: [Int]
    let duplicates: Set<Int>

    static let empty = BattleBoardSummary(remaining: Array(repeating: 9, count: 9), duplicates: [])

    init(remaining: [Int], duplicates: Set<Int>) {
        self.remaining = remaining
        self.duplicates = duplicates
    }

    init(game: GameSession) {
        var counts = Array(repeating: 0, count: 9)
        for index in 0..<81 where game.values[index] == game.puzzle.solution[index] {
            let digit = game.values[index]
            if (1...9).contains(digit) { counts[digit - 1] += 1 }
        }
        remaining = counts.map { max(0, 9 - $0) }
        duplicates = BoardConflicts.indices(in: game.values)
    }
}

/// Keeps exact network time while publishing only changes visible in the timer label.
@MainActor
final class BattleElapsedClock: ObservableObject {
    private(set) var elapsed: Double = 0
    @Published private(set) var seconds = 0

    fileprivate func update(elapsed value: Double) {
        elapsed = value
        let displayedSeconds = Int(value)
        if seconds != displayedSeconds { seconds = displayedSeconds }
    }
}

/// Ephemeral private-match owner. Never writes or replaces LisaStore's solo session.
@MainActor
final class BattleService: NSObject, ObservableObject, GKMatchmakerViewControllerDelegate, GKMatchDelegate {
    static let shared = BattleService()
    @Published private(set) var state: BattlePhase = .idle
    @Published private(set) var participants: [BattleParticipant] = []
    @Published private(set) var session: GameSession?
    @Published private(set) var selection: Int?
    @Published private(set) var lockedDigit: Int?
    @Published private(set) var boardSummary = BattleBoardSummary.empty
    @Published private(set) var difficulty: Difficulty = .easy
    @Published private(set) var errorMessage: String?
    @Published private(set) var countdown = 3
    let elapsedClock = BattleElapsedClock()
    private(set) var elapsed: Double {
        get { elapsedClock.elapsed }
        set { elapsedClock.update(elapsed: newValue) }
    }
    @Published private(set) var results: [BattleResult] = []
    @Published private(set) var roundID: UUID?
    @Published var notesMode = false
    var onRoundFinished: ((UUID, BattleResult) -> Void)? {
        didSet { if state == .finished { deliverRoundFinished() } }
    }
    private var deliveredRoundID: UUID?
    var appearance = PoulpiAppearance(color: .pink, accessory: .none)
    var localPlayerID: String { fixture ? "local-fixture" : (transport?.localPlayerID ?? GKLocalPlayer.local.gamePlayerID) }
    private var localPlayerName: String { transport?.localPlayerName ?? GKLocalPlayer.local.displayName }
    var isHost: Bool { hostID == localPlayerID }
    var canStart: Bool { active && isHost && state == .lobby && (2...4).contains(participants.count) && participants.allSatisfy { $0.ready && $0.status == .connected } }
    var canRematch: Bool { isHost && state == .finished && disconnectedPlayers.isEmpty && (fixture || transport != nil) }
    var canEdit: Bool { state == .playing && active && session?.isComplete == false && localParticipant?.status == .connected }
    private var localParticipant: BattleParticipant? { participants.first { $0.id == localPlayerID } }
    private var hostID: String?
    private var match: GKMatch?
    private var transport: (any BattleTransport)?
    private let clock: any BattleClock
    private var battleID: UUID?
    private var sequence: UInt64 = 0
    private var ledger: BattleRoundLedger?
    private var preparationStarted: Double?
    private var lastHeard: [String: Double] = [:]
    private var interrupted: [String: Double] = [:]
    private var startTime: Double?
    private var clockOffset: Double = 0
    private var bestRTT = Double.infinity
    private var generation: Task<Puzzle, Error>?
    private var preparation: Task<Void, Never>?
    private var stopLoop: (() -> Void)?
    private var lastProgress: Double = 0
    private var lastHello: Double = 0
    private var active = true
    private var inactiveSince: Double?
    private var fixture = false
    private var pendingFinish: Double?
    private var lastFinishSent: Double = 0
    private var pendingInvite: GKInvite?
    private var presented = false
    @Published private var disconnectedPlayers: Set<String> = []
    private var receiveBudgets: [String: (window: Double, count: Int)] = [:]
    private var now: Double { clock.now }
    private var hostNow: Double { now + clockOffset }

    init(clock: any BattleClock = SystemBattleClock()) {
        self.clock = clock
        super.init()
    }

    func configureAppearance(_ value: PoulpiAppearance) {
        appearance = value
        guard state == .lobby else { return }
        update(localPlayerID) { $0.appearance = value }
        send(.profile(name: localParticipant?.name ?? "Lisa", appearance: value))
    }

    func createMatch() {
        guard GKLocalPlayer.local.isAuthenticated else { GameCenterService.shared.authenticate(); errorMessage = "Connectez-vous à Game Center puis réessayez."; return }
        leave(); state = .matchmaking; errorMessage = nil
        let request = GKMatchRequest(); request.minPlayers = 2; request.maxPlayers = 4
        guard let controller = GKMatchmakerViewController(matchRequest: request) else { cancel("Les invitations sont indisponibles."); return }
        controller.matchmakingMode = .inviteOnly
        controller.canStartWithMinimumPlayers = true
        controller.matchmakerDelegate = self
        present(controller)
    }
    func setPresented(_ value: Bool) { presented = value; if value { presentPendingInvitation() } }
    func presentPendingInvitation() {
        guard presented, active, let invite = pendingInvite else { return }
        pendingInvite = nil
        showInvitation(invite)
    }
    func accept(invite: GKInvite) {
        leave(); pendingInvite = invite; state = .matchmaking; errorMessage = nil
        presentPendingInvitation()
    }
    private func showInvitation(_ invite: GKInvite) {
        guard let controller = GKMatchmakerViewController(invite: invite) else { cancel("L’invitation est indisponible."); return }
        controller.matchmakingMode = .inviteOnly; controller.matchmakerDelegate = self; present(controller)
    }
    private func present(_ controller: UIViewController) {
        guard let presenter = GameCenterService.shared.presenter else { cancel("Les invitations n’ont pas pu s’ouvrir."); return }
        presenter.present(controller, animated: true)
    }
    private func attach(_ match: GKMatch) {
        guard (1...3).contains(match.players.count), match.expectedPlayerCount == 0 else { match.disconnect(); cancel("Tous les amis doivent être connectés avant de commencer."); return }
        self.match = match; match.delegate = self
        connect(transport: GameKitBattleTransport(match: match))
    }

    func connect(transport: any BattleTransport) {
        let players = [BattleParticipant(id: transport.localPlayerID, name: String(transport.localPlayerName.prefix(80)))] + transport.peers
        guard (2...4).contains(players.count), Set(players.map(\.id)).count == players.count else {
            transport.disconnect(); cancel("Le groupe de joueurs est invalide."); return
        }
        self.transport = transport
        participants = players.sorted { $0.id < $1.id }
        hostID = BattleValidation.hostID(in: participants.map(\.id)); clockOffset = 0
        if isHost {
            battleID = UUID(); roundID = UUID()
            ledger = BattleRoundLedger(battleID: battleID!, roundID: roundID!, hostID: localPlayerID, playerIDs: Set(participants.map(\.id)))
        }
        state = .lobby; lastHeard = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, now) })
        update(localPlayerID) { $0.appearance = appearance }
        startLoop()
        if isHost { send(.hello(difficulty: difficulty)); send(.profile(name: localPlayerName, appearance: appearance)) }
    }
    func setDifficulty(_ value: Difficulty) {
        guard isHost, state == .lobby else { return }
        difficulty = value; participants.indices.forEach { participants[$0].ready = false }; send(.difficulty(value))
    }
    func setReady(_ value: Bool) {
        guard state == .lobby, battleID != nil else { return }
        update(localPlayerID) { $0.ready = value }; send(.ready(value))
    }
    func startRound() {
        guard canStart else { return }
        state = .preparing; preparationStarted = now; roundID = UUID(); session = nil; results = []; ledger?.beginRound(roundID!); ledger?.markLoaded(localPlayerID)
        startTime = nil; elapsed = 0; selection = nil; notesMode = false; lockedDigit = nil; boardSummary = .empty
        let selectedDifficulty = difficulty
        let previous = generation
        previous?.cancel()
        let worker = Task.detached(priority: .userInitiated) {
            if let previous { _ = await previous.result }
            try Task.checkCancellation()
            return try SudokuGenerator.generateCancellable(difficulty: selectedDifficulty, deadline: Date().addingTimeInterval(5), cancellation: { Task.isCancelled })
        }
        generation = worker
        preparation = Task { [weak self] in
            let result = await worker.result
            guard let self, !Task.isCancelled, self.state == .preparing else { return }
            self.generation = nil
            switch result {
            case .success(let puzzle): self.session = GameSession(puzzle: puzzle); self.refreshBoardSummary(); self.send(.puzzle(puzzle)); self.maybeScheduleStart()
            case .failure: self.cancel("La grille n’a pas pu être préparée. Réessayez avec vos amis.")
            }
        }
    }
    private func maybeScheduleStart() {
        guard isHost, state == .preparing, session != nil,
              ledger?.canScheduleStart(active: active, connectedPlayerIDs: Set(participants.filter { $0.status == .connected }.map(\.id))) == true else { return }
        startTime = now + 3; ledger?.acknowledgeStart(localPlayerID); countdown = 3; state = .countdown
        send(.start(startTime!))
    }
    func select(_ index: Int) {
        guard canEdit, (0..<81).contains(index) else { return }
        selection = index
        if let lockedDigit, session?.isEditable(index) == true { enter(lockedDigit) }
    }
    func lockDigit(_ digit: Int) {
        guard canEdit, (1...9).contains(digit) else { return }
        lockedDigit = digit
    }
    func unlockDigit() { lockedDigit = nil }
    func enter(_ digit: Int) {
        guard canEdit, let selection else { return }
        let previousValue = session?.values[selection]
        let previousNotes = session?.notes[selection]
        if notesMode { session?.toggleNote(digit, at: selection) } else { session?.enter(digit, at: selection) }
        let enteredValue = !notesMode && previousValue != session?.values[selection]
        guard enteredValue || previousNotes != session?.notes[selection] else { return }
        changed(simulatePeerProgress: enteredValue)
    }
    func erase() { guard canEdit, let selection else { return }; session?.erase(at: selection); changed() }
    func undo() { guard canEdit else { return }; session?.undo(); changed() }
    private func changed(simulatePeerProgress: Bool = false) {
        guard let game = session else { return }
        boardSummary = BattleBoardSummary(game: game)
        update(localPlayerID) { $0.progress = game.progress; $0.mistakes = game.mistakes }
        #if DEBUG
        if fixture, simulatePeerProgress, ProcessInfo.processInfo.arguments.contains("--uitest-battle-progress") {
            update("peer-fixture") { $0.progress = min(0.95, $0.progress + 0.08) }
        }
        #endif
        if game.isComplete {
            let seconds = max(0, hostNow - (startTime ?? hostNow)); elapsed = seconds
            session?.elapsedSeconds = Int(seconds)
            if fixture { finishFixture(seconds); return }
            if isHost { acceptFinish(player: localPlayerID, values: game.values, seconds: seconds) }
            else { pendingFinish = seconds; lastFinishSent = now; send(.finish(values: game.values, elapsed: seconds)) }
        }
    }
    private func refreshBoardSummary() { boardSummary = session.map(BattleBoardSummary.init(game:)) ?? .empty }
    func setActive(_ value: Bool) {
        if !value, inactiveSince == nil { inactiveSince = now }
        active = value
        if !value { stopLoop?(); stopLoop = nil }
        if value {
            presentPendingInvitation()
            let expired = inactiveSince.map { BattleValidation.interruptionExpired(since: $0, now: now) } ?? false
            inactiveSince = nil
            if expired && [.preparing, .countdown, .playing].contains(state) {
                if isHost { cancel("La connexion avec l’hôte est perdue."); return }
                update(localPlayerID) { if $0.status != .finished { $0.status = .didNotFinish } }
                send(.forfeit); startLoop(); return
            }
            if transport != nil || fixture { startLoop() }
        }
        if state == .lobby {
            update(localPlayerID) { if !value { $0.ready = false }; $0.status = value ? .connected : .interrupted }
            if !value { send(.ready(false)) }
            send(.active(value)); return
        }
        guard [.preparing, .countdown, .playing].contains(state) else { return }
        if [.preparing, .countdown].contains(state) && !value {
            send(.active(false)); cancel("Le départ a été interrompu."); return
        }
        send(.active(value)); update(localPlayerID) { if $0.status == .connected || $0.status == .interrupted { $0.status = value ? .connected : .interrupted } }
        if value { sendProgress() }
    }
    func leave() {
        if !fixture, transport != nil, ![.finished, .cancelled].contains(state) {
            if isHost { send(.cancelled("L’hôte a quitté la partie. Le duel est annulé.")) }
            else { send(.active(false)) }
        }
        cleanup(); state = .idle; session = nil; participants = []; results = []; roundID = nil; selection = nil; lockedDigit = nil; boardSummary = .empty; notesMode = false; errorMessage = nil
    }
    func rematch() {
        guard isHost, state == .finished else { return }
        #if DEBUG
        if fixture { prepareUITestRound(); return }
        #endif
        guard disconnectedPlayers.isEmpty, let transport, transport.peers.count + 1 == participants.count else { errorMessage = "Un ami a quitté le groupe. Créez une nouvelle invitation."; return }
        roundID = UUID(); ledger?.beginRound(roundID!); resetLobby(); startLoop(); send(.lobby)
    }
    private func resetLobby() {
        state = .lobby; results = []; session = nil; startTime = nil; elapsed = 0; selection = nil; notesMode = false; lockedDigit = nil; boardSummary = .empty
        participants.indices.forEach { participants[$0].ready = false; participants[$0].progress = 0; participants[$0].mistakes = 0; participants[$0].status = .connected }
        interrupted = [:]; pendingFinish = nil
    }
    private func cleanup() {
        stopLoop?(); stopLoop = nil; preparation?.cancel(); preparation = nil; generation?.cancel()
        transport?.disconnect(); transport = nil; match = nil
        battleID = nil; hostID = nil; ledger = nil; sequence = 0; preparationStarted = nil; interrupted = [:]; startTime = nil; fixture = false; clockOffset = 0; bestRTT = .infinity; pendingFinish = nil; pendingInvite = nil; disconnectedPlayers = []; receiveBudgets = [:]; inactiveSince = nil
    }
    private func cancel(_ message: String, broadcast: Bool = true) {
        if broadcast && isHost { send(.cancelled(message)) }
        errorMessage = message; cleanup(); state = .cancelled
    }
    private func update(_ id: String, _ mutation: (inout BattleParticipant) -> Void) {
        guard let index = participants.firstIndex(where: { $0.id == id }) else { return }; mutation(&participants[index])
    }
    private func send(_ message: BattleMessage, reliable: Bool = true, to playerID: String? = nil) {
        guard let transport, let battleID, let roundID else { return }
        guard sequence < UInt64.max else { cancel("La partie doit être relancée.", broadcast: false); return }
        sequence += 1
        let packet = BattleEnvelope(battleID: battleID, roundID: roundID, sequence: sequence, message: message)
        do {
            let data = try JSONEncoder().encode(packet)
            guard data.count <= BattleEnvelope.maximumBytes else { cancel("Un message de partie est invalide.", broadcast: false); return }
            try transport.send(data, reliably: reliable, to: playerID)
        } catch { cancel("La connexion de la partie est indisponible.", broadcast: false) }
    }
    private func sendProgress() {
        guard let game = session else { send(.heartbeat, reliable: false); return }
        send(.progress(fraction: game.progress, mistakes: game.mistakes), reliable: false)
    }
    private func startLoop() {
        stopLoop?()
        stopLoop = clock.startTicks { [weak self] in self?.pulse() }
    }
    private func pulse() {
        guard active else { return }
        if state == .finished { return }
        if fixture {
            if state == .countdown, let startTime { updateCountdown(max(0, Int(ceil(startTime - now)))); if now >= startTime { state = .playing } }
            if state == .playing, session?.isComplete == false { elapsed = max(0, now - (startTime ?? now)) }
            return
        }
        if state == .lobby, now - lastHello >= 1 {
            lastHello = now
            if isHost { send(.hello(difficulty: difficulty)); send(.profile(name: localPlayerName, appearance: appearance)) }
            else if battleID != nil { send(.ping(now)) }
        }
        if state == .playing, let pendingFinish, let game = session, now - lastFinishSent >= 1 {
            lastFinishSent = now; send(.finish(values: game.values, elapsed: pendingFinish))
        }
        if now - lastProgress >= 0.5 { lastProgress = now; sendProgress() }
        if state == .countdown, let startTime {
            updateCountdown(max(0, Int(ceil(startTime - hostNow))))
            if hostNow >= startTime {
                if participants.contains(where: { $0.status != .connected }) { cancel("Le départ a été interrompu."); return }
                if isHost, ledger?.allAcknowledged != true { cancel("Le départ n’a pas été confirmé par tous les amis."); return }
                state = .playing
            }
        }
        if state == .preparing, let started = preparationStarted, now - started > 20 { cancel("La préparation du duel a expiré."); return }
        if state == .playing, let startTime {
            if session?.isComplete == false { elapsed = max(0, hostNow - startTime) }
            if hostNow - startTime > 86_400 { cancel("La durée maximale de la partie est dépassée."); return }
        }
        guard [.preparing, .countdown, .playing].contains(state) else { return }
        if !isHost, let hostID, now - (lastHeard[hostID] ?? now) > 30 { cancel("La connexion avec l’hôte est perdue.", broadcast: false); return }
        for player in participants where player.id != localPlayerID && player.status != .finished && player.status != .didNotFinish {
            if now - (lastHeard[player.id] ?? now) > 5, interrupted[player.id] == nil {
                interrupted[player.id] = lastHeard[player.id] ?? now; update(player.id) { $0.status = .interrupted }
            }
            if isHost, let since = interrupted[player.id], BattleValidation.interruptionExpired(since: since, now: now) { recordDidNotFinish(player.id) }
        }
    }
    private func updateCountdown(_ value: Int) {
        guard countdown != value else { return }
        countdown = value
    }

    func receive(_ data: Data, from sender: String) {
        guard participants.contains(where: { $0.id == sender }), data.count <= BattleEnvelope.maximumBytes else { return }
        let identity = sender
        var budget = receiveBudgets[identity] ?? (window: now, count: 0)
        if now - budget.window >= 1 { budget = (now, 0) }
        guard budget.count < 30 else { return }
        budget.count += 1; receiveBudgets[identity] = budget
        let packet: BattleEnvelope
        do { packet = try BattleEnvelope.decode(data) } catch { cancel("Les versions de Lisa ne sont pas compatibles ou un message est invalide.", broadcast: false); return }
        guard ![.idle, .cancelled].contains(state) else { return }
        if battleID == nil {
            guard sender == hostID, case .hello = packet.message else { return }
            battleID = packet.battleID; roundID = packet.roundID
            ledger = BattleRoundLedger(battleID: packet.battleID, roundID: packet.roundID, hostID: sender, playerIDs: Set(participants.map(\.id)))
            send(.profile(name: String(localPlayerName.prefix(80)), appearance: appearance)); send(.ping(now))
        }
        let canAdopt = sender == hostID && [.lobby, .finished].contains(state)
        guard ledger?.admit(packet, sender: sender, mayAdoptHostRound: canAdopt) == true else { return }
        roundID = ledger?.roundID; lastHeard[sender] = now
        switch packet.message {
        case .hello(let level):
            guard sender == hostID, state == .lobby else { return }; difficulty = level
            send(.profile(name: String(localPlayerName.prefix(80)), appearance: appearance))
        case .profile(let name, let look): guard state == .lobby, name.count <= 80 else { return }; update(sender) { $0.name = name; $0.appearance = look }
        case .ready(let value): guard state == .lobby else { return }; update(sender) { $0.ready = value }
        case .difficulty(let level): guard sender == hostID, state == .lobby else { return }; difficulty = level; participants.indices.forEach { participants[$0].ready = false }
        case .puzzle(let puzzle):
            guard sender == hostID, state == .lobby, puzzle.difficulty == difficulty else { return }
            state = .preparing; preparationStarted = now; session = GameSession(puzzle: puzzle); results = []; elapsed = 0; selection = nil; notesMode = false; lockedDigit = nil; refreshBoardSummary()
            send(.loaded)
        case .loaded: guard isHost, state == .preparing else { return }; ledger?.markLoaded(sender); maybeScheduleStart()
        case .ping(let sent): guard isHost, sent.isFinite else { return }; send(.pong(sent: sent, host: now), to: sender)
        case .pong(let sent, let host):
            guard sender == hostID, sent.isFinite, host.isFinite else { return }
            let rtt = now - sent
            guard rtt >= 0, rtt <= 1, rtt < bestRTT, state == .lobby else { return }
            bestRTT = rtt; clockOffset = host - (sent + now) / 2
        case .start(let at):
            guard sender == hostID else { return }
            guard state == .preparing, session != nil, bestRTT.isFinite, at.isFinite, at - hostNow > 1, at - hostNow < 5 else { cancel("La synchronisation du départ a échoué.", broadcast: false); return }
            startTime = at; state = .countdown; countdown = 3; send(.startAcknowledged)
        case .startAcknowledged: guard isHost, state == .countdown else { return }; ledger?.acknowledgeStart(sender)
        case .progress(let fraction, let mistakes):
            guard BattleValidation.validProgress(fraction, mistakes: mistakes), [.countdown, .playing].contains(state) else { return }
            interrupted[sender] = nil
            update(sender) { $0.progress = fraction; $0.mistakes = mistakes; if $0.status == .interrupted { $0.status = .connected } }
        case .active(let value):
            if state == .lobby {
                update(sender) {
                    if !value { $0.ready = false; $0.status = .interrupted }
                    else if $0.status == .interrupted { $0.status = .connected }
                }
                return
            }
            guard [.preparing, .countdown, .playing].contains(state) else { return }
            if !value && [.preparing, .countdown].contains(state) { cancel("Le départ a été interrompu.", broadcast: isHost); return }
            if value { interrupted[sender] = nil; update(sender) { if $0.status == .interrupted { $0.status = .connected } } }
            else { if interrupted[sender] == nil { interrupted[sender] = now }; update(sender) { if $0.status == .connected { $0.status = .interrupted } } }
        case .heartbeat: break
        case .forfeit:
            guard isHost, [.preparing, .countdown, .playing].contains(state) else { return }
            if state != .playing { cancel("Le départ a été interrompu."); return }
            recordDidNotFinish(sender)
        case .finish(let values, let seconds): guard isHost, state == .playing else { return }; acceptFinish(player: sender, values: values, seconds: seconds)
        case .finishAccepted(let result):
            guard sender == hostID, [.playing, .countdown].contains(state), participants.contains(where: { $0.id == result.playerID }), ((result.status == .finished && result.seconds?.isFinite == true && (result.seconds ?? -1) >= 0) || (result.status == .didNotFinish && result.seconds == nil)) else { return }
            if !results.contains(where: { $0.playerID == result.playerID }) { results.append(result) }
            if result.playerID == localPlayerID { pendingFinish = nil }
            update(result.playerID) { $0.status = result.status; if result.status == .finished { $0.progress = 1 } }
        case .results(let final):
            guard sender == hostID, state == .playing, final.count == participants.count, Set(final.map(\.playerID)) == Set(participants.map(\.id)), final.allSatisfy({ ($0.status == .finished && $0.seconds?.isFinite == true && ($0.seconds ?? -1) >= 0) || ($0.status == .didNotFinish && $0.seconds == nil) }) else { return }
            publishFinalResults(final)
        case .cancelled(let reason): guard sender == hostID else { return }; cancel(String(reason.prefix(200)), broadcast: false)
        case .lobby: guard sender == hostID, state == .finished else { return }; resetLobby(); startLoop(); send(.profile(name: String(localPlayerName.prefix(80)), appearance: appearance)); send(.ping(now))
        }
    }
    private func recordDidNotFinish(_ id: String) {
        guard let participant = participants.first(where: { $0.id == id }) else { return }
        if let previous = results.first(where: { $0.playerID == id }) { send(.finishAccepted(previous)); return }
        let result = BattleResult(playerID: id, name: participant.name, seconds: nil, status: .didNotFinish)
        guard ledger?.record(result) == true else { return }
        results = ledger?.results ?? []; update(id) { $0.status = .didNotFinish }; send(.finishAccepted(result)); finalizeIfNeeded()
    }
    private func acceptFinish(player id: String, values: [Int], seconds: Double) {
        guard let puzzle = session?.puzzle, let startTime, let participant = participants.first(where: { $0.id == id }) else { return }
        if let previous = results.first(where: { $0.playerID == id }) { send(.finishAccepted(previous)); return }
        let valid = (participant.status == .connected || participant.status == .interrupted)
            && BattleValidation.validFinish(values: values, puzzle: puzzle, claimedElapsed: seconds, hostElapsed: now - startTime)
        let result = BattleResult(playerID: id, name: participant.name, seconds: valid ? seconds : nil, status: valid ? .finished : .didNotFinish)
        guard ledger?.record(result) == true else { return }
        results = ledger?.results ?? []; update(id) { $0.status = result.status; if valid { $0.progress = 1 } }
        send(.finishAccepted(result)); finalizeIfNeeded()
    }
    private func finalizeIfNeeded() {
        guard isHost, ledger?.isFinalized == true else { return }
        let final = BattleValidation.ranked(results); send(.results(final)); publishFinalResults(final)
    }

    /// Finalization and its business callback do not depend on SwiftUI observing a transition.
    private func publishFinalResults(_ final: [BattleResult]) {
        guard let battleID, let roundID, let hostID, final.count == participants.count else { return }
        var validated = BattleRoundLedger(battleID: battleID, roundID: roundID, hostID: hostID, playerIDs: Set(participants.map(\.id)))
        for result in final { guard validated.record(result) else { return } }
        guard validated.isFinalized else { return }
        results = BattleValidation.ranked(validated.results)
        for result in results { update(result.playerID) { $0.status = result.status; if result.status == .finished { $0.progress = 1 } } }
        // Persist rewards before publishing podium phase, so its first frame sees unlocked items.
        deliverRoundFinished()
        state = .finished; stopLoop?(); stopLoop = nil
    }
    private func deliverRoundFinished() {
        guard let roundID, deliveredRoundID != roundID, let callback = onRoundFinished,
              let local = results.first(where: { $0.playerID == localPlayerID && $0.status == .finished }),
              results.count == participants.count else { return }
        deliveredRoundID = roundID
        callback(roundID, local)
    }

    nonisolated func matchmakerViewControllerWasCancelled(_ controller: GKMatchmakerViewController) {
        Task { @MainActor in controller.dismiss(animated: true); self.leave() }
    }
    nonisolated func matchmakerViewController(_ controller: GKMatchmakerViewController, didFailWithError error: Error) {
        Task { @MainActor in controller.dismiss(animated: true); self.cancel("Les invitations ont échoué. Réessayez.") }
    }
    nonisolated func matchmakerViewController(_ controller: GKMatchmakerViewController, didFind match: GKMatch) {
        // One-shot, lock-protected handoff. Only the main actor consumes the match;
        // the callback never reads it after enqueueing, and no client thread blocks.
        // The unchecked API is limited to this single-consumer mailbox: the
        // producer stops using the payload, extraction clears it under lock,
        // and subsequent application access belongs exclusively to MainActor.
        let pending = OSAllocatedUnfairLock(uncheckedState: Optional(match))
        Task { @MainActor in
            let match = pending.withLockUnchecked { payload in
                defer { payload = nil }
                return payload
            }
            guard let match else { return }
            controller.dismiss(animated: true)
            self.attach(match)
        }
    }
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        let matchID = ObjectIdentifier(match)
        let playerID = player.gamePlayerID
        Task { @MainActor in guard self.match.map(ObjectIdentifier.init) == matchID else { return }; self.receive(data, from: playerID) }
    }
    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        let matchID = ObjectIdentifier(match)
        let playerID = player.gamePlayerID
        let connected = state == .connected
        guard connected || state == .disconnected else { return }
        Task { @MainActor in
            guard self.match.map(ObjectIdentifier.init) == matchID else { return }
            self.connectionChanged(playerID: playerID, connected: connected)
        }
    }
    func connectionChanged(playerID id: String, connected: Bool) {
        guard participants.contains(where: { $0.id == id }) else { return }
        if connected { disconnectedPlayers.remove(id) }
        else { disconnectedPlayers.insert(id) }
        if state == .finished { return }
        if !connected {
            if id == hostID { cancel("La connexion avec l’hôte est perdue.", broadcast: false) }
            else { interrupted[id] = now; update(id) { if $0.status == .connected { $0.status = .interrupted } } }
        } else {
            lastHeard[id] = now
            interrupted[id] = nil; update(id) { if $0.status == .interrupted { $0.status = .connected } }
            send(.active(active)); sendProgress()
        }
    }
    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        let matchID = ObjectIdentifier(match)
        Task { @MainActor in guard self.match.map(ObjectIdentifier.init) == matchID else { return }; self.cancel("Game Center ne peut pas rétablir la connexion.", broadcast: false) }
    }
    nonisolated func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool { true }

    #if DEBUG
    /// Isolated model fixture for control tests; no network or timer.
    func prepareControlsTestRound() {
        leave(); fixture = true; state = .playing
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var givens = solution
        givens[0] = 0; givens[40] = 0
        session = GameSession(puzzle: Puzzle(givens: givens, solution: solution, difficulty: .easy, seed: 42))
        participants = [BattleParticipant(id: localPlayerID, name: "Lisa", appearance: appearance)]
        refreshBoardSummary()
    }

    /// Local UI fixture only; never authenticates, submits or creates a GameKit match.
    func prepareUITestRound() {
        guard ProcessInfo.processInfo.arguments.contains("--uitest-reset"), ProcessInfo.processInfo.arguments.contains("--uitest-battle") else { return }
        leave(); fixture = true; hostID = localPlayerID; battleID = UUID(); roundID = UUID()
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var givens = solution; for index in [0, 40, 80] { givens[index] = 0 }
        session = GameSession(puzzle: Puzzle(givens: givens, solution: solution, difficulty: .easy, seed: 42))
        refreshBoardSummary(); lockedDigit = nil; selection = nil; notesMode = false
        participants = [BattleParticipant(id: localPlayerID, name: "Lisa", appearance: appearance), BattleParticipant(id: "peer-fixture", name: "Ami")]
        if ProcessInfo.processInfo.arguments.contains("--uitest-battle-four") {
            let longNames = ProcessInfo.processInfo.arguments.contains("--uitest-battle-long-names")
            participants[1].name = longNames ? "Camille aux mille tentacules" : "Camille"
            participants.append(BattleParticipant(id: "peer-fixture-2", name: longNames ? "Alexandre des océans scintillants" : "Alex"))
            participants.append(BattleParticipant(id: "peer-fixture-3", name: longNames ? "Dominique et son Poulpi arc-en-ciel" : "Noa"))
        }
        participants.indices.forEach { participants[$0].ready = true }
        startTime = now + 3; state = .countdown; countdown = 3; elapsed = 0; startLoop()
    }
    private func finishFixture(_ seconds: Double) {
        let final = participants.enumerated().map { index, player in BattleResult(playerID: player.id, name: player.name, seconds: seconds + Double(index), status: .finished) }
        publishFinalResults(final)
    }
    #else
    private func finishFixture(_ seconds: Double) {}
    #endif
}
