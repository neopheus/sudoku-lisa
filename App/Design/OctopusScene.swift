import SwiftUI
import SceneKit

struct OctopusSceneView: UIViewRepresentable {
    let mood: LisaMascotMood
    let reactionToken: Int
    let animated: Bool

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: OctopusRenderView, context: Context) -> CGSize {
        CGSize(width: proposal.width ?? 115, height: proposal.height ?? 110)
    }

    func makeUIView(context: Context) -> OctopusRenderView { OctopusRenderView() }
    func updateUIView(_ view: OctopusRenderView, context: Context) {
        view.configure(mood: mood, reaction: reactionToken, animated: animated)
    }
    static func dismantleUIView(_ view: OctopusRenderView, coordinator: ()) {
        view.wantsAnimation = false
        view.synchronizePlayback()
    }
}

/// SceneKit owns interpolated animation timing; there are no display-link retain cycles.
final class OctopusRenderView: SCNView {
    private let companion = OctopusModel()
    var wantsAnimation = false
    private var previousMood: LisaMascotMood?
    private var previousReaction: Int?
    #if DEBUG
    private let renderProbe = OctopusRenderProbe()
    #endif

    init() {
        super.init(frame: .zero, options: nil)
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
        #if DEBUG
        delegate = renderProbe
        #endif
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func didMoveToWindow() { super.didMoveToWindow(); synchronizePlayback() }

    override func layoutSubviews() {
        super.layoutSubviews()
        #if DEBUG
        print("OCTOPUS_LAYOUT frame=\(frame) bounds=\(bounds) window=\(window != nil) alpha=\(alpha) hidden=\(isHidden) camera=\(pointOfView != nil) playing=\(isPlaying) paused=\(scene?.isPaused ?? true) wanted=\(wantsAnimation) nodes=\(scene?.rootNode.childNodes.count ?? 0) backend=\(renderingAPI.rawValue)")
        #endif
    }

    func synchronizePlayback() {
        let running = wantsAnimation && window != nil
        isPlaying = running
        scene?.isPaused = !running
        rendersContinuously = running
        setNeedsDisplay()
        #if DEBUG
        print("OCTOPUS_PLAY running=\(running) bounds=\(bounds) window=\(window != nil) wanted=\(wantsAnimation)")
        #endif
    }
    func configure(mood: LisaMascotMood, reaction: Int, animated: Bool) {
        wantsAnimation = animated
        if previousMood != mood {
            companion.setMood(mood, animated: animated)
            previousMood = mood
        }
        if let previousReaction, previousReaction != reaction, animated {
            companion.react(mood)
        }
        self.previousReaction = reaction
        companion.setMotionEnabled(animated)
        synchronizePlayback()
    }
}

/// Small, original toy-like model made exclusively from native geometry.
/// Eight connected tube meshes morph continuously between matching vertex topologies.
final class OctopusModel {
    let scene = SCNScene()
    private let body = SCNNode()
    private let head = SCNNode()
    private var eyes: [SCNNode] = []
    private var pupils: [SCNNode] = []
    private var brows: [SCNNode] = []
    private var arms: [SCNNode] = []
    private let bubbles = SCNNode()
    private var motionEnabled = true
    private var currentMood: LisaMascotMood = .idle
    private let purple = OctopusModel.material(UIColor(red: 0.39, green: 0.25, blue: 0.82, alpha: 1), roughness: 0.30)
    private let cream = OctopusModel.material(UIColor(red: 1, green: 0.88, blue: 0.65, alpha: 1), roughness: 0.46)

    init() {
        scene.background.contents = UIColor.clear
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 1.22
        camera.position = SCNVector3(0, 1.30, 7)
        camera.look(at: SCNVector3(0, 0.24, 0))
        scene.rootNode.addChildNode(camera)
        light(.omni, color: UIColor(red: 1, green: 0.94, blue: 0.90, alpha: 1), intensity: 650, position: SCNVector3(-3, 5, 5))
        light(.omni, color: UIColor(red: 0.63, green: 0.80, blue: 1, alpha: 1), intensity: 250, position: SCNVector3(3, 2, -2))
        light(.ambient, color: UIColor(red: 0.78, green: 0.74, blue: 1, alpha: 1), intensity: 350, position: SCNVector3Zero)
        scene.rootNode.addChildNode(body)
        body.addChildNode(head)
        let skull = sphere(radius: 0.79, scale: SCNVector3(1, 1.01, 0.88), material: purple)
        skull.position = SCNVector3(0, 0.50, 0)
        head.addChildNode(skull)
        for side: Float in [-1, 1] {
            let eye = sphere(radius: 0.255, scale: SCNVector3(0.91, 1.15, 0.44), material: Self.material(.white, roughness: 0.2))
            eye.position = SCNVector3(side * 0.286, 0.54, 0.607)
            head.addChildNode(eye); eyes.append(eye)
            let pupil = sphere(radius: 0.145, scale: SCNVector3(0.86, 1.14, 0.47), material: Self.material(UIColor(red: 0.045, green: 0.025, blue: 0.16, alpha: 1), roughness: 0.15))
            pupil.position = SCNVector3(-side * 0.025, -0.015, 0.245)
            eye.addChildNode(pupil); pupils.append(pupil)
            let glint = sphere(radius: 0.047, scale: SCNVector3(1, 1, 0.5), material: Self.material(.white, roughness: 0.1))
            glint.position = SCNVector3(-0.036, 0.052, 0.145); pupil.addChildNode(glint)
            let glint2 = sphere(radius: 0.021, scale: SCNVector3(1, 1, 0.5), material: Self.material(.white, roughness: 0.1))
            glint2.position = SCNVector3(0.041, -0.040, 0.147); pupil.addChildNode(glint2)
            let brow = sphere(radius: 0.105, scale: SCNVector3(1, 0.25, 0.40), material: Self.material(UIColor(red: 0.29, green: 0.10, blue: 0.63, alpha: 1)))
            brow.position = SCNVector3(side * 0.29, 0.91, 0.54)
            brow.eulerAngles.z = side * -0.13
            head.addChildNode(brow); brows.append(brow)
            let cheek = sphere(radius: 0.115, scale: SCNVector3(1, 0.46, 0.16), material: Self.material(UIColor(red: 0.94, green: 0.34, blue: 0.70, alpha: 1)))
            cheek.position = SCNVector3(side * 0.49, 0.24, 0.55); head.addChildNode(cheek)
        }
        let smile = UIBezierPath()
        smile.flatness = 0.001
        smile.move(to: CGPoint(x: -0.13, y: 0.035))
        smile.addQuadCurve(to: CGPoint(x: 0.13, y: 0.035), controlPoint: CGPoint(x: 0, y: -0.035))
        smile.addCurve(to: CGPoint(x: -0.13, y: 0.035), controlPoint1: CGPoint(x: 0.09, y: -0.16), controlPoint2: CGPoint(x: -0.09, y: -0.16))
        smile.close()
        let mouth = SCNNode(geometry: SCNShape(path: smile, extrusionDepth: 0.035))
        mouth.geometry?.firstMaterial = Self.material(UIColor(red: 1, green: 0.38, blue: 0.12, alpha: 1), roughness: 0.36)
        (mouth.geometry as? SCNShape)?.chamferRadius = 0.017
        mouth.position = SCNVector3(0, 0.25, 0.70); head.addChildNode(mouth)
        for index in 0..<8 { addTentacle(index) }
        addBubbles()
        installIdle()
    }

    private static func material(_ color: UIColor, roughness: CGFloat = 0.4) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.specular.contents = UIColor(white: 0.22, alpha: 1)
        material.shininess = 0.45
        material.diffuse.contents = color
        material.roughness.contents = roughness
        material.metalness.contents = 0.0
        return material
    }
    private func sphere(radius: CGFloat, scale: SCNVector3, material: SCNMaterial) -> SCNNode {
        let geometry = SCNSphere(radius: radius); geometry.segmentCount = 32
        geometry.firstMaterial = material
        let node = SCNNode(geometry: geometry); node.scale = scale; return node
    }
    private func light(_ type: SCNLight.LightType, color: UIColor, intensity: CGFloat, position: SCNVector3) {
        let node = SCNNode(); node.light = SCNLight(); node.light?.type = type
        node.light?.color = color; node.light?.intensity = intensity; node.position = position
        scene.rootNode.addChildNode(node)
    }

    private func addTentacle(_ index: Int) {
        let angle = Float(index) * .pi / 4 + .pi / 8
        let node = SCNNode(geometry: tube(angle: angle, phase: 0))
        node.geometry?.firstMaterial = purple
        let morpher = SCNMorpher()
        morpher.targets = [tube(angle: angle, phase: 1), tube(angle: angle, phase: -1)]
        morpher.calculationMode = .normalized
        node.morpher = morpher
        body.addChildNode(node); arms.append(node)
        let tip = sphere(radius: 0.027, scale: SCNVector3(1, 1, 1), material: purple)
        tip.position = Self.curve(1, angle, 0)
        node.addChildNode(tip)
        var suckers: [SCNNode] = []
        for step in 0..<5 {
            let t = Float(step) * 0.13 + 0.35
            let sucker = sphere(radius: CGFloat(0.047 - t * 0.018), scale: SCNVector3(1, 0.48, 1), material: cream)
            let p = Self.curve(t, angle, 0)
            sucker.position = SCNVector3(p.x, p.y + 0.082 * (1-t) + 0.032, p.z + 0.048)
            node.addChildNode(sucker); suckers.append(sucker)
        }
        let duration = 4.3 + Double(index % 3) * 0.45
        let action = SCNAction.customAction(duration: duration) { node, elapsed in
            let wave = sin(Float(elapsed / duration) * 2 * .pi)
            tip.position = Self.curve(1, angle, wave)
            node.morpher?.setWeight(CGFloat(max(wave, 0)), forTargetAt: 0)
            node.morpher?.setWeight(CGFloat(max(-wave, 0)), forTargetAt: 1)
            for (step, sucker) in suckers.enumerated() {
                let t = Float(step) * 0.13 + 0.35
                let p = Self.curve(t, angle, wave)
                sucker.position = SCNVector3(p.x, p.y + 0.082 * (1-t) + 0.032, p.z + 0.048)
            }
        }
        node.runAction(.repeatForever(action), forKey: "ripple")
    }
    private static func curve(_ t: Float, _ angle: Float, _ phase: Float) -> SCNVector3 {
        let radius = 0.25 + 0.78 * t
        let curl = sin(t * .pi) * 0.13
        return SCNVector3(
            sin(angle) * radius + cos(angle) * curl,
            -0.18 - 0.41 * sin(t * .pi * 0.79) + 0.13 * pow(t, 5) + phase * 0.13 * t * t,
            cos(angle) * radius + sin(angle) * curl
        )
    }
    private func tube(angle: Float, phase: Float) -> SCNGeometry {
        let sections = 32, sides = 16
        var vertices: [SCNVector3] = [], normals: [SCNVector3] = [], indices: [UInt16] = []
        for ring in 0...sections {
            let t = Float(ring) / Float(sections)
            let center = Self.curve(t, angle, phase)
            let before = Self.curve(max(0, t - 0.002), angle, phase)
            let after = Self.curve(min(1, t + 0.002), angle, phase)
            let tangent = simd_normalize(SIMD3<Float>(after.x-before.x, after.y-before.y, after.z-before.z))
            let u = simd_normalize(simd_cross(tangent, SIMD3<Float>(0, 1, 0)))
            let v = simd_cross(tangent, u)
            let radius: Float = 0.155 * pow(1-t, 0.65) + 0.027
            for side in 0..<sides {
                let a = Float(side) / Float(sides) * 2 * .pi
                let normal = u * cos(a) + v * sin(a)
                vertices.append(SCNVector3(center.x + normal.x * radius, center.y + normal.y * radius, center.z + normal.z * radius))
                normals.append(SCNVector3(normal.x, normal.y, normal.z))
                if ring < sections {
                    let a = UInt16(ring * sides + side), b = UInt16(ring * sides + (side + 1) % sides)
                    let c = a + UInt16(sides), d = b + UInt16(sides)
                    indices += [a, b, c, b, d, c]
                }
            }
        }
        return SCNGeometry(sources: [.init(vertices: vertices), .init(normals: normals)], elements: [.init(indices: indices, primitiveType: .triangles)])
    }

    private func installIdle() {
        let breathe = SCNAction.smoothSequence([.scale(to: 1.025, duration: 1.8), .scale(to: 1, duration: 1.8)])
        breathe.actionsWithEaseInOut()
        body.runAction(.repeatForever(breathe), forKey: "breath")
        let sway = SCNAction.smoothSequence([.rotateTo(x: 0, y: -0.075, z: -0.035, duration: 2.4), .rotateTo(x: 0, y: 0.075, z: 0.035, duration: 2.4)])
        sway.actionsWithEaseInOut(); head.runAction(.repeatForever(sway), forKey: "sway")
        for eye in eyes {
            let blink = SCNAction.sequence([.wait(duration: 3.6), .scaleY(to: 0.08, duration: 0.09), .scaleY(to: 1.15, duration: 0.15), .wait(duration: 2.2)])
            eye.runAction(.repeatForever(blink), forKey: "blink")
        }
        for pupil in pupils {
            pupil.runAction(.repeatForever(.sequence([.wait(duration: 2.4), .moveBy(x: 0.025, y: 0.015, z: 0, duration: 0.7), .wait(duration: 1.5), .moveBy(x: -0.025, y: -0.015, z: 0, duration: 0.7)])), forKey: "gaze")
        }
    }
    private func addBubbles() {
        scene.rootNode.addChildNode(bubbles)
        for index in 0..<4 {
            let bubble = sphere(radius: CGFloat(0.035 + Double(index % 2) * 0.018), scale: SCNVector3(1, 1, 1), material: Self.material(UIColor(red: 0.68, green: 0.91, blue: 1, alpha: 0.42), roughness: 0.13))
            bubble.position = SCNVector3(index % 2 == 0 ? -1.05 : 1.08, -0.5, -0.2)
            bubble.opacity = 0
            bubbles.addChildNode(bubble)
            let rise = SCNAction.group([.moveBy(x: index % 2 == 0 ? -0.05 : 0.05, y: 1.9, z: 0, duration: 3.3), .sequence([.fadeOpacity(to: 0.62, duration: 0.7), .wait(duration: 1.7), .fadeOut(duration: 0.9)])])
            bubble.runAction(.repeatForever(.sequence([.wait(duration: Double(index) * 0.8), rise, .moveBy(x: index % 2 == 0 ? 0.05 : -0.05, y: -1.9, z: 0, duration: 0)])))
        }
    }
    func setMotionEnabled(_ enabled: Bool) {
        guard enabled != motionEnabled else { return }
        motionEnabled = enabled
        bubbles.isHidden = !enabled || currentMood == .sleepy
        if !enabled {
            // Neutral open eyes remain readable even if Reduce Motion changes mid-blink.
            body.scale = SCNVector3(1, 1, 1)
            head.eulerAngles = SCNVector3Zero
            for eye in eyes { eye.scale.y = currentMood == .sleepy ? 0.15 : 1.15 }
        }
    }
    func setMood(_ mood: LisaMascotMood, animated: Bool) {
        currentMood = mood
        SCNTransaction.begin(); SCNTransaction.animationDuration = animated ? 0.4 : 0
        bubbles.isHidden = !animated || mood == .sleepy
        for (index, brow) in brows.enumerated() {
            let side: Float = index == 0 ? -1 : 1
            brow.eulerAngles.z = mood == .encouraging ? side * 0.30 : mood == .thinking ? side * 0.20 : side * -0.13
        }
        for eye in eyes {
            eye.isPaused = mood == .sleepy
            eye.scale.y = mood == .sleepy ? 0.15 : 1.15
        }
        head.position.y = mood == .sleepy ? -0.08 : 0
        SCNTransaction.commit()
        if animated && mood == .happy { react(mood) }
    }
    func react(_ mood: LisaMascotMood) {
        guard motionEnabled, mood != .sleepy else { return }
        let hop = SCNAction.smoothSequence([.moveBy(x: 0, y: 0.13, z: 0, duration: 0.22), .moveBy(x: 0, y: -0.13, z: 0, duration: 0.36)])
        hop.actionsWithEaseInOut()
        body.removeAction(forKey: "reaction")
        body.position = SCNVector3Zero
        body.runAction(hop, forKey: "reaction")
        if let arm = arms.last {
            let wave = SCNAction.smoothSequence([.rotateTo(x: 0, y: 0, z: 0.25, duration: 0.22), .rotateTo(x: 0, y: 0, z: -0.10, duration: 0.22), .rotateTo(x: 0, y: 0, z: 0.20, duration: 0.22), .rotateTo(x: 0, y: 0, z: 0, duration: 0.30)])
            wave.actionsWithEaseInOut(); arm.runAction(wave, forKey: "wave")
        }
    }
}

private extension SCNAction {
    func actionsWithEaseInOut() { timingMode = .easeInEaseOut }
    static func smoothSequence(_ actions: [SCNAction]) -> SCNAction {
        for action in actions { action.timingMode = .easeInEaseOut }
        return .sequence(actions)
    }
    static func scaleY(to value: Float, duration: TimeInterval) -> SCNAction {
        .customAction(duration: duration) { node, elapsed in
            // Blink endpoints are fixed so interpolation is independent of frame rate.
            let start: Float = value < 0.5 ? 1.15 : 0.08
            let t = min(1, Float(elapsed / duration))
            node.scale.y = start + (value-start) * t
        }
    }
}

#if DEBUG
private final class OctopusRenderProbe: NSObject, SCNSceneRendererDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var remaining = 3
    func renderer(_ renderer: any SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        lock.lock()
        let shouldPrint = remaining > 0
        remaining -= shouldPrint ? 1 : 0
        lock.unlock()
        if shouldPrint { print("OCTOPUS_RENDER time=\(time) viewport=\(renderer.currentViewport) camera=\(String(describing: renderer.pointOfView?.position))") }
    }
}
#endif
