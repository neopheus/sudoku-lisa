import SudokuCore
import PoulpiStickers
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
        case .surprised: L10n.text("Surpris")
        case .nervous: L10n.text("Nerveux")
        case .confused: L10n.text("Confus")
        case .loved: L10n.text("Amoureux")
        case .proud: L10n.text("Fier")
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
        case .surprised: "exclamationmark.circle.fill"
        case .nervous: "bolt.fill"
        case .confused: "questionmark.circle.fill"
        case .loved: "heart.fill"
        case .proud: "crown.fill"
        }
    }
}

struct PoulpiView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    var active: Bool
    @EnvironmentObject private var store: LisaStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mood: LisaMascotMood = .idle
    @State private var reaction = 0
    @State private var automatic = false
    @State private var looping = false
    @State private var paused = false
    @State private var slowMotion = false
    @State private var compactPreview = false
    @State private var visible = false
    @State private var yaw = 0.0
    @State private var pitch = 0.0
    @State private var zoom = 1.0
    @GestureState private var drag = CGSize.zero
    @GestureState private var magnification: CGFloat = 1
    private var running: Bool { active && visible && scenePhase == .active && store.settings.animatedDecor && !reduceMotion }
    private var playbackSpeed: Double { slowMotion ? 0.35 : 1 }
    private static let expressions = LisaMascotMood.allCases.filter { !$0.isAcrobatic }
    private static let acrobatics = LisaMascotMood.allCases.filter(\.isAcrobatic)

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 560
                && geometry.size.width > geometry.size.height * 1.2
                && geometry.size.height >= 150
            let contentWidth = max(0, min(1040, geometry.size.width - 32))
            let panelWidth = wide
                ? min(dynamicTypeSize.isAccessibilitySize ? 420 : 340,
                      contentWidth * (dynamicTypeSize.isAccessibilitySize ? 0.55 : 0.43))
                : contentWidth
            let availableHeight = max(0, geometry.size.height - 12)
            let stageHeight = wide
                ? min(compactPreview ? 250 : 500, availableHeight)
                : ceil(min(compactPreview ? 180 : 300, max(100, availableHeight * (compactPreview ? 0.24 : 0.34))))
            let controlsHeight = wide ? availableHeight : max(0, availableHeight - stageHeight - 10)
            let layout = wide
                ? AnyLayout(HStackLayout(alignment: .center, spacing: 20))
                : AnyLayout(VStackLayout(spacing: 10))
            ZStack {
                LisaBackground(motionEnabled: active, quiet: true)
                layout {
                    stage(height: stageHeight)
                        .frame(width: wide ? max(0, contentWidth - panelWidth - 20) : contentWidth)
                    ScrollView {
                        controls(moodColumns: dynamicTypeSize.isAccessibilitySize ? 1 : (panelWidth >= 320 ? 3 : 2))
                            .frame(width: panelWidth)
                    }
                    .frame(width: panelWidth, height: controlsHeight)
                    .accessibilityIdentifier("poulpiControlsScroll")
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
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .task(id: "\(automatic)-\(looping)-\(paused)-\(running)-\(mood.rawValue)-\(reaction)-\(slowMotion)") {
            guard (automatic || looping) && running && !paused else { return }
            do { try await Task.sleep(for: .seconds(mood.reactionDuration / playbackSpeed + 0.15)) } catch { return }
            guard !Task.isCancelled else { return }
            if automatic {
                let moods = LisaMascotMood.allCases
                let index = moods.firstIndex(of: mood) ?? 0
                choose(moods[(index + 1) % moods.count], feedback: false)
            } else if looping {
                replay(feedback: false)
            }
        }
        .onChange(of: active) { _, value in if !value { automatic = false; looping = false } }
    }

    private func tilt(_ amount: Double) {
        pitch = min(0.65, max(-0.65, pitch + amount))
    }

    private func controls(moodColumns: Int) -> some View {
        VStack(spacing: 10) {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    control(L10n.text("Tourner à gauche"), icon: "arrow.turn.up.left") { yaw -= .pi / 4 }
                    control(L10n.text("Tourner à droite"), icon: "arrow.turn.up.right") { yaw += .pi / 4 }
                }
                GridRow {
                    control(L10n.text("Incliner vers le haut"), icon: "arrow.up") { tilt(-0.2) }
                    control(L10n.text("Incliner vers le bas"), icon: "arrow.down") { tilt(0.2) }
                }
            }
            .frame(maxWidth: .infinity)
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
                control(L10n.text("Recentrer"), icon: "viewfinder") { yaw = 0; pitch = 0; zoom = 1 }
                control(L10n.text("Éloigner"), icon: "minus.magnifyingglass") { zoom = max(0.75, zoom - 0.15) }
                control(L10n.text("Rapprocher"), icon: "plus.magnifyingglass") { zoom = min(1.6, zoom + 0.15) }
            }
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))) {
                control(L10n.text("Surprise !"), icon: "shuffle") {
                    automatic = false; looping = false
                    choose(LisaMascotMood.allCases.filter { $0 != mood }.randomElement() ?? .happy)
                }
                control(automatic ? L10n.text("Arrêter le défilé") : L10n.text("Tout enchaîner"), icon: automatic ? "stop.fill" : "play.fill") {
                    automatic.toggle()
                    if automatic { looping = false; paused = false }
                }
                    .accessibilityIdentifier("poulpiAutoplay")
                    .accessibilityValue(automatic ? L10n.text("Activé") : L10n.text("Désactivé"))
            }.disabled(!running)
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    control(L10n.text("Rejouer l’animation"), icon: "arrow.counterclockwise") { replay() }
                        .accessibilityIdentifier("poulpiReplay")
                    control(looping ? L10n.text("Arrêter la boucle") : L10n.text("Jouer en boucle"), icon: "repeat") {
                        looping.toggle()
                        if looping { automatic = false; paused = false; replay(feedback: false) }
                    }
                    .accessibilityIdentifier("poulpiLoop")
                    .accessibilityValue(looping ? L10n.text("Activé") : L10n.text("Désactivé"))
                }
                GridRow {
                    control(paused ? L10n.text("Reprendre l’animation") : L10n.text("Mettre l’animation en pause"), icon: paused ? "play.fill" : "pause.fill") { paused.toggle() }
                        .accessibilityIdentifier("poulpiPause")
                        .accessibilityValue(paused ? L10n.text("En pause") : L10n.text("En lecture"))
                    control(slowMotion ? L10n.text("Vitesse normale") : L10n.text("Ralenti"), icon: "speedometer") { slowMotion.toggle() }
                        .accessibilityIdentifier("poulpiSlowMotion")
                        .accessibilityValue(slowMotion ? L10n.text("Activé") : L10n.text("Désactivé"))
                }
            }
            .frame(maxWidth: .infinity)
            .disabled(!running)
            control(compactPreview ? L10n.text("Grand aperçu") : L10n.text("Aperçu compact"), icon: compactPreview ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left") {
                compactPreview.toggle()
            }
            .accessibilityIdentifier("poulpiCompactPreview")
            .accessibilityValue(compactPreview ? L10n.text("Activé") : L10n.text("Désactivé"))
            if !store.settings.animatedDecor || reduceMotion {
                Text(L10n.text("Les animations sont désactivées dans les réglages. Vous pouvez toujours tourner Poulpi et zoomer."))
                    .font(LisaTheme.body(11)).foregroundStyle(LisaTheme.muted)
            }
            moodSection(L10n.text("Émotions"), moods: Self.expressions, columns: moodColumns)
            moodSection(L10n.text("Acrobaties"), moods: Self.acrobatics, columns: moodColumns)
            PoulpiAppearanceControls()
            NavigationLink {
                PoulpiStickersView()
            } label: {
                Label(PoulpiStickerCatalog.text("Autocollants Poulpi"), systemImage: "face.smiling")
                    .font(LisaTheme.heading(17))
                    .foregroundStyle(LisaTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(10)
                    .background(CandySurface(tint: LisaTheme.yellow, cornerRadius: 18, depth: 3))
            }
            .buttonStyle(LisaPressStyle())
            .accessibilityIdentifier("openPoulpiStickers")
            .padding(.bottom, 12)
        }
    }

    private func moodSection(_ title: String, moods: [LisaMascotMood], columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(LisaTheme.heading(17)).foregroundStyle(LisaTheme.ink)
            Grid(alignment: .leading, horizontalSpacing: 9, verticalSpacing: 10) {
                ForEach(0..<(moods.count + columns - 1) / columns, id: \.self) { row in
                    GridRow {
                        ForEach(moods[(row * columns)..<min((row + 1) * columns, moods.count)]) { animation in
                            Button {
                                automatic = false
                                choose(animation)
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: animation.icon).font(.system(size: 20, weight: .bold))
                                    Text(animation.title).font(LisaTheme.body(11)).fixedSize(horizontal: false, vertical: true)
                                }
                                .foregroundStyle(LisaTheme.ink)
                                .padding(8).frame(maxWidth: .infinity, minHeight: 63)
                                .background(CandySurface(tint: mood == animation ? LisaTheme.yellow : LisaTheme.paper, cornerRadius: 16, depth: 3))
                                .overlay(alignment: .topTrailing) { if mood == animation { Image(systemName: "checkmark.circle.fill").font(.caption).padding(4).accessibilityHidden(true) } }
                            }
                            .buttonStyle(LisaPressStyle())
                            .accessibilityIdentifier("poulpiAnimation-" + animation.rawValue)
                            .accessibilityAddTraits(mood == animation ? .isSelected : [])
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(!running)
    }

    private func stage(height: CGFloat) -> some View {
        let captionHeight: CGFloat = dynamicTypeSize.isAccessibilitySize ? 48 : 72
        let renderHeight = max(1, height - captionHeight)
        let compactSize = min(100, renderHeight)
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 28).fill(LisaTheme.paper.opacity(0.5))
            Ellipse().fill(LisaTheme.lavender.opacity(0.4)).frame(width: compactPreview ? 90 : 160, height: 16).padding(.bottom, captionHeight)
            OctopusSceneView(mood: mood, reactionToken: reaction, animated: running,
                             interactivePortrait: true,
                             yaw: yaw + Double(drag.width) * 0.012,
                             pitch: min(0.65, max(-0.65, pitch + Double(drag.height) * 0.008)),
                             zoom: min(1.6, max(0.75, zoom * Double(magnification))),
                             playbackPaused: paused,
                             playbackSpeed: playbackSpeed,
                             appearance: store.poulpiAppearance)
                .frame(width: compactPreview ? compactSize : nil, height: compactPreview ? compactSize : renderHeight)
                .frame(maxWidth: .infinity)
                .frame(height: renderHeight)
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
                .onTapGesture { if running { choose(.giggle) } }
                .accessibilityElement()
                .accessibilityLabel(L10n.text("Poulpi en trois dimensions"))
                .accessibilityValue(L10n.text("%@, rotation %@ degrés, zoom %@ pour cent", String(describing: mood.title), String(describing: Int(yaw * 180 / .pi)), String(describing: Int(zoom * 100))))
                .accessibilityHint(running
                    ? L10n.text("Glissez pour tourner, pincez pour zoomer, touchez pour le faire rire.")
                    : L10n.text("Glissez pour tourner et pincez pour zoomer."))
                .accessibilityAdjustableAction { direction in yaw += direction == .increment ? .pi / 4 : -.pi / 4 }
                .accessibilityAction { if running { choose(.giggle) } }
                .accessibilityAction(named: Text(L10n.text("Tourner à gauche"))) { yaw -= .pi / 4 }
                .accessibilityAction(named: Text(L10n.text("Tourner à droite"))) { yaw += .pi / 4 }
                .accessibilityAction(named: Text(L10n.text("Incliner vers le haut"))) { tilt(-0.2) }
                .accessibilityAction(named: Text(L10n.text("Incliner vers le bas"))) { tilt(0.2) }
                .accessibilityAction(named: Text(L10n.text("Rapprocher"))) { zoom = min(1.6, zoom + 0.15) }
                .accessibilityAction(named: Text(L10n.text("Éloigner"))) { zoom = max(0.75, zoom - 0.15) }
                .accessibilityIdentifier("poulpiStage")
            VStack(spacing: 2) {
                Text(mood.title).font(LisaTheme.heading(16)).contentTransition(.numericText())
                    .lineLimit(1).minimumScaleFactor(0.75)
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(L10n.text("Tournez · zoomez · chatouillez")).font(LisaTheme.body(10))
                }
            }.foregroundStyle(LisaTheme.ink).padding(8)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .background(LisaTheme.paper.opacity(0.9), in: Capsule()).padding(.bottom, 5)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(height: height).clipShape(RoundedRectangle(cornerRadius: 28))
        .contentShape(RoundedRectangle(cornerRadius: 28))
    }
    private func choose(_ animation: LisaMascotMood, feedback: Bool = true) {
        mood = animation; reaction += 1
        paused = false
        if feedback { store.feedback(.hello) }
    }
    private func replay(feedback: Bool = true) {
        reaction += 1
        paused = false
        if feedback { store.feedback(.hello) }
    }
    private func control(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(LisaTheme.body(11)).fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(LisaTheme.ink).frame(maxWidth: .infinity, minHeight: 44).padding(.vertical, 6)
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
                                   animationEnabled: store.settings.animatedDecor, appearance: store.poulpiAppearance)
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
