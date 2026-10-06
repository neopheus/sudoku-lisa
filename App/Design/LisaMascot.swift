import SwiftUI

enum LisaMascotMood: Equatable {
    case idle, happy, thinking, encouraging, sleepy, celebrating, pirouette, wobble, peek, jelly, swim, bow, curious, giggle, rocket, chase, moonwalk, juggle, cloudHide, sneeze, tumble, balance, dizzy, superhero
}

/// Articulated Poulpi sculpt with continuous scene-space movement.
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
    var requestToken: Int = 0
    var occlusionRect = CGRect.zero
    var onMessage: (String) -> Void = { _ in }
    @EnvironmentObject private var store: LisaStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var antic: LisaMascotMood = .idle
    @State private var token = 0
    @State private var turn = 0
    @State private var lastAntic = Date.distantPast
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
        OctopusSceneView(mood: mood == .idle ? antic : mood,
                         reactionToken: reaction + token, animated: running, spatial: true, occlusionRect: occlusionRect)
        .allowsHitTesting(false).accessibilityHidden(true)
        .onChange(of: requestToken) { _, _ in perform() }
        .onChange(of: message, initial: true) { _, value in onMessage(value.isEmpty ? "Au repos" : value) }
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
        token += 1
    }
}
