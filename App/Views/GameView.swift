import SwiftUI
import UIKit
import SudokuCore

struct GameView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @EnvironmentObject private var store: LisaStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var keypadDigitSize = 28.0
    @State private var gameDetailsPresented = false
    @State private var selected: Int?
    @State private var notesMode = false
    @State private var paused = false
    @StateObject private var coach = HintCoachModel()
    private var hint: SudokuHint? { coach.hint }
    private var observedBoard: GameBoardSnapshot? {
        store.session.map { GameBoardSnapshot(puzzle: $0.puzzle, values: $0.values) }
    }
    @State private var learning = false
    @State private var lessonTechnique: SudokuTechnique?
    @State private var lockedDigit: Int?
    @State private var continueRequested = false
    @State private var hintPresented = false
    @State private var usesWideLayout = false
    @State private var hintStage = 0
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
    private var mascotUncovered: Bool { scenePhase == .active && !settings && !gameDetailsPresented && !victoryPresented && !hintPresented && !errorPresented && !learning && !coach.isWorking && !store.isGenerating }
    private var timerRunning: Bool {
        scenePhase == .active && !paused && !hintPresented && !settings && !gameDetailsPresented && !errorPresented && !learning
            && !coach.isWorking && !store.isGenerating && store.session?.isComplete == false
    }

    var body: some View {
        let _ = LisaRenderBudget.shared.recordGameBody()
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
                    let wide = geometry.size.width >= 600 && !dynamicTypeSize.isAccessibilitySize
                    let compact = geometry.size.height < 820 || dynamicTypeSize.isAccessibilitySize
                    let contentWidth = max(0, min(wide ? 1040 : 500, geometry.size.width - 32))
                    let controlsWidth = wide ? min(300, max(220, contentWidth * 0.32)) : contentWidth
                    let accessibilityControlsHeight = 48.0 + 44.0 + 3 * (min(keypadDigitSize, 56) * 1.25 + 10) + 58
                    let boardWidth = wide
                        ? min(680, max(252, geometry.size.height - 94), max(9, contentWidth - controlsWidth - 24))
                        : dynamicTypeSize.isAccessibilitySize
                            ? min(contentWidth, max(225, geometry.size.height - accessibilityControlsHeight))
                            : min(contentWidth, compact ? max(270, geometry.size.height - 330) : 480)
                    let layout = wide
                        ? AnyLayout(HStackLayout(alignment: .center, spacing: 24))
                        : AnyLayout(VStackLayout(spacing: compact ? 8 : 16))
                    ScrollView {
                        VStack(spacing: compact ? 8 : 16) {
                            gameHeader(game, wide: wide)
                            layout {
                                VStack(spacing: compact ? 8 : 16) {
                                    if !wide && !hintPresented && !dynamicTypeSize.isAccessibilitySize { gameStatus(game, wide: false) }
                                    board(game, width: boardWidth).disabled(hintPresented)
                                }
                                .frame(width: wide ? boardWidth : contentWidth)
                                if hintPresented, wide, let hint {
                                    ScrollView { coaching(hint) }
                                        .frame(width: controlsWidth, height: max(180, geometry.size.height - 94))
                                } else if !hintPresented {
                                    gameControls(game, compact: compact, wide: wide)
                                        .frame(width: controlsWidth)
                                }
                            }
                            .frame(minHeight: wide ? max(0, geometry.size.height - (compact ? 94 : 102)) : nil)
                        }
                        .frame(maxWidth: wide ? 1040 : 500)
                        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 15)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                        .accessibilityHidden(paused || store.isGenerating)
                    }
                    .onChange(of: wide, initial: true) { _, value in usesWideLayout = value }
                }
            }
            if paused {
                Color.black.opacity(0.3).ignoresSafeArea()
                LisaPauseCard { paused = false }
                    .environment(\.lisaMotionAllowed, mascotUncovered)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .accessibilityHidden(store.isGenerating)
            }
        }
        .animation(reduceMotion || !store.settings.animatedDecor ? nil : .easeInOut(duration: 0.25), value: paused)
        .coordinateSpace(name: "game-space")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hintPresented, !usesWideLayout, let hint {
                ScrollView { coaching(hint) }
                    .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? 420 : 260)
                    .accessibilityHidden(store.isGenerating)
                    .background(LisaTheme.paper)
            }
        }
        .onPreferenceChange(LisaBoardFrameKey.self) { boardFrame = $0 }
        .preferredColorScheme(store.settings.darkMode ? .dark : .light)
        .saturation(store.settings.paperMode ? 0 : 1)
        .environment(\.lisaMotionAllowed, !paused && mascotUncovered)
        .task(id: timerRunning) {
            guard timerRunning else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard !Task.isCancelled else { return }
                store.tick()
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { paused = true; if coach.isWorking { coach.cancel() }; store.saveForBackground() } }
        .onDisappear { coach.cancel(); store.synchronizeElapsedTime(); store.save(); LisaAudio.shared.configure(paused: false) }
        .onChange(of: paused, initial: true) { _, value in LisaAudio.shared.configure(paused: value) }
        .onChange(of: observedBoard) { previous, current in
            guard let current, let previous, previous.puzzle == current.puzzle else {
                resetForNewPuzzle()
                return
            }
            guard let game = store.session else { return }
            let before = previous.values, after = current.values
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
            if hintPresented, let game = store.session { hintPresented = false; coach.request(game) }
        }
        .onChange(of: coach.hint) { _, suggestion in
            guard suggestion != nil, coach.matches(store.session) else { return }
            hintStage = 0
            store.session?.recordHintConsultation()
            store.save()
            store.feedback(.hint)
            react(.thinking)
            hintPresented = true
        }
        .onChange(of: store.settings.numberFirst) { _, _ in lockedDigit = nil }
        .sheet(isPresented: $learning) {
            LearnView(initialTechnique: lessonTechnique).environment(\.lisaMotionAllowed, scenePhase == .active)
        }
        .overlay { GenerationOverlay() }
        .alert(L10n.text("Préparation de la grille"), isPresented: Binding(get: { store.generationError != nil }, set: { if !$0 { store.generationError = nil } })) {
            Button(L10n.text("D’accord")) { store.generationError = nil }
        } message: { Text(L10n.text(store.generationError ?? "")) }
        .sheet(isPresented: $settings) { SettingsView() }
        .sheet(isPresented: $gameDetailsPresented) { gameDetails }
        .sheet(isPresented: $victoryPresented, onDismiss: {
            if continueRequested { continueRequested = false; store.continueAfterVictory() }
        }) {
            VictoryView(onContinue: {
                store.showVictory = false
                continueRequested = true
                victoryPresented = false
            }).environment(\.lisaMotionAllowed, scenePhase == .active).interactiveDismissDisabled()
        }
        .alert(L10n.text("On respire, puis on reprend ?"), isPresented: $errorPresented) {
            Button(L10n.text("Continuer sans limite")) { store.settings.errorLimit = false }
            Button(L10n.text("Retour à l’accueil")) { store.showGame = false }
        } message: { Text(L10n.text("Trois erreurs, ce n’est pas la fin du monde. Continuez à votre rythme ou faites une pause.")) }
    }

    /// Reset the puzzle interaction without rebuilding the companion scene.
    /// Monotonic companion requests and geometry belong to the retained scene.
    private func resetForNewPuzzle() {
        coach.cancel()
        selected = nil
        lockedDigit = nil
        notesMode = false
        paused = false
        hintPresented = false
        hintStage = 0
        learning = false
        lessonTechnique = nil
        settings = false
        gameDetailsPresented = false
        errorPresented = false
        continueRequested = false
        victoryPresented = false
        glowCells = []
        completedUnits = []
        completedDigits = []
        celebrationOrigin = 40
        celebrationToken = 0
        celebrationMessage = ""
        mascotMood = .idle
        mascotReaction = 0
        companionMessage = L10n.text("Au repos")
    }

    private func coaching(_ hint: SudokuHint) -> some View {
        HintCoachView(hint: hint, stage: $hintStage,
                      animationEnabled: scenePhase == .active && !learning && !reduceMotion && store.settings.animatedDecor,
                      close: { hintPresented = false },
                      learn: { lessonTechnique = hint.deduction?.techniqueID; learning = true },
                      apply: { applyHint(hint) })
            .environment(\.lisaMotionAllowed, scenePhase == .active && !learning && !reduceMotion && store.settings.animatedDecor)
    }

    private func applyHint(_ hint: SudokuHint) {
        guard coach.matches(store.session), let deduction = hint.deduction else { hintPresented = false; return }
        if store.session?.applyDeduction(deduction) == true {
            selected = hint.index
            store.feedback(.place); store.changed(); react(.happy)
        }
        hintPresented = false
    }

    @ViewBuilder
    private func gameHeader(_ game: GameSession, wide: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: 4) {
                LisaIconButton(icon: "chevron.left", label: L10n.text("Sauvegarder et revenir à l’accueil")) { store.save(); store.showGame = false }
                Spacer(minLength: 0)
                LisaIconButton(icon: "face.smiling", label: L10n.text("Faire rire Lisa")) { companionRequest += 1 }
                    .accessibilityInputLabels(["Lisa"]).accessibilityValue(companionMessage)
                    .disabled(paused || !mascotUncovered || reduceMotion || !store.settings.animatedDecor)
                LisaIconButton(icon: "book", label: L10n.text("Apprendre")) { lessonTechnique = nil; learning = true }
                    .accessibilityIdentifier("gameLearnButton")
                LisaIconButton(icon: "info.circle", label: L10n.text("La partie en détail")) { gameDetailsPresented = true }
                    .accessibilityIdentifier("gameDetailsButton")
                LisaIconButton(icon: "pause.fill", label: L10n.text("Mettre en pause")) { paused = true }
                LisaIconButton(icon: "gearshape", label: L10n.text("Réglages")) { settings = true }
                    .accessibilityIdentifier("gameSettingsButton")
            }
        } else {
            HStack(spacing: 8) {
                LisaIconButton(icon: "chevron.left", label: L10n.text("Sauvegarder et revenir à l’accueil")) { store.save(); store.showGame = false }
                Spacer()
                VStack(spacing: 0) {
                    Button { companionRequest += 1 } label: {
                        Label("Lisa !", systemImage: "face.smiling")
                            .font(LisaTheme.heading(23)).foregroundStyle(LisaTheme.ink)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(LisaPressStyle()).accessibilityLabel(L10n.text("Faire rire Lisa"))
                    .accessibilityValue(companionMessage)
                    .accessibilityInputLabels(["Lisa"])
                    .disabled(paused || !mascotUncovered || reduceMotion || !store.settings.animatedDecor)
                    Text(wide && !celebrationMessage.isEmpty ? celebrationMessage : (wide ? L10n.text(store.mode) : "Lisa") + " · " + game.puzzle.difficulty.label)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(LisaTheme.ink).padding(.top, 4)
                }
                Spacer()
                LisaIconButton(icon: "book", label: L10n.text("Apprendre")) { lessonTechnique = nil; learning = true }
                    .accessibilityIdentifier("gameLearnButton")
                LisaIconButton(icon: "gearshape", label: L10n.text("Réglages")) { settings = true }.accessibilityIdentifier("gameSettingsButton")
            }
        }
    }

    private var gameDetails: some View {
        NavigationStack {
            ScrollView {
                if let game = store.session {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(L10n.text(store.mode) + " · " + game.puzzle.difficulty.label).font(LisaTheme.heading(23))
                        Text(store.settings.autoCheck || store.settings.errorLimit
                             ? L10n.text("Erreurs %@%@", String(game.mistakes), store.settings.errorLimit ? "/3" : "")
                             : L10n.text("Mode zen")).font(LisaTheme.body())
                        if store.settings.showTimer { LisaGameTimer(clock: store.clock) }
                        if let selected {
                            Text(cellLabel(game, index: selected)).font(LisaTheme.body(20))
                                .accessibilityIdentifier("selectedCellDetail")
                        }
                        if notesMode {
                            Label(L10n.text("Mode notes · Les petits chiffres sont des possibilités."), systemImage: "pencil.tip").font(LisaTheme.body())
                        }
                        if let digit = lockedDigit {
                            Button { lockedDigit = nil } label: {
                                Label(L10n.text("Chiffre %@ verrouillé · Libérer", String(digit)), systemImage: "lock.open")
                                    .font(LisaTheme.body())
                            }.accessibilityIdentifier("unlockDigit")
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(24)
                }
            }
            .navigationTitle(L10n.text("La partie en détail")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.text("Terminé")) { gameDetailsPresented = false } } }
            .background(LisaTheme.paper)
        }
        .preferredColorScheme(store.settings.darkMode ? .dark : .light)
    }

    private var modeLabel: some View {
        Label(celebrationMessage.isEmpty ? L10n.text(store.mode) : celebrationMessage,
              systemImage: celebrationMessage.isEmpty ? (store.mode == "Libre" ? "sparkles" : "sun.max") : "sparkles")
            .font(.caption.weight(.bold))
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(LisaTheme.ink).padding(.horizontal, 10).padding(.vertical, 6)
            .background(LisaTheme.paper.opacity(0.8), in: Capsule())
    }

    private func gameStatus(_ game: GameSession, wide: Bool) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            if !wide { modeLabel }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(store.settings.autoCheck || store.settings.errorLimit ? L10n.text("Erreurs %@%@", String(describing: game.mistakes), String(describing: store.settings.errorLimit ? "/3" : "")) : L10n.text("Mode zen"))
                .font(LisaTheme.body(13)).foregroundStyle(game.mistakes > 0 ? LisaTheme.coral : LisaTheme.muted)
            if store.settings.showTimer {
                LisaGameTimer(clock: store.clock)
            }
            Button { paused = true } label: {
                Image(systemName: "pause.fill").frame(width: 44, height: 44)
            }.accessibilityLabel(L10n.text("Mettre en pause"))
        }
        .padding(.horizontal, wide ? 8 : 0)
        .background {
            if wide { RoundedRectangle(cornerRadius: 14).fill(LisaTheme.paper) }
        }
    }

    private func gameControls(_ game: GameSession, compact: Bool, wide: Bool) -> some View {
        VStack(spacing: compact ? 8 : 16) {
            if wide { gameStatus(game, wide: true) }
            if game.isComplete && !victoryPresented && !store.isGenerating && !store.showVictory {
                LisaButton(title: store.victoryContinuationTitle, icon: "arrow.right") {
                    store.continueAfterVictory()
                }
                .accessibilityIdentifier("completedContinue")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                tool(L10n.text("Annuler"), icon: "arrow.uturn.backward", enabled: game.canUndo) { store.session?.undo(); store.feedback(.erase); store.changed() }
                tool(L10n.text("Gommer"), icon: "eraser", enabled: selected.map { game.isEditable($0) } ?? false) { if let selected { store.session?.erase(at: selected); store.feedback(.erase); store.changed() } }
                tool(notesMode ? L10n.text("Notes oui") : L10n.text("Notes"), icon: "pencil.tip", active: notesMode) { notesMode.toggle(); store.feedback(.note) }
                tool(coach.isWorking ? L10n.text("Recherche…") : L10n.text("Indice"), icon: "lightbulb", enabled: !coach.isWorking) { if let game = store.session { coach.request(game) } }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                ForEach(1...9, id: \.self) { value in
                    let remaining = max(0, 9 - game.values.filter { $0 == value }.count)
                    Button { if store.settings.numberFirst || lockedDigit != nil { lockedDigit = value; store.feedback(.select) } else { enter(value) } } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("\(value)").font(.system(size: min(keypadDigitSize, 56), weight: .black, design: .rounded))
                                .shadow(color: .black.opacity(0.12), radius: 0, y: 1)
                            if !dynamicTypeSize.isAccessibilitySize {
                                Text("\(remaining)").font(.caption.weight(.bold))
                            }
                        }
                        .foregroundStyle(LisaTheme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? min(keypadDigitSize, 56) * 1.25 : nil)
                        .frame(minHeight: 47).padding(.vertical, 5)
                        .background(CandySurface(tint: candyColor(value), cornerRadius: notesMode ? 10 : 16))
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: notesMode ? 10 : 16).strokeBorder(lockedDigit == value ? LisaTheme.ink : .clear, lineWidth: 3))
                        .overlay(alignment: .topLeading) {
                            if notesMode { Image(systemName: "pencil.tip").font(.caption2.weight(.bold)).foregroundStyle(LisaTheme.ink).padding(5) }
                        }
                    }
                    .buttonStyle(LisaPressStyle()).accessibilityLabel("\(value), " + L10n.count("remaining", remaining))
                    .accessibilityInputLabels([String(value)])
                    .accessibilityAction(named: Text(L10n.text("Verrouiller ce chiffre"))) { lockedDigit = value; store.feedback(.select) }
                    .accessibilityIdentifier("digit-\(value)")
                    .accessibilityAddTraits(lockedDigit == value ? .isSelected : [])
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in lockedDigit = value; store.feedback(.select) })
                    .disabled(paused || game.isComplete)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize, let digit = lockedDigit {
                Button { lockedDigit = nil } label: {
                    Label(L10n.text("Chiffre %@ verrouillé · Libérer", String(digit)), systemImage: "lock.open")
                        .font(LisaTheme.body(12))
                }.accessibilityIdentifier("unlockDigit")
            }
            if notesMode && !dynamicTypeSize.isAccessibilitySize {
                Label(L10n.text("Mode notes · Les petits chiffres sont des possibilités."), systemImage: "pencil.tip")
                    .font(LisaTheme.body(12)).foregroundStyle(LisaTheme.accentInk)
                    .padding(8).frame(maxWidth: .infinity).background(LisaTheme.lavender, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("notesModeBanner")
            }
            if !compact && !dynamicTypeSize.isAccessibilitySize {
                Text(!celebrationMessage.isEmpty ? celebrationMessage : notesMode ? L10n.text("Mode notes · Touchez une case puis un chiffre.") : L10n.text("Une case, un chiffre, un petit déclic."))
                    .font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
                    .multilineTextAlignment(.center)
            }
        }
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
        if UIAccessibility.isVoiceOverRunning, let game = store.session {
            UIAccessibility.post(notification: .announcement, argument: cellLabel(game, index: selected))
        }
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
                                if let lockedDigit, game.isEditable(index) { enter(lockedDigit) } else { store.feedback() }
                            } label: { cell(game, index: index, side: side) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("cell-\(index)")
                            .accessibilityLabel(cellLabel(game, index: index))
                            .accessibilityInputLabels([L10n.text("Case %@ %@", String(row + 1), String(col + 1))])
                            .accessibilityValue(selected == index ? L10n.text("Sélectionnée") : "")
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
        SudokuCellContent(
            value: game.values[index], notes: displayedNotes(game, index: index), given: game.puzzle.givens[index] != 0,
            wrong: store.settings.autoCheck && game.isIncorrect(at: index),
            duplicate: store.settings.highlightDuplicates && store.duplicateCells.contains(index),
            isSelected: selected == index,
            sameNumber: lockedDigit.map { game.values[index] == $0 } ?? selected.map { game.values[$0] != 0 && game.values[$0] == game.values[index] } ?? false,
            peer: store.settings.highlightPeers && (selected.map { peers(index, $0) } ?? false),
            inHintFocus: hintPresented && coach.focusedCells.contains(index),
            marks: hintPresented && hintStage >= 1 ? coach.marksByCell[index] ?? [] : [],
            side: side, colorScheme: colorScheme, differentiateWithoutColor: differentiateWithoutColor
        ).equatable()
    }
    private func peers(_ a: Int, _ b: Int) -> Bool { a / 9 == b / 9 || a % 9 == b % 9 || (a / 27 == b / 27 && a % 9 / 3 == b % 9 / 3) }
    private func displayedNotes(_ game: GameSession, index: Int) -> Set<Int> {
        hintPresented && hintStage >= 1 && coach.candidates.count == 81 && coach.focusedCells.contains(index)
            ? coach.candidates[index] : game.notes[index]
    }
    private func cellLabel(_ game: GameSession, index: Int) -> String {
        let value = game.values[index]
        let notes = displayedNotes(game, index: index).sorted().map(String.init).formatted(.list(type: .and).locale(L10n.locale))
        let base = L10n.text("Ligne %@, colonne %@, %@%@%@%@", String(describing: index / 9 + 1), String(describing: index % 9 + 1), String(describing: value == 0 ? L10n.text("vide") : String(value)), String(describing: game.puzzle.givens[index] != 0 ? L10n.text(", chiffre donné") : ""), String(describing: notes.isEmpty ? "" : L10n.text(", notes ") + notes), String(describing: store.settings.autoCheck && game.isIncorrect(at: index) ? L10n.text(", erreur") : ""))
        let duplicate = store.settings.highlightDuplicates && store.duplicateCells.contains(index)
        let sameNumber = lockedDigit.map { value == $0 }
            ?? selected.map { game.values[$0] != 0 && value == game.values[$0] } ?? false
        let peer = store.settings.highlightPeers && (selected.map { peers(index, $0) && index != $0 } ?? false)
        let description = base
            + (sameNumber && index != selected ? L10n.text(", chiffre mis en évidence") : "")
            + (peer ? L10n.text(", même ligne, colonne ou carré que la sélection") : "")
            + (duplicate ? L10n.text(", doublon") : "")
            + (hintPresented && coach.focusedCells.contains(index) ? L10n.text(", case de l’indice") : "")
        guard hintPresented, hintStage >= 1 else { return description }
        let removals = (coach.marksByCell[index] ?? []).map {
            L10n.text("Ligne %@, colonne %@ : retirer le candidat %@.", String(index / 9 + 1), String(index % 9 + 1), String($0.value))
        }
        return ([description] + removals).joined(separator: " ")
    }
    private func candyColor(_ value: Int) -> Color {
        let colors: [Color] = [LisaTheme.lavender, LisaTheme.sky, LisaTheme.paper,
                               LisaTheme.mint, LisaTheme.yellow, LisaTheme.sky,
                               LisaTheme.lavender, LisaTheme.yellow, LisaTheme.mint]
        return colors[value - 1]
    }
    private func tool(_ title: String, icon: String, active: Bool = false, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        let tint = active ? LisaTheme.yellow
            : icon == "lightbulb" ? LisaTheme.paper
            : icon == "eraser" ? LisaTheme.sky : LisaTheme.lavender
        return Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 22, weight: .bold))
                    .lisaFloat(amplitude: 1, tilt: 3, period: 3.8)
                    .shadow(color: .black.opacity(0.13), radius: 0, y: 2)
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(title).font(.caption.weight(.heavy)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity).frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 44 : 60)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 0 : 6)
            .foregroundStyle(LisaTheme.ink)
            .background(CandySurface(tint: tint, cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(active ? LisaTheme.ink : .clear, lineWidth: 2))
            .contentShape(RoundedRectangle(cornerRadius: 17))
            .opacity(enabled ? 1 : 0.42)
        }.buttonStyle(LisaPressStyle()).disabled(!enabled)
            .accessibilityLabel(title)
            .accessibilityInputLabels([icon == "pencil.tip" ? L10n.text("Notes") : icon == "lightbulb" ? L10n.text("Indice") : title])
            .accessibilityAddTraits(active ? .isSelected : [])
    }
}

struct VictoryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var onContinue: () -> Void = {}
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
                            .font(LisaTheme.heading(35))
                            .foregroundStyle(LisaTheme.actionInk)
                            .multilineTextAlignment(.center)
                        Text(L10n.text("81 cases. Et ce petit plaisir\nd’avoir trouvé la dernière."))
                            .font(LisaTheme.body(17)).multilineTextAlignment(.center).foregroundStyle(LisaTheme.ink)
                    }
                    if let game = store.session {
                        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 9)) : AnyLayout(HStackLayout(spacing: 9))) {
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
                    LisaButton(title: store.victoryContinuationTitle, icon: "arrow.right", action: onContinue)
                        .accessibilityIdentifier("victoryContinue")
                    Button(L10n.text("Retour à l’accueil")) { store.showVictory = false; store.showGame = false }
                        .font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted)
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
                .accessibilityIdentifier("victoryReward")
            if store.mode == "Voyage", store.eventWins == 5 {
                PoulpiStarBadge(size: 44)
                Text(L10n.text("Un souvenir pour Poulpi !")).font(LisaTheme.heading(18))
                Text(L10n.text("L’étoile du voyage est à vous. Retrouvez-la dans Poulpi."))
                    .font(LisaTheme.body(13)).multilineTextAlignment(.center)
                Button(store.poulpiStarEquipped ? L10n.text("Étoile équipée") : L10n.text("Équiper l’étoile")) {
                    store.equipPoulpiStar(true)
                }.disabled(store.poulpiStarEquipped).accessibilityIdentifier("equipVictoryStar")
            }
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

/// Candidate/clock changes do not trigger board milestones. Puzzle equality
/// separates edits within a game from a successfully generated next game.
private struct GameBoardSnapshot: Equatable {
    let puzzle: Puzzle
    let values: [Int]
}

private struct LisaBoardFrameKey: PreferenceKey {
    static let defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let frame = nextValue()
        if !frame.isEmpty { value = frame }
    }
}

private struct LisaGameTimer: View {
    @ObservedObject var clock: LisaGameClock
    var body: some View {
        Text(LisaStore.time(clock.seconds))
            .font(.body.monospacedDigit())
            .foregroundStyle(LisaTheme.muted)
            .accessibilityIdentifier("gameTimer")
    }
}

private struct SudokuCellContent: View, Equatable {
    let value: Int
    let notes: Set<Int>
    let given: Bool
    let wrong: Bool
    let duplicate: Bool
    let isSelected: Bool
    let sameNumber: Bool
    let peer: Bool
    let inHintFocus: Bool
    let marks: [CandidateElimination]
    let side: CGFloat
    let colorScheme: ColorScheme
    let differentiateWithoutColor: Bool
    var body: some View {
        let blue = Color(red: 0.18, green: 0.59, blue: 0.94)
        let background = inHintFocus ? LisaTheme.yellow.opacity(colorScheme == .dark ? 0.45 : 0.72)
            : (wrong || duplicate) ? Color.red.opacity(colorScheme == .dark ? 0.27 : 0.12)
            : isSelected ? blue.opacity(colorScheme == .dark ? 0.42 : 0.26)
            : sameNumber ? LisaTheme.yellow.opacity(colorScheme == .dark ? 0.27 : 0.45)
            : (peer) ? LisaTheme.lavender.opacity(colorScheme == .dark ? 0.12 : 0.22) : LisaTheme.paper
        return ZStack {
            RoundedRectangle(cornerRadius: 4).fill(background).padding(0.7)
            if isSelected {
                RoundedRectangle(cornerRadius: 4).strokeBorder(blue, lineWidth: 2).padding(1)
            }
            if inHintFocus {
                RoundedRectangle(cornerRadius: 4).strokeBorder(LisaTheme.ink, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).padding(2)
            }
            if differentiateWithoutColor && sameNumber && !isSelected {
                Capsule().fill(LisaTheme.ink).frame(width: side * 0.38, height: 2)
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 3)
            }
            if differentiateWithoutColor && peer && !isSelected {
                Circle().fill(LisaTheme.ink).frame(width: 3, height: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(3)
            }
            if value != 0 {
                Text("\(value)").contentTransition(.numericText()).font(.system(size: side * 0.54, weight: !given ? .medium : .semibold, design: .rounded)).foregroundStyle(wrong || duplicate ? (colorScheme == .dark ? Color(red: 1, green: 0.55, blue: 0.6) : Color(red: 0.76, green: 0.12, blue: 0.22)) : !given ? (colorScheme == .dark ? Color(red: 0.62, green: 0.84, blue: 1) : Color(red: 0.13, green: 0.39, blue: 0.72)) : LisaTheme.ink)
            } else {
                VStack(spacing: 0) { ForEach(0..<3) { row in HStack(spacing: 0) { ForEach(1...3, id: \.self) { col in let note = row * 3 + col; Text(notes.contains(note) ? "\(note)" : " ").font(.system(size: side * 0.23, weight: .medium, design: .rounded)).foregroundStyle(LisaTheme.muted).frame(width: side / 3, height: side / 3) } } } }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if wrong || duplicate {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: max(8, side * 0.24), weight: .bold))
                    .foregroundStyle(LisaTheme.ink).background(LisaTheme.paper, in: Circle())
                    .padding(2).accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !marks.isEmpty {
                HStack(spacing: 0) {
                    ForEach(marks, id: \.self) { mark in
                        Text("\(mark.value)").font(.system(size: max(7, side * 0.22), weight: .bold, design: .rounded))
                            .strikethrough().foregroundStyle(LisaTheme.coral)
                            .padding(.horizontal, 1).background(LisaTheme.paper.opacity(0.85), in: Capsule())
                    }
                }.padding(1).allowsHitTesting(false)
            }
        }
        .frame(width: side, height: side).contentShape(Rectangle())
    }
}
