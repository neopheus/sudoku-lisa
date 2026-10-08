import Foundation

public enum BattlePhase: String, Codable, Sendable { case idle, matchmaking, lobby, preparing, countdown, playing, finished, cancelled }
public enum BattlePlayerStatus: String, Codable, Sendable { case connected, interrupted, finished, didNotFinish }
public struct BattleParticipant: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var appearance: PoulpiAppearance
    public var ready = false
    public var progress: Double = 0
    public var mistakes = 0
    public var status: BattlePlayerStatus = .connected
    public init(id: String, name: String, appearance: PoulpiAppearance = .init(color: .pink, accessory: .none)) {
        self.id = id; self.name = name; self.appearance = appearance
    }
}
public struct BattleResult: Codable, Sendable, Equatable, Identifiable {
    public var id: String { playerID }
    public let playerID: String
    public let name: String
    public let seconds: Double?
    public var rank: Int?
    public let status: BattlePlayerStatus
    public init(playerID: String, name: String, seconds: Double?, rank: Int? = nil, status: BattlePlayerStatus) {
        self.playerID = playerID; self.name = name; self.seconds = seconds; self.rank = rank; self.status = status
    }
}
public enum BattleMessage: Codable, Sendable {
    case hello(difficulty: Difficulty)
    case profile(name: String, appearance: PoulpiAppearance)
    case ready(Bool)
    case difficulty(Difficulty)
    case puzzle(Puzzle)
    case loaded
    case ping(Double)
    case pong(sent: Double, host: Double)
    case start(Double)
    case startAcknowledged
    case progress(fraction: Double, mistakes: Int)
    case active(Bool)
    case heartbeat
    case forfeit
    case finish(values: [Int], elapsed: Double)
    case finishAccepted(BattleResult)
    case results([BattleResult])
    case cancelled(String)
    case lobby
}
public struct BattleEnvelope: Codable, Sendable {
    public static let version = 1
    public static let maximumBytes = 32_768
    public let version: Int
    public let battleID: UUID
    public let roundID: UUID
    public let sequence: UInt64
    public let message: BattleMessage
    public init(battleID: UUID, roundID: UUID, sequence: UInt64, message: BattleMessage) {
        version = Self.version; self.battleID = battleID; self.roundID = roundID; self.sequence = sequence; self.message = message
    }
    public static func decode(_ data: Data) throws -> BattleEnvelope {
        guard data.count <= maximumBytes else { throw BattleProtocolError.invalidPacket }
        let result = try JSONDecoder().decode(Self.self, from: data)
        guard result.version == version else { throw BattleProtocolError.incompatibleVersion }
        return result
    }
}
public enum BattleProtocolError: Error { case invalidPacket, incompatibleVersion }
public enum BattleValidation {
    public static func interruptionExpired(since: Double, now: Double) -> Bool {
        since.isFinite && now.isFinite && now >= since && now - since >= 30
    }
    public static func hostID(in ids: [String]) -> String? { ids.sorted().first }
    public static func validProgress(_ fraction: Double, mistakes: Int) -> Bool {
        fraction.isFinite && (0...1).contains(fraction) && (0...100_000).contains(mistakes)
    }
    public static func validFinish(values: [Int], puzzle: Puzzle, claimedElapsed: Double, hostElapsed: Double, tolerance: Double = 2) -> Bool {
        values == puzzle.solution && claimedElapsed.isFinite && hostElapsed.isFinite && claimedElapsed >= 0
            && hostElapsed >= 0 && claimedElapsed <= hostElapsed + tolerance && claimedElapsed <= 86_400
    }
    /// Ties use a group anchored to the first finisher, avoiding transitive tie chains.
    public static func ranked(_ results: [BattleResult]) -> [BattleResult] {
        var sorted = results.sorted {
            if let a = $0.seconds, let b = $1.seconds { return a == b ? $0.playerID < $1.playerID : a < b }
            if $0.seconds != nil { return true }; if $1.seconds != nil { return false }
            return $0.playerID < $1.playerID
        }
        var anchor = -Double.infinity, rank = 0
        for index in sorted.indices {
            guard let seconds = sorted[index].seconds else { sorted[index].rank = nil; continue }
            if seconds - anchor > 0.5 { anchor = seconds; rank = index + 1 }
            sorted[index].rank = rank
        }
        return sorted
    }
}
