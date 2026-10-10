/// Exact weights for the existing sixteen eyelid targets. The small fixed cache
/// avoids submitting unchanged zeroes to SceneKit on every animated frame.
public struct PoulpiEyelidWeights: Sendable {
    public static let targetCount = 16
    private var weights = Array(repeating: Float(0), count: targetCount)

    public init() {}

    public mutating func update(closure: Float, apply: (Int, Float) -> Void) {
        guard closure.isFinite else { return }
        let phase = max(0, min(1, closure)) * Float(Self.targetCount)
        let segment = min(Self.targetCount - 1, Int(phase))
        let progress = phase - Float(segment)
        for target in weights.indices {
            let weight = target == segment ? progress : (target == segment - 1 ? 1 - progress : 0)
            guard weights[target] != weight else { continue }
            weights[target] = weight
            apply(target, weight)
        }
    }
}
