import Foundation

public enum SceneryWorld: String, Codable, CaseIterable, Sendable {
    case garden, candyForest, lagoon, frost, stars

    public var index: Int { Self.allCases.firstIndex(of: self)! }
    public var title: String { L10n.text(["Les jardins guimauve", "La forêt des sucettes", "Le lagon pétillant", "Les sommets givrés", "La voie des étoiles"][index]) }
    public var musicResource: String { "lisa-world-" + rawValue }
    public var symbol: String { ["leaf.fill", "tree.fill", "water.waves", "snowflake", "star.fill"][index] }
}

/// Stable identifiers are persisted, never translated. The catalogue is shared by scenery and audio.
public struct SceneryStop: Hashable, Sendable, Identifiable {
    public let world: SceneryWorld
    public let index: Int
    public var id: String { "\(world.rawValue)-\(index)" }
    public var title: String { L10n.text(Self.names[world.index][index]) }
    public static let all: [Self] = SceneryWorld.allCases.flatMap { world in (0..<5).map { Self(world: world, index: $0) } }
    private static let names = [
        ["Prairie guimauve", "Fleurs géantes", "Rivière rose", "Jardin suspendu", "Crépuscule fleuri"],
        ["Clairière sucrée", "Bosquet de sucettes", "Pont de bonbons", "Confiserie cachée", "Forêt nocturne"],
        ["Plage pétillante", "Récif de corail", "Grotte turquoise", "Épave aux perles", "Lagon lumineux"],
        ["Vallée givrée", "Forêt enneigée", "Lac de cristal", "Sommet des neiges", "Aurore polaire"],
        ["Orbite douce", "Lune poudrée", "Anneaux célestes", "Nébuleuse mauve", "Constellation de Poulpi"]
    ]
    private init(world: SceneryWorld, index: Int) { self.world = world; self.index = index }
    public init?(id: String) {
        guard let value = Self.all.first(where: { $0.id == id }) else { return nil }
        self = value
    }
    public static func journey(stage: Int) -> Self? {
        guard (1...25).contains(stage) else { return nil }
        return all[stage - 1]
    }
    public static func legacyFree(seed: UInt64) -> Self { all[Int(seed % 25)] }
}

/// Five-world shuffle bag and five bounded visit counters. Looking ahead never advances it.
public struct FreeSceneryRoute: Codable, Sendable {
    private var remaining: [SceneryWorld]
    private var visits: [Int]
    public init(after previous: SceneryStop? = nil) {
        remaining = SceneryWorld.allCases.shuffled()
        visits = Array(repeating: 0, count: 5)
        if let previous {
            visits[previous.world.index] = (previous.index + 1) % 5
            if remaining.first == previous.world { remaining.swapAt(0, 1) }
        }
    }
    public var next: SceneryStop { SceneryStop.all[remaining[0].index * 5 + visits[remaining[0].index]] }
    @discardableResult public mutating func takeNext() -> SceneryStop {
        let stop = next
        remaining.removeFirst()
        visits[stop.world.index] = (stop.index + 1) % 5
        if remaining.isEmpty {
            remaining = SceneryWorld.allCases.shuffled()
            if remaining.first == stop.world { remaining.swapAt(0, 1) }
        }
        return stop
    }
    private enum CodingKeys: CodingKey { case remaining, visits }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        remaining = try c.decode([SceneryWorld].self, forKey: .remaining)
        visits = try c.decode([Int].self, forKey: .visits)
        guard (1...5).contains(remaining.count), Set(remaining).count == remaining.count,
              visits.count == 5, visits.allSatisfy({ (0..<5).contains($0) }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid scenery route"))
        }
    }
}
