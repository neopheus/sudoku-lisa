import Foundation

/// Converts the looping SceneKit action clock into continuous animation time.
public struct PoulpiAnimationClock: Sendable {
    public static let period: Double = 24
    public private(set) var previousActionTime: Double = 0
    public private(set) var totalTime: Double = 0

    public init() {}

    @discardableResult
    public mutating func advance(actionTime: Double) -> Double {
        guard actionTime.isFinite, actionTime >= 0 else { return 0 }
        let current = min(Self.period, actionTime)
        var elapsed = current - previousActionTime
        if elapsed < 0 { elapsed += Self.period }
        previousActionTime = current
        totalTime += elapsed
        return elapsed
    }
}

public enum PoulpiAnimationTiming {
    /// Fast closing, a fully closed hold, then a gentler opening.
    public static func blink(at time: Double) -> Float {
        guard time.isFinite else { return 0 }
        let phase = ((time.truncatingRemainder(dividingBy: 4) + 4)
            .truncatingRemainder(dividingBy: 4)) - 3.65
        if phase < 0 { return 0 }
        if phase < 0.10 { return smoothstep(Float(phase / 0.10)) }
        if phase < 0.15 { return 1 }
        return 1 - smoothstep(Float((phase - 0.15) / 0.20))
    }

    /// Exponential smoothing preserves response speed across frame rates.
    public static func smoothing(elapsed: Double, timeConstant: Double = 0.13) -> Float {
        guard elapsed > 0, elapsed.isFinite, timeConstant > 0, timeConstant.isFinite else { return 0 }
        return Float(-expm1(-elapsed / timeConstant))
    }

    public static func reactionPhase(elapsed: Double, duration: Double) -> Float {
        guard elapsed.isFinite, duration > 0, duration.isFinite else { return 0 }
        return Float(min(1, max(0, elapsed / duration)))
    }

    /// One impulse shared by the body's sneeze pose and facial expression.
    public static func sneezeImpulse(phase: Float) -> Float {
        guard phase.isFinite, phase > 0.45, phase < 0.65 else { return 0 }
        if phase <= 0.55 { return smoothstep((phase - 0.45) / 0.10) }
        return 1 - smoothstep((phase - 0.55) / 0.10)
    }

    private static func smoothstep(_ value: Float) -> Float {
        let value = min(1, max(0, value))
        return value * value * (3 - 2 * value)
    }
}
