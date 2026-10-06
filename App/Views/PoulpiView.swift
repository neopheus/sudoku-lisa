import SudokuCore
import SwiftUI

extension LisaMascotMood {
    var title: String {
        switch self {
        case .idle: L10n.text("Au repos")
        case .happy: L10n.text("Coucou")
        case .thinking: L10n.text("Réflexion")
        case .encouraging: L10n.text("Courage !")
        case .sleepy: L10n.text("Dodo")
        case .celebrating: L10n.text("Victoire !")
        case .pirouette: L10n.text("Pirouette")
        case .wobble: L10n.text("Balancement")
        case .peek: L10n.text("Timide")
        case .jelly: L10n.text("Tout mou")
        case .swim: L10n.text("Nager")
        case .bow: L10n.text("Étirement")
        case .curious: L10n.text("Curieux")
        case .giggle: L10n.text("Rigoler")
        case .rocket: L10n.text("Fusée")
        case .chase: L10n.text("Papillon")
        case .moonwalk: L10n.text("Marche arrière")
        case .juggle: L10n.text("Jongler")
        case .cloudHide: L10n.text("Cache-cache")
        case .sneeze: L10n.text("Atchoum !")
        case .tumble: L10n.text("Galipette")
        case .balance: L10n.text("Équilibre")
        case .dizzy: L10n.text("Tout tourne")
        case .superhero: L10n.text("Super Poulpi")
        }
    }
    var icon: String {
        switch self {
        case .idle, .sleepy: "moon.zzz.fill"
        case .happy, .encouraging: "hand.wave.fill"
        case .thinking, .curious: "lightbulb.fill"
        case .celebrating, .giggle: "face.smiling.fill"
        case .pirouette, .tumble, .dizzy: "arrow.triangle.2.circlepath"
        case .wobble, .balance, .moonwalk: "figure.dance"
        case .peek, .cloudHide: "eye.slash.fill"
        case .swim, .jelly: "water.waves"
        case .bow: "figure.flexibility"
        case .rocket, .superhero: "bolt.fill"
        case .chase: "leaf.fill"
        case .juggle: "circle.grid.2x2.fill"
        case .sneeze: "wind"
        }
    }
}

struct PoulpiView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    var active: Bool
    @EnvironmentObject private var store: LisaStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mood: LisaMascotMood = .idle
    @State private var reaction = 0
    @State private var automatic = false
    @State private var yaw = 0.0
    @State private var pitch = 0.0
    @State private var zoom = 1.0
    @GestureState private var drag = CGSize.zero
    @GestureState private var magnification: CGFloat = 1
    private var running: Bool { active && scenePhase == .active && store.settings.animatedDecor && !reduceMotion }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 600
            let contentWidth = max(0, min(1040, geometry.size.width - 32))
            let panelWidth = wide ? min(340, contentWidth * 0.43) : contentWidth
            let stageHeight = wide
                ? max(140, min(500, geometry.size.height - 12))
                : ceil(min(350, max(140, geometry.size.height * 0.4)))
            let layout = wide
                ? AnyLayout(HStackLayout(alignment: .center, spacing: 20))
                : AnyLayout(VStackLayout(spacing: 10))
            ZStack {
                LisaBackground(motionEnabled: active, quiet: true)
                layout {
                    stage(height: stageHeight)
                        .frame(width: wide ? max(0, contentWidth - panelWidth - 20) : contentWidth)
                    controls
                        .frame(width: panelWidth)
                        .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
                .frame(maxWidth: 1072).frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Poulpi").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(LisaTheme.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environment(\.lisaMotionAllowed, active && scenePhase == .active)
        .lisaAppear()
        .task(id: automatic && running) {
            guard automatic && running else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                let moods = LisaMascotMood.allCases
                let index = moods.firstIndex(of: mood) ?? 0
                choose(moods[(index + 1) % moods.count], feedback: false)
            }
        }
        .onChange(of: active) { _, value in if !value { automatic = false } }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                control(L10n.text("Recentrer"), icon: "viewfinder") { yaw = 0; pitch = 0; zoom = 1 }
                control(L10n.text("Éloigner"), icon: "minus.magnifyingglass") { zoom = max(0.75, zoom - 0.15) }
                control(L10n.text("Rapprocher"), icon: "plus.magnifyingglass") { zoom = min(1.6, zoom + 0.15) }
            }
            HStack(spacing: 10) {
                control(L10n.text("Surprise !"), icon: "shuffle") {
                    choose(LisaMascotMood.allCases.filter { $0 != mood }.randomElement() ?? .happy)
                }
                control(automatic ? L10n.text("Arrêter le défilé") : L10n.text("Tout enchaîner"), icon: automatic ? "stop.fill" : "play.fill") { automatic.toggle() }
                    .accessibilityIdentifier("poulpiAutoplay")
                    .accessibilityValue(automatic ? L10n.text("Activé") : L10n.text("Désactivé"))
            }.disabled(!running)
            if !store.settings.animatedDecor || reduceMotion {
                Text(L10n.text("Les animations sont désactivées dans les réglages. Vous pouvez toujours tourner Poulpi et zoomer."))
                    .font(LisaTheme.body(11)).foregroundStyle(LisaTheme.muted)
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 9)], spacing: 10) {
                    ForEach(LisaMascotMood.allCases) { animation in
                        Button { choose(animation) } label: {
                            VStack(spacing: 6) {
                                Image(systemName: animation.icon).font(.system(size: 20, weight: .bold))
                                Text(animation.title).font(LisaTheme.body(11)).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .foregroundStyle(LisaTheme.ink)
                            .frame(maxWidth: .infinity).frame(height: 63)
                            .background(CandySurface(tint: mood == animation ? LisaTheme.yellow : LisaTheme.paper, cornerRadius: 16, depth: 3))
                        }
                        .buttonStyle(LisaPressStyle())
                        .accessibilityIdentifier("poulpiAnimation-" + animation.rawValue)
                        .accessibilityAddTraits(mood == animation ? .isSelected : [])
                    }
                }.padding(.bottom, 12)
            }
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("poulpiAnimationList")
            .disabled(!running)
        }
    }

    private func stage(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 28).fill(LisaTheme.paper.opacity(0.5))
            Ellipse().fill(LisaTheme.lavender.opacity(0.4)).frame(width: 160, height: 22).padding(.bottom, 61)
            OctopusSceneView(mood: mood, reactionToken: reaction, animated: running,
                             interactivePortrait: true,
                             yaw: yaw + Double(drag.width) * 0.012,
                             pitch: min(0.65, max(-0.65, pitch + Double(drag.height) * 0.008)),
                             zoom: min(1.6, max(0.75, zoom * Double(magnification))))
                .frame(height: height - 48)
                .frame(height: height, alignment: .top)
                .allowsHitTesting(false)
            Color.clear.contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 3)
                    .updating($drag) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        yaw = (yaw + Double(value.translation.width) * 0.012).truncatingRemainder(dividingBy: .pi * 2)
                        pitch = min(0.65, max(-0.65, pitch + Double(value.translation.height) * 0.008))
                    })
                .simultaneousGesture(MagnificationGesture()
                    .updating($magnification) { value, state, _ in state = value }
                    .onEnded { value in zoom = min(1.6, max(0.75, zoom * Double(value))) })
                .onTapGesture { choose(.giggle) }
                .accessibilityElement()
                .accessibilityLabel(L10n.text("Poulpi en trois dimensions"))
                .accessibilityValue(L10n.text("%@, rotation %@ degrés, zoom %@ pour cent", String(describing: mood.title), String(describing: Int(yaw * 180 / .pi)), String(describing: Int(zoom * 100))))
                .accessibilityHint(L10n.text("Glissez pour tourner, pincez pour zoomer, touchez pour le faire rire."))
                .accessibilityAdjustableAction { direction in yaw += direction == .increment ? .pi / 4 : -.pi / 4 }
                .accessibilityIdentifier("poulpiStage")
            VStack(spacing: 2) {
                Text(mood.title).font(LisaTheme.heading(16)).contentTransition(.numericText())
                Text(L10n.text("Tournez · zoomez · chatouillez")).font(LisaTheme.body(10))
            }.foregroundStyle(LisaTheme.ink).padding(8)
                .background(LisaTheme.paper.opacity(0.9), in: Capsule()).padding(.bottom, 5)
                .allowsHitTesting(false)
        }
        .frame(height: height).clipShape(RoundedRectangle(cornerRadius: 28))
        .contentShape(RoundedRectangle(cornerRadius: 28))
    }
    private func choose(_ animation: LisaMascotMood, feedback: Bool = true) {
        mood = animation; reaction += 1
        if feedback { store.feedback(.hello) }
    }
    private func control(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(LisaTheme.body(11)).lineLimit(1).minimumScaleFactor(0.7)
                .foregroundStyle(LisaTheme.ink).frame(maxWidth: .infinity, minHeight: 42)
                .background(CandySurface(tint: LisaTheme.paper, cornerRadius: 14, depth: 3))
        }.buttonStyle(LisaPressStyle()).accessibilityLabel(title)
    }
}

struct LisaPauseCard: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    let resume: () -> Void
    @EnvironmentObject private var store: LisaStore
    @State private var greeted = false
    @State private var reaction = 0
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 450
            ScrollView {
                VStack(spacing: compact ? 10 : 22) {
                    Button { greeted = true; reaction += 1; store.feedback(.hello) } label: {
                        LisaMascot(size: compact ? 64 : 110, mood: greeted ? .happy : .sleepy, reactionToken: reaction,
                                   animationEnabled: store.settings.animatedDecor)
                    }.buttonStyle(LisaPressStyle()).accessibilityLabel(L10n.text("Réveiller doucement Poulpi"))
                    Text(L10n.text("Prenez votre temps.")).font(LisaTheme.heading(28))
                    Text(L10n.text("Votre grille vous attend.")).font(LisaTheme.body()).foregroundStyle(LisaTheme.muted)
                    LisaButton(title: L10n.text("Reprendre"), icon: "play.fill", action: resume)
                }
                .padding(compact ? 18 : 28)
                .frame(maxWidth: 440)
                .background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 30))
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .lisaAppear()
        .task(id: reaction) {
            guard reaction > 0 else { return }
            do { try await Task.sleep(for: .seconds(2.5)) } catch { return }
            greeted = false
        }
    }
}
