#if DEBUG
import SceneKit
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Development-only export: icons and stickers share the actual in-game model.
@MainActor
enum OctopusAssetExporter {
    static func exportIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--export-octopus-assets") else { return }
        do {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("OctopusAssets", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let model = OctopusModel()
            model.setMood(.happy, animated: false)
            model.setMotionEnabled(false)
            model.scene.isPaused = true
            let renderer = SCNRenderer(device: nil, options: nil)
            renderer.scene = model.scene
            renderer.pointOfView = model.scene.rootNode.childNodes.first { $0.camera != nil }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let sizes = [("AppIcon.png", 1024, 1024),
                         ("messages-iphone-58x58.png", 58, 58), ("messages-iphone-87x87.png", 87, 87),
                         ("messages-iphone-120x90.png", 120, 90), ("messages-iphone-180x135.png", 180, 135),
                         ("messages-ipad-58x58.png", 58, 58), ("messages-ipad-134x100.png", 134, 100),
                         ("messages-ipad-148x110.png", 148, 110), ("messages-universal-54x40.png", 54, 40),
                         ("messages-universal-81x60.png", 81, 60), ("messages-universal-64x48.png", 64, 48),
                         ("messages-universal-96x72.png", 96, 72), ("messages-ios-marketing-1024x768.png", 1024, 768)]
            for (name, width, height) in sizes {
                let size = CGSize(width: width, height: height)
                let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
                let result = UIGraphicsImageRenderer(size: size, format: format).image { context in
                    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                        UIColor(red: 0.80, green: 0.95, blue: 1, alpha: 1).cgColor,
                        UIColor(red: 0.99, green: 0.82, blue: 0.94, alpha: 1).cgColor
                    ] as CFArray, locations: [0, 1])!
                    context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                try writeOpaquePNG(result, width: width, height: height, to: directory.appendingPathComponent(name))
            }
            for (name, mood) in [("lisa-smile", LisaMascotMood.idle), ("lisa-bravo", .happy), ("lisa-zen", .sleepy), ("lisa-heart", .encouraging)] {
                model.setMood(mood, animated: false)
                let image = renderer.snapshot(atTime: 0, with: CGSize(width: 408, height: 408), antialiasingMode: .multisampling4X)
                try image.pngData()!.write(to: directory.appendingPathComponent(name + ".png"))
            }
            print("OCTOPUS_ASSETS_EXPORTED \(directory.path)")
        } catch { print("OCTOPUS_ASSETS_EXPORT_FAILED \(error)") }
    }

    /// UIImage.pngData may retain an alpha channel even for an opaque renderer.
    /// Encode an explicitly RGB bitmap so App Store icon validation sees no alpha.
    private static func writeOpaquePNG(_ image: UIImage, width: Int, height: Int, to url: URL) throws {
        guard let source = image.cgImage,
              let bitmap = CGContext(data: nil, width: width, height: height,
                                     bitsPerComponent: 8, bytesPerRow: width * 4,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw NSError(domain: "OctopusAssetExporter", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to create opaque icon bitmap"])
        }
        bitmap.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let rgbImage = bitmap.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "OctopusAssetExporter", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to create PNG destination"])
        }
        CGImageDestinationAddImage(destination, rgbImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "OctopusAssetExporter", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to encode opaque icon PNG"])
        }
    }
}
#endif
