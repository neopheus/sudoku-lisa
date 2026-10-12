import Foundation

/// Rewards are derived from existing progress, including saves made before the album existed.
public struct JourneyProgress: Equatable, Sendable {
    public let completed: Int
    public init(completed: Int) { self.completed = min(25, max(0, completed)) }
    public var souvenirs: [SceneryStop] { Array(SceneryStop.all.prefix(completed)) }
    public var next: SceneryStop? { SceneryStop.journey(stage: completed + 1) }
    public var latest: SceneryStop? { SceneryStop.journey(stage: completed) }
    public var completedWorlds: Int { completed / 5 }
    public var stepsToNextWorld: Int { completed == 25 ? 0 : 5 - completed % 5 }
    public var nextDifficulty: Difficulty {
        completed == 0 ? .quick : [.easy, .easy, .medium, .hard, .expert][min(completed / 5, 4)]
    }
}
