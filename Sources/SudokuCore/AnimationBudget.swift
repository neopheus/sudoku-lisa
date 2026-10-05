/// Frame-pressure policy independent of UIKit. Reduce detail before reducing cadence.
public struct AnimationBudget: Sendable {
    public private(set) var level = 0
    private var healthyWindows = 0
    public init() {}

    /// Feed a two-second window. Recovery is deliberately slower than degradation.
    public mutating func sample(lateFraction: Double) {
        if lateFraction > 0.15 {
            level = min(2, level + 1)
            healthyWindows = 0
        } else if lateFraction < 0.03 {
            healthyWindows += 1
            if healthyWindows >= 8 {
                level = max(0, level - 1)
                healthyWindows = 0
            }
        } else { healthyWindows = 0 }
    }

    public static func effectiveLevel(measured: Int, lowPower: Bool, hot: Bool) -> Int {
        max(measured, hot ? 2 : lowPower ? 1 : 0)
    }

    public static func frameRate(maximum: Int, level: Int, lowPower: Bool, hot: Bool) -> Int {
        min(maximum, hot ? 30 : lowPower || level >= 2 ? 60 : maximum)
    }
}
