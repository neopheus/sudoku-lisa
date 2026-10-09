import XCTest
import SceneKit
import UIKit
@testable import SudokuLisa

/// Reproducible close-ups of the actual articulated eyes. Attachment names are
/// stable so two xcresult bundles can be compared before and after a sculpt fix.
@MainActor
final class PoulpiEyeRenderingTests: XCTestCase {
    private func makeStage() -> (rig: PoulpiRig, renderer: SCNRenderer) {
        let rig = PoulpiRig()
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        scene.rootNode.addChildNode(rig.node)

        let target = SCNVector3(0, 0.46, 0.62)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 0.55
        camera.position = SCNVector3(0, 0.46, 4)
        camera.look(at: target)
        scene.rootNode.addChildNode(camera)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.intensity = 220
        key.position = SCNVector3(0, 2, 4)
        scene.rootNode.addChildNode(key)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 85
        scene.rootNode.addChildNode(ambient)

        // The test drives the action clock explicitly for identical frames.
        scene.isPaused = true
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        return (rig, renderer)
    }

    @discardableResult
    private func capture(_ name: String, using renderer: SCNRenderer) -> UIImage {
        let image = renderer.snapshot(
            atTime: 0,
            with: CGSize(width: 512, height: 384),
            antialiasingMode: .multisampling4X
        )
        let attachment = XCTAttachment(image: image)
        attachment.name = "PoulpiEye-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    private struct Pixels {
        let rgba: [UInt8]
        let width: Int
        let height: Int
        let flipped: Bool

        init(_ image: UIImage) throws {
            let cgImage = try XCTUnwrap(image.cgImage)
            let imageWidth = cgImage.width
            let imageHeight = cgImage.height
            var bytes = [UInt8](repeating: 0, count: imageWidth * imageHeight * 4)
            try bytes.withUnsafeMutableBytes { storage in
                let context = try XCTUnwrap(CGContext(
                    data: storage.baseAddress, width: imageWidth, height: imageHeight,
                    bitsPerComponent: 8, bytesPerRow: imageWidth * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ))
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
            }
            // CoreGraphics bitmap rows can be inverted relative to the image
            // attachment. The mouth's orange pigment identifies the lower half.
            func orangeCount(_ rows: Range<Int>) -> Int {
                var count = 0
                for y in rows {
                    for x in 205..<310 {
                        let i = (y * imageWidth + x) * 4
                        if bytes[i] > 180, bytes[i + 1] > 45, bytes[i + 1] < 190,
                           bytes[i + 2] < 110 { count += 1 }
                    }
                }
                return count
            }
            let rowsAreFlipped = orangeCount(0..<(imageHeight / 2)) > orangeCount((imageHeight / 2)..<imageHeight)
            self.rgba = bytes
            self.width = imageWidth
            self.height = imageHeight
            self.flipped = rowsAreFlipped
        }

        func color(_ x: Int, _ visualY: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
            let y = flipped ? height - visualY - 1 : visualY
            let i = (y * width + x) * 4
            return (rgba[i], rgba[i + 1], rgba[i + 2])
        }

        func isIvory(_ x: Int, _ y: Int) -> Bool {
            let c = color(x, y)
            // Bright lavender lid highlights can exceed the RGB thresholds;
            // ivory is neutral or warm, while those highlights skew blue.
            return c.r > 205 && c.g > 200 && c.b > 170
                && Int(c.b) <= Int(c.g) + 20 && Int(c.b) <= Int(c.r) + 15
        }

        func isIris(_ x: Int, _ y: Int) -> Bool {
            let c = color(x, y)
            return c.r < 80 && c.g < 110 && c.b < 190
        }

        func innerWhiteGap(onLeftEye: Bool, y: Int) -> Int {
            if onLeftEye {
                guard let edge = (90..<230).last(where: { isIris($0, y) }) else { return 0 }
                return ((edge + 1)..<min(245, edge + 16)).filter { isIvory($0, y) }.count
            }
            guard let edge = (280..<420).first(where: { isIris($0, y) }) else { return 0 }
            return (max(265, edge - 15)..<edge).filter { isIvory($0, y) }.count
        }

        func ivoryCount(x: Range<Int>, y: Range<Int>) -> Int {
            var count = 0
            for row in y {
                for column in x where isIvory(column, row) { count += 1 }
            }
            return count
        }

        func exposedEyeCount(x: Range<Int>, y: Range<Int>) -> Int {
            var count = 0
            for row in y {
                for column in x where isIvory(column, row) || isIris(column, row) { count += 1 }
            }
            return count
        }

        func upperExposedEdge(x: Int, y: Range<Int>) -> Int? {
            y.first { isIvory(x, $0) || isIris(x, $0) }
        }
    }

    private func component(_ source: SCNGeometrySource, vector: Int, component: Int) -> Float {
        let offset = source.dataOffset + vector * source.dataStride + component * source.bytesPerComponent
        return source.data.withUnsafeBytes { bytes in
            if source.bytesPerComponent == 8 {
                return Float(bytes.loadUnaligned(fromByteOffset: offset, as: Double.self))
            }
            return bytes.loadUnaligned(fromByteOffset: offset, as: Float.self)
        }
    }

    private func cornerAnchors(in geometry: SCNGeometry) throws -> (left: SIMD3<Float>, right: SIMD3<Float>) {
        let positions = try XCTUnwrap(geometry.sources(for: .vertex).first)
        let coordinates = try XCTUnwrap(geometry.sources(for: .texcoord).first)
        XCTAssertEqual(positions.vectorCount, coordinates.vectorCount)
        var left: [SIMD3<Float>] = [], right: [SIMD3<Float>] = []
        for index in 0..<min(positions.vectorCount, coordinates.vectorCount) {
            let u = component(coordinates, vector: index, component: 0)
            guard abs(u) > 0.9999 else { continue }
            let point = SIMD3<Float>(
                component(positions, vector: index, component: 0),
                component(positions, vector: index, component: 1),
                component(positions, vector: index, component: 2)
            )
            if u < 0 { left.append(point) } else { right.append(point) }
        }
        let firstLeft = try XCTUnwrap(left.first)
        let firstRight = try XCTUnwrap(right.first)
        XCTAssertGreaterThan(simd_distance(firstLeft, firstRight), 0.35)
        for corner in left { XCTAssertLessThan(simd_distance(corner, firstLeft), 0.0002) }
        for corner in right { XCTAssertLessThan(simd_distance(corner, firstRight), 0.0002) }
        return (firstLeft, firstRight)
    }

    func testEyeCloseUpsAndPupilContainment() throws {
        let (rig, renderer) = makeStage()
        let leftPupil = try XCTUnwrap(rig.node.childNode(withName: "poulpi-pupil-left", recursively: true))
        let rightPupil = try XCTUnwrap(rig.node.childNode(withName: "poulpi-pupil-right", recursively: true))

        // Identical frontal camera and light isolate each held expression.
        var staticImages: [String: UIImage] = [:]
        for (name, mood) in [
            ("front-idle-static", LisaMascotMood.idle),
            ("front-surprised-static", .surprised),
            ("front-nervous-static", .nervous),
            ("front-peek-static", .peek),
            ("front-sleepy-static", .sleepy)
        ] {
            rig.play(mood, animated: false)
            staticImages[name] = capture(name, using: renderer)
        }

        let surprisedPixels = try Pixels(XCTUnwrap(staticImages["front-surprised-static"]))
        for y in [195, 205, 215] {
            // One fully ivory pixel is sufficient at the near-tangent top rim;
            // the uncoupled baseline had none at all on these scan lines.
            XCTAssertGreaterThanOrEqual(surprisedPixels.innerWhiteGap(onLeftEye: true, y: y), 1,
                                        "Surprised left iris must keep visible ivory on its inner edge at y=\(y)")
            XCTAssertGreaterThanOrEqual(surprisedPixels.innerWhiteGap(onLeftEye: false, y: y), 1,
                                        "Surprised right iris must keep visible ivory on its inner edge at y=\(y)")
        }
        // Keep geometry and rendered-mask checks after the captures so failures
        // still leave a reviewable baseline image set in the result bundle.
        rig.play(.surprised, animated: false)
        for pupil in [leftPupil, rightPupil] {
            let material = try XCTUnwrap(pupil.childNodes.first?.geometry?.firstMaterial)
            let side = try XCTUnwrap(material.value(forKey: "irisSide") as? NSNumber).floatValue
            let rotation = try XCTUnwrap((material.value(forKey: "irisRotation") as? NSValue)?.scnVector4Value)
            let angularScale = try XCTUnwrap(material.value(forKey: "irisAngularScale") as? NSNumber).floatValue
            let quaternion = simd_quatf(ix: rotation.x, iy: rotation.y, iz: rotation.z, r: rotation.w)
            for index in 0..<64 {
                let angle = Float(index) * 2 * .pi / 64
                for (sampleRadius, minimumForward) in [(Float(1), Float(0)), (Float(0.9), Float(0.05))] {
                    let source = SIMD2<Float>(cos(angle) * 0.125 * sampleRadius,
                                              sin(angle) * 0.1625 * sampleRadius)
                    let projected = PoulpiRig.EyeSurface.projectedPoint(
                        source, side: side, rotation: quaternion, angularScale: angularScale
                    )
                    let forward = (projected.z - 0.012) / PoulpiRig.EyeSurface.radius.z
                    XCTAssertGreaterThan(forward, minimumForward,
                                         "\(pupil.name ?? "pupil") wraps a visible iris sample behind the eye")
                }
            }
        }

        for (name, yaw) in [("yaw-left-surprised-static", Float(-0.45)),
                            ("yaw-right-surprised-static", Float(0.45))] {
            rig.node.eulerAngles.y = yaw
            capture(name, using: renderer)
        }
        rig.node.eulerAngles.y = 0

        // The same rig is driven through a real mood transition, then a wink.
        rig.play(.idle, animated: false)
        rig.play(.surprised, animated: true)
        for (name, time) in [("front-surprised-transition-start", CGFloat(0.03)),
                             ("front-surprised-transition-accent", CGFloat(0.67)),
                             ("front-surprised-transition-settle", CGFloat(1.55))] {
            rig.animate(time)
            capture(name, using: renderer)
        }
        rig.play(.idle, animated: false)
        rig.play(.peek, animated: true)
        rig.animate(CGFloat(LisaMascotMood.peek.reactionDuration * 0.47))
        let winkPeak = try Pixels(capture("front-peek-wink-peak", using: renderer))
        XCTAssertLessThan(winkPeak.ivoryCount(x: 70..<220, y: 125..<285), 50,
                          "The wink peak must truly close the left eye")
        XCTAssertGreaterThan(winkPeak.ivoryCount(x: 295..<445, y: 125..<285), 2_000,
                             "The other eye must stay open during the wink")
    }

    func testEyelidClosureStagesFrontAndProfile() throws {
        let (rig, renderer) = makeStage()
        rig.play(.idle, animated: false)
        let stages: [(name: String, closure: Float)] = [
            ("00", 0), ("25", 0.25), ("50", 0.5), ("75", 0.75), ("100", 1)
        ]
        var front: [String: Pixels] = [:]

        for stage in stages {
            rig.setInspectionEyelids(stage.closure)
            front[stage.name] = try Pixels(capture("lid-front-\(stage.name)", using: renderer))
        }
        rig.node.eulerAngles.y = 0.45
        for stage in stages {
            rig.setInspectionEyelids(stage.closure)
            capture("lid-profile-\(stage.name)", using: renderer)
        }

        // The actual morpher must progressively cover both eyes, with no
        // second opening or exposed ivory left when the lids meet.
        for eye in [70..<220, 295..<445] {
            let areas = try stages.map { stage in
                try XCTUnwrap(front[stage.name]).exposedEyeCount(x: eye, y: 125..<285)
            }
            XCTAssertGreaterThan(areas[0], areas[1], "The first quarter of closure must move the lid")
            for index in 1..<areas.count {
                XCTAssertLessThanOrEqual(areas[index], areas[index - 1] + 80,
                                         "Exposed eye must not reopen during closure at stage \(stages[index].name)")
            }
            let fullyClosed = try XCTUnwrap(front["100"])
            XCTAssertLessThan(fullyClosed.ivoryCount(x: eye, y: 125..<285), 50,
                              "A fully closed lid must cover the ivory shell")
        }
        let halfway = try XCTUnwrap(front["50"])
        for columns in [[90, 140, 190], [320, 370, 420]] {
            let edge = try columns.map { try XCTUnwrap(halfway.upperExposedEdge(x: $0, y: 125..<285)) }
            let arc = Float(edge[1]) - Float(edge[0] + edge[2]) / 2
            XCTAssertLessThan(arc, -5,
                              "At half closure the exposed eye needs a curved lid edge, not a straight chord")
        }
    }

    func testLidMorphTargetsKeepBothEyeCornersAnchored() throws {
        let rig = PoulpiRig()
        var lids: [SCNNode] = []
        rig.node.enumerateChildNodes { node, _ in
            if node.morpher != nil { lids.append(node) }
        }
        XCTAssertEqual(lids.count, 2)
        for lid in lids {
            let base = try XCTUnwrap(lid.geometry)
            let corners = try cornerAnchors(in: base)
            let morpher = try XCTUnwrap(lid.morpher)
            XCTAssertFalse(morpher.targets.isEmpty)
            for target in morpher.targets {
                let current = try cornerAnchors(in: target)
                XCTAssertLessThan(simd_distance(corners.left, current.left), 0.0002,
                                  "The outer lid corner must stay attached through the whole morph")
                XCTAssertLessThan(simd_distance(corners.right, current.right), 0.0002,
                                  "The inner lid corner must stay attached through the whole morph")
            }
        }
    }
}
