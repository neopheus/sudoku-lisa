import Foundation

/// Version 1 remains compatible with snapshots sent before appearance syncing.
public struct WatchProgressSnapshot: Equatable, Sendable {
    public let completedGames: Int
    public let currentStreak: Int
    public let updatedAt: Date
    public let appearance: PoulpiAppearance

    public var context: [String: Any] {
        ["lisaProgressVersion": 1, "completedGames": completedGames,
         "currentStreak": currentStreak, "updatedAt": updatedAt.timeIntervalSince1970,
         "poulpiColor": appearance.color.rawValue, "poulpiAccessory": appearance.accessory.rawValue]
    }

    public init?(context: [String: Any]) {
        guard let version = context["lisaProgressVersion"] as? Int, version == 1,
              let games = context["completedGames"] as? Int, games >= 0,
              let streak = context["currentStreak"] as? Int, streak >= 0,
              let timestamp = context["updatedAt"] as? Double, timestamp.isFinite, timestamp > 0 else { return nil }
        completedGames = games
        currentStreak = streak
        updatedAt = Date(timeIntervalSince1970: timestamp)
        appearance = PoulpiAppearance(
            color: (context["poulpiColor"] as? String).flatMap(PoulpiColor.init(rawValue:)) ?? .pink,
            accessory: (context["poulpiAccessory"] as? String).flatMap(PoulpiAccessory.init(rawValue:)) ?? .none
        )
    }
}
