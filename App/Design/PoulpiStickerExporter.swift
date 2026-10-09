#if DEBUG
import SceneKit
import UIKit
import PoulpiStickers

/// Renders the in-game sculpt into transparent, square art for Messages and sharing.
@MainActor
enum PoulpiStickerExporter {
    private static let side = 512

    static func exportIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--export-poulpi-stickers") else { return }
        do {
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PoulpiStickers", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for sticker in PoulpiStickerCatalog.stickers {
                guard let mood = LisaMascotMood(rawValue: sticker.id) else {
                    throw ExportError.unknownMood(sticker.id)
                }
                let art = render(mood)
                guard let data = art.pngData() else { throw ExportError.encoding(mood.rawValue) }
                try data.write(to: folder.appendingPathComponent("poulpi-\(mood.rawValue).png"), options: .atomic)
            }
            let tray = render(.happy)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let small = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96), format: format).image { _ in
                tray.draw(in: CGRect(x: 0, y: 0, width: 96, height: 96))
            }
            guard let trayData = small.pngData() else { throw ExportError.encoding("tray") }
            try trayData.write(to: folder.appendingPathComponent("poulpi-tray.png"), options: .atomic)
            print("POULPI_STICKERS_EXPORTED \(folder.path)")
        } catch {
            print("POULPI_STICKERS_EXPORT_FAILED \(error)")
        }
    }

    private enum ExportError: Error { case encoding(String), unknownMood(String) }

    private struct Style {
        let symbol: String
        let color: UIColor
        let position: CGPoint
        let size: CGFloat
        let tilt: Float
        let lift: Float
        let yaw: Float
        let pitch: Float
    }

    private static func style(_ mood: LisaMascotMood) -> Style {
        let rose = UIColor(red: 1, green: 0.28, blue: 0.50, alpha: 1)
        let gold = UIColor(red: 1, green: 0.72, blue: 0.15, alpha: 1)
        let aqua = UIColor(red: 0.10, green: 0.78, blue: 0.91, alpha: 1)
        let lilac = UIColor(red: 0.61, green: 0.40, blue: 0.95, alpha: 1)
        let styles: [LisaMascotMood: Style] = [
            .idle: .init(symbol: "hand.wave.fill", color: aqua, position: CGPoint(x: 390, y: 115), size: 76, tilt: 0.03, lift: 0, yaw: 0, pitch: 0),
            .happy: .init(symbol: "heart.fill", color: rose, position: CGPoint(x: 390, y: 84), size: 86, tilt: -0.10, lift: 0.03, yaw: -0.12, pitch: 0),
            .thinking: .init(symbol: "lightbulb.fill", color: gold, position: CGPoint(x: 390, y: 80), size: 78, tilt: -0.13, lift: 0, yaw: 0.25, pitch: 0.04),
            .encouraging: .init(symbol: "hand.thumbsup.fill", color: gold, position: CGPoint(x: 398, y: 122), size: 82, tilt: 0.12, lift: 0.03, yaw: -0.18, pitch: 0),
            .sleepy: .init(symbol: "moon.stars.fill", color: lilac, position: CGPoint(x: 378, y: 76), size: 94, tilt: -0.12, lift: -0.06, yaw: 0, pitch: 0.05),
            .celebrating: .init(symbol: "party.popper.fill", color: gold, position: CGPoint(x: 405, y: 95), size: 94, tilt: 0.14, lift: 0.11, yaw: -0.10, pitch: 0),
            .pirouette: .init(symbol: "sparkles", color: gold, position: CGPoint(x: 388, y: 82), size: 97, tilt: 0.38, lift: 0.05, yaw: 0.47, pitch: 0.08),
            .wobble: .init(symbol: "scribble.variable", color: aqua, position: CGPoint(x: 385, y: 84), size: 93, tilt: -0.26, lift: -0.04, yaw: -0.15, pitch: 0),
            .peek: .init(symbol: "eye.fill", color: aqua, position: CGPoint(x: 399, y: 87), size: 80, tilt: -0.11, lift: -0.11, yaw: 0.35, pitch: 0),
            .jelly: .init(symbol: "drop.fill", color: rose, position: CGPoint(x: 389, y: 83), size: 80, tilt: 0.14, lift: -0.08, yaw: 0, pitch: 0),
            .swim: .init(symbol: "water.waves", color: aqua, position: CGPoint(x: 388, y: 370), size: 100, tilt: -0.29, lift: 0.07, yaw: -0.15, pitch: -0.18),
            .bow: .init(symbol: "sparkle", color: gold, position: CGPoint(x: 386, y: 122), size: 75, tilt: 0.06, lift: -0.08, yaw: 0, pitch: 0.35),
            .curious: .init(symbol: "questionmark.circle.fill", color: lilac, position: CGPoint(x: 393, y: 72), size: 86, tilt: 0.10, lift: 0, yaw: 0.32, pitch: 0),
            .giggle: .init(symbol: "face.smiling.inverse", color: gold, position: CGPoint(x: 385, y: 91), size: 80, tilt: 0.20, lift: 0.06, yaw: -0.13, pitch: 0),
            .rocket: .init(symbol: "flame.fill", color: gold, position: CGPoint(x: 265, y: 423), size: 84, tilt: -0.20, lift: 0.16, yaw: -0.22, pitch: -0.18),
            .chase: .init(symbol: "sparkle", color: rose, position: CGPoint(x: 395, y: 91), size: 82, tilt: -0.22, lift: 0.05, yaw: 0.28, pitch: 0),
            .moonwalk: .init(symbol: "moon.fill", color: gold, position: CGPoint(x: 390, y: 88), size: 85, tilt: -0.18, lift: 0, yaw: -0.42, pitch: 0),
            .juggle: .init(symbol: "circle.hexagongrid.fill", color: rose, position: CGPoint(x: 394, y: 77), size: 87, tilt: 0.15, lift: 0.04, yaw: 0, pitch: 0),
            .cloudHide: .init(symbol: "cloud.fill", color: aqua, position: CGPoint(x: 383, y: 91), size: 100, tilt: 0, lift: -0.13, yaw: 0.20, pitch: 0),
            .sneeze: .init(symbol: "wind", color: aqua, position: CGPoint(x: 390, y: 208), size: 85, tilt: -0.18, lift: -0.02, yaw: 0, pitch: -0.16),
            .tumble: .init(symbol: "arrow.triangle.2.circlepath", color: lilac, position: CGPoint(x: 393, y: 83), size: 82, tilt: 0.57, lift: 0, yaw: 0.33, pitch: 0),
            .balance: .init(symbol: "scalemass.fill", color: gold, position: CGPoint(x: 390, y: 88), size: 82, tilt: 0.21, lift: 0.02, yaw: 0, pitch: 0),
            .dizzy: .init(symbol: "hurricane", color: lilac, position: CGPoint(x: 391, y: 75), size: 89, tilt: -0.25, lift: -0.05, yaw: 0.16, pitch: 0),
            .superhero: .init(symbol: "bolt.shield.fill", color: gold, position: CGPoint(x: 394, y: 85), size: 95, tilt: -0.27, lift: 0.10, yaw: -0.20, pitch: -0.13)
        ]
        return styles[mood]!
    }

    private static func render(_ mood: LisaMascotMood) -> UIImage {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        let rig = PoulpiRig()
        let pose = style(mood)
        rig.play(mood, animated: false)
        // The static play path resets the arms. Step the same bounded animation
        // solver used in the app to settle each distinct gesture before capture.
        for tick in 0...48 { rig.animate(CGFloat(tick) / 20) }
        rig.node.eulerAngles = SCNVector3(pose.pitch, pose.yaw, pose.tilt)
        rig.node.position.y = pose.lift
        scene.rootNode.addChildNode(rig.node)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 1.72
        camera.position = SCNVector3(0, 1.3, 7)
        camera.look(at: SCNVector3(0, 0.15, 0))
        scene.rootNode.addChildNode(camera)
        for (point, power, color) in [
            (SCNVector3(-3, 4, 5), CGFloat(220), UIColor(red: 1, green: 0.96, blue: 0.91, alpha: 1)),
            (SCNVector3(3, 2, 2), CGFloat(95), UIColor(red: 0.78, green: 0.85, blue: 1, alpha: 1)),
            (SCNVector3(0, -3, 4), CGFloat(20), UIColor(red: 1, green: 0.94, blue: 0.82, alpha: 1))
        ] {
            let light = SCNNode()
            light.light = SCNLight()
            light.light?.type = .omni
            light.light?.intensity = power
            light.light?.color = color
            light.position = point
            scene.rootNode.addChildNode(light)
        }
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 85
        scene.rootNode.addChildNode(ambient)
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        let bounds = CGRect(x: 0, y: 0, width: CGFloat(side), height: CGFloat(side))
        let sculpt = renderer.snapshot(atTime: 0, with: bounds.size, antialiasingMode: .multisampling4X)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: bounds.size, format: format).image { _ in
            // Keep the violet sculpt legible on both dark and light chat themes.
            let silhouette = sculpt.withTintColor(.white, renderingMode: .alwaysOriginal)
            let outlineOffsets: [(CGFloat, CGFloat)] = [
                (-4, 0), (4, 0), (0, -4), (0, 4),
                (-3, -3), (3, -3), (-3, 3), (3, 3)
            ]
            for (dx, dy) in outlineOffsets {
                silhouette.draw(in: bounds.offsetBy(dx: dx, dy: dy))
            }
            sculpt.draw(in: bounds)
            drawAccent(pose)
        }
    }

    private static func drawAccent(_ pose: Style) {
        let point = pose.position
        let rect = CGRect(x: point.x - pose.size / 2, y: point.y - pose.size / 2,
                          width: pose.size, height: pose.size)
        let config = UIImage.SymbolConfiguration(pointSize: pose.size * 0.8, weight: .bold)
        if let symbol = UIImage(systemName: pose.symbol, withConfiguration: config)
            ?? UIImage(systemName: "sparkle", withConfiguration: config) {
            symbol.withTintColor(.white, renderingMode: .alwaysOriginal)
                .draw(in: rect.insetBy(dx: -3, dy: -3))
            let tinted = symbol.withTintColor(pose.color, renderingMode: .alwaysOriginal)
            tinted.draw(in: rect)
        }
        // A small pair of hand-drawn gleams ties the prop to the sculpt.
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(pose.color.withAlphaComponent(0.8).cgColor)
        let gleams: [(CGFloat, CGFloat, CGFloat)] = [(-50, -28, 5), (44, 39, 3.5)]
        for (dx, dy, radius) in gleams {
            context.fillEllipse(in: CGRect(x: point.x + dx, y: point.y + dy,
                                           width: radius * 2, height: radius * 2))
        }
    }
}
#endif
