import SwiftUI

enum LisaMascotMood: Equatable {
    case idle, happy, thinking, encouraging, sleepy, celebrating, pirouette, wobble, peek, jelly, swim, bow, curious, giggle, rocket, chase, moonwalk, juggle, cloudHide, sneeze, tumble, balance, dizzy, superhero
}

/// A real 3D companion. Every motion is interpolated, with no sprite frames.
struct LisaMascot: View {
    var size: CGFloat = 100
    var celebrating = false
    var mood: LisaMascotMood = .idle
    var reactionToken: Int = 0
    var animationEnabled = true
    @Environment(\.lisaMotionAllowed) private var motionAllowed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false

    var body: some View {
        OctopusSceneView(
            mood: celebrating ? .celebrating : mood,
            reactionToken: reactionToken,
            animated: animationEnabled && motionAllowed && visible && scenePhase == .active && !reduceMotion
        )
        // SceneKit can fail to create a drawable for fractional SwiftUI dimensions.
        // Whole-point bounds keep the live Metal surface reliable at compact sizes.
        .frame(width: ceil(size * 1.15), height: ceil(size * 1.1))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }
}

/// Accessible interaction with a cooldown, including a quiet text response.
struct LisaCompanion: View {
    var size: CGFloat = 100
    var animationEnabled = true
    @EnvironmentObject private var store: LisaStore
    @State private var greeting = 0
    @State private var waving = false
    private let greetings = ["Coucou !", "À votre rythme.", "On joue ensemble ?"]

    var body: some View {
        Button {
            guard !waving else { return }
            greeting += 1
            waving = true
            store.feedback(.hello)
        } label: {
            LisaMascot(size: size, mood: waving ? .happy : .idle, reactionToken: greeting, animationEnabled: animationEnabled)
                .overlay(alignment: .bottom) {
                    if waving {
                        Text(greetings[(greeting - 1) % greetings.count])
                            .font(LisaTheme.body(11)).foregroundStyle(LisaTheme.ink)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(LisaTheme.paper, in: Capsule())
                            .fixedSize().offset(y: 5)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Faire coucou à Lisa")
        .accessibilityValue(waving ? greetings[(greeting - 1) % greetings.count] : "Votre petit compagnon")
        .disabled(!animationEnabled)
        .task(id: greeting) {
            guard waving else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            waving = false
        }
    }
}

/// Two finite confetti fountains, stopped after their last particle lands.
struct LisaCelebration: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date().timeIntervalSinceReferenceDate
    @State private var finished = false
    @ObservedObject private var renderBudget = LisaRenderBudget.shared

    var body: some View {
        LisaMotionClock(enabled: isActive && !finished) { time in
            Canvas { context, size in
                guard isActive, !reduceMotion, !finished, time > 0 else { return }
                let elapsed = max(0, time - started)
                for index in 0..<(renderBudget.particleCount * 3) {
                    let delay = Double(index % 15) * 0.028
                    let age = elapsed - delay
                    guard age >= 0, age < 4 else { continue }
                    let left = index.isMultiple(of: 2)
                    let velocity = 45 + Double((index * 31) % 120)
                    let x = (left ? size.width * 0.05 : size.width * 0.95) + (left ? 1 : -1) * velocity * age
                    let y = size.height * 0.42 - (160 + Double((index * 17) % 180)) * age + 130 * age * age
                    var particle = context
                    particle.opacity = min(1, max(0, (4 - age) / 1.2))
                    particle.translateBy(x: x, y: y)
                    particle.rotate(by: .degrees(age * Double(90 + index * 13)))
                    let width = CGFloat(index.isMultiple(of: 3) ? 9 : 5)
                    let path = Path(roundedRect: CGRect(x: -width / 2, y: -6, width: width, height: 12), cornerRadius: index.isMultiple(of: 4) ? 5 : 1)
                    particle.fill(path, with: .color(colors[index % colors.count]))
                }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .task(id: isActive) {
            guard isActive else { finished = true; return }
            started = Date().timeIntervalSinceReferenceDate
            finished = false
            do { try await Task.sleep(for: .seconds(4.6)) } catch { return }
            finished = true
        }
    }

    private var colors: [Color] { [LisaTheme.coral, LisaTheme.lavender, LisaTheme.mint, LisaTheme.yellow, .white, .cyan] }
}

/// Occasional antics are independent of correctness, including in zen mode.
struct LisaGameCompanion: View {
    let mood: LisaMascotMood
    let reaction: Int
    let active: Bool
    var stageWidth: CGFloat = 160
    @ObservedObject private var renderBudget = LisaRenderBudget.shared
    @EnvironmentObject private var store: LisaStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var antic: LisaMascotMood = .idle
    @State private var token = 0
    @State private var turn = 0
    @State private var lastAntic = Date.distantPast
    @State private var started = Date().timeIntervalSinceReferenceDate
    private var running: Bool { active && !reduceMotion && store.settings.animatedDecor }
    private var message: String {
        switch antic {
        case .chase: return "Reviens, papillon !"
        case .moonwalk: return "Marche arrière !"
        case .juggle: return "Un, deux… oups !"
        case .cloudHide: return "Vous me voyez ?"
        case .sneeze: return "A… a… atchoum !"
        case .tumble: return "Même pas le vertige !"
        case .balance: return "Ça tient… presque !"
        case .dizzy: return "Qui a tourné le décor ?"
        case .superhero: return "Super Poulpe arrive !"
        case .pirouette: return "Tadaaa !"
        case .wobble: return "Huit bras, quel talent !"
        case .peek: return "Coucou !"
        case .jelly: return "Tout mou !"
        case .swim: return "Plouf, plouf !"
        case .bow: return "À votre service !"
        case .curious: return "Oh, par ici !"
        case .giggle: return "Hi hi hi !"
        case .rocket: return "Décollage !"
        default: return ""
        }
    }
    var body: some View {
        Button { perform() } label: {
            LisaMotionClock(enabled: running, fps: 60) { time in
                let age = time == 0 ? 0 : max(0, time - started)
                let progress = min(1, age / 4.4)
                let envelope = pow(sin(progress * .pi), 2)
                let walking = time == 0 ? 0 : sin(time * 0.36) * (stageWidth - 76) * 0.5
                let travel = (antic == .chase || antic == .moonwalk || antic == .superhero) ? sin(progress * .pi * 2) * (stageWidth - 76) * 0.45 : 0
                ZStack {
                    if running && mood == .idle && antic != .idle {
                        LisaStageFireworks(progress: progress, time: age, count: renderBudget.particleCount)
                    }
                    Ellipse().fill(LisaTheme.lavender.opacity(0.18))
                        .frame(width: 43, height: 6).offset(x: walking + travel * 0.2, y: 26)
                    LisaMascot(size: 58, mood: mood == .idle ? antic : mood,
                               reactionToken: reaction + token, animationEnabled: running)
                        .offset(x: walking * (1 - envelope) + travel, y: antic == .superhero ? -envelope * 6 : 0)
                    if mood == .idle && running {
                        LisaComedyProps(antic: antic, time: age, progress: progress)
                            .offset(x: walking * (1 - envelope) + travel)
                    }
                }.frame(width: stageWidth, height: 76)
            }
            .background(Color.clear.contentShape(Rectangle()))
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !message.isEmpty && mood == .idle && running {
                    Text(message).font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(LisaTheme.ink).padding(.horizontal, 6).padding(.vertical, 3)
                        .background(LisaTheme.paper, in: Capsule()).fixedSize().offset(y: 3)
                }
            }
        }
        .buttonStyle(.plain).accessibilityLabel("Faire rire Lisa")
        .accessibilityValue(message.isEmpty ? "Au repos" : message).disabled(!running)
        .task(id: running) {
            guard running else { antic = .idle; return }
            do {
                try await Task.sleep(for: .seconds(10))
                while !Task.isCancelled {
                    if mood == .idle && antic == .idle && Date().timeIntervalSince(lastAntic) >= 18 { perform() }
                    try await Task.sleep(for: .seconds(Int.random(in: 18...28)))
                }
            } catch { return }
        }
        .task(id: token) {
            guard token > 0 else { return }
            do { try await Task.sleep(for: .seconds(4.8)) } catch { return }
            antic = .idle
        }
        .onChange(of: reaction) { _, _ in antic = .idle }
    }
    private func perform() {
        guard running, mood == .idle, antic == .idle else { return }
        let antics: [LisaMascotMood] = [.chase, .moonwalk, .juggle, .cloudHide, .sneeze, .tumble, .balance, .dizzy, .superhero, .pirouette, .wobble, .peek, .jelly, .swim, .bow, .curious, .giggle, .rocket]
        antic = antics[turn % antics.count]
        turn += 1
        lastAntic = Date()
        started = lastAntic.timeIntervalSinceReferenceDate
        token += 1
    }
}

/// Small comic props share the stage clock; no timers, particles or views are accumulated.
private struct LisaComedyProps: View {
    let antic: LisaMascotMood
    let time: Double
    let progress: Double
    var body: some View {
        let envelope = pow(sin(progress * .pi), 2)
        ZStack {
            switch antic {
            case .chase:
                LisaButterfly(time: time, color: LisaTheme.coral)
                    .scaleEffect(0.65).offset(x: cos(time * 2) * 32, y: -20 + sin(time * 3) * 7)
            case .moonwalk:
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "music.note").foregroundStyle(LisaTheme.coral)
                        .font(.system(size: 12)).offset(x: CGFloat(i - 1) * 27, y: -22 + sin(time * 3 + Double(i)) * 6)
                }
            case .juggle:
                ForEach(0..<3, id: \.self) { i in
                    let phase = time * 3 + Double(i) * .pi * 2 / 3
                    Image(systemName: "star.fill").foregroundStyle([LisaTheme.yellow, LisaTheme.coral, LisaTheme.mint][i])
                        .font(.system(size: 13)).rotationEffect(.degrees(time * 120))
                        .offset(x: cos(phase) * 31, y: -8 - abs(sin(phase)) * 25)
                }
            case .cloudHide:
                LisaCloud().frame(width: 87, height: 45).offset(x: sin(time * 2) * 12, y: 7)
                    .opacity(envelope)
            case .sneeze:
                ForEach(0..<6, id: \.self) { i in
                    Image(systemName: "sparkle").foregroundStyle(LisaTheme.yellow)
                        .font(.system(size: 11)).offset(x: cos(Double(i)) * 40 * envelope, y: sin(Double(i)) * 26 * envelope)
                }
            case .balance:
                LisaSweet(color: LisaTheme.coral, rotation: sin(time * 5) * 30)
                    .frame(width: 20, height: 20).offset(x: sin(time * 4) * 12, y: -29)
            case .dizzy:
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "star.fill").foregroundStyle(LisaTheme.yellow).font(.system(size: 10))
                        .offset(x: cos(time * 4 + Double(i) * 2.1) * 25, y: -27 + sin(time * 4 + Double(i) * 2.1) * 5)
                }
            case .superhero:
                Image(systemName: "wind").font(.system(size: 26)).foregroundStyle(.white.opacity(0.8))
                    .offset(x: -36, y: sin(time * 5) * 4)
            default: EmptyView()
            }
        }.opacity(min(1, envelope * 5)).allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// A finite stage-sized burst: light bloom, curved ribbons and orbiting sparks.
/// Drawn on the existing stage clock, never an additional animation loop.
private struct LisaStageFireworks: View {
    let progress: Double
    let time: Double
    let count: Int
    var body: some View {
        Canvas { context, size in
            let envelope = pow(sin(progress * .pi), 2)
            guard envelope > 0.001 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            context.opacity = min(1, envelope * 3)
            let glow = CGRect(x: center.x - 65, y: center.y - 32, width: 130, height: 64)
            context.fill(Path(ellipseIn: glow), with: .radialGradient(Gradient(colors: [LisaTheme.yellow.opacity(0.48), LisaTheme.coral.opacity(0.13), .clear]), center: center, startRadius: 2, endRadius: 66))
            for ribbon in 0..<2 {
                var path = Path()
                for step in 0...24 {
                    let t = Double(step) / 24
                    let x = center.x + (t - 0.5) * min(size.width - 12, 180) * envelope
                    let y = center.y + sin(t * .pi * 2 + time * 2 + Double(ribbon) * .pi) * 24 * envelope
                    if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .linearGradient(Gradient(colors: [.clear, ribbon == 0 ? .cyan : LisaTheme.coral, .white, .clear]), startPoint: CGPoint(x: 0, y: center.y), endPoint: CGPoint(x: size.width, y: center.y)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            for i in 0..<count {
                let angle = Double(i) * 2.39996 + time * (i.isMultiple(of: 2) ? 1 : -0.65)
                let radius = (18 + Double(i % 5) * 9) * envelope
                let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius * 0.5)
                let spark = context.resolve(Text(Image(systemName: i.isMultiple(of: 3) ? "sparkle" : "circle.fill")).font(.system(size: i.isMultiple(of: 3) ? 11 : 3)).foregroundColor(i.isMultiple(of: 2) ? LisaTheme.yellow : .white))
                context.draw(spark, at: point)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
