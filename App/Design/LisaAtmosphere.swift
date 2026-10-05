import SwiftUI

enum LisaJourneyAtmosphere {
    static let names = ["Les jardins guimauve", "La forêt des sucettes", "Le lagon pétillant", "Les sommets givrés", "La voie des étoiles"]
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
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.65).delay(Double(index / 9 + index % 9) * 0.025), value: expanded)
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

/// Lights travel only around the frame, never across a number or a touch target.
struct LisaBoardSparkles: View {
    var body: some View {
        LisaMotionClock { time in
            Canvas { context, size in
                guard time > 0 else { return }
                let w = size.width - 8
                let h = size.height - 8
                let perimeter = 2 * (w + h)
                for index in 0..<8 {
                    let d = (time * 28 + Double(index) * perimeter / 8).truncatingRemainder(dividingBy: perimeter)
                    let point: CGPoint
                    if d < w { point = CGPoint(x: 4 + d, y: 4) }
                    else if d < w + h { point = CGPoint(x: 4 + w, y: 4 + d - w) }
                    else if d < 2 * w + h { point = CGPoint(x: 4 + 2 * w + h - d, y: 4 + h) }
                    else { point = CGPoint(x: 4, y: 4 + perimeter - d) }
                    let star = context.resolve(Text(Image(systemName: "sparkle")).foregroundColor(index.isMultiple(of: 2) ? LisaTheme.yellow : .white).font(.system(size: 10)))
                    context.draw(star, at: point)
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Finite sweeps follow the completed unit; a box receives its own expanding star burst.
struct LisaUnitCelebration: View {
    let units: Set<Int>
    let token: Int
    @State private var started = Date().timeIntervalSinceReferenceDate
    @State private var finished = false
    var body: some View {
        LisaMotionClock(enabled: !units.isEmpty && !finished) { time in
            Canvas { context, size in
                guard !finished else { return }
                let age = time == 0 ? 0 : max(0, time - started)
                let side = size.width / 9
                for unit in units.sorted() {
                    let row = unit < 9
                    let column = (9..<18).contains(unit)
                    let box = unit - 18
                    let rect: CGRect
                    if row { rect = CGRect(x: 1, y: CGFloat(unit) * side + 1, width: size.width - 2, height: side - 2) }
                    else if column { rect = CGRect(x: CGFloat(unit - 9) * side + 1, y: 1, width: side - 2, height: size.height - 2) }
                    else { rect = CGRect(x: CGFloat(box % 3 * 3) * side + 1, y: CGFloat(box / 3 * 3) * side + 1, width: side * 3 - 2, height: side * 3 - 2) }
                    let color = row ? LisaTheme.mint : column ? Color.cyan : LisaTheme.yellow
                    var layer = context
                    layer.opacity = age < 1.7 ? 1 : max(0, (2.4 - age) / 0.7)
                    layer.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(color.opacity(0.13)))
                    layer.stroke(Path(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: 5), with: .color(color), lineWidth: 3)
                    guard time > 0 else { continue }
                    let travel = min(1, age / 1.1)
                    for index in 0..<12 {
                        let phase = Double(index) / 12 * .pi * 2
                        let point: CGPoint
                        if row {
                            point = CGPoint(x: rect.minX + rect.width * travel - Double(index % 4) * 5, y: rect.midY + sin(phase) * side * 0.35)
                        } else if column {
                            point = CGPoint(x: rect.midX + cos(phase) * side * 0.35, y: rect.minY + rect.height * travel - Double(index % 4) * 5)
                        } else {
                            let radius = side * (0.25 + min(1, age / 1.2) * 1.1)
                            point = CGPoint(x: rect.midX + cos(phase + age) * radius, y: rect.midY + sin(phase + age) * radius)
                        }
                        let star = layer.resolve(Text(Image(systemName: "sparkle")).font(.system(size: index.isMultiple(of: 3) ? 16 : 9)).foregroundColor(index.isMultiple(of: 2) ? color : .white))
                        layer.draw(star, at: point)
                    }
                }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .task(id: token) {
            started = Date().timeIntervalSinceReferenceDate
            finished = false
            do { try await Task.sleep(for: .seconds(2.4)) } catch { return }
            finished = true
        }
    }
}
