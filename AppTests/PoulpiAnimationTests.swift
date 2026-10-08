import XCTest
import SceneKit
import UIKit
import SudokuCore
@testable import SudokuLisa

@MainActor
final class PoulpiAnimationTests: XCTestCase {
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
        var writes = 0
        var observations: [NSKeyValueObservation] = []
        rig.node.enumerateChildNodes { node, _ in
            observations.append(node.observe(\.position) { _, _ in writes += 1 })
            observations.append(node.observe(\.scale) { _, _ in writes += 1 })
        }
        // No elapsed time and no changed inputs: the visible pose is identical.
        for _ in 0..<120 { rig.animate(0) }
        XCTAssertEqual(writes, 0, "Unchanged transforms must not dirty SceneKit nodes every frame")
        withExtendedLifetime(observations) {}
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
