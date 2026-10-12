import Foundation

/// Local, bounded counters. No puzzle, account, device identifier or free text is recorded.
public enum PlayStudyEvent: String, Codable, CaseIterable, Sendable {
    case appActive, firstJourneySelected, gameStarted, gameResumed, firstMove
    case gameCompleted, hintViewed, hintExplained, hintApplied, souvenirViewed
}

public struct PlayStudy: Codable, Sendable {
    public static let windowDays = 90
    public private(set) var enabled = true
    public private(set) var recordingInterrupted = false
    public let startedAt: Date
    public let existingPlayer: Bool
    public private(set) var days: [Int: [String: Int]] = [:]

    public init(now: Date = Date(), existingPlayer: Bool) {
        self.startedAt = now
        self.existingPlayer = existingPlayer
    }

    public func dayOffset(at date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: startedAt),
                                       to: calendar.startOfDay(for: date)).day ?? 0
    }

    public mutating func setEnabled(_ value: Bool) {
        if !value { recordingInterrupted = true }
        enabled = value
    }

    public mutating func record(_ event: PlayStudyEvent, at date: Date = Date()) {
        let day = dayOffset(at: date)
        guard enabled, (0..<Self.windowDays).contains(day) else { return }
        let count = days[day]?[event.rawValue] ?? 0
        days[day, default: [:]][event.rawValue] = min(1_000_000, count + 1)
    }

    public func count(_ event: PlayStudyEvent) -> Int {
        days.values.reduce(0) { $0 + ($1[event.rawValue] ?? 0) }
    }

    private enum CodingKeys: CodingKey { case enabled, recordingInterrupted, startedAt, existingPlayer, days }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decode(Bool.self, forKey: .enabled)
        recordingInterrupted = try c.decodeIfPresent(Bool.self, forKey: .recordingInterrupted) ?? !enabled
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        existingPlayer = try c.decode(Bool.self, forKey: .existingPlayer)
        days = try c.decode([Int: [String: Int]].self, forKey: .days)
        guard startedAt.timeIntervalSinceReferenceDate.isFinite,
              days.count <= Self.windowDays,
              days.allSatisfy({ day, counts in
                  (0..<Self.windowDays).contains(day) && counts.count <= PlayStudyEvent.allCases.count &&
                  counts.allSatisfy { PlayStudyEvent(rawValue: $0.key) != nil && (1...1_000_000).contains($0.value) }
              }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid play study"))
        }
    }
}
