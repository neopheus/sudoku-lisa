import SudokuCore
import SwiftUI

enum LisaJourneyAtmosphere {
    static var names: [String] { [L10n.text("Les jardins guimauve"), L10n.text("La forêt des sucettes"), L10n.text("Le lagon pétillant"), L10n.text("Les sommets givrés"), L10n.text("La voie des étoiles")] }
    static let symbols = ["leaf.fill", "leaf.fill", "circle", "snowflake", "star.fill"]
    static let colors: [Color] = [.pink, .mint, .cyan, .purple, .indigo]
    static func chapter(_ wins: Int) -> Int { min(max(wins / 5, 0), 4) }
}

/// Layered candy sky: large moving clouds, floating sweets and twinkling stardust.
struct LisaAtmosphere: View {
    var enabled: Bool
    var quiet: Bool
    var chapter: Int?
    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var budget = LisaRenderBudget.shared

    var body: some View {
        LisaMotionClock(enabled: enabled, fps: quiet ? 15 : 30) { time in
            GeometryReader { geometry in
                let w = geometry.size.width
                let h = geometry.size.height
                ZStack {
                    ForEach(0..<(quiet ? 3 : 5), id: \.self) { index in
                        let phase = Double(index) * 1.9
                        let wave = sin(time / (quiet ? 7 : 5) + phase)
                        LisaCloud()
                            .fillStyle(scheme: scheme, foreground: index.isMultiple(of: 2))
                            .frame(width: w * (index.isMultiple(of: 2) ? 0.64 : 0.43), height: w * 0.28)
                            .offset(x: wave * (quiet ? 30 : 52), y: cos(time / 4 + phase) * (quiet ? 2 : 9))
                            .position(x: w * (index.isMultiple(of: 2) ? 0.08 : 0.93), y: h * [0.16, 0.38, 0.69, 0.88, 0.03][index])
                    }
                    ForEach(0..<min(quiet ? 12 : 20, budget.particleCount), id: \.self) { index in
                        let phase = Double(index) * 1.7
                        let drift = sin(time / 2.8 + phase)
                        Image(systemName: symbol(index))
                            .font(.system(size: index.isMultiple(of: 3) ? 19 : 6, weight: .bold))
                            .foregroundStyle(index.isMultiple(of: 4) ? LisaTheme.yellow : .white)
                            .opacity((quiet ? 0.25 : 0.65) + 0.22 * sin(time * 1.4 + phase))
                            .scaleEffect(0.8 + 0.22 * sin(time * 1.4 + phase))
                            .rotationEffect(.degrees(drift * 20))
                            .position(x: quiet ? (index.isMultiple(of: 2) ? 7 : w - 7) : w * CGFloat((index * 37 + 13) % 100) / 100,
                                      y: h * CGFloat((index * 23 + 9) % 95) / 100 + drift * (quiet ? 9 : 18))
                    }
                    ForEach(0..<(budget.level == 2 ? 2 : quiet ? 4 : 6), id: \.self) { index in
                        let phase = Double(index) * 1.8
                        LisaButterfly(time: time == 0 ? 0 : time + phase, color: [LisaTheme.coral, LisaTheme.lavender, Color.orange][index % 3])
                            .scaleEffect(index.isMultiple(of: 2) ? 0.85 : 0.65)
                            .rotationEffect(.degrees(sin(time * 0.8 + phase) * 18))
                            .position(x: w * (index.isMultiple(of: 2) ? 0.12 : 0.88) + sin(time * 0.45 + phase) * 24,
                                      y: h * [0.13, 0.23, 0.88, 0.95, 0.48, 0.72][index] + cos(time * 0.7 + phase) * 18)
                    }
                    ForEach(0..<4, id: \.self) { index in
                        let phase = Double(index) * 2.3
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 12)).foregroundStyle(LisaTheme.mint.opacity(0.65))
                            .rotationEffect(.degrees(sin(time * 0.6 + phase) * 45))
                            .position(x: w * (index.isMultiple(of: 2) ? 0.035 : 0.965) + sin(time * 0.5 + phase) * 7,
                                      y: h * (0.18 + Double(index) * 0.23) + sin(time * 0.4 + phase) * 24)
                    }
                    if !quiet {
                        ForEach(0..<4, id: \.self) { index in
                            let phase = Double(index) * 2.1
                            LisaSweet(color: [LisaTheme.coral, LisaTheme.mint, LisaTheme.lavender, LisaTheme.yellow][index], rotation: time * 12 + phase * 30)
                                .frame(width: index.isMultiple(of: 2) ? 29 : 21, height: index.isMultiple(of: 2) ? 29 : 21)
                                .opacity(scheme == .dark ? 0.5 : 0.72)
                                .rotationEffect(.degrees(sin(time / 3 + phase) * 18))
                                .position(x: w * (index.isMultiple(of: 2) ? 0.045 : 0.955) + sin(time / 4 + phase) * 8,
                                          y: h * [0.30, 0.49, 0.72, 0.91][index] + cos(time / 2 + phase) * 14)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func symbol(_ index: Int) -> String {
        if let chapter, index.isMultiple(of: 2) { return LisaJourneyAtmosphere.symbols[min(max(chapter, 0), 4)] }
        return index.isMultiple(of: 3) ? "sparkle" : "circle.fill"
    }
}

private extension LisaCloud {
    func fillStyle(scheme: ColorScheme, foreground: Bool) -> some View {
        opacity(scheme == .dark ? 0.40 : foreground ? 0.92 : 0.70)
            .shadow(color: LisaTheme.lavender.opacity(scheme == .dark ? 0.05 : 0.14), radius: 12, y: 8)
    }
}

/// A finite sweep across only the cells completed by the last move.
struct LisaGridGlow: View {
    var cells: Set<Int>
    var token: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width / 9
            ForEach(cells.sorted(), id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(LisaTheme.yellow.opacity(expanded ? 0 : 0.55))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(expanded ? 0 : 0.85), lineWidth: 1.5))
                    .frame(width: side - 2, height: side - 2)
                    .position(x: (CGFloat(index % 9) + 0.5) * side, y: (CGFloat(index / 9) + 0.5) * side)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.32).delay(Double(index / 9 + index % 9) * 0.012), value: expanded)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: token) {
            expanded = false
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 450 : 35)) } catch { return }
            expanded = true
        }
    }
}

/// One finite Canvas for the whole move: cell ripples, twin comets and block bursts.
/// Detail scales with load while feedback keeps the display's fast cadence.
struct LisaUnitCelebration: View {
    let units: Set<Int>
    let cells: Set<Int>
    let originIndex: Int
    let token: Int
    @State private var started = Date().timeIntervalSinceReferenceDate
    @State private var finished = false
    @ObservedObject private var budget = LisaRenderBudget.shared

    var body: some View {
        LisaMotionClock(enabled: !cells.isEmpty && !finished, fps: 60) { time in
            Canvas { context, size in
                guard !finished, !cells.isEmpty else { return }
                let age = time == 0 ? 0 : max(0, time - started)
                let side = size.width / 9
                let origin = CGPoint(x: (CGFloat(originIndex % 9) + 0.5) * side,
                                     y: (CGFloat(originIndex / 9) + 0.5) * side)
                drawCells(context, side: side, origin: origin, age: age, animated: time > 0)
                guard time > 0 else { return }
                for unit in units.sorted() {
                    let rect = unitRect(unit, side: side)
                    let color: Color = unit < 9 ? .cyan : unit < 18 ? LisaTheme.mint : LisaTheme.yellow
                    var outline = context
                    outline.opacity = fade(age, hold: 0.38, end: 0.9)
                    let path = Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 6)
                    luminousStroke(path, in: outline, color: color, width: 2.5)
                    if unit < 18 {
                        drawComets(context, rect: rect, origin: origin, horizontal: unit < 9,
                                   side: side, age: age, color: color)
                    } else {
                        drawBlock(context, rect: rect, side: side, age: age, color: color)
                    }
                }
                // A local impact ties simultaneous row / column / block rewards together.
                if units.count > 1 {
                    var combo = context
                    combo.opacity = fade(age, hold: 0.16, end: 0.65)
                    let radius = side * (0.2 + easeOut(age / 0.55) * 1.15)
                    let ring = Path(ellipseIn: CGRect(x: origin.x - radius, y: origin.y - radius,
                                                     width: radius * 2, height: radius * 2))
                    luminousStroke(ring, in: combo, color: LisaTheme.coral, width: 2)
                    burst(context, at: origin, age: age, reach: side * 1.4,
                          color: LisaTheme.coral, count: min(12, budget.particleCount))
                }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .task(id: token) {
            started = Date().timeIntervalSinceReferenceDate
            finished = false
            do { try await Task.sleep(for: .seconds(1.15)) } catch { return }
            finished = true
        }
    }

    private func drawCells(_ context: GraphicsContext, side: Double, origin: CGPoint, age: Double, animated: Bool) {
        for cell in cells.sorted() {
            let center = CGPoint(x: (Double(cell % 9) + 0.5) * side, y: (Double(cell / 9) + 0.5) * side)
            let delay = hypot(center.x - origin.x, center.y - origin.y) / side * 0.025
            let local = animated ? age - delay : 0
            guard local >= 0 else { continue }
            var layer = context
            layer.opacity = animated ? fade(local, hold: 0.12, end: 0.65) : 0.65
            let rect = CGRect(x: center.x - side / 2 + 2, y: center.y - side / 2 + 2, width: side - 4, height: side - 4)
            let path = Path(roundedRect: rect, cornerRadius: 5)
            layer.fill(path, with: .color(LisaTheme.yellow.opacity(0.18)))
            layer.stroke(path, with: .color(LisaTheme.yellow), lineWidth: 1.5)
            if animated {
                // Small glints sit on cell corners, leaving every digit unobstructed.
                LisaFXGeometry.spark(in: layer, at: CGPoint(x: rect.maxX, y: rect.minY),
                                     radius: 3 + 3 * sin(min(1, local / 0.65) * .pi),
                                     rotation: local * 4, color: .white)
            }
        }
    }

    private func drawComets(_ context: GraphicsContext, rect: CGRect, origin: CGPoint,
                            horizontal: Bool, side: Double, age: Double, color: Color) {
        let start = horizontal ? origin.x : origin.y
        let low = horizontal ? rect.minX : rect.minY
        let high = horizontal ? rect.maxX : rect.maxY
        let travel = easeOut(age / 0.4)
        // Two heads launch from the placed digit along both edges of the unit.
        for end in [low, high] {
            let head = start + (end - start) * travel
            let tail = start + (end - start) * easeOut(max(0, age - 0.10) / 0.4)
            var comet = context
            comet.opacity = fade(age, hold: 0.36, end: 0.55)
            for edge in [horizontal ? rect.minY + 2 : rect.minX + 2,
                         horizontal ? rect.maxY - 2 : rect.maxX - 2] {
                let point = CGPoint(x: horizontal ? head : edge, y: horizontal ? edge : head)
                var path = Path()
                path.move(to: CGPoint(x: horizontal ? tail : edge, y: horizontal ? edge : tail))
                path.addLine(to: point)
                luminousStroke(path, in: comet, color: color, width: 3)
                LisaFXGeometry.spark(in: comet, at: point, radius: 6, rotation: age * 9, color: .white)
            }
            let impact = CGPoint(x: horizontal ? end : rect.midX, y: horizontal ? rect.midY : end)
            burst(context, at: impact, age: age - 0.32, reach: side * 0.8,
                  color: color, count: min(10, budget.particleCount))
        }
    }

    private func drawBlock(_ context: GraphicsContext, rect: CGRect, side: Double, age: Double, color: Color) {
        var wave = context
        wave.opacity = fade(age, hold: 0.22, end: 0.75)
        let expansion = easeOut(age / 0.55) * side * 0.25
        let ring = Path(roundedRect: rect.insetBy(dx: -expansion, dy: -expansion), cornerRadius: 7 + expansion)
        luminousStroke(ring, in: wave, color: color, width: 2.5)
        // Corner fireworks give the 3x3 a square silhouette rather than a generic circle.
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)]
        for (index, corner) in corners.enumerated() {
            burst(context, at: corner, age: age - 0.06 - Double(index) * 0.035,
                  reach: side * 0.72, color: color, count: max(4, min(8, budget.particleCount / 2)))
        }
    }

    private func burst(_ context: GraphicsContext, at origin: CGPoint, age: Double,
                       reach: Double, color: Color, count: Int) {
        guard age >= 0, age < 0.72 else { return }
        let travel = easeOut(age / 0.72)
        var layer = context
        layer.opacity = min(1, age / 0.035) * fade(age, hold: 0.28, end: 0.72)
        for index in 0..<count {
            let angle = Double(index) / Double(count) * .pi * 2 + .pi / 8
            let distance = reach * travel * (index.isMultiple(of: 2) ? 1 : 0.7)
            let point = CGPoint(x: origin.x + cos(angle) * distance, y: origin.y + sin(angle) * distance + age * age * 12)
            LisaFXGeometry.spark(in: layer, at: point,
                                 radius: (index.isMultiple(of: 3) ? 8 : 4.5) * (1 - travel * 0.55),
                                 rotation: angle + age * 5, color: index.isMultiple(of: 3) ? .white : color)
        }
    }

    private func luminousStroke(_ path: Path, in context: GraphicsContext, color: Color, width: Double) {
        context.stroke(path, with: .color(color.opacity(0.16)), style: StrokeStyle(lineWidth: width * 4, lineCap: .round))
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width * 2, lineCap: .round))
        context.stroke(path, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: width * 0.55, lineCap: .round))
    }

    private func easeOut(_ value: Double) -> Double { 1 - pow(1 - min(1, max(0, value)), 3) }
    private func fade(_ age: Double, hold: Double, end: Double) -> Double { 1 - min(1, max(0, (age - hold) / (end - hold))) }

    private func unitRect(_ unit: Int, side: Double) -> CGRect {
        if unit < 9 { return CGRect(x: 1, y: Double(unit) * side + 1, width: side * 9 - 2, height: side - 2) }
        if unit < 18 { return CGRect(x: Double(unit - 9) * side + 1, y: 1, width: side - 2, height: side * 9 - 2) }
        let box = unit - 18
        return CGRect(x: Double(box % 3 * 3) * side + 1, y: Double(box / 3 * 3) * side + 1, width: side * 3 - 2, height: side * 3 - 2)
    }
}
