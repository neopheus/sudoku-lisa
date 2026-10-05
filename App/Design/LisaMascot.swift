import SwiftUI

enum LisaMascotMood: Equatable {
    case idle, happy, thinking, encouraging, sleepy
}

/// A real 3D companion. Every motion is interpolated, with no sprite frames.
struct LisaMascot: View {
    var size: CGFloat = 100
    var celebrating = false
    var mood: LisaMascotMood = .idle
    var reactionToken: Int = 0
    var animationEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false

    var body: some View {
        OctopusSceneView(
            mood: celebrating ? .happy : mood,
            reactionToken: reactionToken,
            animated: animationEnabled && visible && scenePhase == .active && !reduceMotion
        )
        .frame(width: size * 1.15, height: size * 1.1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { visible = true }
        .onDisappear { visible = false }
    }
}

/// Deterministic, finite confetti: no images, particle engine or persistent timers.
struct LisaCelebration: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    var body: some View {
        GeometryReader { geometry in
            if isActive && !reduceMotion {
                ForEach(0..<28, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors[index % colors.count])
                        .frame(width: index.isMultiple(of: 3) ? 9 : 5, height: 12)
                        .rotationEffect(.degrees(expanded ? Double(index * 73) : 0))
                        .position(
                            x: expanded ? geometry.size.width * CGFloat((index * 37) % 101) / 100 : geometry.size.width / 2,
                            y: expanded ? geometry.size.height * CGFloat(20 + (index * 19) % 80) / 100 : geometry.size.height * 0.2
                        )
                        .opacity(expanded ? 0 : 1)
                        .animation(.easeOut(duration: 2.4).delay(Double(index % 5) * 0.035), value: expanded)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: isActive, initial: true) { _, active in
            expanded = false
            if active {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    guard !Task.isCancelled else { return }
                    expanded = true
                }
            }
        }
    }

    private var colors: [Color] { [LisaTheme.coral, LisaTheme.lavender, LisaTheme.mint, LisaTheme.yellow] }
}
