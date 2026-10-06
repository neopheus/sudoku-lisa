import SwiftUI
import Combine
import SudokuCore

struct GameView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
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
    @State private var companionRequest = 0
    @State private var boardFrame = CGRect.zero
    @State private var companionMessage = L10n.text("Au repos")
    @State private var glowCells: Set<Int> = []
    @State private var completedUnits: Set<Int> = []
    @State private var celebrationOrigin = 40
    @State private var completedDigits: Set<Int> = []
    @State private var celebrationToken = 0
    @State private var celebrationMessage = ""
    @State private var victoryPresented = false
    @Environment(\.colorScheme) private var colorScheme
    private var mascotUncovered: Bool { scenePhase == .active && !settings && !victoryPresented && !hintPresented && !errorPresented }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LisaBackground(motionEnabled: !paused && mascotUncovered, quiet: true, chapter: store.mode == "Voyage" ? LisaJourneyAtmosphere.chapter(store.eventWins - (store.showVictory ? 1 : 0)) : nil)
            // Keep the entire companion scene behind the opaque board at every flight depth.
            LisaGameCompanion(mood: mascotMood, reaction: mascotReaction,
                              active: !paused && mascotUncovered && !store.showVictory,
                              requestToken: companionRequest, occlusionRect: boardFrame,
                              onMessage: { companionMessage = $0 })
                .opacity(!paused && mascotUncovered ? 1 : 0)
            if let game = store.session {
                GeometryReader { geometry in
                    let compact = geometry.size.height < 820
                    ScrollView {
                        VStack(spacing: compact ? 8 : 16) {
                            HStack {
                                LisaIconButton(icon: "chevron.left", label: L10n.text("Sauvegarder et revenir à l’accueil")) { store.save(); store.showGame = false }
                                Spacer()
                                VStack(spacing: 0) {
                                    Button { companionRequest += 1 } label: {
                                        Label("Lisa !", systemImage: "face.smiling")
                                            .font(LisaTheme.heading(23)).foregroundStyle(LisaTheme.ink)
                                            .frame(minHeight: 48)
                                    }
                                    .buttonStyle(LisaPressStyle()).accessibilityLabel(L10n.text("Faire rire Lisa"))
                                    .accessibilityValue(companionMessage)
                                    .disabled(paused || !mascotUncovered || reduceMotion || !store.settings.animatedDecor)
                                    Text("Lisa · " + game.puzzle.difficulty.label)
                                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                                        .foregroundStyle(LisaTheme.ink).padding(.top, 4)
                                }
                                Spacer()
                                LisaIconButton(icon: "gearshape", label: L10n.text("Réglages")) { settings = true }.accessibilityIdentifier("gameSettingsButton")
                            }
                            HStack {
                                Label(celebrationMessage.isEmpty ? L10n.text(store.mode) : celebrationMessage,
                                      systemImage: celebrationMessage.isEmpty ? (store.mode == "Libre" ? "sparkles" : "sun.max") : "sparkles")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .lineLimit(1).minimumScaleFactor(0.8)
                                    .foregroundStyle(LisaTheme.ink).padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(LisaTheme.paper.opacity(0.8), in: Capsule())
                                Spacer()
                                Text(store.settings.autoCheck || store.settings.errorLimit ? L10n.text("Erreurs %@%@", String(describing: game.mistakes), String(describing: store.settings.errorLimit ? "/3" : "")) : L10n.text("Mode zen")).font(LisaTheme.body(13)).foregroundStyle(game.mistakes > 0 ? LisaTheme.coral : LisaTheme.muted)
                                if store.settings.showTimer { Text(LisaStore.time(game.elapsedSeconds)).font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundStyle(LisaTheme.muted) }
                                Button { paused = true } label: { Image(systemName: "pause.fill").frame(width: 36, height: 40) }.accessibilityLabel(L10n.text("Mettre en pause"))
                            }
                            board(game, width: max(9, min(geometry.size.width - 32, compact ? geometry.size.height - 318 : 480)))
                            HStack(spacing: 8) {
                                tool(L10n.text("Annuler"), icon: "arrow.uturn.backward", enabled: game.canUndo) { store.session?.undo(); store.feedback(.erase); store.changed() }
                                tool(L10n.text("Gommer"), icon: "eraser", enabled: selected.map { game.isEditable($0) } ?? false) { if let selected { store.session?.erase(at: selected); store.feedback(.erase); store.changed() } }
                                tool(notesMode ? L10n.text("Notes oui") : L10n.text("Notes"), icon: "pencil.tip", active: notesMode) { notesMode.toggle(); store.feedback(.note) }
                                tool(L10n.text("Indice"), icon: "lightbulb") { hint = store.session?.hint(); if hint != nil { store.session?.recordHintConsultation(); store.save(); store.feedback(.hint); react(.thinking) }; hintPresented = true }
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
                                    }
                                    .buttonStyle(LisaPressStyle()).accessibilityLabel("\(value), " + L10n.count("remaining", remaining)).disabled(paused || game.isComplete)
                                }
                            }
                            if !compact { Text(!celebrationMessage.isEmpty ? celebrationMessage : notesMode ? L10n.text("Mode notes · Touchez une case puis un chiffre.") : L10n.text("Une case, un chiffre, un petit déclic.")).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted) }
                        }.frame(maxWidth: 500).padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 15).frame(maxWidth: .infinity)
                    }
                }
            }
            if paused {
                Color.black.opacity(0.3).ignoresSafeArea()
                LisaPauseCard { paused = false }
                    .environment(\.lisaMotionAllowed, mascotUncovered)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(reduceMotion || !store.settings.animatedDecor ? nil : .easeInOut(duration: 0.25), value: paused)
        .coordinateSpace(name: "game-space")
        .onPreferenceChange(LisaBoardFrameKey.self) { boardFrame = $0 }
        .preferredColorScheme(store.settings.darkMode ? .dark : .light)
        .saturation(store.settings.paperMode ? 0 : 1)
        .environment(\.lisaMotionAllowed, !paused && mascotUncovered)
        .onReceive(timer) { _ in
            guard scenePhase == .active, !paused, !hintPresented, !settings, !errorPresented, store.session?.isComplete == false else { return }
            store.session?.tick()
            if (store.session?.elapsedSeconds ?? 0) % 5 == 0 { store.save() }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { paused = true; store.save() } }
        .onDisappear { store.save(); LisaAudio.shared.configure(paused: false) }
        .onChange(of: paused, initial: true) { _, value in LisaAudio.shared.configure(paused: value) }
        .onChange(of: store.session?.values) { before, after in
            guard let before, let after, let game = store.session else { return }
            let event = store.milestones.record(before: before, after: after, solution: game.puzzle.solution,
                                          revealsCorrectness: store.settings.autoCheck || store.settings.errorLimit)
            guard !game.isComplete, !event.isEmpty else { return }
            glowCells = event.cells.union(after.indices.filter { event.digits.contains(after[$0]) })
            celebrationOrigin = after.indices.first { before[$0] != after[$0] } ?? selected ?? 40
            completedUnits = event.completedUnits
            completedDigits = event.digits
            let kinds = [event.completedUnits.contains { $0 < 9 } ? L10n.text("Ligne terminée !") : nil,
                         event.completedUnits.contains { (9..<18).contains($0) } ? L10n.text("Colonne terminée !") : nil,
                         event.completedUnits.contains { $0 >= 18 } ? L10n.text("Carré terminé !") : nil].compactMap { $0 }
            celebrationMessage = kinds.count > 1 ? L10n.text("Combo ×%@ !", String(describing: event.unitCount)) : kinds.first ?? L10n.text("Chiffre terminé !")
            celebrationToken += 1
            react(event.unitCount > 1 ? .celebrating : .happy)
            store.feedback(.milestone)
        }
        .task(id: celebrationToken) {
            guard celebrationToken > 0 else { return }
            do { try await Task.sleep(for: .seconds(2.8)) } catch { return }
            completedDigits = []
            glowCells = []
            completedUnits = []
            celebrationMessage = ""
        }
        .task(id: store.showVictory && scenePhase == .active && !paused) {
            guard store.showVictory, scenePhase == .active, !paused, !victoryPresented else { return }
            glowCells = Set(0..<81)
            celebrationToken += 1
            react(.celebrating)
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 480)) } catch { return }
            victoryPresented = true
        }
        .task(id: mascotReaction) {
            guard mascotReaction > 0 else { return }
            do { try await Task.sleep(for: .seconds(2.4)) } catch { return }
            mascotMood = .idle
        }
        .onChange(of: languagePreference) { _, _ in
            celebrationMessage = ""
            companionMessage = L10n.text("Au repos")
            if hint != nil { hint = store.session?.hint() }
        }
        .sheet(isPresented: $settings) { SettingsView() }
        .sheet(isPresented: $victoryPresented) { VictoryView().environment(\.lisaMotionAllowed, true).interactiveDismissDisabled() }
        .alert(L10n.text("Un petit coup de pouce"), isPresented: $hintPresented) {
            if let hint { Button(L10n.text("Placer le %@", String(describing: hint.value))) { selected = hint.index; store.session?.applyHint(countAsUsed: false); store.feedback(.place); store.changed(); react(.happy) } }
            Button(L10n.text("Je continue seul"), role: .cancel) {}
        } message: { Text(hint.map { "\($0.title)\n\($0.detail)" } ?? L10n.text("La grille est terminée.")) }
        .alert(L10n.text("On respire, puis on reprend ?"), isPresented: $errorPresented) {
            Button(L10n.text("Continuer sans limite")) { store.settings.errorLimit = false }
            Button(L10n.text("Retour à l’accueil")) { store.showGame = false }
        } message: { Text(L10n.text("Trois erreurs, ce n’est pas la fin du monde. Continuez à votre rythme ou faites une pause.")) }
    }

    private func enter(_ value: Int) {
        guard let selected, store.session?.isEditable(selected) == true, !paused else { return }
        if store.settings.errorLimit && (store.session?.mistakes ?? 0) >= 3 { errorPresented = true; return }
        if notesMode {
            guard store.session?.values[selected] == 0 else { return }
            store.session?.toggleNote(value, at: selected)
            store.feedback(.note)
        }
        else {
            let previousValue = store.session?.values[selected]
            guard previousValue != value else { return }
            var correct = false
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                correct = store.session?.enter(value, at: selected) ?? false
            }
            // A neutral companion in zen mode must not reveal the solution.
            if previousValue != value, store.settings.autoCheck || store.settings.errorLimit {
                react(correct ? .happy : .encouraging)
            }
        }
        if !notesMode { store.feedback(.place) }
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
        .overlay { if !paused && store.showVictory { LisaGridGlow(cells: glowCells, token: celebrationToken) } }
        .frame(width: innerWidth, height: innerWidth)
        .background(LisaTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            if !paused && !store.showVictory {
                LisaUnitCelebration(units: completedUnits, cells: glowCells, originIndex: celebrationOrigin, token: celebrationToken)
            }
        }
        .padding(8)
        .background(CandySurface(tint: Color(red: 0.6, green: 0.26, blue: 0.78), cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.5), lineWidth: 2))
        .shadow(color: Color(red: 0.36, green: 0.12, blue: 0.54).opacity(0.25), radius: 10, y: 6)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: LisaBoardFrameKey.self, value: proxy.frame(in: .named("game-space")))
            }
        }
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
        return L10n.text("Ligne %@, colonne %@, %@%@%@%@", String(describing: index / 9 + 1), String(describing: index % 9 + 1), String(describing: value == 0 ? L10n.text("vide") : String(value)), String(describing: game.puzzle.givens[index] != 0 ? L10n.text(", chiffre donné") : ""), String(describing: notes.isEmpty ? "" : L10n.text(", notes ") + notes), String(describing: store.settings.autoCheck && game.isIncorrect(at: index) ? L10n.text(", erreur") : ""))
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
                    .lisaFloat(amplitude: 1, tilt: 3, period: 3.8)
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
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @EnvironmentObject private var store: LisaStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var stage = 0
    @State private var progress = 0.0

    private var reward: (String, String) {
        if store.mode == "Voyage", store.eventWins >= 25 { return (L10n.text("Âme voyageuse"), "globe.europe.africa.fill") }
        if store.history.count == 1 { return (L10n.text("Premier déclic"), "star.fill") }
        if store.history.count == 10 { return (L10n.text("Le club des 10"), "crown.fill") }
        if let last = store.history.last, last.hints == 0, last.mistakes == 0,
           !store.history.dropLast().contains(where: { $0.hints == 0 && $0.mistakes == 0 }) { return (L10n.text("Esprit libre"), "leaf.fill") }
        return (store.mode == "Quotidien" ? L10n.text("Votre étoile du jour") : L10n.text("Un nouveau déclic"), "checkmark.seal.fill")
    }

    var body: some View {
        ZStack {
            LisaBackground(motionEnabled: scenePhase == .active, chapter: store.mode == "Voyage" ? LisaJourneyAtmosphere.chapter(store.eventWins) : nil)
            LisaCelebration(isActive: stage > 0 && scenePhase == .active)
            ScrollView {
                VStack(spacing: 20) {
                    victoryStars
                        .accessibilityHidden(true)
                        .padding(.top, 28)
                    ZStack {
                        LisaMagicHalo(strong: true).frame(width: 225, height: 225)
                        Circle().fill(LisaTheme.yellow.opacity(0.35)).frame(width: 175, height: 175)
                        Circle().strokeBorder(.white.opacity(0.75), style: StrokeStyle(lineWidth: 3, dash: [4, 8])).frame(width: 190, height: 190)
                        LisaMascot(size: 140, celebrating: true, mood: .happy)
                    }
                    VStack(spacing: 8) {
                        Text(L10n.text("Bien joué, vous !"))
                            .font(.system(size: 35, weight: .black, design: .rounded))
                            .foregroundStyle(LisaTheme.coral)
                            .shadow(color: .white.opacity(0.7), radius: 0, y: 2)
                            .multilineTextAlignment(.center)
                        Text(L10n.text("81 cases. Et ce petit plaisir\nd’avoir trouvé la dernière."))
                            .font(LisaTheme.body(17)).multilineTextAlignment(.center).foregroundStyle(LisaTheme.ink)
                    }
                    if let game = store.session {
                        HStack(spacing: 9) {
                            metric(LisaStore.time(game.elapsedSeconds), L10n.text("votre temps"), icon: "stopwatch.fill")
                            metric("\(game.mistakes)", L10n.text("erreurs"), icon: "heart.fill")
                            metric("\(game.hintsUsed)", L10n.text("indices"), icon: "lightbulb.fill")
                        }
                        if stage >= 1 {
                            rewardCard
                                .transition(reduceMotion ? .identity : .scale(scale: 0.85).combined(with: .opacity))
                        }
                        ShareLink(item: L10n.text("J’ai terminé un sudoku %@ en %@ avec Sudoku Lisa. À votre tour !", String(describing: game.puzzle.difficulty.label.lowercased()), String(describing: LisaStore.time(game.elapsedSeconds)))) {
                            Label(L10n.text("Partager mon petit exploit"), systemImage: "square.and.arrow.up")
                                .font(LisaTheme.body(15)).foregroundStyle(LisaTheme.ink)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(CandySurface(tint: LisaTheme.paper, cornerRadius: 18, depth: 3))
                        }
                        .buttonStyle(LisaPressStyle())
                    }
                    LisaButton(title: L10n.text("Continuer l’aventure"), icon: "arrow.right") {
                        store.showVictory = false; store.showGame = false
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 30)
                .frame(maxWidth: 480).frame(maxWidth: .infinity)
            }
        }
        .task(id: scenePhase == .active) {
            guard scenePhase == .active else { return }
            if stage == 0 {
                progress = Double(max(0, min(store.eventWins - 1, 25))) / 25
                // Let the initial star pose render, then launch the whole celebration together.
                do { try await Task.sleep(for: .milliseconds(motionEnabled ? 60 : 0)) } catch { return }
                withAnimation(motionEnabled ? .spring(response: 0.34, dampingFraction: 0.65) : nil) { stage = 1 }
            }
            do { try await Task.sleep(for: .milliseconds(motionEnabled ? 280 : 0)) } catch { return }
            withAnimation(motionEnabled ? .easeOut(duration: 0.45) : nil) {
                progress = Double(min(store.eventWins, 25)) / 25
                stage = 2
            }
        }
    }

    private var motionEnabled: Bool { !reduceMotion && store.settings.animatedDecor }

    private var victoryStars: some View {
        HStack(spacing: 15) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: index == 1 ? 52 : 38, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [.white, LisaTheme.yellow, Color.orange], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(red: 0.66, green: 0.27, blue: 0.3), radius: 0, y: 4)
                    .shadow(color: LisaTheme.yellow.opacity(0.65), radius: 12)
                    .rotationEffect(.degrees((index == 0 ? -15.0 : index == 2 ? 15.0 : 0) + (stage == 0 && motionEnabled ? -100 : 0)))
                    .scaleEffect(stage == 0 && motionEnabled ? 0.15 : 1)
                    .opacity(stage == 0 && motionEnabled ? 0 : 1)
                    .offset(y: (index == 1 ? -8.0 : 4.0) + (stage == 0 && motionEnabled ? 26 : 0))
                    .animation(motionEnabled ? .spring(response: 0.38, dampingFraction: 0.52).delay(Double(index) * 0.09) : nil, value: stage > 0)
            }
        }
    }

    private var rewardCard: some View {
        VStack(spacing: 10) {
            Label(reward.0, systemImage: reward.1).font(LisaTheme.heading(20)).foregroundStyle(LisaTheme.ink)
            if store.mode == "Voyage" {
                ProgressView(value: progress).tint(LisaTheme.coral)
                    .accessibilityLabel(L10n.text("Progression du voyage"))
                    .accessibilityValue(L10n.text("%@ étapes sur 25", String(describing: min(store.eventWins, 25))))
                Text(L10n.text("%@ / 25 étoiles", String(describing: min(store.eventWins, 25)))).font(LisaTheme.body(13))
                if store.eventWins < 25 {
                    Text(L10n.text("Prochaine étape · ") + LisaJourneyAtmosphere.names[LisaJourneyAtmosphere.chapter(store.eventWins)])
                        .font(LisaTheme.body(12)).multilineTextAlignment(.center)
                } else { Text(L10n.text("Les cinq escales sont à vous !")).font(LisaTheme.body(13)) }
            } else if store.mode == "Événement" {
                Text(L10n.text("%@ / 10 souvenirs du mois", String(describing: store.seasonProgress))).font(LisaTheme.body(14))
            } else if store.mode == "Quotidien" {
                Text(L10n.count("streak", store.streak)).font(LisaTheme.body(14))
            } else {
                Text(L10n.count("collection", store.history.count)).font(LisaTheme.body(14))
            }
        }
        .frame(maxWidth: .infinity).padding(18)
        .background(CandySurface(tint: LisaTheme.paper, cornerRadius: 22, depth: 3))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(LisaTheme.yellow.opacity(0.65), lineWidth: 2))
        .overlay { LisaShimmer(radius: 22) }
        .accessibilityIdentifier("victoryReward")
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

private struct LisaBoardFrameKey: PreferenceKey {
    static let defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let frame = nextValue()
        if !frame.isEmpty { value = frame }
    }
}
