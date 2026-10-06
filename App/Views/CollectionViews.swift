import SwiftUI
import SudokuCore

struct DailyView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    var motionEnabled = true
    @EnvironmentObject private var store: LisaStore
    @State private var monthOffset = 0
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var replace = false
    private var month: Date { Calendar.current.date(byAdding: .month, value: monthOffset, to: Date())! }
    private var days: [Date] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        return (calendar.range(of: .day, in: .month, for: month) ?? 1..<29).compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: start) }
    }
    private var leading: Int { (Calendar.current.component(.weekday, from: days[0]) + 5) % 7 }
    private var completed: Bool { store.completedDays.contains(LisaStore.dayKey(selected)) }
    var body: some View {
        ZStack { LisaBackground(motionEnabled: motionEnabled && !replace); ScrollView { VStack(alignment: .leading, spacing: 23) {
            Text(L10n.text("Un jour.\nUn petit déclic.")).font(LisaTheme.heading(34))
            Text(L10n.text("Un rendez-vous avec vous-même. Retrouvez aussi les défis des jours passés.")).font(LisaTheme.body()).foregroundStyle(LisaTheme.muted)
            LisaCard {
                VStack(spacing: 22) {
                    HStack {
                        Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel(L10n.text("Mois précédent"))
                        Spacer(); Text(month.formatted(.dateTime.month(.wide).year().locale(L10n.locale)).capitalized).font(LisaTheme.heading(20)); Spacer()
                        Button { monthOffset += 1 } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.disabled(monthOffset == 0).accessibilityLabel(L10n.text("Mois suivant"))
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 9) {
                        ForEach(Array(L10n.weekdaySymbols.enumerated()), id: \.offset) { _, day in Text(day).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted) }
                        ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 35) }
                        ForEach(days, id: \.self) { date in
                            let done = store.completedDays.contains(LisaStore.dayKey(date))
                            let isSelected = Calendar.current.isDate(date, inSameDayAs: selected)
                            let future = date > Date()
                            Button { selected = date } label: {
                                ZStack { Circle().fill(isSelected ? LisaTheme.coral : done ? LisaTheme.mint : .clear); if done { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)) } else { Text("\(Calendar.current.component(.day, from: date))").font(LisaTheme.body(14)) } }.frame(height: 35).foregroundStyle(future ? LisaTheme.muted.opacity(0.3) : (isSelected || done ? LisaTheme.accentInk : LisaTheme.ink))
                            }.buttonStyle(LisaPressStyle()).disabled(future).accessibilityLabel(date.formatted(Date.FormatStyle(date: .complete, time: .omitted).locale(L10n.locale)) + (done ? L10n.text(", terminé") : ""))
                        }
                    }
                    LisaButton(title: completed ? L10n.text("Défi accompli !") : L10n.text("Jouer le défi"), icon: completed ? "checkmark.seal.fill" : "sun.max.fill") {
                        if store.session != nil && store.session?.isComplete == false { replace = true } else { start() }
                    }.disabled(completed)
                    Text(selected.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(L10n.locale))).font(LisaTheme.body(13)).foregroundStyle(LisaTheme.muted)
                }
            }
            HStack { LisaCompanion(size: 70, animationEnabled: motionEnabled && !replace); VStack(alignment: .leading, spacing: 6) { Text(L10n.count("streak", store.streak)).font(LisaTheme.heading(24)); Text(L10n.text("Chaque grille compte. Chaque pause aussi.")).font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted) } }
        }.frame(maxWidth: 720).padding(24).frame(maxWidth: .infinity) } }.environment(\.lisaMotionAllowed, motionEnabled && !replace).navigationTitle(L10n.text("Chaque jour")).navigationBarTitleDisplayMode(.inline)
            .alert(L10n.text("Remplacer la partie en cours ?"), isPresented: $replace) { Button(L10n.text("Annuler l’action"), role: .cancel) {}; Button(L10n.text("Jouer le défi"), role: .destructive) { start() } } message: { Text(L10n.text("Votre progression dans la partie actuelle sera perdue.")) }
    }
    private func start() { store.start(.medium, mode: "Quotidien", date: selected) }
}

struct JourneyView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    var motionEnabled = true
    @EnvironmentObject private var store: LisaStore
    @State private var replace = false
    @State private var seasonReplace = false
    private var places: [String] { [L10n.text("Les jardins guimauve"), L10n.text("La forêt des sucettes"), L10n.text("Le lagon pétillant"), L10n.text("Les sommets givrés"), L10n.text("La voie des étoiles")] }
    private let icons = ["leaf.fill", "tree.fill", "drop.fill", "mountain.2.fill", "moon.stars.fill"]
    private let colors: [Color] = [Color(red: 0.96, green: 0.33, blue: 0.60), Color(red: 0.18, green: 0.72, blue: 0.58), Color(red: 0.18, green: 0.63, blue: 0.91), Color(red: 0.59, green: 0.40, blue: 0.88), Color(red: 0.95, green: 0.59, blue: 0.18)]
    private var chapter: Int { min(store.eventWins / 5, 4) }

    var body: some View {
        ZStack {
            LisaBackground(motionEnabled: motionEnabled && !replace && !seasonReplace, chapter: chapter)
            ScrollView {
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 7) {
                            LisaPill(title: L10n.text("LA GRANDE AVENTURE"), icon: "sparkles", tint: LisaTheme.yellow)
                            Text(L10n.text("Le monde\ndes déclics")).font(LisaTheme.heading(36)).lineSpacing(-3)
                            Text(L10n.text("25 défis. Une étoile à la fois.")).font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted)
                        }
                        Spacer(minLength: 0)
                        LisaCompanion(size: 84, animationEnabled: motionEnabled && !replace && !seasonReplace)
                    }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 22)

                    seasonPass.padding(.horizontal, 20).padding(.bottom, 24)

                    HStack(spacing: 10) {
                        Image(systemName: "star.fill").foregroundStyle(Color.orange)
                        Text(L10n.text("%@ / 25 étoiles", String(describing: min(store.eventWins, 25)))).font(LisaTheme.heading(17))
                        Spacer()
                        Text(L10n.text("100 % hors ligne")).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
                    }.padding(.horizontal, 28).padding(.bottom, 22)

                    LazyVStack(spacing: 0) { ForEach(0..<5) { region in
                        JourneyRegionView(title: places[region], icon: icons[region], color: colors[region], region: region, completed: store.eventWins, onPlay: requestStart)
                    } }
                    if store.eventWins >= 25 {
                        VStack(spacing: 12) {
                            Image(systemName: "crown.fill").font(.system(size: 48)).foregroundStyle(LisaTheme.yellow).lisaFloat(amplitude: 6, tilt: 7)
                            Text(L10n.text("Tout un monde de déclics !")).font(LisaTheme.heading(27))
                            Text(L10n.text("Vos 25 étoiles brillent. Les défis du jour et les événements vous réservent encore des surprises.")).font(LisaTheme.body()).multilineTextAlignment(.center).foregroundStyle(LisaTheme.muted)
                        }.padding(28)
                    }
                }.padding(.bottom, 25)
            }
        }
        .environment(\.lisaMotionAllowed, motionEnabled && !replace && !seasonReplace)
        .navigationTitle(L10n.text("Voyage")).navigationBarTitleDisplayMode(.inline)
        .alert(L10n.text("Remplacer la partie en cours ?"), isPresented: $seasonReplace) {
            Button(L10n.text("Annuler l’action"), role: .cancel) {}
            Button(L10n.text("Jouer l’événement"), role: .destructive) { store.startSeason() }
        } message: { Text(L10n.text("Votre progression dans la partie actuelle sera perdue.")) }
        .alert(L10n.text("Remplacer la partie en cours ?"), isPresented: $replace) {
            Button(L10n.text("Annuler l’action"), role: .cancel) {}
            Button(L10n.text("Commencer l’étape"), role: .destructive) { start() }
        } message: { Text(L10n.text("Votre progression dans la partie actuelle sera perdue.")) }
    }

    private var seasonPass: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(LisaTheme.yellow.gradient).frame(width: 62, height: 66).rotationEffect(.degrees(-8))
                    Image(systemName: "medal.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(Color(red: 0.63, green: 0.31, blue: 0.09))
                }.lisaFloat(amplitude: 4, tilt: 5, period: 3.5).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("L’ÉVÉNEMENT DU MOIS")).font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.2).foregroundStyle(LisaTheme.muted)
                    Text(store.seasonTitle).font(LisaTheme.heading(22))
                    Text(L10n.text("10 grilles → 1 médaille à collectionner")).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
                }
            }
            HStack(spacing: 4) {
                ForEach(0..<10) { step in
                    Capsule().fill(step < store.seasonProgress ? LisaTheme.coral : LisaTheme.line.opacity(0.7)).frame(height: 9)
                }
            }.accessibilityLabel(L10n.text("Événement : %@ grilles sur 10 terminées", String(describing: store.seasonProgress)))
            LisaButton(title: store.seasonProgress >= 10 ? L10n.text("Médaille remportée !") : L10n.text("Jouer · %@/10", String(describing: store.seasonProgress)), icon: "sparkles") {
                if store.session != nil && store.session?.isComplete == false { seasonReplace = true } else { store.startSeason() }
            }.disabled(store.seasonProgress >= 10)
        }
        .padding(20)
        .background(CandySurface(tint: LisaTheme.paper, cornerRadius: 28, depth: 6))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(LisaTheme.yellow.opacity(0.8), lineWidth: 3))
    }

    private func requestStart() {
        guard store.eventWins < 25 else { return }
        if store.session != nil && store.session?.isComplete == false { replace = true } else { start() }
    }
    private func start() { store.start([Difficulty.easy, .easy, .medium, .hard, .expert][chapter], mode: "Voyage") }
}

private struct JourneyRegionView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    let title: String
    let icon: String
    let color: Color
    let region: Int
    let completed: Int
    let onPlay: () -> Void
    private let positions: [CGFloat] = [0.34, 0.68, 0.73, 0.38, 0.28]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("MONDE %@", String(describing: region + 1))).font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(2).foregroundStyle(LisaTheme.muted)
                    Text(title).font(LisaTheme.heading(22))
                }
                Spacer()
                if completed >= (region + 1) * 5 { Image(systemName: "checkmark.seal.fill").foregroundStyle(color).font(.title2) }
            }.padding(.horizontal, 25).padding(.vertical, 16)

            GeometryReader { geometry in
                let width = max(1, geometry.size.width)
                ZStack(alignment: .topLeading) {
                    LisaJourneyScenery(region: region, color: color)
                        .frame(width: width, height: 544)
                    JourneyWindingPath(positions: positions)
                        .stroke(color.opacity(0.13), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .padding(.vertical, 80)
                    LisaMotionClock { time in
                        JourneyWindingPath(positions: positions)
                            .stroke(color.opacity(0.65), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [1, 12], dashPhase: -CGFloat(time.truncatingRemainder(dividingBy: 13) * 8)))
                    }
                    .padding(.vertical, 80)
                    .allowsHitTesting(false).accessibilityHidden(true)
                    ForEach(0..<5) { step in
                        levelNode(region * 5 + step)
                            .position(x: width * positions[step], y: 80 + CGFloat(step) * 96)
                    }
                }
                .frame(width: width, height: 544)
                .clipped()
            }.frame(height: 544)
        }
        .background(LinearGradient(colors: [color.opacity(0.05), color.opacity(0.13), color.opacity(0.035)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func levelNode(_ index: Int) -> some View {
        let done = index < completed
        let current = index == completed
        let tint = done ? Color(red: 0.98, green: 0.72, blue: 0.18) : current ? color : LisaTheme.line
        return Button(action: onPlay) {
            ZStack {
                if current {
                    LisaMagicHalo(color: color, strong: true).frame(width: 128, height: 128)
                    Circle().stroke(color.opacity(0.22), lineWidth: 6).frame(width: 94, height: 94)
                }
                Ellipse().fill(Color.black.opacity(0.10)).frame(width: 76, height: 18).offset(y: 41)
                Circle().fill(tint.opacity(0.65)).frame(width: 76, height: 76).offset(y: 7)
                Circle().fill(LinearGradient(colors: [tint, tint.opacity(0.85)], startPoint: .top, endPoint: .bottom)).frame(width: 76, height: 76)
                Circle().strokeBorder(.white.opacity(current || done ? 0.75 : 0.32), lineWidth: 3).frame(width: 66, height: 66)
                Ellipse().fill(.white.opacity(0.25)).frame(width: 39, height: 13).offset(y: -22)
                VStack(spacing: 1) {
                    if done { Image(systemName: "star.fill").font(.system(size: 15, weight: .black)).lisaFloat(amplitude: 2, tilt: 14, period: 4) }
                    Text("\(index + 1)").font(.system(size: done ? 25 : 30, weight: .black, design: .rounded))
                    if !done && !current { Image(systemName: "lock.fill").font(.system(size: 10, weight: .bold)) }
                }.foregroundStyle(current ? Color.white : done ? LisaTheme.accentInk : LisaTheme.muted)
                if current {
                    Text(L10n.text("À VOUS !")).font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(0.8)
                        .foregroundStyle(.white).padding(.horizontal, 13).padding(.vertical, 6)
                        .background(color, in: Capsule()).overlay(Capsule().strokeBorder(.white, lineWidth: 2)).lisaFloat(amplitude: 4, tilt: 4, period: 2.5).offset(y: -56)
                }
            }.frame(width: 100, height: 110).contentShape(Rectangle())
                .lisaFloat(amplitude: 3, tilt: 0, period: 3, enabled: current)
        }
        .buttonStyle(LisaPressStyle()).disabled(!current)
        .accessibilityLabel(L10n.text("Étape %@, %@", String(describing: index + 1), String(describing: done ? L10n.text("terminée") : current ? L10n.text("à jouer") : L10n.text("verrouillée"))))
        .accessibilityHint(current ? L10n.text("Commencer la prochaine grille du voyage") : "")
    }
}

private struct JourneyWindingPath: Shape {
    let positions: [CGFloat]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = positions.first, positions.count > 1 else { return path }
        let gap = rect.height / CGFloat(positions.count - 1)
        path.move(to: CGPoint(x: first * rect.width, y: 0))
        for step in 1..<positions.count {
            let previous = CGPoint(x: positions[step - 1] * rect.width, y: CGFloat(step - 1) * gap)
            let next = CGPoint(x: positions[step] * rect.width, y: CGFloat(step) * gap)
            path.addCurve(to: next, control1: CGPoint(x: previous.x, y: previous.y + gap * 0.55), control2: CGPoint(x: next.x, y: next.y - gap * 0.55))
        }
        return path
    }
}

struct ProgressViewLisa: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @EnvironmentObject private var store: LisaStore
    @State private var difficulty: Difficulty?
    private var games: [FinishedGame] { store.history.filter { difficulty == nil || $0.difficulty == difficulty } }
    var body: some View {
        ZStack { LisaBackground(); ScrollView { VStack(alignment: .leading, spacing: 24) {
            Text(L10n.text("Les petits pas\nfont les grands esprits.")).font(LisaTheme.heading(32))
            Picker(L10n.text("Niveau"), selection: $difficulty) { Text(L10n.text("Tous les niveaux")).tag(Optional<Difficulty>.none); ForEach(Difficulty.allCases, id: \.self) { Text($0.label).tag(Optional($0)) } }.pickerStyle(.menu).tint(LisaTheme.coral)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                stat("\(games.count)", L10n.text("grilles terminées"), "checkmark.seal.fill")
                stat(games.map(\.seconds).min().map(LisaStore.time) ?? "—", L10n.text("meilleur temps"), "stopwatch")
                stat(games.isEmpty ? "—" : LisaStore.time(games.reduce(0) { $0 + $1.seconds } / games.count), L10n.text("temps moyen"), "clock")
                stat("\(games.filter { $0.mistakes == 0 }.count)", L10n.text("sans erreur"), "sparkles")
            }
            Text(L10n.text("Votre collection")).font(LisaTheme.heading(24))
            VStack(spacing: 12) {
                badge(L10n.text("Premier déclic"), subtitle: L10n.text("Terminer votre première grille"), icon: "star.fill", earned: !store.history.isEmpty)
                badge(L10n.text("La belle série"), subtitle: L10n.text("Trois défis quotidiens consécutifs"), icon: "flame.fill", earned: store.longestStreak >= 3)
                badge(L10n.text("Esprit libre"), subtitle: L10n.text("Une grille sans indice ni erreur"), icon: "leaf.fill", earned: store.history.contains { $0.hints == 0 && $0.mistakes == 0 })
                badge(L10n.text("Le club des 10"), subtitle: L10n.text("Dix grilles terminées"), icon: "crown.fill", earned: store.history.count >= 10)
                badge(L10n.text("Âme voyageuse"), subtitle: L10n.text("Les cinq escales du voyage"), icon: "globe.europe.africa.fill", earned: store.eventWins >= 25)
            }
            ForEach(store.monthlyTrophies, id: \.self) { month in
                badge(L10n.text("Le mois en or · ") + month, subtitle: L10n.text("Tous les défis du mois terminés"), icon: "trophy.fill", earned: true)
            }
            NavigationLink { TournamentView() } label: {
                HStack { Image(systemName: "trophy.fill").foregroundStyle(LisaTheme.coral); Text(L10n.text("Le rendez-vous des curieux")).font(LisaTheme.heading(17)); Spacer(); Image(systemName: "chevron.right") }.padding(20).background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 20))
            }.buttonStyle(LisaPressStyle())
            ForEach(Array(Set(store.eventMedals.map { String($0.prefix(7)) })).sorted(), id: \.self) { month in
                let count = store.eventMedals.filter { $0.hasPrefix(month + "-") }.count
                badge(L10n.text("Souvenir de %@", String(describing: month)), subtitle: L10n.text("%@/10 grilles de l’événement", String(describing: count)), icon: "medal.fill", earned: count >= 10)
            }
            Text(L10n.text("Vos dernières pauses")).font(LisaTheme.heading(24))
            if games.isEmpty { Text(L10n.text("Votre histoire commence avec une première grille.")).font(LisaTheme.body()).foregroundStyle(LisaTheme.muted) }
            ForEach(games.suffix(10).reversed()) { game in
                HStack { VStack(alignment: .leading, spacing: 4) { Text(game.difficulty.label).font(LisaTheme.heading(17)); Text(game.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(L10n.locale)) + " · " + L10n.text(game.mode)).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted) }; Spacer(); Text(LisaStore.time(game.seconds)).font(LisaTheme.body()) }.padding(18).background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 19))
            }
        }.frame(maxWidth: 720).padding(24).frame(maxWidth: .infinity) } }.navigationTitle(L10n.text("Mes progrès")).navigationBarTitleDisplayMode(.inline)
    }
    private func stat(_ value: String, _ title: String, _ icon: String) -> some View { VStack(alignment: .leading, spacing: 10) { Image(systemName: icon).foregroundStyle(LisaTheme.coral).lisaFloat(amplitude: 3, tilt: 8); Text(value).font(LisaTheme.heading(29)); Text(title).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted) }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 23)) }
    private func badge(_ title: String, subtitle: String, icon: String, earned: Bool) -> some View { HStack(spacing: 16) { Image(systemName: earned ? icon : "lock.fill").foregroundStyle(earned ? LisaTheme.accentInk : LisaTheme.ink).font(.system(size: 22)).frame(width: 50, height: 50).background(earned ? LisaTheme.yellow : LisaTheme.line.opacity(0.4), in: Circle()).lisaFloat(amplitude: 3, tilt: 6, enabled: earned); VStack(alignment: .leading, spacing: 5) { Text(title).font(LisaTheme.heading(17)); Text(subtitle).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted) }; Spacer() }.padding(15).background(LisaTheme.paper, in: RoundedRectangle(cornerRadius: 21)).opacity(earned ? 1 : 0.65) }
}

struct SettingsView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @EnvironmentObject private var store: LisaStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { Form {
            Section(L10n.text("Langue")) {
                Picker(L10n.text("Langue"), selection: $languagePreference) {
                    Text(L10n.text("Langue de l’iPhone")).tag(L10n.systemLanguage)
                    ForEach(L10n.supportedLanguages, id: \.self) { language in
                        Text(verbatim: L10n.nativeName(for: language)).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("languagePicker")
            }
            Section(L10n.text("Votre ambiance")) {
                Picker(L10n.text("Thème"), selection: Binding<Int>(get: { store.settings.darkMode ? 1 : store.settings.paperMode ? 2 : 0 }, set: { value in store.settings.darkMode = value == 1; store.settings.paperMode = value == 2 })) {
                    Text(L10n.text("Soleil")).tag(0)
                    Text(L10n.text("Nuit")).tag(1)
                    Text(L10n.text("Papier")).tag(2)
                }.accessibilityIdentifier("themePicker")
                Toggle(L10n.text("Sons"), isOn: $store.settings.sound)
                Toggle(L10n.text("Musique douce"), isOn: $store.settings.music).accessibilityIdentifier("musicToggle")
                Toggle(L10n.text("Décor animé"), isOn: $store.settings.animatedDecor).accessibilityIdentifier("decorToggle")
                Toggle(L10n.text("Retours haptiques"), isOn: $store.settings.haptics)
            }
            Section(L10n.text("Votre façon de jouer")) {
                Toggle(L10n.text("Vérifier les erreurs"), isOn: $store.settings.autoCheck)
                Toggle(L10n.text("Surligner ligne, colonne et bloc"), isOn: $store.settings.highlightPeers)
                Toggle(L10n.text("Signaler les doublons"), isOn: $store.settings.highlightDuplicates)
                Toggle(L10n.text("Pause après trois erreurs"), isOn: $store.settings.errorLimit)
                Toggle(L10n.text("Afficher le chronomètre"), isOn: $store.settings.showTimer)
            }
            Section { Text(L10n.text("Les notes se mettent à jour lorsque vous placez un chiffre correct. Les indices expliquent les déductions simples et proposent une valeur vérifiée pour les étapes avancées.")) }
            Section(L10n.text("Une petite app, rien de superflu")) {
                Label(L10n.text("Toutes vos grilles hors ligne"), systemImage: "wifi.slash")
                Label(L10n.text("Aucune publicité, aucun compte"), systemImage: "heart")
                Label(L10n.text("Votre progression sur cet iPhone"), systemImage: "iphone")
                Text(L10n.text("La réduction des animations suit le réglage d’accessibilité de votre iPhone.")).font(.footnote).foregroundStyle(.secondary)
            }
            Section { Text(L10n.text("Sudoku Lisa · 1.0\nConçu pour les petits moments à soi.")).font(.footnote).foregroundStyle(.secondary) }
        }.preferredColorScheme(store.settings.darkMode ? .dark : .light).tint(LisaTheme.actionInk).navigationTitle(L10n.text("À votre goût")).toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.text("Terminé")) { dismiss() } } } }
    }
}
