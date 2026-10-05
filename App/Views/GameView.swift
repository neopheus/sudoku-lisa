import SwiftUI
import Combine
import SudokuCore

struct GameView: View {
    @EnvironmentObject private var store: LisaStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected: Int?
    @State private var notesMode = false
    @State private var paused = false
    @State private var hint: SudokuHint?
    @State private var hintPresented = false
    @State private var settings = false
    @State private var errorPresented = false
    @State private var mascotMood: LisaMascotMood = .idle
    @State private var mascotReaction = 0
    @Environment(\.colorScheme) private var colorScheme
    private var mascotUncovered: Bool { scenePhase == .active && !settings && !store.showVictory && !hintPresented && !errorPresented }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LisaBackground()
            if let game = store.session {
                GeometryReader { geometry in
                    let compact = geometry.size.height < 820
                    ScrollView {
                        VStack(spacing: compact ? 8 : 16) {
                            HStack {
                                LisaIconButton(icon: "chevron.left", label: "Sauvegarder et revenir à l’accueil") { store.save(); store.showGame = false }
                                Spacer()
                                HStack(spacing: 6) {
                                    LisaMascot(size: 44, mood: paused ? .sleepy : mascotMood, reactionToken: mascotReaction, animationEnabled: !paused && mascotUncovered)
                                        .accessibilityHidden(true)
                                    VStack(spacing: 0) {
                                        Text("Lisa!")
                                            .font(.system(size: 30, weight: .black, design: .rounded)).italic()
                                            .foregroundStyle(LinearGradient(colors: [.white, Color(red: 1, green: 0.9, blue: 0.53)], startPoint: .top, endPoint: .bottom))
                                            .shadow(color: Color(red: 0.59, green: 0.18, blue: 0.57), radius: 0, x: 0, y: 2)
                                            .shadow(color: Color(red: 0.59, green: 0.18, blue: 0.57), radius: 1, x: 1, y: 0)
                                        Text(game.puzzle.difficulty.label.uppercased())
                                            .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.5)
                                            .foregroundStyle(LisaTheme.ink)
                                    }
                                }
                                Spacer()
                                LisaIconButton(icon: "gearshape", label: "Réglages") { settings = true }
                            }
                            HStack {
                                Label(store.mode, systemImage: store.mode == "Libre" ? "sparkles" : "sun.max")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(LisaTheme.ink).padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(LisaTheme.paper.opacity(0.8), in: Capsule())
                                Spacer()
                                Text(store.settings.autoCheck || store.settings.errorLimit ? "Erreurs \(game.mistakes)\(store.settings.errorLimit ? "/3" : "")" : "Mode zen").font(LisaTheme.body(13)).foregroundStyle(game.mistakes > 0 ? LisaTheme.coral : LisaTheme.muted)
                                if store.settings.showTimer { Text(LisaStore.time(game.elapsedSeconds)).font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundStyle(LisaTheme.muted) }
                                Button { paused = true } label: { Image(systemName: "pause.fill").frame(width: 36, height: 40) }.accessibilityLabel("Mettre en pause")
                            }
                            board(game, width: max(9, min(geometry.size.width - 32, compact ? geometry.size.height - 310 : 480)))
                            HStack(spacing: 8) {
                                tool("Annuler", icon: "arrow.uturn.backward", enabled: game.canUndo) { store.session?.undo(); store.changed() }
                                tool("Gommer", icon: "eraser", enabled: selected.map { game.isEditable($0) } ?? false) { if let selected { store.session?.erase(at: selected); store.changed() } }
                                tool(notesMode ? "Notes oui" : "Notes", icon: "pencil.tip", active: notesMode) { notesMode.toggle(); store.feedback() }
                                tool("Indice", icon: "lightbulb") { hint = store.session?.hint(); if hint != nil { store.session?.recordHintConsultation(); store.save(); react(.thinking) }; hintPresented = true }
                            }
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: compact ? 5 : 3), spacing: 9) {
                                ForEach(1...9, id: \.self) { value in
                                    let remaining = max(0, 9 - game.values.filter { $0 == value }.count)
                                    Button { enter(value) } label: {
                                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                                            Text("\(value)").font(.system(size: compact ? 27 : 30, weight: .black, design: .rounded))
                                                .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
                                            Text("\(remaining)").font(.system(size: 10, weight: .bold, design: .rounded))
                                        }
                                        .foregroundStyle(value == 5 || value == 8 ? Color(red: 0.27, green: 0.12, blue: 0.32) : .white)
                                        .frame(maxWidth: .infinity).frame(height: 47)
                                        .background(CandySurface(tint: candyColor(value), cornerRadius: notesMode ? 10 : 16))
                                        .contentShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(alignment: .topLeading) {
                                            if notesMode { Image(systemName: "pencil.tip").font(.system(size: 8, weight: .bold)).foregroundStyle(.white).padding(5) }
                                        }
                                    }.buttonStyle(LisaPressStyle()).accessibilityLabel("\(value), \(remaining) restant\(remaining > 1 ? "s" : "")").disabled(paused || game.isComplete)
                                }
                            }
                            if !compact { Text(notesMode ? "Mode notes · Touchez une case puis un chiffre." : "Une case, un chiffre, un petit déclic.").font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted) }
                        }.frame(maxWidth: 500).padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 15).frame(maxWidth: .infinity)
                    }
                }
            }
            if paused {
                Color.black.opacity(0.3).ignoresSafeArea()
                VStack(spacing: 22) { LisaMascot(size: 100, mood: .sleepy, animationEnabled: mascotUncovered); Text("Prenez votre temps.").font(LisaTheme.heading(28)); Text("Votre grille vous attend.").font(LisaTheme.body()).foregroundStyle(LisaTheme.muted); LisaButton(title: "Reprendre", icon: "play.fill") { paused = false } }.padding(28).background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 30)).padding(24)
            }
        }
        .preferredColorScheme(store.settings.darkMode ? .dark : .light)
        .saturation(store.settings.paperMode ? 0 : 1)
        .onReceive(timer) { _ in
            guard scenePhase == .active, !paused, !hintPresented, !settings, !errorPresented, store.session?.isComplete == false else { return }
            store.session?.tick()
            if (store.session?.elapsedSeconds ?? 0) % 5 == 0 { store.save() }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { paused = true; store.save() } }
        .onDisappear { store.save() }
        .task(id: mascotReaction) {
            guard mascotReaction > 0 else { return }
            do { try await Task.sleep(for: .seconds(2.4)) } catch { return }
            mascotMood = .idle
        }
        .sheet(isPresented: $settings) { SettingsView() }
        .sheet(isPresented: $store.showVictory) { VictoryView().interactiveDismissDisabled() }
        .alert("Un petit coup de pouce", isPresented: $hintPresented) {
            if let hint { Button("Placer le \(hint.value)") { selected = hint.index; store.session?.applyHint(countAsUsed: false); store.changed(); react(.happy) } }
            Button("Je continue seul", role: .cancel) {}
        } message: { Text(hint.map { "\($0.title)\n\($0.detail)" } ?? "La grille est terminée.") }
        .alert("On respire, puis on reprend ?", isPresented: $errorPresented) {
            Button("Continuer sans limite") { store.settings.errorLimit = false }
            Button("Retour à l’accueil") { store.showGame = false }
        } message: { Text("Trois erreurs, ce n’est pas la fin du monde. Continuez à votre rythme ou faites une pause.") }
    }

    private func enter(_ value: Int) {
        guard let selected, store.session?.isEditable(selected) == true, !paused else { return }
        if store.settings.errorLimit && (store.session?.mistakes ?? 0) >= 3 { errorPresented = true; return }
        if notesMode { store.session?.toggleNote(value, at: selected) }
        else {
            let previousValue = store.session?.values[selected]
            var correct = false
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                correct = store.session?.enter(value, at: selected) ?? false
            }
            // A neutral companion in zen mode must not reveal the solution.
            if previousValue != value, store.settings.autoCheck || store.settings.errorLimit {
                react(correct ? .happy : .encouraging)
            }
        }
        store.feedback()
        store.changed()
        if store.settings.errorLimit && (store.session?.mistakes ?? 0) >= 3 && store.session?.isComplete == false { errorPresented = true }
    }

    private func react(_ mood: LisaMascotMood) {
        mascotMood = mood
        mascotReaction += 1
    }

    private func board(_ game: GameSession, width: CGFloat) -> some View {
        let innerWidth = max(9, width - 16)
        let side = innerWidth / 9
        return ZStack {
            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { col in
                            let index = row * 9 + col
                            Button {
                                guard !paused else { return }
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) { selected = index }
                                store.feedback()
                            } label: { cell(game, index: index, side: side) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(cellLabel(game, index: index))
                            .accessibilityAddTraits(selected == index ? .isSelected : [])
                        }
                    }
                }
            }
            Path { path in
                for n in 0...9 {
                    let coordinate = CGFloat(n) * side
                    path.move(to: CGPoint(x: coordinate, y: 0)); path.addLine(to: CGPoint(x: coordinate, y: innerWidth))
                    path.move(to: CGPoint(x: 0, y: coordinate)); path.addLine(to: CGPoint(x: innerWidth, y: coordinate))
                }
            }.stroke(Color(red: 0.58, green: 0.42, blue: 0.68).opacity(colorScheme == .dark ? 0.4 : 0.2), lineWidth: 0.5).allowsHitTesting(false)
            Path { path in
                for n in stride(from: 0, through: 9, by: 3) {
                    let coordinate = CGFloat(n) * side
                    path.move(to: CGPoint(x: coordinate, y: 0)); path.addLine(to: CGPoint(x: coordinate, y: innerWidth))
                    path.move(to: CGPoint(x: 0, y: coordinate)); path.addLine(to: CGPoint(x: innerWidth, y: coordinate))
                }
            }.stroke(colorScheme == .dark ? Color(red: 0.7, green: 0.49, blue: 0.88) : Color(red: 0.47, green: 0.26, blue: 0.61), lineWidth: 2).allowsHitTesting(false)
        }
        .frame(width: innerWidth, height: innerWidth)
        .background(LisaTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(8)
        .background(CandySurface(tint: Color(red: 0.6, green: 0.26, blue: 0.78), cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.5), lineWidth: 2))
        .shadow(color: Color(red: 0.36, green: 0.12, blue: 0.54).opacity(0.25), radius: 10, y: 6)
        .blur(radius: paused ? 12 : 0).accessibilityHidden(paused)
    }

    private func cell(_ game: GameSession, index: Int, side: CGFloat) -> some View {
        let value = game.values[index]
        let wrong = store.settings.autoCheck && game.isIncorrect(at: index)
        let duplicate = store.settings.highlightDuplicates && value != 0 && (0..<81).contains { other in other != index && game.values[other] == value && peers(index, other) }
        let sameNumber = selected.map { game.values[$0] != 0 && game.values[$0] == value } ?? false
        let peer = selected.map { peers(index, $0) } ?? false
        let blue = Color(red: 0.18, green: 0.59, blue: 0.94)
        let background = (wrong || duplicate) ? Color.red.opacity(colorScheme == .dark ? 0.27 : 0.12)
            : selected == index ? blue.opacity(colorScheme == .dark ? 0.42 : 0.26)
            : sameNumber ? LisaTheme.yellow.opacity(colorScheme == .dark ? 0.27 : 0.45)
            : (peer && store.settings.highlightPeers) ? LisaTheme.lavender.opacity(colorScheme == .dark ? 0.12 : 0.22) : LisaTheme.paper
        return ZStack {
            RoundedRectangle(cornerRadius: 4).fill(background).padding(0.7)
            if selected == index {
                RoundedRectangle(cornerRadius: 4).strokeBorder(blue, lineWidth: 2).padding(1)
            }
            if value != 0 {
                Text("\(value)").contentTransition(.numericText()).font(.system(size: side * 0.54, weight: game.puzzle.givens[index] == 0 ? .medium : .semibold, design: .rounded)).foregroundStyle(wrong || duplicate ? (colorScheme == .dark ? Color(red: 1, green: 0.55, blue: 0.6) : Color(red: 0.76, green: 0.12, blue: 0.22)) : game.puzzle.givens[index] == 0 ? (colorScheme == .dark ? Color(red: 0.62, green: 0.84, blue: 1) : Color(red: 0.13, green: 0.39, blue: 0.72)) : LisaTheme.ink)
            } else {
                VStack(spacing: 0) { ForEach(0..<3) { row in HStack(spacing: 0) { ForEach(1...3, id: \.self) { col in let note = row * 3 + col; Text(game.notes[index].contains(note) ? "\(note)" : " ").font(.system(size: side * 0.23, weight: .medium, design: .rounded)).foregroundStyle(LisaTheme.muted).frame(width: side / 3, height: side / 3) } } } }
            }
        }.frame(width: side, height: side).contentShape(Rectangle())
    }
    private func peers(_ a: Int, _ b: Int) -> Bool { a / 9 == b / 9 || a % 9 == b % 9 || (a / 27 == b / 27 && a % 9 / 3 == b % 9 / 3) }
    private func cellLabel(_ game: GameSession, index: Int) -> String {
        let value = game.values[index]
        let notes = game.notes[index].sorted().map(String.init).joined(separator: ", ")
        return "Ligne \(index / 9 + 1), colonne \(index % 9 + 1), \(value == 0 ? "vide" : String(value))\(game.puzzle.givens[index] != 0 ? ", chiffre donné" : "")\(notes.isEmpty ? "" : ", notes " + notes)\(store.settings.autoCheck && game.isIncorrect(at: index) ? ", erreur" : "")"
    }
    private func candyColor(_ value: Int) -> Color {
        let colors: [Color] = [
            .init(red: 0.49, green: 0.22, blue: 0.77), .init(red: 0.08, green: 0.44, blue: 0.77),
            .init(red: 0.81, green: 0.19, blue: 0.34), .init(red: 0.08, green: 0.47, blue: 0.29),
            .init(red: 0.98, green: 0.76, blue: 0.19), .init(red: 0.04, green: 0.44, blue: 0.57),
            .init(red: 0.75, green: 0.18, blue: 0.48), .init(red: 1, green: 0.61, blue: 0.25),
            .init(red: 0.46, green: 0.28, blue: 0.73)
        ]
        return colors[value - 1]
    }
    private func tool(_ title: String, icon: String, active: Bool = false, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        let tint = active ? Color(red: 0.98, green: 0.74, blue: 0.17)
            : icon == "lightbulb" ? Color(red: 0.81, green: 0.22, blue: 0.43)
            : icon == "eraser" ? Color(red: 0.08, green: 0.47, blue: 0.63)
            : Color(red: 0.51, green: 0.3, blue: 0.73)
        return Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 22, weight: .bold))
                    .shadow(color: .black.opacity(0.13), radius: 0, y: 2)
                Text(title).font(.system(size: 10, weight: .heavy, design: .rounded)).lineLimit(1)
            }
            .frame(maxWidth: .infinity).frame(height: 60)
            .foregroundStyle(active ? Color(red: 0.3, green: 0.14, blue: 0.38) : .white)
            .background(CandySurface(tint: tint, cornerRadius: 17))
            .contentShape(RoundedRectangle(cornerRadius: 17))
            .opacity(enabled ? 1 : 0.42)
        }.buttonStyle(LisaPressStyle()).disabled(!enabled)
    }
}

struct VictoryView: View {
    @EnvironmentObject private var store: LisaStore
    var body: some View {
        ZStack {
            LisaBackground()
            LisaCelebration(isActive: true)
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 15) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: "star.fill")
                                .font(.system(size: index == 1 ? 52 : 38, weight: .black))
                                .foregroundStyle(LinearGradient(colors: [.white, LisaTheme.yellow, Color.orange], startPoint: .top, endPoint: .bottom))
                                .shadow(color: Color(red: 0.66, green: 0.27, blue: 0.3), radius: 0, y: 4)
                                .rotationEffect(.degrees(index == 0 ? -15 : index == 2 ? 15 : 0))
                                .offset(y: index == 1 ? -8 : 4)
                        }
                    }
                    .accessibilityHidden(true)
                    .padding(.top, 28)
                    ZStack {
                        Circle().fill(LisaTheme.yellow.opacity(0.35)).frame(width: 175, height: 175)
                        Circle().strokeBorder(.white.opacity(0.75), style: StrokeStyle(lineWidth: 3, dash: [4, 8])).frame(width: 190, height: 190)
                        LisaMascot(size: 140, celebrating: true, mood: .happy)
                    }
                    VStack(spacing: 8) {
                        Text("Bien joué, vous !")
                            .font(.system(size: 35, weight: .black, design: .rounded))
                            .foregroundStyle(LisaTheme.coral)
                            .shadow(color: .white.opacity(0.7), radius: 0, y: 2)
                            .multilineTextAlignment(.center)
                        Text("81 cases. Et ce petit plaisir\nd’avoir trouvé la dernière.")
                            .font(LisaTheme.body(17)).multilineTextAlignment(.center).foregroundStyle(LisaTheme.ink)
                    }
                    if let game = store.session {
                        HStack(spacing: 9) {
                            metric(LisaStore.time(game.elapsedSeconds), "votre temps", icon: "stopwatch.fill")
                            metric("\(game.mistakes)", "erreurs", icon: "heart.fill")
                            metric("\(game.hintsUsed)", "indices", icon: "lightbulb.fill")
                        }
                        ShareLink(item: "J’ai terminé un sudoku \(game.puzzle.difficulty.label.lowercased()) en \(LisaStore.time(game.elapsedSeconds)) avec Sudoku Lisa. À votre tour !") {
                            Label("Partager mon petit exploit", systemImage: "square.and.arrow.up")
                                .font(LisaTheme.body(15)).foregroundStyle(LisaTheme.ink)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(CandySurface(tint: LisaTheme.paper, cornerRadius: 18, depth: 3))
                        }
                        .buttonStyle(LisaPressStyle())
                    }
                    LisaButton(title: "Continuer l’aventure", icon: "arrow.right") {
                        store.showVictory = false; store.showGame = false
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 30)
                .frame(maxWidth: 480).frame(maxWidth: .infinity)
            }
        }
    }
    private func metric(_ value: String, _ label: String, icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(LisaTheme.coral)
            Text(value).font(LisaTheme.heading(23)).foregroundStyle(LisaTheme.ink)
            Text(label).font(LisaTheme.body(11)).foregroundStyle(LisaTheme.muted)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 13)
        .background(CandySurface(tint: LisaTheme.paper, cornerRadius: 18, depth: 3))
    }
}
