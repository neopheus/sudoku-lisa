import SwiftUI
import SudokuCore

struct RootView: View {
    @EnvironmentObject private var store: LisaStore
    @State private var tab = 0
    @State private var settings = false
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack { HomeView(onRoute: { tab = $0 }, mascotAnimationEnabled: tab == 0 && !store.showGame && !settings && !store.isGenerating && store.saveError == nil).toolbar { ToolbarItem(placement: .topBarTrailing) { Button { settings = true } label: { Image(systemName: "slider.horizontal.3").foregroundStyle(LisaTheme.ink) }.accessibilityLabel("Réglages") } } }
                .environment(\.lisaMotionAllowed, motionAllowed(tab: 0))
                .tabItem { Label("Jouer", systemImage: "square.grid.3x3.fill") }.tag(0)
            NavigationStack { DailyView(motionEnabled: tab == 1 && !store.showGame && !settings && !store.isGenerating && store.saveError == nil) }.environment(\.lisaMotionAllowed, motionAllowed(tab: 1)).tabItem { Label("Chaque jour", systemImage: "sun.max.fill") }.tag(1)
            NavigationStack { JourneyView(motionEnabled: tab == 2 && !store.showGame && !settings && !store.isGenerating && store.saveError == nil) }.environment(\.lisaMotionAllowed, motionAllowed(tab: 2)).tabItem { Label("Voyage", systemImage: "sparkles") }.tag(2)
            NavigationStack { ProgressViewLisa() }.environment(\.lisaMotionAllowed, motionAllowed(tab: 3)).tabItem { Label("Mes progrès", systemImage: "chart.bar.fill") }.tag(3)
        }
        .tint(LisaTheme.actionInk)
        .toolbarBackground(LisaTheme.paper, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .saturation(store.settings.paperMode ? 0 : 1)
        .sheet(isPresented: $settings) { SettingsView() }
        .fullScreenCover(isPresented: $store.showGame) { GameView() }
        .overlay {
            if store.isGenerating {
                ZStack { Color.black.opacity(0.25).ignoresSafeArea(); VStack(spacing: 18) { LisaMascot(size: 80, mood: .thinking, animationEnabled: !store.showGame && !settings && store.saveError == nil); ProgressView("On prépare votre petite pause…").font(LisaTheme.body()) }.padding(30).background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 28)) }
            }
        }
        .alert("Sauvegarde", isPresented: Binding(get: { store.saveError != nil }, set: { if !$0 { store.saveError = nil } })) { Button("D’accord") { store.saveError = nil } } message: { Text(store.saveError ?? "") }
    }
    private func motionAllowed(tab index: Int) -> Bool {
        tab == index && !store.showGame && !settings && !store.isGenerating && store.saveError == nil
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
    var onRoute: (Int) -> Void = { _ in }
    var mascotAnimationEnabled = true
    @EnvironmentObject private var store: LisaStore
    @State private var difficultySheet = false
    @State private var replaceAlert = false
    @State private var learn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            LisaBackground(motionEnabled: mascotAnimationEnabled && !learn && !difficultySheet && !replaceAlert)
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        LisaPill(title: "\(store.streak) jour\(store.streak > 1 ? "s" : "")", icon: "flame.fill", tint: LisaTheme.yellow)
                        Spacer()
                        LisaPill(title: "\(store.history.count) victoire\(store.history.count > 1 ? "s" : "")", icon: "crown.fill", tint: LisaTheme.mint)
                    }
                    HStack(spacing: 24) {
                        LisaWordmark(size: 83).rotationEffect(.degrees(-5)).lisaFloat(amplitude: 5, tilt: 2, period: 4.5)
                        LisaCompanion(size: 124, animationEnabled: mascotAnimationEnabled && !learn && !difficultySheet && !replaceAlert)
                            .rotationEffect(.degrees(6))
                            .background { LisaMagicHalo().frame(width: 185, height: 185) }
                            .lisaFloat(amplitude: 7, tilt: 2, period: 4, phase: 1.5)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 4).padding(.bottom, 5)
                    .scaleEffect(appeared ? 1 : 0.85)
                    VStack(spacing: 5) {
                        Text("À vous de briller !").font(LisaTheme.heading(26)).foregroundStyle(LisaTheme.ink)
                        Text("Des chiffres, des défis et plein de déclics.").font(LisaTheme.body(13)).foregroundStyle(LisaTheme.muted)
                    }
                    LisaCard {
                        VStack(spacing: 15) {
                            HStack(spacing: 18) {
                                MiniGrid().frame(width: 106, height: 106).rotationEffect(.degrees(-5)).lisaFloat(amplitude: 5, tilt: 4, period: 4.5).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 6) {
                                    if let session = store.session, !session.isComplete {
                                        Text("Votre aventure\ncontinue").font(LisaTheme.heading(22))
                                        Text("\(session.puzzle.difficulty.label) · \(LisaStore.time(session.elapsedSeconds))").font(LisaTheme.body(13)).foregroundStyle(LisaTheme.muted)
                                    } else {
                                        Text("Un nouveau\ndéfi vous attend").font(LisaTheme.heading(22))
                                        Text("6 niveaux · À votre rythme").font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if let session = store.session, !session.isComplete {
                                LisaButton(title: "Reprendre ma partie", icon: "play.fill") { store.showGame = true }
                                Button("Nouvelle partie") { replaceAlert = true }.font(LisaTheme.heading(14)).foregroundStyle(LisaTheme.actionInk).padding(.top, 2)
                            } else {
                                LisaButton(title: "C’est parti !", icon: "play.fill") { difficultySheet = true }
                            }
                        }
                    }
                    .offset(y: appeared ? 0 : 20)
                    HStack(spacing: 14) {
                        shortcut(title: "Défi du jour", subtitle: store.completedDays.contains(LisaStore.dayKey(Date())) ? "Défi accompli !" : "Une étoile à décrocher", icon: "sun.max.fill", color: LisaTheme.yellow) { onRoute(1) }
                        shortcut(title: "Voyage gourmand", subtitle: "\(min(store.eventWins, 25)) / 25 étapes", icon: "map.fill", color: LisaTheme.mint) { onRoute(2) }
                    }
                    Button { learn = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "lightbulb.fill").font(.system(size: 26, weight: .bold)).foregroundStyle(LisaTheme.actionInk)
                            VStack(alignment: .leading, spacing: 4) { Text("Le déclic commence ici").font(LisaTheme.heading(16)); Text("Trois petits défis pour apprendre.").font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted) }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right.circle.fill").font(.title2).foregroundStyle(LisaTheme.actionInk)
                        }.padding(17).background(LisaTheme.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.7), lineWidth: 2))
                    }.buttonStyle(LisaPressStyle())
                    Label("Sans pub. Tout le plaisir du jeu.", systemImage: "heart.fill").font(LisaTheme.body(11)).foregroundStyle(LisaTheme.muted).padding(.bottom, 12)
                }.padding(.horizontal, 22).padding(.top, 5)
            }
        }
        .environment(\.lisaMotionAllowed, mascotAnimationEnabled && !learn && !difficultySheet && !replaceAlert)
        .onAppear { withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7)) { appeared = true } }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $difficultySheet) { DifficultyView().environment(\.lisaMotionAllowed, true) }
        .sheet(isPresented: $learn) { LearnView().environment(\.lisaMotionAllowed, true) }
        .alert("Commencer une autre grille ?", isPresented: $replaceAlert) { Button("Garder ma partie", role: .cancel) {}; Button("Nouvelle partie", role: .destructive) { difficultySheet = true } } message: { Text("La partie en cours sera remplacée après le choix du niveau.") }
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
                Text(title).font(LisaTheme.heading(14)).foregroundStyle(LisaTheme.ink).lineLimit(1).minimumScaleFactor(0.8)
                Text(subtitle).font(LisaTheme.body(10)).foregroundStyle(LisaTheme.muted).lineLimit(1).minimumScaleFactor(0.8)
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
                    .background(LinearGradient(colors: i == 4 ? [LisaTheme.coral, Color(red: 0.8, green: 0.12, blue: 0.43)] : [.white, LisaTheme.lavender.opacity(0.45)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 8))
            }
        }.padding(5).background(CandySurface(tint: LisaTheme.lavender, cornerRadius: 14, depth: 4))
    }
}

struct DifficultyView: View {
    @EnvironmentObject private var store: LisaStore
    @Environment(\.dismiss) private var dismiss
    private let descriptions = ["Une pause express", "Pour prendre confiance", "Le bon petit défi", "On passe à la vitesse supérieure", "Pour les esprits affûtés", "Toute votre concentration"]
    var body: some View {
        NavigationStack {
            ZStack { LisaBackground(); ScrollView { VStack(alignment: .leading, spacing: 14) {
                Text("À chaque humeur,\nson défi.").font(LisaTheme.heading(31)).padding(.bottom, 12)
                ForEach(Array(Difficulty.allCases.enumerated()), id: \.element.rawValue) { index, difficulty in
                    Button { dismiss(); store.start(difficulty) } label: {
                        HStack { VStack(alignment: .leading, spacing: 5) { Text(difficulty.label).font(LisaTheme.heading(20)); Text(descriptions[index]).font(LisaTheme.body(13)).foregroundStyle(LisaTheme.muted) }; Spacer(); HStack(spacing: 3) { ForEach(0..<6) { dot in Circle().fill(dot <= index ? LisaTheme.coral : LisaTheme.line).frame(width: 6, height: 6) } }; Image(systemName: "chevron.right").font(.caption).padding(.leading, 5) }.padding(19).background(CandySurface(tint: LisaTheme.paper, cornerRadius: 23, depth: 4)).contentShape(RoundedRectangle(cornerRadius: 23))
                    }.buttonStyle(LisaPressStyle())
                }
            }.padding(24) } }.navigationTitle("Nouvelle partie").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { dismiss() } } }
        }
    }
}
