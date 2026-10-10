import XCTest
import os
import SceneKit
import UIKit
import SudokuCore
@testable import SudokuLisa

@MainActor
final class PoulpiAnimationTests: XCTestCase {
    private func irisRotation(of pupil: SCNNode) throws -> SCNVector4 {
        let material = try XCTUnwrap(pupil.childNodes.first?.geometry?.firstMaterial)
        return try XCTUnwrap((material.value(forKey: "irisRotation") as? NSValue)?.scnVector4Value)
    }

    private func irisAngularScale(of pupil: SCNNode) throws -> Float {
        let material = try XCTUnwrap(pupil.childNodes.first?.geometry?.firstMaterial)
        return try XCTUnwrap(material.value(forKey: "irisAngularScale") as? NSNumber).floatValue
    }

    private func differs(_ a: SCNVector4, _ b: SCNVector4) -> Bool {
        a.x != b.x || a.y != b.y || a.z != b.z || a.w != b.w
    }

    func testAmbientExpressionSchedulerCyclesOnlyOnRestingMoods() {
        XCTAssertEqual(LisaMascotExpressionScheduler.nextMood(baseMood: .thinking, previousMood: nil, sequence: 0), .curious)
        XCTAssertEqual(LisaMascotExpressionScheduler.nextMood(baseMood: .thinking, previousMood: .curious, sequence: 0), .confused)
        XCTAssertEqual(LisaMascotExpressionScheduler.nextMood(baseMood: .happy, previousMood: .giggle, sequence: 1), .loved)
        XCTAssertNil(LisaMascotExpressionScheduler.nextMood(baseMood: .rocket, previousMood: nil, sequence: 0))
        XCTAssertNil(LisaMascotExpressionScheduler.nextMood(baseMood: .celebrating, previousMood: nil, sequence: 0))
    }

    func testRenderedPalettesChangeRealSkinAndOriginalCanBeRestored() throws {
        let model = OctopusModel()
        model.setMotionEnabled(false)
        model.scene.isPaused = true
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = model.scene
        renderer.pointOfView = model.scene.rootNode.childNodes.first { $0.camera != nil }
        var totals: [PoulpiColor: SIMD3<Double>] = [:]
        var original: [UInt8]?
        for color in PoulpiColor.allCases {
            model.setAppearance(PoulpiAppearance(color: color, accessory: .headband))
            let image = renderer.snapshot(atTime: 0, with: CGSize(width: 160, height: 160), antialiasingMode: .multisampling4X)
            totals[color] = try opaqueColorTotals(image)
            let attachment = XCTAttachment(image: image)
            attachment.name = "Poulpi-palette-" + color.rawValue
            attachment.lifetime = .keepAlways
            add(attachment)
            if color == .pink { original = try rgbaPixels(image) }
        }
        let pink = try XCTUnwrap(totals[.pink])
        let mint = try XCTUnwrap(totals[.mint])
        let gold = try XCTUnwrap(totals[.gold])
        XCTAssertGreaterThan(pink.z, pink.x * 1.1, "The original visible skin must retain its blue/violet pigment")
        XCTAssertGreaterThan(mint.y / mint.z, pink.y / pink.z * 1.3, "Mint must change the rendered body, not only a selector")
        XCTAssertGreaterThan(gold.x / gold.z, pink.x / pink.z * 1.6, "Gold must change the rendered body")
        XCTAssertGreaterThan(mint.y, mint.z * 1.05, "Mint must read green rather than cyan")
        XCTAssertGreaterThan(gold.x, gold.z * 1.7, "Gold must have a warm golden hue rather than a grey-blue body")
        XCTAssertGreaterThan(gold.y, gold.z * 1.25, "Gold must suppress the original blue pigment")
        model.setAppearance(PoulpiAppearance(accessory: .headband))
        var restoredMultiplier: SCNVector3?
        model.scene.rootNode.enumerateChildNodes { node, _ in
            guard let material = node.geometry?.firstMaterial,
                  material.shaderModifiers?[.surface]?.contains("poulpiPigment") == true else { return }
            restoredMultiplier = (material.value(forKey: "poulpiPigment") as? NSValue)?.scnVector3Value
        }
        let multiplier = try XCTUnwrap(restoredMultiplier)
        XCTAssertEqual(multiplier.x, 1)
        XCTAssertEqual(multiplier.y, 1)
        XCTAssertEqual(multiplier.z, 1, "Returning to Original must restore the exact shader pigment multiplier")
        let restored = renderer.snapshot(atTime: 0, with: CGSize(width: 160, height: 160), antialiasingMode: .multisampling4X)
        let before = try XCTUnwrap(original)
        let after = try rgbaPixels(restored)
        XCTAssertEqual(before.count, after.count)
        let errors = zip(before, after).map { pair in abs(Int(pair.0) - Int(pair.1)) }
        let meanError = Double(errors.reduce(0, +)) / Double(errors.count)
        let changedFraction = Double(errors.filter { $0 > 4 }.count) / Double(errors.count)
        // Metal's antialias sampling can change a few quantized edge pixels.
        // Compare decoded color instead of PNG compression bytes, with a mean
        // tolerance below one fifth of a single 8-bit channel step.
        XCTAssertLessThanOrEqual(meanError, 0.2, "Original must restore the visible pigment within subpixel rendering noise")
        XCTAssertLessThanOrEqual(changedFraction, 0.001, "Meaningful color differences must not hide inside the average")
    }

    private func rgbaPixels(_ image: UIImage) throws -> [UInt8] {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: width, height: height,
                                                 bitsPerComponent: 8, bytesPerRow: width * 4,
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }

    private func opaqueColorTotals(_ image: UIImage) throws -> SIMD3<Double> {
        let pixels = try rgbaPixels(image)
        var totals = SIMD3<Double>.zero
        var opaque = 0
        for index in stride(from: 0, to: pixels.count, by: 4) where pixels[index + 3] > 200 {
            totals += SIMD3(Double(pixels[index]), Double(pixels[index + 1]), Double(pixels[index + 2]))
            opaque += 1
        }
        XCTAssertGreaterThan(opaque, pixels.count / 4 / 8, "The real model must render a substantial visible silhouette")
        return totals
    }

    func testCosmeticsKeepTheSculptAndEyesAndEquipOneAttachment() {
        let rig = PoulpiRig()
        var skinnedGeometry: [SCNGeometry] = []
        var irisTextures: [UIImage] = []
        rig.node.enumerateChildNodes { node, _ in
            if node.skinner != nil, let geometry = node.geometry { skinnedGeometry.append(geometry) }
            if let image = node.geometry?.firstMaterial?.diffuse.contents as? UIImage { irisTextures.append(image) }
        }
        XCTAssertEqual(skinnedGeometry.count, 2)
        XCTAssertFalse(irisTextures.isEmpty)
        let accessory = rig.node.childNode(withName: "poulpi-accessory", recursively: true)!
        XCTAssertEqual(accessory.childNodes.count, 0)
        rig.setAppearance(PoulpiAppearance(color: .mint, accessory: .crown))
        XCTAssertEqual(accessory.childNodes.count, 11)
        rig.setAppearance(PoulpiAppearance(color: .gold, accessory: .headband))
        XCTAssertEqual(accessory.childNodes.count, 4, "Equipping a headband replaces the crown")
        rig.setAppearance(PoulpiAppearance(color: .coral, accessory: .star))
        XCTAssertEqual(accessory.childNodes.count, 1)
        rig.setAppearance(PoulpiAppearance())
        XCTAssertEqual(accessory.childNodes.count, 0)
        var currentGeometry: [SCNGeometry] = []
        var currentTextures: [UIImage] = []
        rig.node.enumerateChildNodes { node, _ in
            if node.skinner != nil, let geometry = node.geometry { currentGeometry.append(geometry) }
            if let image = node.geometry?.firstMaterial?.diffuse.contents as? UIImage { currentTextures.append(image) }
        }
        XCTAssertEqual(currentGeometry.count, skinnedGeometry.count)
        for (old, new) in zip(skinnedGeometry, currentGeometry) { XCTAssertTrue(old === new) }
        XCTAssertEqual(currentTextures.count, irisTextures.count)
        for (old, new) in zip(irisTextures, currentTextures) { XCTAssertTrue(old === new) }
    }

    func testUnchangedPoseDoesNotRewritePositionsAndScales() {
        let rig = PoulpiRig()
        rig.animate(0)
        let writes = OSAllocatedUnfairLock(initialState: 0)
        var observations: [NSKeyValueObservation] = []
        rig.node.enumerateChildNodes { node, _ in
            observations.append(node.observe(\.position) { _, _ in writes.withLock { $0 += 1 } })
            observations.append(node.observe(\.scale) { _, _ in writes.withLock { $0 += 1 } })
        }
        // No elapsed time and no changed inputs: the visible pose is identical.
        for _ in 0..<120 { rig.animate(0) }
        XCTAssertEqual(writes.withLock { $0 }, 0, "Unchanged transforms must not dirty SceneKit nodes every frame")
        withExtendedLifetime(observations) {}
    }

    func testEveryMoodMovesFaceAndAllEightTentaclesThroughItsReaction() throws {
        let rig = PoulpiRig()
        let pupils = try ["poulpi-pupil-left", "poulpi-pupil-right"].map { try XCTUnwrap(rig.node.childNode(withName: $0, recursively: true)) }
        let arms = try (0..<8).map { try XCTUnwrap(rig.node.childNode(withName: "poulpi-arm-\($0)-joint-0", recursively: true)) }
        let mouth = try XCTUnwrap(rig.node.childNode(withName: "poulpi-mouth", recursively: true))
        let cavity = try XCTUnwrap(rig.node.childNode(withName: "poulpi-mouth-cavity", recursively: true))
        var clock: CGFloat = 0
        for mood in LisaMascotMood.allCases {
            clock += 0.02
            rig.play(mood, animated: true)
            rig.animate(clock.truncatingRemainder(dividingBy: 24))
            let initialPupils = try pupils.map(irisRotation)
            let initialArms = arms.map(\.simdOrientation.vector)
            let initialMouth = mouth.scale
            clock += CGFloat(mood.reactionDuration) * 0.37
            rig.animate(clock.truncatingRemainder(dividingBy: 24))
            let laterPupils = try pupils.map(irisRotation)
            XCTAssertTrue(zip(initialPupils, laterPupils).contains { differs($0.0, $0.1) }, "\(mood) must move its gaze on the eye surface")
            for (index, arm) in arms.enumerated() {
                XCTAssertNotEqual(initialArms[index], arm.simdOrientation.vector, "\(mood) must articulate arm \(index)")
            }
            if mood == .surprised || mood == .celebrating || mood == .sneeze {
                XCTAssertFalse(cavity.isHidden, "\(mood) must reveal an actual mouth opening")
                XCTAssertGreaterThan(cavity.scale.y, 0.01)
                XCTAssertNotEqual(initialMouth.y, mouth.scale.y)
            }
        }
    }

    func testWinkUsesIndependentEyelidsAndStaticPoseKeepsExpression() throws {
        let rig = PoulpiRig()
        rig.play(.idle, animated: false)
        let idlePupil = try XCTUnwrap(rig.node.childNode(withName: "poulpi-pupil-left", recursively: true))
        let idleRotation = try irisRotation(of: idlePupil)
        rig.play(.peek, animated: false)
        let eyes = try ["poulpi-pupil-left", "poulpi-pupil-right"].map { try XCTUnwrap(rig.node.childNode(withName: $0, recursively: true)) }
        let cavity = try XCTUnwrap(rig.node.childNode(withName: "poulpi-mouth-cavity", recursively: true))
        XCTAssertTrue(differs(idleRotation, try irisRotation(of: eyes[0])), "Peek keeps a directed gaze in the static pose")
        XCTAssertTrue(cavity.isHidden)
        rig.play(.surprised, animated: false)
        XCTAssertFalse(cavity.isHidden, "Reduce Motion still shows the surprised expression")
        XCTAssertGreaterThan(cavity.scale.y, 0.04)
        let surprisedPupilScale = try irisAngularScale(of: eyes[0])
        rig.play(.nervous, animated: false)
        XCTAssertGreaterThan(surprisedPupilScale, try irisAngularScale(of: eyes[0]), "Surprise widens the pupils while nervousness contracts them")
        rig.play(.surprised, animated: false)
        rig.play(.peek, animated: true)
        rig.animate(0.5)
        let eyelidNodes = rig.node.childNodes.flatMap { $0.childNodes }.flatMap { $0.childNodes }.filter { $0.morpher != nil }
        XCTAssertEqual(eyelidNodes.count, 2)
        let first = eyelidNodes[0].morpher?.weights.map(\.floatValue)
        let second = eyelidNodes[1].morpher?.weights.map(\.floatValue)
        XCTAssertNotEqual(first, second, "A wink must close one eyelid independently")
    }

    func testRenderedMoodsKeepTheWholeSculptInFrameAtStartAccentAndSettle() throws {
        let rig = PoulpiRig()
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.rootNode.addChildNode(rig.node)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 1.9
        camera.position = SCNVector3(0, 0.6, 5)
        camera.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(camera)
        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.intensity = 220
        light.position = SCNVector3(0, 2, 4)
        scene.rootNode.addChildNode(light)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 85
        scene.rootNode.addChildNode(ambient)
        scene.isPaused = true
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        var clock: CGFloat = 0
        for mood in LisaMascotMood.allCases {
            rig.play(mood, animated: true)
            let startTime = clock
            for (label, fraction) in [("start", 0.02), ("accent", 0.37), ("settle", 0.86)] {
                clock = startTime + CGFloat(mood.reactionDuration * fraction)
                rig.animate(clock.truncatingRemainder(dividingBy: 24))
                let image = renderer.snapshot(atTime: TimeInterval(clock), with: CGSize(width: 240, height: 240), antialiasingMode: .multisampling4X)
                let pixels = try rgbaPixels(image)
                let width = 240
                let background = Array(pixels[0..<4])
                func difference(_ offset: Int) -> Int {
                    (0..<4).reduce(0) { $0 + abs(Int(pixels[offset + $1]) - Int(background[$1])) }
                }
                let visible = stride(from: 0, to: pixels.count, by: 4).filter { difference($0) > 45 }.count
                XCTAssertGreaterThan(visible, 3_000, "\(mood) \(label) must render a recognizable sculpt")
                for y in 0..<width where y < 2 || y >= width - 2 {
                    for x in 0..<width {
                        XCTAssertLessThan(difference((y * width + x) * 4), 45, "\(mood) \(label) clips vertically")
                    }
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "Poulpi-\(mood.rawValue)-\(label)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            clock += 0.02
        }
    }

    func testReactionClockContinuesAcrossSceneKitActionWrap() throws {
        let rig = PoulpiRig()
        rig.animate(23.8)
        rig.play(.surprised, animated: true)
        let cavity = try XCTUnwrap(rig.node.childNode(withName: "poulpi-mouth-cavity", recursively: true))
        rig.animate(23.9)
        let beforeWrap = cavity.scale.y
        rig.animate(0.1)
        let afterWrap = cavity.scale.y
        XCTAssertGreaterThan(afterWrap, beforeWrap, "The expression timeline must continue through the 24-second action boundary")
    }

    func testStaticPoseThenResumeRestoresAnimatedFace() {
        let rig = PoulpiRig()
        rig.play(.celebrating, animated: true)
        rig.animate(1)
        var animated: [SCNVector3] = []
        rig.node.enumerateChildNodes { node, _ in animated.append(node.position) }
        rig.play(.sleepy, animated: false)
        rig.play(.celebrating, animated: true)
        rig.animate(1)
        var resumed: [SCNVector3] = []
        rig.node.enumerateChildNodes { node, _ in resumed.append(node.position) }
        XCTAssertEqual(animated.count, resumed.count)
        for (a, b) in zip(animated, resumed) {
            XCTAssertEqual(a.x, b.x, accuracy: 0.00001)
            XCTAssertEqual(a.y, b.y, accuracy: 0.00001)
            XCTAssertEqual(a.z, b.z, accuracy: 0.00001)
        }
    }
}
