import SwiftUI

private struct LisaMotionAllowedKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var lisaMotionAllowed: Bool {
        get { self[LisaMotionAllowedKey.self] }
        set { self[LisaMotionAllowedKey.self] = newValue }
    }
}

/// A local clock: scrolls out of view, covered tabs, background and accessibility all stop it.
/// Only the decorated view updates; the Sudoku state never subscribes to animation frames.
struct LisaMotionClock<Content: View>: View {
    var enabled: Bool
    var fps: Double
    let content: (Double) -> Content
    @EnvironmentObject private var store: LisaStore
    @Environment(\.lisaMotionAllowed) private var allowed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.lisaVisibleBounds) private var visibleBounds
    @State private var visible = false
    @State private var onScreen = true
    @State private var budgetClient = UUID()
    @ObservedObject private var budget = LisaRenderBudget.shared

    init(enabled: Bool = true, fps: Double = 30, @ViewBuilder content: @escaping (Double) -> Content) {
        self.enabled = enabled
        self.fps = fps
        self.content = content
    }

    var body: some View {
        let running = enabled && allowed && visible && onScreen && store.settings.animatedDecor && !reduceMotion && scenePhase == .active
        TimelineView(.animation(minimumInterval: 1 / budget.cadence(fps), paused: !running)) { context in
            content(running ? context.date.timeIntervalSinceReferenceDate : 0)
                .environment(\.lisaMotionAllowed, running)
        }
        .background {
            GeometryReader { proxy in
                Color.clear.onChange(of: visibleBounds.map { proxy.frame(in: .global).intersects($0) } ?? true, initial: true) { _, intersects in
                    onScreen = intersects
                }
            }
        }
        .onChange(of: running, initial: true) { _, active in budget.setActive(active, client: budgetClient) }
        .onAppear { visible = true }
        .onDisappear { visible = false; budget.setActive(false, client: budgetClient) }
    }
}

private struct LisaFloat: ViewModifier {
    let amplitude: CGFloat
    let tilt: Double
    let period: Double
    let phase: Double
    let enabled: Bool
    func body(content: Content) -> some View {
        LisaMotionClock(enabled: enabled) { time in
            let wave = time == 0 ? 0 : sin(time * .pi * 2 / period + phase)
            content.offset(y: wave * amplitude).rotationEffect(.degrees(wave * tilt))
        }
    }
}

extension View {
    func lisaFloat(amplitude: CGFloat = 4, tilt: Double = 3, period: Double = 4, phase: Double = 0, enabled: Bool = true) -> some View {
        modifier(LisaFloat(amplitude: amplitude, tilt: tilt, period: period, phase: phase, enabled: enabled))
    }
}

struct LisaShimmer: View {
    var radius: CGFloat = 23
    var phase: Double = 0
    @Environment(\.isEnabled) private var enabled
    var body: some View {
        LisaMotionClock(enabled: enabled, fps: 24) { time in
            GeometryReader { geometry in
                let cycle = (time + phase).truncatingRemainder(dividingBy: 5.5)
                let travel = cycle / 1.6
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * 0.25, height: geometry.size.height * 2)
                    .rotationEffect(.degrees(22))
                    .offset(x: geometry.size.width * (travel * 1.6 - 0.35), y: -geometry.size.height * 0.5)
                    .opacity(time > 0 && cycle < 1.6 ? 1 : 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Rotating sunbeams and orbiting stars, with no flashing or change to hit targets.
struct LisaMagicHalo: View {
    var color: Color = LisaTheme.yellow
    var strong = false
    var body: some View {
        LisaMotionClock(fps: 60) { time in
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                ZStack {
                    Circle().fill(RadialGradient(colors: [color.opacity(strong ? 0.5 : 0.28), color.opacity(0)], center: .center, startRadius: 0, endRadius: size * 0.5))
                    LisaHaloRays(size: size, color: color, strong: strong).equatable()
                        .rotationEffect(.degrees(time.truncatingRemainder(dividingBy: 60) * 6))
                    ForEach(0..<5, id: \.self) { index in
                        let angle = Double(index) * .pi * 0.4 + time * (strong ? 0.65 : 0.35)
                        Image(systemName: index.isMultiple(of: 2) ? "star.fill" : "sparkle")
                            .font(.system(size: strong ? 19 : 13, weight: .bold))
                            .foregroundStyle(index.isMultiple(of: 2) ? color : .white)
                            .shadow(color: .white.opacity(0.6), radius: 5)
                            .rotationEffect(.degrees(time * 9))
                            .offset(x: cos(angle) * size * 0.46, y: sin(angle) * size * 0.40)
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Rotate the fixed fan once instead of updating twelve separate ray transforms.
struct LisaHaloRays: View, Equatable {
    let size: CGFloat
    let color: Color
    let strong: Bool
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Capsule().fill(color.opacity(strong ? 0.26 : 0.14))
                    .frame(width: size * 0.06, height: size * 0.22)
                    .offset(y: -size * 0.34)
                    .rotationEffect(.degrees(Double(index) * 30))
            }
        }.frame(width: size, height: size)
    }
}

/// Soft, asymmetric cumulus: shaded cloud mass, sunlit lobes and wispy base.
struct LisaCloud: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var scale
    var body: some View {
        GeometryReader { proxy in
            LisaCloudImage(size: proxy.size, scheme: scheme, scale: scale).equatable()
        }
    }
}

/// Keep the original Canvas at native resolution, but rasterize only on a
/// size/theme/scale change. Animated parents only composite this image.
private struct LisaCloudImage: View, Equatable {
    let size: CGSize
    let scheme: ColorScheme
    let scale: CGFloat
    var body: some View {
        if let image = LisaCloudCache.image(size: size, scheme: scheme, scale: scale) {
            Image(uiImage: image).resizable().frame(width: size.width, height: size.height)
        } else {
            LisaCloudDrawing(scheme: scheme)
        }
    }
}

@MainActor
private enum LisaCloudCache {
    private static let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 16 * 1024 * 1024
        cache.countLimit = 32
        return cache
    }()
    static func image(size: CGSize, scheme: ColorScheme, scale: CGFloat) -> UIImage? {
        guard size.width > 0, size.height > 0, scale > 0,
              size.width.isFinite, size.height.isFinite else { return nil }
        let key = "\(size.width):\(size.height):\(scale):\(scheme == .dark)" as NSString
        if let image = images.object(forKey: key) { return image }
        // Avoid a transient oversized allocation during unusual window layouts.
        guard size.width * size.height * scale * scale <= 4_000_000 else { return nil }
        let renderer = ImageRenderer(content: LisaCloudDrawing(scheme: scheme)
            .frame(width: size.width, height: size.height))
        renderer.scale = scale
        guard let image = renderer.uiImage else { return nil }
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        images.setObject(image, forKey: key, cost: cost)
        return image
    }
}

private struct LisaCloudDrawing: View {
    let scheme: ColorScheme
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lobes: [(Double, Double, Double, Double)] = [
                (0.03,0.48,0.30,0.34), (0.15,0.30,0.30,0.48),
                (0.30,0.12,0.35,0.68), (0.52,0.25,0.27,0.52),
                (0.68,0.43,0.26,0.36), (0.14,0.58,0.74,0.27)
            ]
            var mass = Path()
            for (x,y,width,height) in lobes {
                mass.addEllipse(in: CGRect(x:x*w,y:y*h,width:width*w,height:height*h))
            }
            let white = scheme == .dark ? Color(red:0.47,green:0.53,blue:0.68) : .white
            let shadow = scheme == .dark ? Color(red:0.25,green:0.30,blue:0.45) : Color(red:0.76,green:0.83,blue:0.91)
            context.addFilter(.blur(radius: max(0.5,w * 0.004)))
            context.fill(mass, with:.linearGradient(Gradient(stops:[.init(color:white,location:0),.init(color:white,location:0.48),.init(color:shadow,location:1)]),startPoint:CGPoint(x:0,y:h*0.1),endPoint:CGPoint(x:0,y:h*0.92)))
            for (x,y,width,height) in lobes.prefix(5) {
                let rect = CGRect(x:x*w,y:y*h,width:width*w,height:height*h)
                context.fill(Path(ellipseIn:rect),with:.radialGradient(Gradient(colors:[white.opacity(0.75),white.opacity(0)]),center:CGPoint(x:rect.midX-width*w*0.15,y:rect.minY+height*h*0.3),startRadius:0,endRadius:width*w*0.58))
            }
            var mist = context
            mist.addFilter(.blur(radius:w*0.025))
            mist.fill(Path(ellipseIn:CGRect(x:w*0.03,y:h*0.69,width:w*0.94,height:h*0.13)),with:.color(white.opacity(0.6)))
        }
    }
}

struct LisaButterfly: View {
    var time: Double
    var color: Color
    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { wing in
                LisaButterflyWing(color: color).equatable()
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

private struct LisaButterflyWing: View, Equatable {
    let color: Color
    var body: some View {
        ZStack {
            Ellipse().fill(color.gradient).frame(width: 15, height: 22).offset(y: -5)
            Ellipse().fill(color.opacity(0.8).gradient).frame(width: 11, height: 14).offset(y: 8)
            Ellipse().fill(.white.opacity(0.6)).frame(width: 4, height: 8).offset(y: -7)
        }
    }
}

/// A glossy striped sweet, also used as a rotating lollipop crown on the map.
struct LisaSweet: View {
    var color: Color = LisaTheme.coral
    var rotation: Double = 0
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle().fill(color.gradient)
                LisaSweetStripes(side: side).equatable()
                    .rotationEffect(.degrees(rotation)).clipShape(Circle())
                Circle().strokeBorder(.white.opacity(0.8), lineWidth: 3)
                Ellipse().fill(.white.opacity(0.55)).frame(width: side * 0.35, height: side * 0.12)
                    .rotationEffect(.degrees(-25)).offset(x: -side * 0.13, y: -side * 0.25)
            }.frame(width: side, height: side)
                .shadow(color: color.opacity(0.25), radius: 4, y: 5)
        }
    }
}

private struct LisaSweetStripes: View, Equatable {
    let side: CGFloat
    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Ellipse().fill(.white.opacity(0.65))
                    .frame(width: side * 0.23, height: side * 0.68)
                    .offset(y: -side * 0.21)
                    .rotationEffect(.degrees(Double(index) * 60))
            }
        }.frame(width: side, height: side)
    }
}

/// Reusable vector geometry: no SF Symbol/text layout in per-particle frame loops.
enum LisaFXGeometry {
    static let star: Path = {
        var path = Path()
        for index in 0..<10 {
            let angle = Double(index) * .pi / 5 - .pi / 2
            let radius = index.isMultiple(of: 2) ? 1.0 : 0.43
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }()

    static func spark(in context: GraphicsContext, at point: CGPoint, radius: Double,
                      rotation: Double = 0, color: Color) {
        var particle = context
        particle.translateBy(x: point.x, y: point.y)
        particle.rotate(by: .radians(rotation))
        particle.scaleBy(x: radius, y: radius)
        particle.fill(star, with: .color(color))
    }
}

/// One finite entrance per appearance, with no idle timer for cards or screens.
private struct LisaEntrance: ViewModifier {
    @EnvironmentObject private var store: LisaStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lisaMotionAllowed) private var allowed
    @State private var appeared = false
    private var animated: Bool { allowed && store.settings.animatedDecor && !reduceMotion }
    func body(content: Content) -> some View {
        content
            .opacity(appeared || !animated ? 1 : 0)
            .offset(y: appeared || !animated ? 0 : 12)
            .scaleEffect(appeared || !animated ? 1 : 0.98)
            .onAppear { withAnimation(animated ? .spring(response: 0.45, dampingFraction: 0.8) : nil) { appeared = true } }
            .onDisappear { appeared = false }
    }
}
extension View {
    func lisaAppear() -> some View { modifier(LisaEntrance()) }
}
