import Foundation

/// Closed, C1-continuous 3D flight in normalized screen coordinates plus world depth.
public enum CompanionFlight {
    public struct Pose: Sendable {
        public let x: Double
        public let y: Double
        public let depth: Double
        public let dx: Double
        public let dy: Double
        public let dz: Double
    }
    /// The same clock drives the route, arm stroke and mantle contraction.
    public struct SwimPose: Sendable {
        public let pose: Pose
        public let phase: Double
        public let propulsion: Double
        public let braking: Double
        public let turn: Double
        public let effort: Double
    }
    public static func swimming(seconds: Double) -> SwimPose {
        let phase = seconds * .pi
        // Integrate a positive speed multiplier: a push followed by a glide.
        // Sixteen complete strokes close exactly at the 32-second route seam.
        let sine = sin(phase), cosine = cos(phase)
        let routeTime = seconds + 0.18 * (1 - cosine)
        let rate = 1 + 0.18 * .pi * sine
        let p = sample(seconds: routeTime)
        // Turning only needs the two planar tangents, not two complete 3D poses.
        let next = tangent(seconds: routeTime + 0.08)
        let previous = tangent(seconds: routeTime - 0.08)
        let headingChange = atan2(previous.x * next.y - previous.y * next.x,
                                  previous.x * next.x + previous.y * next.y)
        return SwimPose(
            pose: Pose(x: p.x, y: p.y, depth: p.depth,
                       dx: p.dx * rate, dy: p.dy * rate, dz: p.dz * rate),
            phase: phase, propulsion: (1 + sine) / 2,
            braking: max(0, -cosine), turn: max(-1, min(1, headingChange * 5)),
            effort: min(1, sqrt(p.dx * p.dx + p.dy * p.dy + p.dz * p.dz * 0.025) * 4))
    }
    private static let points: [(Double, Double, Double)] = [
        (0, 0.76, -1), (0.72, 0.35, 1.2), (0.68, -0.62, 0),
        (-0.58, -0.72, -1), (-0.74, 0.10, 1.5), (-0.35, 0.32, -5),
        (0.55, 0.58, -3), (0.10, 0.72, 4)
    ]
    /// Eight immutable cubic segments; no allocation or coefficient construction per frame.
    private struct Cubic: Sendable {
        let a: Double, b: Double, c: Double, d: Double
        init(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double) {
            a = 0.5 * (-p0 + 3*p1 - 3*p2 + p3)
            b = 0.5 * (2*p0 - 5*p1 + 4*p2 - p3)
            c = 0.5 * (-p0 + p2)
            d = p1
        }
        func position(_ t: Double) -> Double { ((a*t + b)*t + c)*t + d }
        func velocity(_ t: Double) -> Double { ((3*a*t + 2*b)*t + c) / 4 }
    }
    private struct Segment: Sendable {
        let x: Cubic, y: Cubic, z: Cubic
    }
    private static let segments: [Segment] = (0..<8).map { index in
        let a = points[(index + 7) % 8], b = points[index]
        let c = points[(index + 1) % 8], d = points[(index + 2) % 8]
        return Segment(x: Cubic(a.0, b.0, c.0, d.0), y: Cubic(a.1, b.1, c.1, d.1), z: Cubic(a.2, b.2, c.2, d.2))
    }
    private static func segment(seconds: Double) -> (curve: Segment, t: Double) {
        let phase = ((seconds.truncatingRemainder(dividingBy: 32) + 32).truncatingRemainder(dividingBy: 32)) / 4
        let index = Int(phase)
        return (segments[index], phase - Double(index))
    }
    private static func tangent(seconds: Double) -> (x: Double, y: Double) {
        let (curve, t) = segment(seconds: seconds)
        return (curve.x.velocity(t), curve.y.velocity(t))
    }
    public static func sample(seconds: Double) -> Pose {
        let (curve, t) = segment(seconds: seconds)
        return Pose(x: curve.x.position(t), y: curve.y.position(t), depth: curve.z.position(t),
                    dx: curve.x.velocity(t), dy: curve.y.velocity(t), dz: curve.z.velocity(t))
    }
}
