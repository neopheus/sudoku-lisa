import XCTest
import SwiftUI
@testable import SudokuLisa

@MainActor
final class DecorRenderingTests: XCTestCase {
    private var capturedMismatch = false
    func testAnimatedDecorMatchesOriginalAtFixedPhases() throws {
        for scheme in [ColorScheme.light, .dark] {
            for time in [0.0, 0.17, 1.3, 3.82, 17.6] {
                try compare(LisaButterfly(time: time, color: .orange),
                            OriginalButterfly(time: time, color: .orange), scheme: scheme)
                try compare(LisaSweet(color: .pink, rotation: time * 12).frame(width: 58, height: 58),
                            OriginalSweet(color: .pink, rotation: time * 12).frame(width: 58, height: 58), scheme: scheme)
                for strong in [false, true] {
                    try compare(LisaHaloRays(size: 170, color: .yellow, strong: strong)
                        .rotationEffect(.degrees(time * 6)),
                        OriginalHaloRays(size: 170, strong: strong, angle: time * 6), scheme: scheme)
                }
            }
        }
    }

    private func compare<A: View, B: View>(_ actual: A, _ expected: B, scheme: ColorScheme,
                                          file: StaticString = #filePath, line: UInt = #line) throws {
        var rendered: [CGImage] = []
        func pixels<V: View>(_ view: V) throws -> [UInt8] {
            let renderer = ImageRenderer(content: view.frame(width: 220, height: 220)
                .environment(\.colorScheme, scheme).environment(\.displayScale, 3))
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.cgImage)
            rendered.append(image)
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            try bytes.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width,
                    height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            return bytes
        }
        let a = try pixels(actual), b = try pixels(expected)
        XCTAssertEqual(a.count, b.count, file: file, line: line)
        let error = zip(a, b).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(a.count)
        if error >= 0.15, !capturedMismatch {
            capturedMismatch = true
            for (name, image) in zip(["Actual", "Reference"], rendered) {
                let attachment = XCTAttachment(image: UIImage(cgImage: image))
                attachment.name = name
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        // Allows subpixel matrix rounding, but catches changed geometry or layout.
        XCTAssertLessThan(error, 0.15, "Mean pixel error on 0...255: \(error)", file: file, line: line)
    }
}

private struct OriginalHaloRays: View {
    let size: CGFloat
    let strong: Bool
    let angle: Double
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Capsule().fill(Color.yellow.opacity(strong ? 0.26 : 0.14))
                    .frame(width: size * 0.06, height: size * 0.22)
                    .offset(y: -size * 0.34)
                    .rotationEffect(.degrees(Double(index) * 30 + angle))
            }
        }.frame(width: size, height: size)
    }
}

// Frozen pre-optimization drawings: compare output, not SwiftUI's implementation details.
struct OriginalButterfly: View {
    var time: Double
    var color: Color
    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { wing in
                ZStack {
                    Ellipse().fill(color.gradient).frame(width: 15, height: 22).offset(y: -5)
                    Ellipse().fill(color.opacity(0.8).gradient).frame(width: 11, height: 14).offset(y: 8)
                    Ellipse().fill(.white.opacity(0.6)).frame(width: 4, height: 8).offset(y: -7)
                }
                .rotationEffect(.degrees(wing == 0 ? -28 : 28))
                .scaleEffect(x: time == 0 ? 0.8 : 0.35 + abs(sin(time * 7)) * 0.65, y: 1, anchor: wing == 0 ? .trailing : .leading)
                .offset(x: wing == 0 ? -8 : 8)
            }
            Capsule().fill(LisaTheme.accentInk).frame(width: 3, height: 19)
            Path { p in
                p.move(to: CGPoint(x: 18,y: 13)); p.addQuadCurve(to:CGPoint(x:13,y:5),control:CGPoint(x:18,y:5))
                p.move(to: CGPoint(x: 18,y: 13)); p.addQuadCurve(to:CGPoint(x:23,y:5),control:CGPoint(x:18,y:5))
            }.stroke(LisaTheme.accentInk,lineWidth:1)
        }.frame(width:36,height:36)
    }
}

/// A glossy striped sweet, also used as a rotating lollipop crown on the map.
struct OriginalSweet: View {
    var color: Color = LisaTheme.coral
    var rotation: Double = 0
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(color.gradient)
                ZStack {
                    ForEach(0..<6, id: \.self) { index in
                        Ellipse().fill(.white.opacity(0.65))
                            .frame(width: side * 0.23, height: side * 0.68)
                            .offset(y: -side * 0.21)
                            .rotationEffect(.degrees(Double(index) * 60))
                    }
                }.frame(width: side, height: side).rotationEffect(.degrees(rotation)).clipShape(Circle())
                Circle().strokeBorder(.white.opacity(0.8), lineWidth: 3)
                Ellipse().fill(.white.opacity(0.55)).frame(width: side * 0.35, height: side * 0.12)
                    .rotationEffect(.degrees(-25)).offset(x: -side * 0.13, y: -side * 0.25)
            }.frame(width: side, height: side)
                .shadow(color: color.opacity(0.25), radius: 4, y: 5)
        }
    }
}
