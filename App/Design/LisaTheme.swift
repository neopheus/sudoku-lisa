import SwiftUI
import UIKit

/// A native candy world: vectors, system rounded type and no downloaded textures.
enum LisaTheme {
    static let background = adaptive(light: (0.79, 0.94, 0.98), dark: (0.105, 0.07, 0.19))
    static let ink = adaptive(light: (0.27, 0.12, 0.37), dark: (0.98, 0.94, 1))
    static let accentInk = Color(red: 0.27, green: 0.12, blue: 0.37)
    static let muted = adaptive(light: (0.43, 0.28, 0.49), dark: (0.79, 0.70, 0.86))
    static let coral = Color(red: 0.79, green: 0.07, blue: 0.43)
    static let actionInk = adaptive(light: (0.69, 0.04, 0.36), dark: (1, 0.57, 0.80))
    static let lavender = Color(red: 0.79, green: 0.66, blue: 1)
    static let mint = Color(red: 0.49, green: 0.88, blue: 0.77)
    static let yellow = Color(red: 1, green: 0.82, blue: 0.28)
    static let line = adaptive(light: (0.78, 0.67, 0.84), dark: (0.39, 0.28, 0.48))
    static let paper = adaptive(light: (1, 0.985, 0.94), dark: (0.20, 0.14, 0.29))
    static let candyShadow = Color(red: 0.35, green: 0.10, blue: 0.43)
    static let sky = adaptive(light: (0.53, 0.88, 0.97), dark: (0.11, 0.15, 0.29))

    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: value.0, green: value.1, blue: value.2, alpha: 1)
        })
    }
    static func heading(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func body(_ size: CGFloat = 16) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

struct LisaBackground: View {
    var motionEnabled = true
    var quiet = false
    var chapter: Int? = nil
    @EnvironmentObject private var store: LisaStore
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [LisaTheme.sky, LisaTheme.background, scheme == .dark ? Color(red: 0.23, green: 0.12, blue: 0.33) : Color(red: 0.94, green: 0.80, blue: 0.96)], startPoint: .top, endPoint: .bottom)
                if let chapter {
                    LisaJourneyAtmosphere.colors[min(max(chapter, 0), 4)].opacity(scheme == .dark ? 0.16 : 0.14)
                }
                Ellipse().fill(LisaTheme.lavender.opacity(scheme == .dark ? 0.12 : 0.5))
                    .frame(width: geometry.size.width * 1.2, height: geometry.size.height * 0.4)
                    .rotationEffect(.degrees(-20))
                    .position(x: geometry.size.width * 0.2, y: geometry.size.height * 0.98)
                Ellipse().fill(LisaTheme.mint.opacity(scheme == .dark ? 0.10 : 0.55))
                    .frame(width: geometry.size.width * 1.3, height: geometry.size.height * 0.35)
                    .rotationEffect(.degrees(15))
                    .position(x: geometry.size.width * 0.92, y: geometry.size.height * 1.03)

            }
            .overlay { LisaAtmosphere(enabled: motionEnabled && store.settings.animatedDecor, quiet: quiet, chapter: chapter) }
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

}

/// Reusable candy shell. Use in .background(CandySurface(tint: ..., cornerRadius: ...)).
struct CandySurface: View {
    var tint: Color = LisaTheme.paper
    var cornerRadius: CGFloat = 25
    var depth: CGFloat = 5
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(tint).overlay(shape.fill(LisaTheme.candyShadow.opacity(0.35))).offset(y: depth)
            shape.fill(tint).overlay(shape.fill(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.06 : 0.20), .clear], startPoint: .top, endPoint: .bottom)))
            shape.strokeBorder(.white.opacity(scheme == .dark ? 0.2 : 0.9), lineWidth: 2.5)
            shape.inset(by: 5).strokeBorder(.white.opacity(scheme == .dark ? 0.035 : 0.32), lineWidth: 1)
        }
        .shadow(color: LisaTheme.candyShadow.opacity(scheme == .dark ? 0.2 : 0.13), radius: 9, x: 0, y: depth + 3)
        .allowsHitTesting(false)
    }
}

struct LisaCard<Content: View>: View {
    private let content: Content
    var tint: Color
    init(tint: Color = LisaTheme.paper, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }
    var body: some View {
        content.padding(20).background(CandySurface(tint: tint, cornerRadius: 28, depth: 5))
    }
}

struct LisaButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = LisaTheme.coral
    let action: () -> Void
    private var labelColor: Color { tint == LisaTheme.coral ? .white : tint == LisaTheme.paper ? LisaTheme.ink : LisaTheme.accentInk }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title).font(LisaTheme.heading(19))
                if let icon { Image(systemName: icon).font(.system(size: 18, weight: .heavy)).lisaFloat(amplitude: 2, tilt: 8, period: 2.8) }
            }
            .foregroundStyle(labelColor)
            .shadow(color: tint == LisaTheme.coral ? LisaTheme.candyShadow.opacity(0.5) : .clear, radius: 0, y: 1)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(CandySurface(tint: tint, cornerRadius: 23, depth: 6))
            .overlay(alignment: .top) {
                Capsule().fill(.white.opacity(0.3)).frame(height: 3).padding(.horizontal, 23).padding(.top, 7).allowsHitTesting(false)
            }
            .overlay { LisaShimmer() }
            .contentShape(RoundedRectangle(cornerRadius: 23))
        }
        .buttonStyle(LisaPressStyle())
        .padding(.bottom, 5)
    }
}

struct LisaIconButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(LisaTheme.ink)
                .frame(width: 48, height: 48)
                .background(CandySurface(cornerRadius: 18, depth: 3))
                .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(LisaPressStyle())
        .accessibilityLabel(label)
    }
}

struct LisaPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.04 : 0)
            .offset(y: configuration.isPressed && !reduceMotion ? 4 : 0)
            .scaleEffect(x: configuration.isPressed && !reduceMotion ? 0.96 : 1, y: configuration.isPressed && !reduceMotion ? 0.90 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.48), value: configuration.isPressed)
    }
}

struct LisaPill: View {
    let title: String
    var icon: String? = nil
    var tint: Color = LisaTheme.lavender
    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).lisaFloat(amplitude: 1.5, tilt: 9, period: 3.2) }
            Text(title)
        }
        .font(.system(size: 12, weight: .heavy, design: .rounded))
        .foregroundStyle(tint == LisaTheme.coral ? .white : LisaTheme.accentInk)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(CandySurface(tint: tint, cornerRadius: 18, depth: 3))
    }
}
