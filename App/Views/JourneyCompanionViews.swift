import SwiftUI
import SudokuCore

struct HomePlayCard: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @EnvironmentObject private var store: LisaStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onFreePlay: () -> Void

    var body: some View {
        LisaCard {
            VStack(alignment: .leading, spacing: 14) {
                if let session = store.session, !session.isComplete {
                    Text(L10n.text("Votre aventure continue")).font(LisaTheme.heading(23))
                    Text("\(L10n.text(store.mode)) · \(session.puzzle.difficulty.label) · \(LisaStore.time(session.elapsedSeconds))")
                        .font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted)
                    LisaButton(title: L10n.text("Reprendre ma partie"), icon: "play.fill") { _ = store.resumeLastGame() }
                        .accessibilityIdentifier("homeResume")
                } else if let next = store.journeyProgress.next {
                    if dynamicTypeSize.isAccessibilitySize { recommendedPlayButton }
                    HStack(alignment: .top, spacing: 14) {
                        if !dynamicTypeSize.isAccessibilitySize {
                            Image(next.artworkName).resizable().scaledToFill()
                                .frame(width: 72, height: 90).clipShape(RoundedRectangle(cornerRadius: 15))
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.text(store.eventWins == 0 ? "Votre premier voyage" : "Poulpi vous attend"))
                                .font(LisaTheme.heading(23))
                            Text(store.eventWins == 0
                                 ? L10n.text("Une grille Express, un premier souvenir. Les indices sont là pour vous aider.")
                                 : L10n.text("Prochaine escale : %@", next.title))
                                .font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    if !dynamicTypeSize.isAccessibilitySize { recommendedPlayButton }
                } else {
                    Text(L10n.text("Tout un monde de déclics !")).font(LisaTheme.heading(23))
                    LisaButton(title: L10n.text("Nouvelle partie"), icon: "play.fill", action: onFreePlay)
                }
                Button(L10n.text("Choisir mon niveau"), action: onFreePlay)
                    .font(LisaTheme.heading(14)).foregroundStyle(LisaTheme.actionInk)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("homeFreePlay")
            }.foregroundStyle(LisaTheme.ink)
        }
    }
    private var recommendedPlayButton: some View {
        LisaButton(title: L10n.text(store.eventWins == 0 ? "Mon premier voyage" : "Continuer le voyage"), icon: "play.fill") {
            store.startRecommendedJourney()
        }.accessibilityIdentifier("homeJourneyPlay")
    }

}

struct JourneyCompanionCard: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @EnvironmentObject private var store: LisaStore
    @Binding var albumPresented: Bool

    var body: some View {
        LisaCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.text("Votre voyage avec Poulpi"), systemImage: "map.fill")
                    .font(LisaTheme.heading(21))
                if let next = store.journeyProgress.next {
                    Text(next.title).font(LisaTheme.heading(18))
                    Text(store.eventWins < 5
                         ? L10n.text("À la cinquième étape, une étoile à offrir à Poulpi.")
                         : L10n.text("Étapes restantes dans ce monde : %@", String(store.journeyProgress.stepsToNextWorld)))
                        .font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted)
                    ProgressView(value: Double(store.eventWins % 5), total: 5)
                        .tint(LisaTheme.coral)
                        .accessibilityLabel(L10n.text("Progression du voyage"))
                        .accessibilityValue(L10n.text("%@ / 25 étapes", String(store.journeyProgress.completed)))
                    LisaButton(title: L10n.text(store.hasSavedGame(mode: "Voyage") ? "Reprendre mon voyage" : "Jouer la prochaine étape"), icon: "play.fill") {
                        store.startRecommendedJourney()
                    }.accessibilityIdentifier(store.hasSavedGame(mode: "Voyage") ? "journey-resume" : "journeyPrimaryPlay")
                } else {
                    Text(L10n.text("Vos 25 souvenirs racontent votre aventure."))
                        .font(LisaTheme.body())
                }
                Button { albumPresented = true } label: {
                    Label(L10n.text("Mon carnet · %@ / 25", String(store.journeyProgress.completed)), systemImage: "book.closed.fill")
                        .font(LisaTheme.heading(15)).frame(maxWidth: .infinity, minHeight: 44)
                }.accessibilityIdentifier("openJourneyAlbum")
            }
        }
    }
}

struct JourneyAlbumView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @EnvironmentObject private var store: LisaStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selected: SceneryStop?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(L10n.text("Chaque étape terminée garde un souvenir ici. Votre carnet vous attend, même après une pause."))
                        .font(LisaTheme.body()).foregroundStyle(LisaTheme.muted)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: 18) {
                        ForEach(SceneryStop.all) { stop in
                            let unlocked = store.journeyProgress.souvenirs.contains(stop)
                            Button {
                                selected = stop
                                store.playStudy.record(.souvenirViewed)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    if unlocked {
                                        Image(stop.artworkName).resizable().aspectRatio(2.0 / 3, contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                    } else {
                                        RoundedRectangle(cornerRadius: 18).fill(LisaTheme.line.opacity(0.35))
                                            .aspectRatio(2.0 / 3, contentMode: .fit)
                                            .overlay { Image(systemName: "lock.fill").font(.title).foregroundStyle(LisaTheme.muted) }
                                    }
                                    Text(stop.title).font(LisaTheme.heading(15)).foregroundStyle(LisaTheme.ink)
                                    Text(L10n.text(unlocked ? "Souvenir collectionné" : "À découvrir"))
                                        .font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
                                }
                            }
                            .buttonStyle(.plain).disabled(!unlocked)
                            .accessibilityIdentifier("souvenir-\(stop.id)")
                            .accessibilityLabel(L10n.text("%@, %@", stop.title, L10n.text(unlocked ? "Souvenir collectionné" : "À découvrir")))
                        }
                    }
                }.padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(LisaTheme.paper)
            .navigationTitle(L10n.text("Mon carnet de voyage"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.text("Fermer")) { dismiss() } } }
            .sheet(item: $selected) { stop in
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 16) {
                            Image(stop.artworkName).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 24))
                            Text(stop.world.title).font(LisaTheme.heading(20))
                            Text(L10n.text("Un souvenir de votre voyage avec Poulpi.")).font(LisaTheme.body()).multilineTextAlignment(.center)
                        }.padding(20).frame(maxWidth: 540).frame(maxWidth: .infinity)
                    }.background(LisaTheme.paper)
                        .navigationTitle(stop.title).navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.text("Fermer")) { selected = nil } } }
                }
            }
        }
    }
}

struct JourneySouvenirReward: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    let stop: SceneryStop
    @Binding var albumPresented: Bool
    var body: some View {
        Button { albumPresented = true } label: {
            HStack(spacing: 14) {
                Image(stop.artworkName).resizable().scaledToFill()
                    .frame(width: 60, height: 80).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("Un souvenir pour votre carnet")).font(LisaTheme.heading(17))
                    Text(stop.title).font(LisaTheme.body(14))
                    Text(L10n.text("Ouvrir mon carnet")).font(LisaTheme.body(12)).foregroundStyle(LisaTheme.actionInk)
                }
                Spacer(minLength: 0)
            }.padding(16).foregroundStyle(LisaTheme.ink)
                .background(CandySurface(tint: LisaTheme.paper, cornerRadius: 22))
        }.buttonStyle(.plain).accessibilityIdentifier("victorySouvenir")
    }
}
