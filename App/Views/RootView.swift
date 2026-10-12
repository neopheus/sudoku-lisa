import SwiftUI
import SudokuCore

struct RootView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @EnvironmentObject private var store: LisaStore
    @State private var tab = 0
    @State private var settings = false
    @State private var battlePresented = false
    @State private var saveRecoveryPresented = false
    @ObservedObject private var battle = BattleService.shared
    @ObservedObject private var social = LisaSocialNavigation.shared
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView(onRoute: { tab = $0 }, onBattle: { battlePresented = true }, mascotAnimationEnabled: tab == 0 && !store.showGame && !battlePresented && !settings && !social.inboxPresented && !store.isGenerating && store.saveError == nil && !store.needsSaveRecovery && !saveRecoveryPresented).toolbar { ToolbarItem(placement: .topBarLeading) { invitationAccessory(tab: 0) } }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button { settings = true } label: { Image(systemName: "slider.horizontal.3").foregroundStyle(LisaTheme.ink) }.accessibilityLabel(L10n.text("Réglages")) } } }
                .environment(\.lisaMotionAllowed, motionAllowed(tab: 0))
                .tabItem { Label(L10n.text("Jouer"), systemImage: "square.grid.3x3.fill") }.tag(0)
            NavigationStack { DailyView(motionEnabled: tab == 1 && !store.showGame && !battlePresented && !settings && !social.inboxPresented && !store.isGenerating && store.saveError == nil && !store.needsSaveRecovery && !saveRecoveryPresented).toolbar { ToolbarItem(placement: .topBarLeading) { invitationAccessory(tab: 1) } } }.lisaAppear().environment(\.lisaMotionAllowed, motionAllowed(tab: 1)).tabItem { Label(L10n.text("Chaque jour"), systemImage: "sun.max.fill") }.tag(1)
            NavigationStack { JourneyView(motionEnabled: tab == 2 && !store.showGame && !battlePresented && !settings && !social.inboxPresented && !store.isGenerating && store.saveError == nil && !store.needsSaveRecovery && !saveRecoveryPresented).toolbar { ToolbarItem(placement: .topBarLeading) { invitationAccessory(tab: 2) } } }.lisaAppear().environment(\.lisaMotionAllowed, motionAllowed(tab: 2)).tabItem { Label(L10n.text("Voyage"), systemImage: "sparkles") }.tag(2)
            NavigationStack { ProgressViewLisa().toolbar { ToolbarItem(placement: .topBarLeading) { invitationAccessory(tab: 3) } } }.lisaAppear().environment(\.lisaMotionAllowed, motionAllowed(tab: 3)).tabItem { Label(L10n.text("Mes progrès"), systemImage: "chart.bar.fill") }.tag(3)
            NavigationStack { PoulpiView(active: motionAllowed(tab: 4)).toolbar { ToolbarItem(placement: .topBarLeading) { invitationAccessory(tab: 4) } } }
                .tabItem { Label("Poulpi", systemImage: "face.smiling.fill") }.tag(4)
        }
        .buttonStyle(LisaPressStyle())
        .tint(LisaTheme.actionInk)
        .toolbarBackground(LisaTheme.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .saturation(store.settings.paperMode ? 0 : 1)
        .sheet(isPresented: $settings) { SettingsView() }
        .sheet(isPresented: $saveRecoveryPresented) { SaveRecoveryView() }
        .safeAreaInset(edge: .top, spacing: 0) {
            if store.needsSaveRecovery || store.preservedSaveURL != nil {
                Button { saveRecoveryPresented = true } label: {
                    Label(L10n.text("Sauvegarde protégée"), systemImage: "exclamationmark.shield")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .background(LisaTheme.paper)
                .accessibilityIdentifier("saveRecoveryOpen")
            }
        }
        .fullScreenCover(isPresented: $store.showGame) { GameView() }
        .fullScreenCover(isPresented: $battlePresented) { BattleView() }
        .onAppear {
            saveRecoveryPresented = store.needsSaveRecovery
            store.recordStudyLaunch()
            battle.configureAppearance(store.poulpiAppearance)
            battle.onRoundFinished = { [weak store = store] roundID, result in
                store?.recordBattleResult(roundID: roundID, won: result.rank == 1)
            }
        }
        .task(id: store.needsSaveRecovery) {
            guard store.needsSaveRecovery else { return }
            if store.showGame {
                store.showGame = false
                do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
            }
            saveRecoveryPresented = true
            await store.refreshRecoveryBackup()
        }
        .onChange(of: store.saveError) { _, message in
            if store.needsSaveRecovery, message != nil, !store.showGame { saveRecoveryPresented = true }
        }
        .onChange(of: saveRecoveryPresented) { _, presented in
            if !presented, store.needsSaveRecovery { store.saveError = nil }
        }
        .task {
            // Game Center can launch the app for a pending friend invitation.
            // Test installs must never show authentication or create real matches.
            guard !ProcessInfo.processInfo.arguments.contains("--uitest-reset"),
                  ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
                  ProcessInfo.processInfo.environment["LISA_UI_TESTING"] != "1" else { return }
            GameCenterService.shared.authenticate(presentIfNeeded: false)
        }
        .onChange(of: store.poulpiAppearance) { _, appearance in battle.configureAppearance(appearance) }
        .task(id: "\(battle.state != .idle)-\(social.openBattle)") {
            guard battle.state != .idle || social.openBattle else { return }
            guard !battlePresented else { social.openBattle = false; return }
            social.switchingToBattle = true
            defer { social.switchingToBattle = false; social.openBattle = false }
            guard await store.prepareForBattleInvitation(), !Task.isCancelled else { return }
            if store.showGame {
                store.showGame = false
                do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
            }
            battlePresented = true
        }
        .accessibilityHidden(store.isGenerating)
        .overlay { GenerationOverlay() }
        .alert(L10n.text("Préparation de la grille"), isPresented: Binding(get: { store.generationError != nil }, set: { if !$0 { store.generationError = nil } })) { Button(L10n.text("D’accord")) { store.generationError = nil } } message: { Text(L10n.text(store.generationError ?? "")) }
        .alert(L10n.text("Sauvegarde"), isPresented: Binding(get: { store.saveError != nil && !store.needsSaveRecovery }, set: { if !$0 && !store.needsSaveRecovery { store.saveError = nil } })) { Button(L10n.text("D’accord")) { store.saveError = nil } } message: { Text(L10n.text(store.saveError ?? "")) }
    }
    @ViewBuilder private func invitationAccessory(tab index: Int) -> some View {
        if tab == index && !store.showGame && !battlePresented && !settings && !saveRecoveryPresented {
            LisaInvitationsAccessory(compact: true)
        }
    }

    private func motionAllowed(tab index: Int) -> Bool {
        store.settings.animatedDecor && !social.inboxPresented && tab == index && !store.showGame && !battlePresented && !settings && !saveRecoveryPresented && !store.isGenerating && store.saveError == nil && !store.needsSaveRecovery
    }
}

struct LisaWordmark: View {
    var size: CGFloat = 58
    var body: some View {
        VStack(spacing: -5) {
            Text("SUDOKU").font(.system(size: size * 0.24, weight: .black, design: .rounded))
                .tracking(5).foregroundStyle(LisaTheme.ink)
            Text("Lisa")
                .font(.system(size: size, weight: .black, design: .rounded))
                .tracking(-3)
                .foregroundStyle(LinearGradient(colors: [.white, Color(red: 1, green: 0.91, blue: 0.96)], startPoint: .top, endPoint: .bottom))
                .shadow(color: LisaTheme.coral, radius: 0, x: -2, y: 0)
                .shadow(color: LisaTheme.coral, radius: 0, x: 2, y: 0)
                .shadow(color: LisaTheme.coral, radius: 0, x: 0, y: -2)
                .shadow(color: Color(red: 0.62, green: 0.12, blue: 0.41), radius: 0, x: 0, y: 5)
                .shadow(color: Color(red: 0.46, green: 0.18, blue: 0.50).opacity(0.22), radius: 7, y: 9)
        }.accessibilityElement(children: .ignore).accessibilityLabel("Sudoku Lisa")
    }
}

struct HomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    var onRoute: (Int) -> Void = { _ in }
    var onBattle: () -> Void = {}
    var mascotAnimationEnabled = true
    @EnvironmentObject private var store: LisaStore
    @State private var difficultySheet = false
    @State private var replaceAlert = false
    @State private var learn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            LisaBackground(motionEnabled: store.settings.animatedDecor && mascotAnimationEnabled && !learn && !difficultySheet && !replaceAlert)
            ScrollView {
                VStack(spacing: 18) {
                    if !dynamicTypeSize.isAccessibilitySize && verticalSizeClass != .compact {
                        HStack {
                            LisaPill(title: L10n.count("days", store.streak), icon: "flame.fill", tint: LisaTheme.yellow)
                            Spacer()
                            LisaPill(title: L10n.count("wins", store.history.count), icon: "crown.fill", tint: LisaTheme.mint)
                        }
                        HStack(spacing: 24) {
                            LisaWordmark(size: 83).rotationEffect(.degrees(-5)).lisaFloat(amplitude: 5, tilt: 2, period: 4.5)
                            LisaCompanion(size: 124, animationEnabled: store.settings.animatedDecor && mascotAnimationEnabled && !learn && !difficultySheet && !replaceAlert)
                                .rotationEffect(.degrees(6))
                                .background { LisaMagicHalo().frame(width: 185, height: 185) }
                                .lisaFloat(amplitude: 7, tilt: 2, period: 4, phase: 1.5)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 4).padding(.bottom, 5)
                        .scaleEffect(appeared ? 1 : 0.85)
                        VStack(spacing: 5) {
                            Text(L10n.text("Votre pause avec Poulpi")).font(LisaTheme.heading(26)).foregroundStyle(LisaTheme.ink)
                            Text(L10n.text("Un petit rendez-vous, de grands déclics.")).font(LisaTheme.body(13)).foregroundStyle(LisaTheme.muted)
                        }
                    } else {
                        Text("Sudoku Lisa").font(.headline).foregroundStyle(LisaTheme.ink)
                    }
                    HomePlayCard(onFreePlay: requestNewFreeGame)
                    .offset(y: appeared ? 0 : 20)
                    Button(action: onBattle) {
                        HStack(spacing: 14) {
                            Image(systemName: "flag.checkered.2.crossed").font(.title).foregroundStyle(LisaTheme.actionInk)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.text("Battle entre amis")).font(LisaTheme.heading(19))
                                Text(L10n.text("Même grille. Même départ. À vous de jouer !")).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right.circle.fill").font(.title2).foregroundStyle(LisaTheme.actionInk)
                        }.padding(18).background(CandySurface(tint: LisaTheme.mint, cornerRadius: 24))
                    }.buttonStyle(LisaPressStyle()).accessibilityIdentifier("openBattle")
                    SavedGamesCard()
                    (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(spacing: 14))) {
                        shortcut(title: L10n.text("Défi du jour"), subtitle: store.completedDays.contains(LisaStore.dayKey(Date())) ? L10n.text("Défi accompli !") : L10n.text("Une étoile à décrocher"), icon: "sun.max.fill", color: LisaTheme.yellow) { onRoute(1) }
                        shortcut(title: L10n.text("Voyage gourmand"), subtitle: L10n.text("%@ / 25 étapes", String(describing: min(store.eventWins, 25))), icon: "map.fill", color: LisaTheme.mint) { onRoute(2) }
                    }
                    Button { learn = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "lightbulb.fill").font(.system(size: 26, weight: .bold)).foregroundStyle(LisaTheme.actionInk)
                            VStack(alignment: .leading, spacing: 4) { Text(L10n.text("Le déclic commence ici")).font(LisaTheme.heading(16)); Text(L10n.text("Cinq techniques à découvrir et à pratiquer.")).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted) }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right.circle.fill").font(.title2).foregroundStyle(LisaTheme.actionInk)
                        }.padding(17).background(LisaTheme.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.7), lineWidth: 2))
                    }.buttonStyle(LisaPressStyle())
                    Label(L10n.text("Sans pub. Tout le plaisir du jeu."), systemImage: "heart.fill").font(LisaTheme.body(11)).foregroundStyle(LisaTheme.muted).padding(.bottom, 12)
                }.frame(maxWidth: 720).padding(.horizontal, 22).padding(.top, 5).frame(maxWidth: .infinity)
            }
        }
        .environment(\.lisaMotionAllowed, store.settings.animatedDecor && mascotAnimationEnabled && !learn && !difficultySheet && !replaceAlert)
        .onAppear { withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7)) { appeared = true } }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $difficultySheet) { DifficultyView().environment(\.lisaMotionAllowed, true) }
        .sheet(isPresented: $learn) { LearnView().environment(\.lisaMotionAllowed, true) }
        .alert(L10n.text("Commencer une autre grille ?"), isPresented: $replaceAlert) { Button(L10n.text("Garder ma partie"), role: .cancel) {}; Button(L10n.text("Nouvelle partie"), role: .destructive) { difficultySheet = true } } message: { Text(L10n.text("Votre partie libre sera remplacée après le choix du niveau. Les autres modes sont conservés.")) }
    }

    private func requestNewFreeGame() {
        if store.hasSavedGame(mode: "Libre") { replaceAlert = true }
        else { difficultySheet = true }
    }

    private func shortcut(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 27, weight: .bold)).foregroundStyle(LisaTheme.accentInk)
                    .frame(width: 57, height: 51)
                    .background(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 19))
                    .overlay(RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.9), lineWidth: 2))
                    .shadow(color: color.opacity(0.5), radius: 0, y: 4)
                    .lisaFloat(amplitude: 5, tilt: 6, period: 3.5, phase: icon == "sun.max.fill" ? 0 : 2)
                Text(title).font(LisaTheme.heading(14)).foregroundStyle(LisaTheme.ink).fixedSize(horizontal: false, vertical: true)
                Text(subtitle).font(LisaTheme.body(10)).foregroundStyle(LisaTheme.muted).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity).padding(.vertical, 17)
                .background(CandySurface(tint: LisaTheme.paper, cornerRadius: 25, depth: 5))
                .contentShape(RoundedRectangle(cornerRadius: 25))
        }.buttonStyle(LisaPressStyle())
    }
}

struct MiniGrid: View {
    private let numbers = ["1", "", "3", "", "5", "", "7", "", "9"]
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
            ForEach(0..<9) { i in
                Text(numbers[i]).font(LisaTheme.heading(20)).frame(maxWidth: .infinity).frame(height: 30)
                    .foregroundStyle(i == 4 ? .white : LisaTheme.accentInk)
                    .background(LinearGradient(colors: i == 4 ? [LisaTheme.coral, Color(red: 0.8, green: 0.12, blue: 0.43)] : [LisaTheme.paper, LisaTheme.lavender.opacity(0.45)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 8))
            }
        }.padding(5).background(CandySurface(tint: LisaTheme.lavender, cornerRadius: 14, depth: 4))
    }
}

struct DifficultyView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @EnvironmentObject private var store: LisaStore
    @Environment(\.dismiss) private var dismiss
    private func description(for difficulty: Difficulty) -> String {
        let techniques = difficulty.techniqueProfile.sorted().map(\.label).formatted(.list(type: .and).locale(L10n.locale))
        return difficulty == .quick ? L10n.text("Une courte pause · %@", techniques) : techniques
    }
    var body: some View {
        NavigationStack {
            ZStack { LisaBackground(); ScrollView { VStack(alignment: .leading, spacing: 14) {
                Text(L10n.text("À chaque humeur,\nson défi.")).font(LisaTheme.heading(31)).padding(.bottom, 12)
                ForEach(Array(Difficulty.allCases.enumerated()), id: \.element.rawValue) { index, difficulty in
                    Button { dismiss(); store.start(difficulty) } label: {
                        HStack { VStack(alignment: .leading, spacing: 5) { Text(difficulty.label).font(LisaTheme.heading(20)); Text(description(for: difficulty)).font(LisaTheme.body(13)).foregroundStyle(LisaTheme.muted) }; Spacer(); HStack(spacing: 3) { ForEach(0..<6) { dot in Circle().fill(dot <= index ? LisaTheme.coral : LisaTheme.line).frame(width: 6, height: 6) } }; Image(systemName: "chevron.right").font(.caption).padding(.leading, 5) }.padding(19).background(CandySurface(tint: LisaTheme.paper, cornerRadius: 23, depth: 4)).contentShape(RoundedRectangle(cornerRadius: 23))
                    }.buttonStyle(LisaPressStyle())
                    .accessibilityLabel(difficulty.label)
                    .accessibilityValue(description(for: difficulty))
                    .accessibilityInputLabels([difficulty.label])
                }
            }.frame(maxWidth: 640).padding(24).frame(maxWidth: .infinity) } }.navigationTitle(L10n.text("Nouvelle partie")).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.text("Fermer")) { dismiss() } } }
        }
    }
}
