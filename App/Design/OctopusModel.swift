import SceneKit
import UIKit
import SudokuCore

/// Continuous articulated Poulpi sculpt within the depth-aware scene.
final class OctopusModel {
    let scene = SCNScene()
    private let body = SCNNode()
    private let gesture = SCNNode()
    private let flight = SCNNode()
    private let portraitRotation = SCNNode()
    private let camera = SCNNode()
    private let occluder = SCNNode()
    private var spatial = false
    private var flightAspect: Float = 0.5
    private let rig = PoulpiRig()
    private let lighting = SCNNode()
    // Balance the portrait margin around the full breathing/arm envelope.
    // The fixed comparison retains its historical camera for equal framing.
    private let portraitTarget: SCNVector3 = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--octopus-preview") && args.contains("--octopus-still") {
            return SCNVector3(0, 0.24, 0)
        }
        #endif
        return SCNVector3(0, 0.12, 0)
    }()
    private var motionEnabled = true
    private var currentMood: LisaMascotMood = .idle
    private var playbackSpeed: CGFloat = 1

    init() {
        scene.background.contents = UIColor.clear
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 1.35
        camera.position = SCNVector3(0, 1.30, 7)
        camera.look(at: portraitTarget)
        scene.rootNode.addChildNode(camera)
        lighting.name = "flightLighting"
        scene.rootNode.addChildNode(lighting)
        for (position, intensity, color) in [
            (SCNVector3(-3,4,5), CGFloat(220), UIColor(red:1,green:0.96,blue:0.91,alpha:1)),
            (SCNVector3(3,2,2), CGFloat(95), UIColor(red:0.78,green:0.85,blue:1,alpha:1)),
            (SCNVector3(0,-3,4), CGFloat(20), UIColor(red:1,green:0.94,blue:0.82,alpha:1))
        ] {
            let light = SCNNode(); light.light = SCNLight(); light.light?.type = .omni
            light.light?.intensity = intensity; light.light?.color = color; light.position=position
            lighting.addChildNode(light)
        }
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient
        ambient.light?.intensity=85;ambient.light?.color=UIColor.white;lighting.addChildNode(ambient)
        let mask = SCNMaterial()
        mask.colorBufferWriteMask = []
        mask.writesToDepthBuffer = true
        mask.readsFromDepthBuffer = true
        mask.isDoubleSided = true
        occluder.geometry = SCNPlane(width: 1, height: 1)
        occluder.geometry?.firstMaterial = mask
        occluder.renderingOrder = -1
        occluder.isHidden = true
        scene.rootNode.addChildNode(occluder)
        scene.rootNode.addChildNode(portraitRotation)
        portraitRotation.addChildNode(flight)
        flight.addChildNode(gesture)
        gesture.addChildNode(body)
        body.addChildNode(rig.node)
        rig.play(.idle, animated: true)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--octopus-preview") && ProcessInfo.processInfo.arguments.contains("--octopus-still") {
            rig.play(.idle, animated:false)
        }
        if ProcessInfo.processInfo.arguments.contains("--octopus-preview") && ProcessInfo.processInfo.arguments.contains("--octopus-motion-preview") {
            camera.camera?.orthographicScale = 1.60
            let rig = rig
            body.runAction(.repeatForever(.customAction(duration: 32) { _, elapsed in
                rig.setSwimming(CompanionFlight.swimming(seconds: Double(elapsed)))
            }), forKey: "swim-inspection")
        }
        if ProcessInfo.processInfo.arguments.contains("--octopus-preview") && ProcessInfo.processInfo.arguments.contains("--octopus-turntable") {
            // Rear curls project lower when they turn toward the camera.
            // Keep the full animated silhouette inside this inspection view.
            camera.camera?.orthographicScale = 1.52
            body.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 12)), forKey: "inspection")
        }
        #endif
    }

    func setAppearance(_ appearance: PoulpiAppearance) { rig.setAppearance(appearance) }

    /// SceneKit action speed is local to each action, including the rig clock.
    /// Apply it only when controls or actions change, never during a frame.
    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = CGFloat(speed)
        scene.rootNode.enumerateChildNodes { node, _ in
            for key in node.actionKeys {
                if let action = node.action(forKey: key), action.speed != self.playbackSpeed {
                    action.speed = self.playbackSpeed
                }
            }
        }
    }

    func setPortrait(interactive: Bool, yaw: Double, pitch: Double, zoom: Double) {
        guard interactive, !spatial else { return }
        portraitRotation.eulerAngles = SCNVector3(Float(pitch), Float(yaw), 0)
        camera.camera?.orthographicScale = 1.65 / max(0.75, min(1.6, zoom))
    }

    func setSpatial(_ enabled: Bool, aspect: Float) {
        guard spatial != enabled || flightAspect != aspect else { return }
        spatial = enabled; flightAspect = aspect
        camera.camera?.usesOrthographicProjection = !enabled
        if enabled {
            camera.camera?.fieldOfView = 40
            camera.camera?.projectionDirection = .vertical
            camera.position = SCNVector3(0, 0, 12)
            camera.eulerAngles = SCNVector3Zero
            flight.scale = SCNVector3(0.32, 0.32, 0.32)
            restFlight()
            if motionEnabled { installFlight() }
        } else {
            flight.removeAction(forKey: "travel")
            rig.setSwimming(nil)
            flight.transform = SCNMatrix4Identity
            lighting.position = SCNVector3Zero
            camera.position = SCNVector3(0, 1.30, 7)
            camera.look(at: portraitTarget)
        }
    }
    func setOcclusion(_ rect: CGRect, viewport: CGSize) {
        guard spatial, viewport.width > 0, viewport.height > 0, rect.width > 0, rect.height > 0 else {
            occluder.isHidden = true; return
        }
        let halfHeight = 12 * tan(Double.pi / 9)
        let halfWidth = halfHeight * viewport.width / viewport.height
        occluder.scale = SCNVector3(rect.width / viewport.width * halfWidth * 2,
                                   rect.height / viewport.height * halfHeight * 2, 1)
        occluder.position = SCNVector3((rect.midX / viewport.width * 2 - 1) * halfWidth,
                                      (1 - rect.midY / viewport.height * 2) * halfHeight, 0)
        occluder.isHidden = false
    }

    private func restFlight() {
        let p = CompanionFlight.sample(seconds: 0)
        let halfHeight = Float(12 - p.depth) * tan(Float.pi / 9)
        flight.position = SCNVector3(Float(p.x) * halfHeight * flightAspect, Float(p.y) * halfHeight, Float(p.depth))
        flight.eulerAngles = SCNVector3(Float(-p.dz * 0.10), Float(p.dx * 1.8), Float(-p.dx * 0.9))
        flight.opacity = 1
        lighting.position = flight.position
    }
    private func installFlight() {
        let aspect = flightAspect
        let rig = rig
        // SceneKit advances this curve directly; no SwiftUI redraw per frame.
        flight.runAction(.repeatForever(.customAction(duration: 32) { node, elapsed in
            let swim = CompanionFlight.swimming(seconds: Double(elapsed))
            let p = swim.pose
            rig.setSwimming(swim)
            let halfHeight = Float(12 - p.depth) * tan(Float.pi / 9)
            node.position = SCNVector3(Float(p.x) * halfHeight * aspect, Float(p.y) * halfHeight, Float(p.depth))
            // flight -> portraitRotation -> scene.rootNode, where the light rig
            // is a sibling. Resolve through SceneKit's action-owned node rather
            // than capturing a second non-Sendable node across render threads.
            node.parent?.parent?.childNode(withName: "flightLighting", recursively: false)?.position = node.position
            node.eulerAngles = SCNVector3(Float(-p.dz * 0.10), Float(p.dx * 1.8), Float(-p.dx * 0.9 - swim.turn * 0.18))
            // Distant passes remain visually light over the puzzle.
            node.opacity = p.depth < -2 ? CGFloat(max(0.55, 1 + (p.depth + 2) * 0.12)) : 1
        }), forKey: "travel")
        flight.action(forKey: "travel")?.speed = playbackSpeed
    }

    // Preserve the welded silhouette and cups at every quality level.
    func setDetail(_ level: Int) {}
    func setMotionEnabled(_ enabled: Bool) {
        guard motionEnabled != enabled else { return }
        motionEnabled = enabled
        rig.play(currentMood, animated: enabled)
        if spatial {
            if enabled { installFlight() }
            else { flight.removeAction(forKey: "travel"); restFlight() }
        }
        if !enabled {
            rig.setSwimming(nil)
            gesture.removeAllActions()
            gesture.transform = SCNMatrix4Identity
        }
    }
    func setMood(_ mood: LisaMascotMood, animated: Bool) {
        currentMood = mood
        rig.play(mood, animated: animated && motionEnabled)
        if mood == .idle || mood == .sleepy {
            gesture.removeAllActions()
            gesture.transform = SCNMatrix4Identity
        }
    }
    func react(_ mood: LisaMascotMood) {
        guard motionEnabled, mood != .sleepy, mood != .idle else { return }
        rig.play(mood, animated: true)
        // Arm gestures blend over the synchronized swimming stroke.
        // Preserve the visible pose when another reaction interrupts this one.
        let startPosition = gesture.presentation.position
        let startRotation = gesture.presentation.eulerAngles
        let startScale = gesture.presentation.scale
        gesture.removeAllActions()
        let duration = mood.reactionDuration
        gesture.runAction(.customAction(duration: duration) { node, elapsed in
            let t = PoulpiAnimationTiming.reactionPhase(elapsed: Double(elapsed), duration: duration)
            let envelope = pow(sin(.pi * t), 2)
            let phase = t * .pi * 2
            let blend = max(0, 1 - t / 0.18)
            let carry = blend * blend * (3 - 2 * blend)
            var x: Float = 0, y: Float = 0, z: Float = 0
            var pitch: Float = 0, yaw: Float = 0, roll: Float = 0
            var sx: Float = 1, sy: Float = 1
            switch mood {
            case .surprised:
                y = 0.075 * envelope
                sx = 1 + 0.07 * envelope; sy = 1 - 0.06 * envelope
            case .nervous:
                roll = sin(phase * 5) * 0.08 * envelope
                x = sin(phase * 6) * 0.025 * envelope
            case .confused:
                yaw = 0.28 * envelope; roll = -0.12 * envelope
            case .loved:
                y = 0.045 * envelope
                roll = sin(phase * 2) * 0.06 * envelope
            case .proud:
                pitch = -0.13 * envelope; y = 0.045 * envelope
                sx = 1 + 0.04 * envelope; sy = 1 + 0.02 * envelope
            case .chase:
                yaw = sin(phase) * 0.45 * envelope
                pitch = -0.16 * envelope
            case .moonwalk:
                yaw = -0.45 * envelope; roll = sin(phase * 4) * 0.10 * envelope
                y = pow(sin(phase * 4), 2) * 0.06 * envelope
            case .juggle:
                roll = sin(phase * 3) * 0.13 * envelope
                pitch = -0.2 * envelope
            case .cloudHide:
                sx = 1 - 0.25 * envelope; sy = sx; y = -0.1 * envelope
            case .sneeze:
                let impulse = PoulpiAnimationTiming.sneezeImpulse(phase: t)
                pitch = -0.25 * envelope + impulse * 0.5
                sx = 1 + impulse * 0.14
                sy = 1 - impulse * 0.14
            case .tumble:
                roll = .pi * 2 * t * t * (3 - 2 * t)
                sx = 1 - 0.45 * envelope; sy = sx
            case .balance:
                roll = sin(phase * 3) * 0.22 * envelope
            case .dizzy:
                roll = sin(phase * 2) * 0.18 * envelope
                yaw = sin(phase * 3) * 0.25 * envelope
            case .superhero:
                roll = -0.4 * envelope; pitch = -0.2 * envelope
                sx = 1 - 0.12 * envelope; sy = sx
            case .pirouette:
                yaw = .pi * 2 * t * t * (3 - 2 * t)
                y = 0.12 * envelope
            case .wobble:
                roll = sin(phase * 2) * 0.30 * envelope
                x = sin(phase * 2) * 0.08 * envelope
            case .peek:
                sx = 1 - 0.45 * envelope; sy = sx
                y = -0.14 * envelope
            case .jelly:
                sx = 1 + sin(phase * 3) * 0.16 * envelope
                sy = 1 - sin(phase * 3) * 0.16 * envelope
            case .swim:
                x = sin(phase) * 0.23 * envelope
                y = sin(phase * 2) * 0.10 * envelope
                roll = -sin(phase) * 0.22 * envelope
            case .bow:
                pitch = 0.65 * envelope; y = -0.09 * envelope
            case .curious:
                yaw = sin(phase) * 0.65 * envelope
                roll = sin(phase * 2) * 0.10 * envelope
            case .giggle:
                y = pow(sin(phase * mood.laughCycles), 2) * 0.10 * envelope
                roll = sin(phase * mood.laughCycles) * 0.12 * envelope
                sx = 1 + 0.06 * envelope; sy = 1 - 0.06 * envelope
            case .rocket:
                y = 0.12 * envelope
                roll = sin(phase * 3) * 0.07 * envelope
                z = -0.08 * envelope
            case .celebrating:
                y = pow(sin(phase * mood.laughCycles), 2) * 0.12 * envelope
                roll = sin(phase * mood.laughCycles) * 0.16 * envelope
            case .thinking:
                roll = -0.15 * envelope; yaw = 0.12 * envelope
            case .encouraging:
                pitch = sin(phase) * 0.16 * envelope
            default:
                y = 0.14 * envelope; roll = 0.08 * sin(phase) * envelope
            }
            node.position = SCNVector3(x + startPosition.x * carry, y + startPosition.y * carry, z + startPosition.z * carry)
            node.eulerAngles = SCNVector3(pitch + startRotation.x * carry, yaw + startRotation.y * carry, roll + startRotation.z * carry)
            node.scale = SCNVector3(sx + (startScale.x - 1) * carry, sy + (startScale.y - 1) * carry, 1 + (startScale.z - 1) * carry)
            if t >= 1 { node.transform = SCNMatrix4Identity }
        }, forKey: "gesture")
    }

}
