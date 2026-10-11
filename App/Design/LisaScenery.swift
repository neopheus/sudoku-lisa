import SwiftUI
import SudokuCore

extension SceneryWorld {
    var tint: Color { [.pink, .mint, .cyan, .purple, .indigo][index] }
    var arrivalMood: LisaMascotMood { [.happy, .juggle, .swim, .moonwalk, .rocket][index] }
    var victoryMood: LisaMascotMood { [.giggle, .juggle, .swim, .happy, .superhero][index] }
}

extension SceneryStop {
    var artworkName: String {
        "SceneryStop" + world.rawValue.prefix(1).uppercased() + world.rawValue.dropFirst() + String(index)
    }
}

/// Individually illustrated far plane and a separate animated near plane.
/// All effects remain behind the opaque game board. Only the small Canvas redraws.
struct LisaScenery: View {
    let stop: SceneryStop
    var animated = true
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(stop.artworkName)
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(1.025)
                // The vignette ties the illustration to the native control palette.
                LinearGradient(colors: [stop.world.tint.opacity(Double(stop.index) * 0.055),
                                        .clear, .indigo.opacity(stop.index == 4 ? 0.28 : 0.06)],
                               startPoint: .top, endPoint: .bottom)
                Color.black.opacity(scheme == .dark ? 0.38 : 0)
                LisaMotionClock(enabled: animated, fps: 30) { time in
                    Canvas { context, size in
                        SceneryAtmosphere.draw(stop: stop, time: time, context: context, size: size)
                    }
                }
            }
            .overlay(alignment: .top) {
                LinearGradient(colors: [LisaTheme.paper.opacity(0.94), LisaTheme.paper.opacity(0.55), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: min(64, geometry.size.height * 0.08))
            }
            .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Deterministic, bounded animation: no per-frame images, random allocation or timers.
enum SceneryAtmosphere {
    static func draw(stop: SceneryStop, time: Double, context: GraphicsContext, size: CGSize) {
        let scale = min(1, max(0.01, size.width / 375))
        var context = context
        context.scaleBy(x: scale, y: scale)
        let size = CGSize(width: size.width / scale, height: size.height / scale)
        let t = time.truncatingRemainder(dividingBy: 3600)
        // Two streams at different depths. The board's central region stays clear.
        for i in 0..<28 {
            let seed = Double(i) * 2.399 + Double(stop.index)
            let cycle = (t * (0.022 + Double(i % 4) * 0.006) + Double(i) / 28).truncatingRemainder(dividingBy: 1)
            let left = i.isMultiple(of: 2)
            let margin = 0.025 + Double(i % 3) * 0.018
            let x = (left ? margin : 1 - margin) * size.width + sin(t * 0.7 + seed) * 8
            let y = (stop.world == .lagoon ? 1 - cycle : cycle) * (size.height + 40) - 20
            let radius = CGFloat(3 + i % 5)
            var c = context
            c.translateBy(x: x, y: y)
            c.opacity = 0.45 + 0.3 * sin(seed + t * 0.8) * sin(seed + t * 0.8)
            switch stop.world {
            case .garden:
                c.rotate(by: .radians(t * 0.55 + seed))
                let petal = Path(ellipseIn: CGRect(x: -radius, y: -radius / 2, width: radius * 2.4, height: radius))
                c.fill(petal, with: .linearGradient(Gradient(colors: [.white, .pink.opacity(0.8)]), startPoint: .zero, endPoint: CGPoint(x: radius, y: radius)))
            case .candyForest:
                c.rotate(by: .radians(sin(t + seed) * 0.5))
                let rect = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
                c.fill(Path(roundedRect: rect, cornerRadius: radius * 0.65), with: .radialGradient(Gradient(colors: [.white, i.isMultiple(of: 3) ? .mint : .pink]), center: CGPoint(x: -radius * 0.4, y: -radius * 0.4), startRadius: 0, endRadius: radius * 2))
            case .lagoon:
                let bubble = Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
                c.fill(bubble, with: .color(.cyan.opacity(0.12)))
                c.stroke(bubble, with: .color(.white.opacity(0.8)), lineWidth: 1)
                c.fill(Path(ellipseIn: CGRect(x: -radius * 0.5, y: -radius * 0.6, width: radius * 0.6, height: radius * 0.35)), with: .color(.white))
            case .frost:
                c.rotate(by: .radians(t * 0.3 + seed))
                var snow = Path()
                for arm in 0..<3 {
                    let angle = Double(arm) * .pi / 3
                    snow.move(to: CGPoint(x: cos(angle) * radius, y: sin(angle) * radius))
                    snow.addLine(to: CGPoint(x: -cos(angle) * radius, y: -sin(angle) * radius))
                }
                c.stroke(snow, with: .color(.white), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            case .stars:
                let pulse = 0.45 + 0.55 * pow(sin(t * 0.8 + seed), 2)
                var star = Path()
                star.move(to: CGPoint(x: 0, y: -radius)); star.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero)
                star.addQuadCurve(to: CGPoint(x: 0, y: radius), control: .zero)
                star.addQuadCurve(to: CGPoint(x: -radius, y: 0), control: .zero)
                star.addQuadCurve(to: CGPoint(x: 0, y: -radius), control: .zero)
                c.scaleBy(x: pulse, y: pulse)
                c.fill(star, with: .color(.yellow))
            }
        }
        // Larger inhabitants travel only along the top and bottom shorelines.
        for i in 0..<3 {
            let phase = t * 0.45 + Double(i) * 2.1
            let x = size.width * (0.15 + Double(i) * 0.34) + sin(phase * 0.6) * 22
            let y = size.height * (i == 1 ? 0.94 : 0.065) + cos(phase) * 9
            var c = context; c.translateBy(x: x, y: y)
            switch stop.world {
            case .garden:
                c.rotate(by: .degrees(sin(phase) * 18))
                let wing = 5 + abs(sin(t * 6 + Double(i))) * 8
                for side in [-1.0, 1.0] {
                    c.fill(Path(ellipseIn: CGRect(x: side < 0 ? -wing : 0, y: -8, width: wing, height: 15)), with: .linearGradient(Gradient(colors: [.white, .pink]), startPoint: .zero, endPoint: CGPoint(x: side * wing, y: -8)))
                }
            case .lagoon where stop.index == 0:
                // Above-water beach: gulls follow the skyline instead of underwater fish.
                let flap = sin(phase * 3) * 5
                var gull = Path(); gull.move(to: CGPoint(x: -12, y: flap))
                gull.addQuadCurve(to: .zero, control: CGPoint(x: -6, y: -5))
                gull.addQuadCurve(to: CGPoint(x: 12, y: flap), control: CGPoint(x: 6, y: -5))
                c.stroke(gull, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            case .lagoon:
                c.scaleBy(x: i == 1 ? -1 : 1, y: 1)
                let fish = Path(ellipseIn: CGRect(x: -10, y: -5, width: 20, height: 10))
                c.fill(fish, with: .linearGradient(Gradient(colors: [.yellow, .orange]), startPoint: CGPoint(x: 0, y: -5), endPoint: CGPoint(x: 0, y: 5)))
                var tail = Path(); tail.move(to: CGPoint(x: -8, y: 0)); tail.addLine(to: CGPoint(x: -17, y: -6 + sin(phase * 4) * 2)); tail.addLine(to: CGPoint(x: -17, y: 6)); tail.closeSubpath()
                c.fill(tail, with: .color(.orange)); c.fill(Path(ellipseIn: CGRect(x: 5, y: -2, width: 2, height: 2)), with: .color(.indigo))
            case .frost:
                var ribbon = Path(); ribbon.move(to: CGPoint(x: -size.width, y: 0))
                ribbon.addCurve(to: CGPoint(x: size.width, y: 0), control1: CGPoint(x: -60, y: -25 + sin(phase) * 20), control2: CGPoint(x: 60, y: 25))
                c.stroke(ribbon, with: .linearGradient(Gradient(colors: [.clear, .mint.opacity(0.3), .pink.opacity(0.3), .clear]), startPoint: CGPoint(x: -size.width / 2, y: 0), endPoint: CGPoint(x: size.width / 2, y: 0)), lineWidth: 14)
            case .stars:
                let flight = (t / 7 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                c.translateBy(x: (flight - 0.5) * size.width, y: flight * 20)
                c.opacity = sin(flight * .pi)
                var trail = Path(); trail.move(to: CGPoint(x: -50, y: 12)); trail.addLine(to: .zero)
                c.stroke(trail, with: .linearGradient(Gradient(colors: [.clear, .white]), startPoint: CGPoint(x: -50, y: 12), endPoint: .zero), lineWidth: 2)
                c.fill(Path(ellipseIn: CGRect(x: -2, y: -2, width: 4, height: 4)), with: .color(.white))
            case .candyForest:
                c.rotate(by: .degrees(sin(phase) * 15))
                c.fill(Path(ellipseIn: CGRect(x: -10, y: -7, width: 20, height: 14)), with: .radialGradient(Gradient(colors: [.white, .pink, .purple]), center: CGPoint(x: -4, y: -3), startRadius: 0, endRadius: 16))
            }
        }
    }
}

struct LisaSceneryIntroduction: View {
    let stop: SceneryStop
    let onSkip: () -> Void
    @EnvironmentObject private var store: LisaStore
    @State private var departed = false

    var body: some View {
        ZStack {
            LisaScenery(stop: stop)
            arrivalArtwork
            ScrollView {
                VStack(spacing: 12) {
                    Text(stop.world.title).font(LisaTheme.body(16))
                    Text(stop.title).font(LisaTheme.heading(30)).multilineTextAlignment(.center)
                        .accessibilityIdentifier("sceneryArrivalTitle")
                    LisaMascot(size: 130, mood: stop.world.arrivalMood, appearance: store.poulpiAppearance)
                        .offset(x: departed && stop.world == .candyForest ? 45 : 0,
                                y: departed && stop.world == .stars ? -24 : 0)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(LisaTheme.ink).padding(24)
                .background(LisaTheme.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 32))
                .overlay(RoundedRectangle(cornerRadius: 32).stroke(.white.opacity(0.6), lineWidth: 1.5))
                .shadow(color: stop.world.tint.opacity(0.25), radius: 24, y: 12)
                .padding(24).padding(.top, 24)
                .frame(maxWidth: 480).frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            LisaButton(title: L10n.text("Jouer maintenant"), icon: "arrow.right", action: onSkip)
                .accessibilityIdentifier("skipSceneryIntroduction")
                .padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
                .background(LisaTheme.paper)
        }
        .accessibilityAddTraits(.isModal)
        .onAppear { withAnimation(.easeInOut(duration: 1.65)) { departed = true } }
    }

    @ViewBuilder private var arrivalArtwork: some View {
        GeometryReader { g in
            switch stop.world {
            case .garden:
                ForEach(0..<6, id: \.self) { i in
                    Ellipse().fill(.pink.opacity(0.35)).frame(width: g.size.width * 0.6, height: g.size.height * 0.32)
                        .rotationEffect(.degrees(Double(i) * 60))
                        .offset(x: cos(Double(i) * .pi / 3) * (departed ? g.size.width : 45),
                                y: sin(Double(i) * .pi / 3) * (departed ? g.size.height : 70))
                        .position(x: g.size.width / 2, y: g.size.height / 2)
                }
            case .candyForest:
                RoundedRectangle(cornerRadius: g.size.width / 2)
                    .trim(from: 0.05, to: 0.95)
                    .stroke(.pink.opacity(0.4), style: StrokeStyle(lineWidth: 25, dash: [24, 15]))
                    .frame(width: g.size.width * 0.7, height: g.size.height * 0.65)
                    .position(x: g.size.width / 2, y: g.size.height * 0.52)
            case .lagoon:
                Ellipse().fill(.cyan.opacity(0.4))
                    .frame(width: g.size.width * 2.5, height: g.size.height * 1.3)
                    .position(x: g.size.width * 0.5, y: g.size.height * (departed ? 1.8 : 0.9))
            case .frost:
                ForEach(0..<12, id: \.self) { i in
                    Image(systemName: "snowflake").font(.system(size: 22)).foregroundStyle(.white.opacity(0.8))
                        .position(x: g.size.width * Double((i * 37 + 9) % 100) / 100,
                                  y: g.size.height * (Double(i % 4) / 4 + (departed ? 0.45 : -0.2)))
                }
            case .stars:
                Image(systemName: "sparkles").font(.system(size: 64)).foregroundStyle(.yellow)
                    .shadow(color: .white, radius: 16)
                    .position(x: g.size.width * (departed ? 0.9 : 0.1), y: g.size.height * (departed ? 0.1 : 0.7))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct LisaSceneryPreview: View {
    let stop: SceneryStop
    var body: some View {
        HStack(spacing: 14) {
            LisaScenery(stop: stop, animated: false).frame(width: 80, height: 70).clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("Prochaine escale")).font(.caption)
                Text(stop.title).font(.headline)
                Text(stop.world.title).font(.caption)
            }.foregroundStyle(LisaTheme.ink)
            Spacer(minLength: 0)
        }.padding(12).background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine).accessibilityIdentifier("nextSceneryPreview")
    }
}
