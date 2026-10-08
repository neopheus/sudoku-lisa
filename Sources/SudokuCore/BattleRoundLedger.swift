import Foundation

/// Deterministic protocol admission and round lifecycle, independent of GameKit/UI.
public struct BattleRoundLedger: Sendable {
    public let battleID: UUID
    public private(set) var roundID: UUID
    public let hostID: String
    public let playerIDs: Set<String>
    public private(set) var loaded: Set<String> = []
    public private(set) var acknowledged: Set<String> = []
    public private(set) var results: [BattleResult] = []
    private var controlSequences: [String: UInt64] = [:]
    private var liveSequences: [String: UInt64] = [:]
    public init(battleID: UUID, roundID: UUID, hostID: String, playerIDs: Set<String>) {
        self.battleID = battleID; self.roundID = roundID; self.hostID = hostID; self.playerIDs = playerIDs
    }
    public mutating func beginRound(_ id: UUID) {
        roundID = id; loaded = []; acknowledged = []; results = []
        // Packet sequences span the match: old retransmits never become valid on rematch.
    }
    public mutating func admit(_ envelope: BattleEnvelope, sender: String, mayAdoptHostRound: Bool) -> Bool {
        guard (2...4).contains(playerIDs.count), playerIDs.contains(hostID), playerIDs.contains(sender),
              envelope.version == BattleEnvelope.version, envelope.battleID == battleID else { return false }
        let live: Bool
        switch envelope.message { case .progress, .heartbeat: live = true; default: live = false }
        guard envelope.sequence > ((live ? liveSequences[sender] : controlSequences[sender]) ?? 0) else { return false }
        if envelope.roundID != roundID {
            guard sender == hostID, mayAdoptHostRound else { return false }
            switch envelope.message { case .puzzle, .lobby: beginRound(envelope.roundID); default: return false }
        }
        if live { liveSequences[sender] = envelope.sequence } else { controlSequences[sender] = envelope.sequence }
        return true
    }
    public mutating func markLoaded(_ player: String) { if playerIDs.contains(player) { loaded.insert(player) } }
    public mutating func acknowledgeStart(_ player: String) { if playerIDs.contains(player) { acknowledged.insert(player) } }
    public var allLoaded: Bool { loaded == playerIDs }
    public func canScheduleStart(active: Bool, connectedPlayerIDs: Set<String>) -> Bool {
        active && allLoaded && connectedPlayerIDs == playerIDs
    }
    public var allAcknowledged: Bool { acknowledged == playerIDs }
    /// A finisher remains a participant/host until all round outcomes are resolved.
    public var isFinalized: Bool { Set(results.map(\.playerID)) == playerIDs }
    public func completedResult(for playerID: String) -> BattleResult? {
        guard isFinalized else { return nil }
        return BattleValidation.ranked(results).first { $0.playerID == playerID && $0.status == .finished }
    }
    @discardableResult public mutating func record(_ result: BattleResult) -> Bool {
        guard playerIDs.contains(result.playerID), !results.contains(where: { $0.playerID == result.playerID }) else { return false }
        switch result.status {
        case .finished: guard let seconds = result.seconds, seconds.isFinite, (0...86_400).contains(seconds) else { return false }
        case .didNotFinish: guard result.seconds == nil else { return false }
        default: return false
        }
        results.append(result); return true
    }
}
