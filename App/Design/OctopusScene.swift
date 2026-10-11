import SwiftUI
import SceneKit
import SudokuCore

struct OctopusSceneView: UIViewRepresentable {
    let mood: LisaMascotMood
    let reactionToken: Int
    let animated: Bool
    var spatial = false
    var occlusionRect = CGRect.zero
    var interactivePortrait = false
    var yaw: Double = 0
    var pitch: Double = 0
    var zoom: Double = 1
    var playbackPaused = false
    var playbackSpeed: Double = 1
    var appearance = PoulpiAppearance()
    @ObservedObject private var budget = LisaRenderBudget.shared

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: OctopusHostView, context: Context) -> CGSize {
        CGSize(width: proposal.width ?? 115, height: proposal.height ?? 110)
    }

    func makeUIView(context: Context) -> OctopusHostView { OctopusHostView() }
    func updateUIView(_ view: OctopusHostView, context: Context) {
        view.renderer.setAppearance(appearance)
        view.renderer.setSpatial(spatial)
        view.renderer.setPortrait(interactive: interactivePortrait, yaw: yaw, pitch: pitch, zoom: zoom)
        view.renderer.setOcclusion(occlusionRect)
        view.renderer.setQuality(level: budget.level, frames: budget.frameRate)
        view.renderer.setPlayback(paused: playbackPaused, speed: playbackSpeed)
        view.renderer.configure(mood: mood, reaction: reactionToken, animated: animated)
    }
    static func dismantleUIView(_ view: OctopusHostView, coordinator: ()) {
        view.renderer.wantsAnimation = false
        view.renderer.synchronizePlayback()
    }
}

/// Keep the Metal-backed view in a normal UIKit child hierarchy. SwiftUI owns
/// only this plain host, including when it is measured inside a ScrollView.
final class OctopusHostView: UIView {
    let renderer = OctopusRenderView()
    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 115, height: 110))
        backgroundColor = .clear
        isOpaque = false
        addSubview(renderer)
        renderer.frame = bounds
        renderer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        renderer.frame = bounds
        renderer.updateViewport()
        renderer.synchronizePlayback()
    }
}

/// SceneKit owns interpolated animation timing; there are no display-link retain cycles.
final class OctopusRenderView: SCNView {
    private let companion = OctopusModel()
    var wantsAnimation = false
    private var previousAppearance: PoulpiAppearance?
    private var previousMood: LisaMascotMood?
    private var previousReaction: Int?
    private var playbackRunning: Bool?
    private var playbackPaused = false
    private var playbackSpeed: Double = 1
    private var detailLevel = -1
    private var spatial = false
    private var portraitState: PortraitState?
    private struct PortraitState: Equatable {
        let interactive: Bool
        let yaw: Double
        let pitch: Double
        let zoom: Double
    }
    private var viewport = CGSize.zero
    private var occlusionRect = CGRect.zero
    private let budgetClient = UUID()
    private lazy var frameProbe = OctopusFrameProbe(client: budgetClient)

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 115, height: 110), options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue])
        scene = companion.scene
        pointOfView = companion.scene.rootNode.childNodes.first { $0.camera != nil }
        backgroundColor = .clear
        isOpaque = false
        autoenablesDefaultLighting = false
        antialiasingMode = .multisampling4X
        preferredFramesPerSecond = 60
        allowsCameraControl = false
        rendersContinuously = false
        accessibilityElementsHidden = true
        delegate = frameProbe
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func didMoveToWindow() { super.didMoveToWindow(); synchronizePlayback() }

    func synchronizePlayback() {
        let running = wantsAnimation && !playbackPaused && window != nil
        guard playbackRunning != running else { return }
        playbackRunning = running
        frameProbe.configure(active: running, target: preferredFramesPerSecond)
        LisaRenderBudget.shared.setActive(running, client: budgetClient)
        scene?.isPaused = !running
        rendersContinuously = running
        if running { play(nil) } else { pause(nil) }
        setNeedsDisplay()
        layer.setNeedsDisplay()
    }
    /// Freezes the current scene pose without removing actions or resetting the rig.
    func setPlayback(paused: Bool, speed: Double) {
        let speed = speed.isFinite ? min(1, max(0.1, speed)) : 1
        if playbackSpeed != speed {
            playbackSpeed = speed
            companion.setPlaybackSpeed(speed)
        }
        if playbackPaused != paused {
            playbackPaused = paused
            synchronizePlayback()
        }
    }
    func setAppearance(_ appearance: PoulpiAppearance) {
        guard previousAppearance != appearance else { return }
        previousAppearance = appearance
        companion.setAppearance(appearance)
        setNeedsDisplay()
    }
    func setSpatial(_ enabled: Bool) {
        guard spatial != enabled else { return }
        spatial = enabled
        portraitState = nil
        viewport = .zero
        updateViewport()
    }
    func setPortrait(interactive: Bool, yaw: Double, pitch: Double, zoom: Double) {
        let state = PortraitState(interactive: interactive, yaw: yaw, pitch: pitch, zoom: zoom)
        guard portraitState != state else { return }
        portraitState = state
        companion.setPortrait(interactive: interactive, yaw: yaw, pitch: pitch, zoom: zoom)
        if interactive { setNeedsDisplay() }
    }
    func setOcclusion(_ rect: CGRect) {
        guard occlusionRect != rect else { return }
        occlusionRect = rect
        companion.setOcclusion(rect, viewport: bounds.size)
    }
    func updateViewport() {
        guard bounds.size != viewport, bounds.width > 0, bounds.height > 0 else { return }
        viewport = bounds.size
        companion.setSpatial(spatial, aspect: Float(bounds.width / bounds.height))
        companion.setOcclusion(occlusionRect, viewport: bounds.size)
    }
    func setQuality(level: Int, frames: Int) {
        if preferredFramesPerSecond != frames {
            preferredFramesPerSecond = frames
            frameProbe.configure(active: playbackRunning == true, target: frames)
        }
        let aa: SCNAntialiasingMode = level == 0 ? .multisampling4X : .multisampling2X
        if antialiasingMode != aa { antialiasingMode = aa }
        let screenScale = window?.windowScene?.screen.scale ?? traitCollection.displayScale
        // Preserve the sculpt silhouette at native density, including close passes.
        // The adaptive budget adjusts cadence and peripheral scenery first.
        let renderScale = screenScale
        if contentScaleFactor != renderScale { contentScaleFactor = renderScale }
        if detailLevel != level { detailLevel = level; companion.setDetail(level) }
    }
    func configure(mood: LisaMascotMood, reaction: Int, animated: Bool) {
        guard previousMood != mood || previousReaction != reaction || wantsAnimation != animated else { return }
        let resuming = animated && !wantsAnimation
        wantsAnimation = animated
        companion.setMotionEnabled(animated)
        let moodChanged = previousMood != mood
        if moodChanged {
            companion.setMood(mood, animated: animated)
            previousMood = mood
        }
        if animated && (previousReaction != reaction || moodChanged || resuming) {
            companion.react(mood)
        }
        self.previousReaction = reaction
        companion.setPlaybackSpeed(playbackSpeed)
        synchronizePlayback()
    }
}

/// Aggregate renderer callbacks off the main thread; publish at most once per two seconds.
private final class OctopusFrameProbe: NSObject, SCNSceneRendererDelegate, @unchecked Sendable {
    private let client: UUID
    private let lock = NSLock()
    private var active = false
    private var target = 60
    private var previous: TimeInterval = 0
    private var elapsed: Double = 0
    private var count = 0
    private var late = 0
    init(client: UUID) { self.client = client }
    func configure(active: Bool, target: Int) {
        lock.lock(); defer { lock.unlock() }
        guard self.active != active || self.target != target else { return }
        self.active = active; self.target = target
        previous = 0; elapsed = 0; count = 0; late = 0
    }
    func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        lock.lock()
        guard active else { lock.unlock(); return }
        let delta = time - previous
        previous = time
        guard delta > 0, delta < 0.25 else { elapsed = 0; count = 0; late = 0; lock.unlock(); return }
        elapsed += delta; count += 1
        if delta > 1.35 / Double(target) { late += 1 }
        guard elapsed >= 2 else { lock.unlock(); return }
        let fps = Double(count) / elapsed
        let fraction = Double(late) / Double(count)
        elapsed = 0; count = 0; late = 0
        lock.unlock()
        let client = client
        Task { @MainActor in LisaRenderBudget.shared.renderedWindow(client: client, fps: fps, lateFraction: fraction) }
    }
}
