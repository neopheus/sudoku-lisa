import Foundation

public enum PoulpiColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case pink, coral, lavender, lagoon, mint, gold
    public var id: String { rawValue }
}

public enum PoulpiAccessory: String, Codable, CaseIterable, Identifiable, Sendable {
    case none, star, headband, crown
    public var id: String { rawValue }
}

public struct PoulpiAppearance: Codable, Equatable, Hashable, Sendable {
    public var color: PoulpiColor
    public var accessory: PoulpiAccessory
    public init(color: PoulpiColor = .pink, accessory: PoulpiAccessory = .none) {
        self.color = color
        self.accessory = accessory
    }
}

/// Rewards survive eviction of old round receipts. Receipts are bounded, and
/// retries for any retained round cannot award a second win or completion.
public struct PoulpiBattleRewards: Codable, Equatable, Sendable {
    public static let receiptLimit = 256
    public private(set) var finishedRounds: Int
    public private(set) var wins: Int
    public private(set) var recentRoundIDs: [UUID]

    public init() {
        finishedRounds = 0
        wins = 0
        recentRoundIDs = []
    }

    public func isUnlocked(_ accessory: PoulpiAccessory, journeyWins: Int) -> Bool {
        switch accessory {
        case .none: true
        case .star: journeyWins >= 5
        case .headband: finishedRounds >= 1
        case .crown: wins >= 5
        }
    }

    @discardableResult
    public mutating func record(roundID: UUID, won: Bool) -> Bool {
        guard !recentRoundIDs.contains(roundID), finishedRounds < Int.max else { return false }
        finishedRounds += 1
        if won, wins < Int.max { wins += 1 }
        recentRoundIDs.append(roundID)
        if recentRoundIDs.count > Self.receiptLimit {
            recentRoundIDs.removeFirst(recentRoundIDs.count - Self.receiptLimit)
        }
        return true
    }

    private enum CodingKeys: String, CodingKey { case finishedRounds, wins, recentRoundIDs }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        finishedRounds = try c.decode(Int.self, forKey: .finishedRounds)
        wins = try c.decode(Int.self, forKey: .wins)
        recentRoundIDs = try c.decode([UUID].self, forKey: .recentRoundIDs)
        guard finishedRounds >= 0, wins >= 0, wins <= finishedRounds,
              recentRoundIDs.count <= Self.receiptLimit,
              Set(recentRoundIDs).count == recentRoundIDs.count,
              recentRoundIDs.count <= finishedRounds else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid battle rewards"))
        }
    }
}
