import Foundation
import SudokuCore
@preconcurrency import GameKit

/// The service owns protocol decisions; transports only deliver encoded packets.
@MainActor
protocol BattleTransport: AnyObject {
    var localPlayerID: String { get }
    var localPlayerName: String { get }
    var peers: [BattleParticipant] { get }
    func send(_ data: Data, reliably: Bool, to playerID: String?) throws
    func disconnect()
}

@MainActor
final class GameKitBattleTransport: BattleTransport {
    private let match: GKMatch
    var localPlayerID: String { GKLocalPlayer.local.gamePlayerID }
    var localPlayerName: String { GKLocalPlayer.local.displayName }
    var peers: [BattleParticipant] {
        match.players.map { BattleParticipant(id: $0.gamePlayerID, name: String($0.displayName.prefix(80))) }
    }
    init(match: GKMatch) { self.match = match }
    func send(_ data: Data, reliably: Bool, to playerID: String?) throws {
        let mode: GKMatch.SendDataMode = reliably ? .reliable : .unreliable
        if let playerID {
            guard let player = match.players.first(where: { $0.gamePlayerID == playerID }) else { throw BattleProtocolError.invalidPacket }
            try match.send(data, to: [player], dataMode: mode)
        } else {
            try match.sendData(toAllPlayers: data, with: mode)
        }
    }
    func disconnect() { match.delegate = nil; match.disconnect() }
}

/// Uptime and ticks share a clock, including when the app suspends and resumes it.
@MainActor
protocol BattleClock: AnyObject {
    var now: Double { get }
    func startTicks(_ tick: @escaping @MainActor () -> Void) -> () -> Void
}

@MainActor
final class SystemBattleClock: BattleClock {
    private var task: Task<Void, Never>?
    deinit { task?.cancel() }
    var now: Double { ProcessInfo.processInfo.systemUptime }
    func startTicks(_ tick: @escaping @MainActor () -> Void) -> () -> Void {
        task?.cancel()
        let task = Task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                tick()
            }
        }
        self.task = task
        return { task.cancel() }
    }
}
