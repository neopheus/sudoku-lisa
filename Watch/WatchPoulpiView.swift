import SwiftUI
import SceneKit
import SudokuCore
import WatchKit

/// The iPhone sculpt, materials, lighting and animation rig, rendered by watchOS.
struct WatchPoulpiView: View {
    var appearance = PoulpiAppearance()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @StateObject private var renderer = WatchPoulpiScene()
    @State private var visible = false
    @State private var onScreen = true

    private var animated: Bool {
        visible && onScreen && scenePhase == .active && !reduceMotion && !isLuminanceReduced
    }

    var body: some View {
        SceneView(scene: renderer.model.scene,
                  pointOfView: renderer.camera,
                  options: animated ? [.rendersContinuously] : [],
                  preferredFramesPerSecond: 60,
                  antialiasingMode: .multisampling4X)
            .background {
                GeometryReader { proxy in
                    Color.clear.onChange(of: proxy.frame(in: .global), initial: true) { _, frame in
                        onScreen = frame.intersects(WKInterfaceDevice.current().screenBounds)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Poulpi")
            .accessibilityIdentifier("watch.poulpi")
            .onAppear { visible = true }
            .onDisappear { visible = false; renderer.setAnimated(false) }
            .onChange(of: animated, initial: true) { _, value in renderer.setAnimated(value) }
            .onChange(of: appearance, initial: true) { _, value in renderer.model.setAppearance(value) }
            .task(id: animated) {
                guard animated else { return }
                var sequence = 0
                var previous: LisaMascotMood?
                do {
                    while !Task.isCancelled {
                        try await Task.sleep(for: .seconds(Double.random(in: 5...9)))
                        guard let mood = LisaMascotExpressionScheduler.nextMood(
                            baseMood: .idle, previousMood: previous, sequence: sequence
                        ) else { continue }
                        renderer.model.setMood(mood, animated: true)
                        renderer.model.react(mood)
                        previous = mood
                        sequence += 1
                        try await Task.sleep(for: .seconds(mood.reactionDuration))
                        renderer.model.setMood(.idle, animated: true)
                    }
                } catch { return }
            }
    }
}

@MainActor
private final class WatchPoulpiScene: ObservableObject {
    let model = OctopusModel()
    var camera: SCNNode? { model.scene.rootNode.childNodes.first { $0.camera != nil } }

    init() {
        model.setMotionEnabled(false)
        model.scene.isPaused = true
    }

    func setAnimated(_ animated: Bool) {
        model.setMotionEnabled(animated)
        if !animated { model.setMood(.idle, animated: false) }
        model.scene.isPaused = !animated
    }
}
