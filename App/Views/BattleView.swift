import SwiftUI
import SudokuCore

/// Battle owns its session in BattleService; the solo store is only used for cosmetics/rewards.
struct BattleView: View {
    @EnvironmentObject private var store: LisaStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var battle = BattleService.shared
    @State private var confirmLeave = false
    @State private var visible = false

    private var motionEnabled: Bool {
        visible && scenePhase == .active && !reduceMotion && store.settings.animatedDecor
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LisaBackground(motionEnabled: false, quiet: true)
                ScrollView {
                    VStack(spacing: 20) {
                        if let error = battle.errorMessage {
                            Label(L10n.text(error), systemImage: "exclamationmark.circle")
                                .font(.callout).foregroundStyle(LisaTheme.ink)
                                .padding().background(LisaTheme.yellow.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
                                .accessibilityIdentifier("battleError")
                        }
                        switch battle.state {
                        case .idle, .matchmaking:
                            BattleWelcome(battle: battle, appearance: store.poulpiAppearance)
                                .transition(.opacity.combined(with: .offset(y: 12)))
                        case .lobby, .preparing, .countdown:
                            BattleLobby(battle: battle)
                                .transition(.opacity.combined(with: .offset(y: 12)))
                        case .playing:
                            BattlePlayView(battle: battle)
                                .transition(.opacity.combined(with: .offset(y: 12)))
                        case .finished:
                            BattlePodium(battle: battle)
                                .transition(.opacity.combined(with: .offset(y: 12)))
                        case .cancelled:
                            VStack(spacing: 20) {
                                ContentUnavailableView(L10n.text("Battle interrompue"), systemImage: "wifi.exclamationmark",
                                    description: Text(L10n.text("La partie n’a pas été comptabilisée. Retrouvez vos amis pour une nouvelle battle.")))
                                LisaButton(title: L10n.text("Retour à l’accueil"), icon: "house") { close() }
                            }
                            .transition(.opacity.combined(with: .offset(y: 12)))
                        }
                    }
                    .animation(motionEnabled ? .easeInOut(duration: 0.24) : nil, value: battle.state)
                    .padding(16).frame(maxWidth: 1000).frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(L10n.text("Battle entre amis"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { if battle.state == .idle || battle.state == .finished || battle.state == .cancelled { close() } else { confirmLeave = true } } label: {
                        Image(systemName: "xmark")
                    }.accessibilityLabel(L10n.text("Quitter la battle")).accessibilityIdentifier("leaveBattle")
                }
            }
            .confirmationDialog(L10n.text("Quitter la battle ?"), isPresented: $confirmLeave, titleVisibility: .visible) {
                Button(L10n.text("Quitter"), role: .destructive) { close() }
                Button(L10n.text("Continuer"), role: .cancel) {}
            } message: {
                Text(L10n.text("Un départ compte comme un abandon. Si vous organisez la course, elle sera interrompue pour tous."))
            }
        }
        .tint(LisaTheme.actionInk)
        .preferredColorScheme(store.settings.darkMode ? .dark : .light)
        .saturation(store.settings.paperMode ? 0 : 1)
        .interactiveDismissDisabled()
        .environment(\.lisaMotionAllowed, motionEnabled)
        .onChange(of: scenePhase, initial: true) { _, phase in battle.setActive(phase == .active) }
        .onDisappear { visible = false; battle.setPresented(false) }
        .onAppear {
            visible = true
            battle.setPresented(true)
            battle.configureAppearance(store.poulpiAppearance)
            #if DEBUG
            battle.prepareUITestRound()
            #endif
        }
    }

    private func close() { battle.leave(); dismiss() }
}

private struct BattleWelcome: View {
    @ObservedObject var battle: BattleService
    let appearance: PoulpiAppearance
    @Environment(\.lisaMotionAllowed) private var motionAllowed
    var body: some View {
        VStack(spacing: 22) {
            LisaMascot(size: 110, mood: .happy, animationEnabled: motionAllowed, appearance: appearance)
            Text(L10n.text("Une grille, quatre Poulpi, un podium.")).font(LisaTheme.heading(28)).multilineTextAlignment(.center)
            Text(L10n.text("Invitez 1 à 3 amis avec Game Center. La course commence quand tout le monde est prêt."))
                .font(.body).foregroundStyle(LisaTheme.muted).multilineTextAlignment(.center)
            LisaCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label(L10n.text("La même grille pour tous"), systemImage: "square.grid.3x3")
                    Label(L10n.text("Départ commun, sans indices"), systemImage: "flag.checkered")
                    Label(L10n.text("Notes autorisées, erreurs sans élimination"), systemImage: "pencil.tip")
                    Label(L10n.text("Progression des amis en direct"), systemImage: "chart.bar.fill")
                }.font(.callout).frame(maxWidth: .infinity, alignment: .leading)
            }
            if battle.state == .matchmaking {
                ProgressView(L10n.text("Connexion aux amis…"))
            } else {
                LisaButton(title: L10n.text("Inviter mes amis"), icon: "person.2.fill") { battle.createMatch() }
                    .accessibilityIdentifier("battleInvite")
            }
            Text(L10n.text("Une connexion Game Center est nécessaire sur chaque appareil."))
                .font(.footnote).foregroundStyle(LisaTheme.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: 540).padding(.vertical, 16)
    }
}

private struct BattleLobby: View {
    @ObservedObject var battle: BattleService
    @Environment(\.lisaMotionAllowed) private var motionAllowed
    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.text("Sur la ligne de départ")).font(LisaTheme.heading(26))
            ForEach(battle.participants) { participant in
                BattleParticipantRow(participant: participant, local: participant.id == battle.localPlayerID, rank: nil)
            }
            if battle.state == .countdown {
                Text("\(battle.countdown)").font(.system(size: 80, weight: .black, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(motionAllowed ? .spring(response: 0.32, dampingFraction: 0.72) : nil, value: battle.countdown)
                    .keyframeAnimator(initialValue: 1.0, trigger: motionAllowed ? battle.countdown : 0) { content, scale in
                        content.scaleEffect(motionAllowed ? scale : 1)
                    } keyframes: { _ in
                        CubicKeyframe(1.16, duration: 0.12)
                        SpringKeyframe(1.0, duration: 0.28)
                    }
                    .accessibilityLabel(L10n.text("Départ dans %@", String(battle.countdown)))
                    .accessibilityIdentifier("battleCountdown")
                Text(L10n.text("La grille se dévoile au départ.")).font(.callout)
            } else if battle.state == .preparing {
                ProgressView(L10n.text("Préparation et synchronisation…"))
            } else {
                Picker(L10n.text("Difficulté"), selection: Binding(get: { battle.difficulty }, set: { battle.setDifficulty($0) })) {
                    ForEach(Difficulty.allCases) { difficulty in Text(difficulty.label).tag(difficulty) }
                }.pickerStyle(.menu).disabled(!battle.isHost).accessibilityIdentifier("battleDifficulty")
                let ready = battle.participants.first(where: { $0.id == battle.localPlayerID })?.ready == true
                LisaButton(title: L10n.text(ready ? "Je ne suis plus prêt" : "Je suis prêt !"), icon: ready ? "arrow.uturn.backward" : "checkmark.circle") {
                    battle.setReady(!ready)
                }.accessibilityIdentifier("battleReady")
                if battle.isHost {
                    LisaButton(title: L10n.text("Lancer la course"), icon: "flag.checkered") { battle.startRound() }
                        .disabled(!battle.canStart).accessibilityIdentifier("battleStart")
                } else {
                    Text(L10n.text("L’organisateur lancera la course quand tous seront prêts.")).font(.callout).foregroundStyle(LisaTheme.muted)
                }
            }
        }.frame(maxWidth: 560)
    }
}

private struct BattleParticipantRow: View {
    let participant: BattleParticipant
    let local: Bool
    let rank: Int?
    @Environment(\.lisaMotionAllowed) private var motionAllowed
    var body: some View {
        HStack(spacing: 12) {
            PoulpiAvatar(appearance: participant.appearance, size: 48).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(local ? L10n.text("%@ · vous", participant.name) : participant.name).font(.headline).lineLimit(1)
                if let rank {
                    Text(L10n.text("Place %@ · %@ %%", String(rank), String(Int(participant.progress * 100)))).font(.caption).monospacedDigit()
                    ProgressView(value: participant.progress).tint(LisaTheme.actionInk).accessibilityHidden(true)
                        .animation(motionAllowed ? .easeOut(duration: 0.35) : nil, value: participant.progress)
                }
                Text(L10n.text(statusKey)).font(.caption).foregroundStyle(LisaTheme.muted)
                    .contentTransition(.opacity)
                    .animation(motionAllowed ? .easeInOut(duration: 0.2) : nil, value: participant.status)
                    .animation(motionAllowed ? .easeInOut(duration: 0.2) : nil, value: participant.ready)
            }
            Spacer(minLength: 0)
            if rank == nil {
                Image(systemName: participant.ready && participant.status == .connected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(LisaTheme.actionInk)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(motionAllowed ? .easeInOut(duration: 0.22) : nil, value: participant.ready)
                    .accessibilityHidden(true)
            } else {
                Text(L10n.text("Erreurs : %@", String(participant.mistakes))).font(.caption).foregroundStyle(LisaTheme.muted)
            }
        }.padding(12).background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(local ? LisaTheme.actionInk.opacity(0.4) : .clear, lineWidth: 1.5))
            .accessibilityElement(children: .combine)
    }
    private var statusKey: String {
        switch participant.status {
        case .connected: rank == nil ? (participant.ready ? "Prêt" : "Se prépare") : "En course"
        case .interrupted: "Connexion interrompue · 30 s maximum"
        case .finished: "Grille terminée"
        case .didNotFinish: "Abandon"
        }
    }
}

private struct BattlePlayView: View {
    @ObservedObject var battle: BattleService
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text(battle.difficulty.label).font(.headline)
                Spacer()
                Text(LisaStore.time(Int(battle.elapsed))).monospacedDigit().accessibilityIdentifier("battleTimer")
            }
            let ranked = battle.participants.sorted {
                if $0.progress != $1.progress { return $0.progress > $1.progress }
                return $0.id < $1.id
            }
            if typeSize.isAccessibilitySize {
                VStack(spacing: 6) {
                    ForEach(ranked) { participant in
                        BattleParticipantRow(participant: participant, local: participant.id == battle.localPlayerID,
                            rank: 1 + ranked.filter { $0.progress > participant.progress }.count)
                    }
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(ranked) { participant in
                            BattleParticipantRow(participant: participant, local: participant.id == battle.localPlayerID,
                                rank: 1 + ranked.filter { $0.progress > participant.progress }.count).frame(width: 220)
                        }
                    }
                }.scrollIndicators(.hidden)
            }
            if let game = battle.session {
                if battle.participants.first(where: { $0.id == battle.localPlayerID })?.status == .didNotFinish {
                    Label(L10n.text("Abandon"), systemImage: "flag.slash").font(.headline)
                    Text(L10n.text("Gardez la battle ouverte jusqu’au podium.")).font(.callout)
                } else if game.isComplete {
                    Label(L10n.text("Bravo ! Les autres Poulpi sont encore en course."), systemImage: "flag.checkered")
                        .font(.headline).padding().accessibilityIdentifier("battleLocalFinished")
                    Text(L10n.text("Gardez la battle ouverte jusqu’au podium.")).font(.callout)
                } else {
                    if !battle.canEdit { Label(L10n.text("Reconnexion en cours…"), systemImage: "wifi.exclamationmark") }
                    GeometryReader { geometry in
                        BattleBoard(game: game, selection: battle.selection, width: geometry.size.width, onSelect: battle.select)
                    }.aspectRatio(1, contentMode: .fit).frame(maxWidth: 500)
                        .disabled(!battle.canEdit)
                    BattleKeypad(battle: battle, canUndo: game.canUndo).frame(maxWidth: 500)
                    Text(L10n.text("Le chronomètre continue si vous quittez l’écran."))
                        .font(.caption).foregroundStyle(LisaTheme.muted)
                }
            }
        }
    }
}

private struct BattleBoard: View {
    let game: GameSession
    let selection: Int?
    let width: CGFloat
    let onSelect: (Int) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate
    var body: some View {
        let inner = max(9, width - 16)
        let side = inner / 9
        let peers = selection.map { SudokuSolver.peers(of: $0) } ?? []
        ZStack {
            VStack(spacing: 0) {
                ForEach(0..<9) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<9) { column in
                            let index = row * 9 + column
                            Button { onSelect(index) } label: {
                                SudokuCellContent(value: game.values[index], notes: game.notes[index], given: game.puzzle.givens[index] != 0,
                                    wrong: game.isIncorrect(at: index), duplicate: false, isSelected: selection == index,
                                    sameNumber: selection.map { game.values[$0] != 0 && game.values[$0] == game.values[index] } ?? false,
                                    peer: peers.contains(index), inHintFocus: false, marks: [], side: side,
                                    colorScheme: colorScheme, differentiateWithoutColor: differentiate).equatable()
                            }.buttonStyle(.plain).accessibilityIdentifier("battleCell-\(index)")
                                .accessibilityLabel(cellLabel(index))
                                .accessibilityValue(selection == index ? L10n.text("Sélectionnée") : "")
                                .accessibilityAddTraits(selection == index ? .isSelected : [])
                        }
                    }
                }
            }
            Path { path in
                for n in stride(from: 0, through: 9, by: 3) {
                    let point = CGFloat(n) * side
                    path.move(to: CGPoint(x: point, y: 0)); path.addLine(to: CGPoint(x: point, y: inner))
                    path.move(to: CGPoint(x: 0, y: point)); path.addLine(to: CGPoint(x: inner, y: point))
                }
            }.stroke(LisaTheme.actionInk.opacity(0.65), lineWidth: 2).allowsHitTesting(false)
        }.frame(width: inner, height: inner).background(LisaTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 8)).padding(8)
            .background(LisaTheme.lavender, in: RoundedRectangle(cornerRadius: 16))
    }
    private func cellLabel(_ index: Int) -> String {
        let notes = game.notes[index].sorted().map(String.init).formatted(.list(type: .and).locale(L10n.locale))
        return L10n.text("Ligne %@, colonne %@, %@%@%@%@", String(index / 9 + 1), String(index % 9 + 1),
            game.values[index] == 0 ? L10n.text("vide") : String(game.values[index]),
            game.puzzle.givens[index] != 0 ? L10n.text(", chiffre donné") : "",
            notes.isEmpty ? "" : L10n.text(", notes ") + notes,
            game.isIncorrect(at: index) ? L10n.text(", erreur") : "")
    }

}

private struct BattleKeypad: View {
    @ObservedObject var battle: BattleService
    let canUndo: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(spacing: 12) {
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))) {
                Button { battle.undo() } label: { Label(L10n.text("Annuler"), systemImage: "arrow.uturn.backward") }.disabled(!canUndo).accessibilityIdentifier("battleUndo")
                Spacer(minLength: 0)
                Button { battle.erase() } label: { Label(L10n.text("Effacer"), systemImage: "eraser") }.disabled(battle.selection == nil).accessibilityIdentifier("battleErase")
                Spacer(minLength: 0)
                Button { battle.notesMode.toggle() } label: { Label(L10n.text("Notes"), systemImage: battle.notesMode ? "pencil.circle.fill" : "pencil.circle") }
                    .accessibilityValue(L10n.text(battle.notesMode ? "Activées" : "Désactivées")).accessibilityIdentifier("battleNotes")
            }.font(.callout).buttonStyle(.bordered).controlSize(.regular)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: typeSize.isAccessibilitySize ? 3 : 9), spacing: 6) {
                ForEach(1...9, id: \.self) { value in
                    Button { battle.enter(value) } label: {
                        Text("\(value)").font(.title2.bold()).frame(maxWidth: .infinity, minHeight: 48)
                            .background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 10))
                    }.accessibilityIdentifier("battleDigit-\(value)").accessibilityLabel(L10n.text("Saisir %@", String(value)))
                }
            }
        }.disabled(!battle.canEdit)
    }
}

private struct BattlePodium: View {
    @ObservedObject var battle: BattleService
    @EnvironmentObject private var store: LisaStore
    @Environment(\.lisaMotionAllowed) private var motionAllowed
    @State private var revealedCount = 0
    var body: some View {
        VStack(spacing: 18) {
            LisaMascot(size: 100, celebrating: true, animationEnabled: motionAllowed,
                appearance: battle.participants.first(where: { $0.id == battle.localPlayerID })?.appearance ?? store.poulpiAppearance)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "trophy.fill").font(.title2).foregroundStyle(LisaTheme.actionInk)
                        .offset(x: 12, y: 4).accessibilityHidden(true)
                }
            Text(L10n.text("Le podium des Poulpi")).font(LisaTheme.heading(28)).accessibilityIdentifier("battlePodium")
            ForEach(battle.results) { result in
                let index = battle.results.firstIndex(where: { $0.id == result.id }) ?? 0
                HStack(spacing: 14) {
                    if let participant = battle.participants.first(where: { $0.id == result.playerID }) {
                        PoulpiAvatar(appearance: participant.appearance, size: 58).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(result.name).font(.headline)
                        if let rank = result.rank, let seconds = result.seconds {
                            Text(L10n.text("Place %@ · %@", String(rank), LisaStore.time(Int(seconds)))).font(.callout)
                        } else { Text(L10n.text("Abandon")).font(.callout) }
                        if let participant = battle.participants.first(where: { $0.id == result.playerID }) {
                            Text(L10n.text("Erreurs : %@", String(participant.mistakes))).font(.caption).foregroundStyle(LisaTheme.muted)
                        }
                    }
                    Spacer()
                }
                .padding().background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 18))
                .opacity(!motionAllowed || index < revealedCount ? 1 : 0)
                .offset(y: !motionAllowed || index < revealedCount ? 0 : 16)
                .accessibilityElement(children: .combine)
                .accessibilityHidden(motionAllowed && index >= revealedCount)
            }
            Text(L10n.text("À moins d’une demi-seconde, vous partagez la même place."))
                .font(.footnote).foregroundStyle(LisaTheme.muted).multilineTextAlignment(.center)
            if battle.isHost {
                if !battle.canRematch {
                    Text(L10n.text("Un ami a quitté le groupe. Créez une nouvelle invitation.")).font(.callout).foregroundStyle(LisaTheme.muted)
                }
                LisaButton(title: L10n.text("Revanche !"), icon: "arrow.clockwise") { battle.rematch() }.disabled(!battle.canRematch).accessibilityIdentifier("battleRematch")
            } else { Text(L10n.text("L’organisateur peut proposer une revanche.")).font(.callout) }
        }
        .frame(maxWidth: 560)
        .task(id: motionAllowed) {
            guard motionAllowed else { revealedCount = battle.results.count; return }
            guard revealedCount < battle.results.count else { return }
            for index in revealedCount..<battle.results.count {
                do { try await Task.sleep(for: .milliseconds(index == 0 ? 100 : 130)) } catch { return }
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) { revealedCount = index + 1 }
            }
        }
    }
}
