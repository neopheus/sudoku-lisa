import Foundation
import CoreGraphics

/// Absolute-time shimmer clock. One closing frame hides the sweep, then the
/// sequence sleeps until the next opening; it never ticks through the idle gap.
public struct ShimmerFrameSequence: Sequence, Sendable {
    public let start: Double
    public let phase: Double
    public let interval: Double
    public init(start: Double, phase: Double, interval: Double) {
        precondition(start.isFinite && phase.isFinite && interval.isFinite && interval > 0)
        self.start = start; self.phase = phase; self.interval = interval
    }
    public func makeIterator() -> Iterator { Iterator(nextTime: start, phase: phase, interval: interval) }
    public struct Iterator: IteratorProtocol {
        var nextTime: Double
        let phase: Double
        let interval: Double
        public mutating func next() -> Double? {
            let time = nextTime
            let periodStart = floor((time + phase) / 5.5) * 5.5 - phase
            // Large absolute timestamps can round the boundary just inside
            // the visible interval. Close on the first representable hidden
            // timestamp so the last drawn sweep cannot remain during dormancy.
            var end = periodStart + 1.6
            while ((end + phase).truncatingRemainder(dividingBy: 5.5) + 5.5)
                .truncatingRemainder(dividingBy: 5.5) < 1.6 {
                end = end.nextUp
            }
            if time < end {
                nextTime = Swift.max(time.nextUp, Swift.min(time + interval, end))
            } else {
                nextTime = periodStart + 5.5
                if nextTime <= time { nextTime = time.nextUp }
                // Ensure floating-point addition reaches the new period.
                while floor((nextTime + phase) / 5.5) * 5.5 - phase <= periodStart {
                    nextTime = nextTime.nextUp
                }
            }
            return time
        }
    }
}

/// Fixed geometry of a celebration; animation only changes ages and transforms.
public struct CelebrationGeometry: Sendable {
    public struct Cell: Sendable {
        public let index: Int
        public let center: CGPoint
        public let delay: Double
        public let rect: CGRect
    }
    public struct Unit: Sendable {
        public let index: Int
        public let rect: CGRect
    }
    public let side: Double
    public let origin: CGPoint
    public let cells: [Cell]
    public let units: [Unit]
    public init(width: Double, cells: Set<Int>, units: Set<Int>, originIndex: Int) {
        let side = width / 9
        let origin = CGPoint(x: (Double(originIndex % 9) + 0.5) * side, y: (Double(originIndex / 9) + 0.5) * side)
        self.side = side; self.origin = origin
        self.cells = cells.sorted().map { index in
            let center = CGPoint(x: (Double(index % 9) + 0.5) * side, y: (Double(index / 9) + 0.5) * side)
            let delay: Double = hypot(Double(center.x - origin.x), Double(center.y - origin.y)) / side * 0.025
            let rect = effectRect(x: Double(center.x) - side / 2 + 2, y: Double(center.y) - side / 2 + 2, width: side - 4, height: side - 4)
            return Cell(index: index, center: center, delay: delay, rect: rect)
        }
        self.units = units.sorted().map { index in
            let rect: CGRect
            if index < 9 { rect = effectRect(x: 1, y: Double(index) * side + 1, width: side * 9 - 2, height: side - 2) }
            else if index < 18 { rect = effectRect(x: Double(index - 9) * side + 1, y: 1, width: side - 2, height: side * 9 - 2) }
            else {
                let box = index - 18
                rect = effectRect(x: Double(box % 3 * 3) * side + 1, y: Double(box / 3 * 3) * side + 1, width: side * 3 - 2, height: side * 3 - 2)
            }
            return Unit(index: index, rect: rect)
        }
    }
}

private func effectRect(x: Double, y: Double, width: Double, height: Double) -> CGRect {
    CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
}
