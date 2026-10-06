import SudokuCore
import SwiftUI

enum LisaMascotMood: String, CaseIterable, Identifiable {
    var id: String { rawValue }
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
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    var size: CGFloat = 100
    var animationEnabled = true
    @EnvironmentObject private var store: LisaStore
    @State private var greeting = 0
    @State private var waving = false
    private var greetings: [String] { [L10n.text("Coucou !"), L10n.text("À votre rythme."), L10n.text("On joue ensemble ?")] }

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
        .buttonStyle(LisaPressStyle())
        .accessibilityLabel(L10n.text("Faire coucou à Lisa"))
        .accessibilityValue(waving ? greetings[(greeting - 1) % greetings.count] : L10n.text("Votre petit compagnon"))
        .disabled(!animationEnabled)
        .task(id: greeting) {
            guard waving else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            waving = false
        }
    }
}

/// A brief radial impact followed by two fast confetti fountains.
struct LisaCelebration: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date().timeIntervalSinceReferenceDate
    @State private var finished = false
    @ObservedObject private var renderBudget = LisaRenderBudget.shared

    var body: some View {
        LisaMotionClock(enabled: isActive && !finished, fps: 60) { time in
            Canvas { context, size in
                guard isActive, !reduceMotion, !finished, time > 0 else { return }
                let elapsed = max(0, time - started)
                let center = CGPoint(x: size.width * 0.5, y: min(220, size.height * 0.3))
                if elapsed < 0.65 {
                    let impact = 1 - pow(1 - elapsed / 0.65, 3)
                    let radius = 24 + impact * size.width * 0.65
                    var ring = context
                    ring.opacity = pow(1 - elapsed / 0.65, 2)
                    ring.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                      width: radius * 2, height: radius * 2)),
                                with: .color(LisaTheme.yellow), lineWidth: 5 * (1 - impact) + 1)
                }
                for index in 0..<renderBudget.particleCount {
                    let age = elapsed - Double(index % 3) * 0.045
                    guard age >= 0, age < 1.1 else { continue }
                    let angle = Double(index) / Double(renderBudget.particleCount) * .pi * 2
                    let distance = (1 - pow(1 - min(1, age / 0.9), 3)) * size.width * 0.62
                    var spark = context
                    spark.opacity = pow(max(0, 1 - age / 1.1), 1.5)
                    LisaFXGeometry.spark(in: spark,
                                         at: CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance),
                                         radius: index.isMultiple(of: 3) ? 12 : 6,
                                         rotation: angle + age * 4,
                                         color: index.isMultiple(of: 2) ? LisaTheme.yellow : .white)
                }
                for index in 0..<(renderBudget.particleCount * 4) {
                    let delay = Double(index % 12) * 0.012
                    let age = elapsed - delay
                    guard age >= 0, age < 2.2 else { continue }
                    let left = index.isMultiple(of: 2)
                    let velocity = (0.24 + Double((index * 31) % 100) / 250) * size.width
                    let x = (left ? size.width * 0.05 : size.width * 0.95) + (left ? 1 : -1) * velocity * age
                    let y = size.height * 0.42 - (300 + Double((index * 17) % 220)) * age + 340 * age * age
                    var particle = context
                    particle.opacity = min(1, max(0, (2.2 - age) / 0.65))
                    particle.translateBy(x: x, y: y)
                    particle.rotate(by: .degrees(age * Double(90 + index * 13)))
                    let width = CGFloat(index.isMultiple(of: 3) ? 9 : 5)
                    let path = Path(roundedRect: CGRect(x: -width / 2, y: -6, width: width, height: 12), cornerRadius: index.isMultiple(of: 4) ? 5 : 1)
                    if index.isMultiple(of: 3) {
                        LisaFXGeometry.spark(in: particle, at: .zero, radius: 7, color: colors[index % colors.count])
                    } else {
                        particle.scaleBy(x: 0.35 + abs(cos(age * 9 + Double(index))) * 0.65, y: 1)
                        particle.fill(path, with: .color(colors[index % colors.count]))
                    }
                }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
        .task(id: isActive) {
            guard isActive else { finished = true; return }
            started = Date().timeIntervalSinceReferenceDate
            finished = false
            do { try await Task.sleep(for: .seconds(2.4)) } catch { return }
            finished = true
        }
    }

    private var colors: [Color] { [LisaTheme.coral, LisaTheme.lavender, LisaTheme.mint, LisaTheme.yellow, .white, .cyan] }
}

/// Occasional antics are independent of correctness, including in zen mode.
struct LisaGameCompanion: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
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
        case .chase: return L10n.text("Reviens, papillon !")
        case .moonwalk: return L10n.text("Marche arrière !")
        case .juggle: return L10n.text("Un, deux… oups !")
        case .cloudHide: return L10n.text("Vous me voyez ?")
        case .sneeze: return L10n.text("A… a… atchoum !")
        case .tumble: return L10n.text("Même pas le vertige !")
        case .balance: return L10n.text("Ça tient… presque !")
        case .dizzy: return L10n.text("Qui a tourné le décor ?")
        case .superhero: return L10n.text("Super Poulpe arrive !")
        case .pirouette: return L10n.text("Tadaaa !")
        case .wobble: return L10n.text("Huit bras, quel talent !")
        case .peek: return L10n.text("Coucou !")
        case .jelly: return L10n.text("Tout mou !")
        case .swim: return L10n.text("Plouf, plouf !")
        case .bow: return L10n.text("À votre service !")
        case .curious: return L10n.text("Oh, par ici !")
        case .giggle: return L10n.text("Hi hi hi !")
        case .rocket: return L10n.text("Décollage !")
        default: return ""
        }
    }
    var body: some View {
        OctopusSceneView(mood: mood == .idle ? antic : mood,
                         reactionToken: reaction + token, animated: running, spatial: true, occlusionRect: occlusionRect)
        .allowsHitTesting(false).accessibilityHidden(true)
        .onChange(of: requestToken) { _, _ in perform() }
        .onChange(of: message, initial: true) { _, value in onMessage(value.isEmpty ? L10n.text("Au repos") : value) }
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
