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
        let routeTime = seconds + 0.18 * (1 - cos(phase))
        let rate = 1 + 0.18 * .pi * sin(phase)
        let p = sample(seconds: routeTime)
        let next = sample(seconds: routeTime + 0.08)
        let previous = sample(seconds: routeTime - 0.08)
        let headingChange = atan2(previous.dx * next.dy - previous.dy * next.dx,
                                  previous.dx * next.dx + previous.dy * next.dy)
        return SwimPose(
            pose: Pose(x: p.x, y: p.y, depth: p.depth,
                       dx: p.dx * rate, dy: p.dy * rate, dz: p.dz * rate),
            phase: phase, propulsion: (1 + sin(phase)) / 2,
            braking: max(0, -cos(phase)), turn: max(-1, min(1, headingChange * 5)),
            effort: min(1, sqrt(p.dx * p.dx + p.dy * p.dy + p.dz * p.dz * 0.025) * 4))
    }
    private static let points: [(Double, Double, Double)] = [
        (0, 0.76, -1), (0.72, 0.35, 1.2), (0.68, -0.62, 0),
        (-0.58, -0.72, -1), (-0.74, 0.10, 1.5), (-0.35, 0.32, -5),
        (0.55, 0.58, -3), (0.10, 0.72, 4)
    ]
    public static func sample(seconds: Double) -> Pose {
        let cycle = 32.0
        let phase = ((seconds.truncatingRemainder(dividingBy: cycle) + cycle).truncatingRemainder(dividingBy: cycle)) / 4
        let index = Int(phase)
        let t = phase - Double(index)
        let a = points[(index + 7) % 8], b = points[index], c = points[(index + 1) % 8], d = points[(index + 2) % 8]
        func interpolate(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> (Double, Double) {
            let v = 0.5 * (2*b + (-a+c)*t + (2*a-5*b+4*c-d)*t*t + (-a+3*b-3*c+d)*t*t*t)
            let velocity = 0.125 * ((-a+c) + 2*(2*a-5*b+4*c-d)*t + 3*(-a+3*b-3*c+d)*t*t)
            return (v, velocity)
        }
        let x = interpolate(a.0,b.0,c.0,d.0), y = interpolate(a.1,b.1,c.1,d.1), z = interpolate(a.2,b.2,c.2,d.2)
        return Pose(x:x.0,y:y.0,depth:z.0,dx:x.1,dy:y.1,dz:z.1)
    }
}
