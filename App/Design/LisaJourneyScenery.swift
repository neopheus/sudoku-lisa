import SwiftUI

/// Each chapter has its own moving toys and weather. The clock sleeps off screen.
struct LisaJourneyScenery: View {
    let region: Int
    let color: Color

    var body: some View {
        LisaMotionClock { time in
            GeometryReader { geometry in
                let w = geometry.size.width
                ZStack {
                    Ellipse().fill(color.opacity(0.15)).frame(width: w * 0.65, height: 155)
                        .rotationEffect(.degrees(-18)).position(x: w * 0.08, y: 220)
                    Ellipse().fill(color.opacity(0.12)).frame(width: w * 0.65, height: 140)
                        .rotationEffect(.degrees(15)).position(x: w * 0.95, y: 410)
                    weather(time: time)
                    prop(time: time, secondary: false)
                        .frame(width: 82, height: 128)
                        .rotationEffect(.degrees(sin(time * 0.9) * (region < 2 ? 7 : 3)), anchor: .bottom)
                        .offset(y: region > 1 ? sin(time * 1.1) * 10 : 0)
                        .position(x: w * 0.13, y: 220)
                    prop(time: time + (time == 0 ? 0 : 2), secondary: true)
                        .frame(width: 67, height: 106)
                        .rotationEffect(.degrees(sin(time * 0.8 + 2) * 6), anchor: .bottom)
                        .offset(y: sin(time * 1.2 + 1) * 8)
                        .position(x: w * 0.88, y: 403)
                    if region < 2 {
                        butterfly(time: time)
                            .position(x: w * (0.50 + sin(time * 0.65) * 0.12), y: 300 + cos(time * 1.2) * 22)
                    } else if region == 2 {
                        Image(systemName: "fish.fill").font(.system(size: 33)).foregroundStyle(LisaTheme.coral)
                            .scaleEffect(x: cos(time * 0.4) < 0 ? -1 : 1, y: 1)
                            .rotationEffect(.degrees(sin(time) * 10))
                            .position(x: w * (0.50 + sin(time * 0.4) * 0.13), y: 308 + sin(time * 0.9) * 12)
                    } else if region == 4 {
                        let travel = time.truncatingRemainder(dividingBy: 7) / 7
                        Capsule().fill(LinearGradient(colors: [.clear, .white, LisaTheme.yellow], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 65, height: 3).rotationEffect(.degrees(25))
                            .position(x: w * (travel * 1.4 - 0.2), y: 20 + travel * 120)
                            .opacity(time == 0 ? 0 : sin(travel * .pi))
                    }
                    LisaCloud().foregroundStyle(.white.opacity(0.75))
                        .frame(width: 100, height: 45)
                        .position(x: w * 0.83 + sin(time * 0.35) * 23, y: 50 + cos(time * 0.7) * 7)
                }
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private func weather(time: Double) -> some View {
        Canvas { context, size in
            guard size.height > 0 else { return }
            // Three symbol sizes serve all 20 particles in these chapters.
            // Resolve once per size, keeping the exact original SF Symbols.
            let symbols: [GraphicsContext.ResolvedText] = (region == 3 || region == 4) ? (0..<3).map { offset in
                context.resolve(Text(Image(systemName: region == 3 ? "snowflake" : "sparkle"))
                    .font(.system(size: CGFloat(2 + offset) * 3))
                    .foregroundColor(region == 4 ? LisaTheme.yellow : .white))
            } : []
            for index in 0..<20 {
                let seed = Double(index)
                let speed = region == 3 ? 16.0 : 10.0
                let travel = (seed * 37 + time * speed).truncatingRemainder(dividingBy: Double(size.height))
                let x = size.width * CGFloat((index * 43 + 7) % 100) / 100 + sin(time + seed) * 9
                let y = region == 2 ? size.height - travel : travel
                let radius = CGFloat(region == 2 ? 4 + index % 7 : 2 + index % 3)
                let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                context.opacity = 0.25 + 0.35 * (sin(time * 1.5 + seed) + 1) / 2
                if region == 2 {
                    context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 1.6)
                    context.fill(Path(ellipseIn: rect.insetBy(dx: radius * 0.6, dy: radius * 0.6).offsetBy(dx: -1, dy: -1)), with: .color(.white))
                } else if region == 3 || region == 4 {
                    context.draw(symbols[index % 3], at: CGPoint(x: x, y: y))
                } else {
                    context.fill(Path(ellipseIn: rect), with: .color(index.isMultiple(of: 2) ? .white : color))
                }
            }
        }
    }

    @ViewBuilder private func prop(time: Double, secondary: Bool) -> some View {
        switch region {
        case 0: flower(time: time, secondary: secondary)
        case 1: lollipop(time: time, secondary: secondary)
        case 2: lagoon(time: time, secondary: secondary)
        case 3: mountain(time: time, secondary: secondary)
        default: planet(time: time, secondary: secondary)
        }
    }

    private func flower(time: Double, secondary: Bool) -> some View {
        GeometryReader { g in
            let size = g.size.width
            ZStack {
                Capsule().fill(LisaTheme.mint.gradient).frame(width: 9, height: g.size.height * 0.6).offset(y: g.size.height * 0.22)
                Ellipse().fill(LisaTheme.mint).frame(width: 30, height: 13).rotationEffect(.degrees(-28)).offset(x: 13, y: 28)
                ZStack {
                    ForEach(0..<7, id: \.self) { petal in
                        Ellipse().fill((secondary ? LisaTheme.lavender : Color.pink).gradient)
                            .frame(width: size * 0.31, height: size * 0.53).offset(y: -size * 0.25)
                            .rotationEffect(.degrees(Double(petal) * 360 / 7))
                    }
                }.rotationEffect(.degrees(time * 13))
                Circle().fill(LisaTheme.yellow.gradient).frame(width: size * 0.40)
                    .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 2))
                Image(systemName: "face.smiling.fill").font(.system(size: size * 0.27)).foregroundStyle(LisaTheme.accentInk.opacity(0.7))
            }.frame(width: size, height: g.size.height * 0.65)
        }
    }

    private func lollipop(time: Double, secondary: Bool) -> some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                Capsule().fill(.white).frame(width: 10, height: g.size.height * 0.8).offset(y: g.size.height * 0.2)
                Capsule().fill(color.opacity(0.35)).frame(width: 4, height: g.size.height * 0.7).offset(x: 3, y: g.size.height * 0.3)
                LisaSweet(color: secondary ? LisaTheme.coral : color, rotation: time * (secondary ? -28 : 24))
                    .frame(width: g.size.width, height: g.size.width)
            }.frame(maxWidth: .infinity)
        }
    }

    private func lagoon(time: Double, secondary: Bool) -> some View {
        GeometryReader { g in
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Ellipse().stroke(.white.opacity(0.6 - Double(ring) * 0.13), lineWidth: 2)
                        .frame(width: g.size.width * (0.6 + Double(ring) * 0.3), height: 14 + Double(ring) * 10)
                        .scaleEffect(1 + sin(time * 1.3 + Double(ring)) * 0.12).offset(y: 32)
                }
                Image(systemName: secondary ? "sailboat.fill" : "water.waves")
                    .font(.system(size: g.size.width * 0.7, weight: .bold))
                    .foregroundStyle(secondary ? .white : Color.cyan)
                    .shadow(color: color.opacity(0.3), radius: 3, y: 4)
                    .rotationEffect(.degrees(sin(time) * 8))
                Circle().fill(.white.opacity(0.45)).frame(width: 17).offset(x: -22, y: -30 + sin(time * 1.4) * 6)
            }.frame(width: g.size.width, height: g.size.height)
        }
    }

    private func mountain(time: Double, secondary: Bool) -> some View {
        GeometryReader { g in
            ZStack {
                Image(systemName: "mountain.2.fill").resizable().scaledToFit()
                    .foregroundStyle(LinearGradient(colors: [.white, secondary ? LisaTheme.mint : LisaTheme.lavender, color], startPoint: .top, endPoint: .bottom))
                    .shadow(color: color.opacity(0.3), radius: 4, y: 5)
                Image(systemName: "snowflake").font(.system(size: 27, weight: .bold)).foregroundStyle(.white)
                    .rotationEffect(.degrees(time * 22)).offset(y: -g.size.height * 0.32)
                Image(systemName: "sparkle").font(.system(size: 20)).foregroundStyle(LisaTheme.yellow)
                    .scaleEffect(0.8 + sin(time * 2) * 0.25).offset(x: g.size.width * 0.36, y: 8)
            }.frame(width: g.size.width, height: g.size.height)
        }
    }

    private func planet(time: Double, secondary: Bool) -> some View {
        GeometryReader { g in
            ZStack {
                Circle().fill(RadialGradient(colors: [.white, secondary ? LisaTheme.coral : LisaTheme.lavender, color], center: .topLeading, startRadius: 0, endRadius: g.size.width))
                    .frame(width: g.size.width * 0.72)
                Ellipse().stroke(secondary ? LisaTheme.mint : LisaTheme.yellow, lineWidth: 6)
                    .frame(width: g.size.width * 1.15, height: g.size.width * 0.34)
                    .rotationEffect(.degrees(-25 + sin(time * 0.8) * 12))
                Image(systemName: "star.fill").font(.system(size: 18)).foregroundStyle(.white)
                    .offset(x: cos(time * 0.8) * g.size.width * 0.53, y: sin(time * 0.8) * g.size.width * 0.53)
            }.frame(width: g.size.width, height: g.size.height)
        }
    }

    private func butterfly(time: Double) -> some View {
        ZStack {
            ForEach(0..<2) { wing in
                Image(systemName: "heart.fill").font(.system(size: 23))
                    .foregroundStyle(wing == 0 ? LisaTheme.coral : LisaTheme.lavender)
                    .rotationEffect(.degrees(wing == 0 ? -40 : 40))
                    .scaleEffect(x: 0.55 + abs(sin(time * 6)) * 0.45, y: 1)
                    .offset(x: wing == 0 ? -9 : 9)
            }
            Capsule().fill(LisaTheme.accentInk).frame(width: 4, height: 19)
        }.rotationEffect(.degrees(sin(time) * 15))
    }
}
