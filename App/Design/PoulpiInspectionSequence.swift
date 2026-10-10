#if DEBUG
import SwiftUI
import SudokuCore

/// Explicit QA launch only. Same renderer and expressions as the app, without
/// the ambient random-expression scheduler or the old swimming preview override.
struct PoulpiInspectionStep {
    let mood: LisaMascotMood
    let yaw: Double
    var duration: Double { max(4.2, mood.reactionDuration + 0.5) }

    static let reference = LisaMascotMood.allCases.flatMap { mood in
        [0.0, -0.45, 0.45].map { PoulpiInspectionStep(mood: mood, yaw: $0) }
    }
}

struct PoulpiInspectionSequenceView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var replay = 0
    @State private var paused = false
    @State private var slow = false
    @State private var visible = false
    private var step: PoulpiInspectionStep { PoulpiInspectionStep.reference[index] }
    private var active: Bool { visible && scenePhase == .active && !reduceMotion }
    private var speed: Double { slow ? 0.35 : 1 }
    private struct Run: Hashable {
        let index: Int, replay: Int
        let running: Bool, slow: Bool
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(step.mood.title).font(.title2.bold())
                Text("\(index + 1)/\(PoulpiInspectionStep.reference.count) · yaw \(step.yaw, specifier: "%.2f")")
                    .monospacedDigit().accessibilityIdentifier("poulpiInspectionStep")
                portrait(size: 280)
                portrait(size: 72)
                HStack {
                    Button { advance(-1) } label: { Image(systemName: "backward.end.fill") }
                        .accessibilityLabel(L10n.text("Précédent"))
                        .accessibilityIdentifier("poulpiInspectionPrevious")
                    Button { paused.toggle() } label: { Image(systemName: paused ? "play.fill" : "pause.fill") }
                        .accessibilityLabel(paused ? L10n.text("Reprendre l’animation") : L10n.text("Mettre l’animation en pause"))
                        .accessibilityIdentifier("poulpiInspectionPause")
                    Button { advance(1) } label: { Image(systemName: "forward.end.fill") }
                        .accessibilityLabel(L10n.text("Suivant"))
                        .accessibilityIdentifier("poulpiInspectionNext")
                }.buttonStyle(.bordered).controlSize(.large)
                Button(L10n.text("Rejouer l’animation")) { replay += 1; paused = false }
                Toggle(L10n.text("Ralenti"), isOn: $slow)
            }.padding().frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .task(id: Run(index: index, replay: replay, running: active && !paused, slow: slow)) {
            guard active && !paused else { return }
            do { try await Task.sleep(for: .seconds(step.duration / speed)) }
            catch { return }
            guard !Task.isCancelled else { return }
            if index + 1 < PoulpiInspectionStep.reference.count { index += 1 }
            else { paused = true }
        }
    }

    private func portrait(size: CGFloat) -> some View {
        OctopusSceneView(mood: step.mood, reactionToken: index + replay * PoulpiInspectionStep.reference.count,
                         animated: active, interactivePortrait: true, yaw: step.yaw,
                         playbackPaused: paused, playbackSpeed: speed)
            .frame(width: size, height: size)
            .accessibilityLabel(step.mood.title)
    }

    private func advance(_ offset: Int) {
        index = (index + offset + PoulpiInspectionStep.reference.count) % PoulpiInspectionStep.reference.count
        paused = false
    }
}
#endif
