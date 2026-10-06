import SudokuCore
import SwiftUI

struct TournamentView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @EnvironmentObject private var store: LisaStore
    @ObservedObject private var gameCenter = GameCenterService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text("LE RENDEZ-VOUS DES CURIEUX"))
                            .font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.5)
                            .foregroundStyle(LisaTheme.muted)
                        Text(L10n.text("Tournois")).font(LisaTheme.heading(36))
                        Text(L10n.text("La même grille. Ton propre défi."))
                            .font(LisaTheme.body()).foregroundStyle(LisaTheme.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 42)).foregroundStyle(LisaTheme.coral)
                        .padding(.top, 18).lisaFloat(amplitude: 6, tilt: 8).accessibilityHidden(true)
                }
                LisaCard(tint: LisaTheme.yellow.opacity(0.35)) {
                    VStack(alignment: .leading, spacing: 16) {
                        LisaPill(title: L10n.text("CHAQUE SEMAINE"), icon: "calendar", tint: LisaTheme.yellow)
                        Text(gameCenter.isConfigured ? L10n.text("Une grille pour nous tous") : L10n.text("Les tournois arrivent bientôt"))
                            .font(LisaTheme.heading(26))
                        Text(gameCenter.isConfigured
                             ? L10n.text("Retrouve les autres joueurs autour d’une grille de niveau moyen, renouvelée chaque lundi. Fais parler ta logique !")
                             : L10n.text("Bientôt, une grille commune et un classement pour partager le plaisir de progresser."))
                            .font(LisaTheme.body()).fixedSize(horizontal: false, vertical: true)
                        if gameCenter.isConfigured {
                            if gameCenter.isAuthenticated {
                                if let name = gameCenter.playerName {
                                    Label(name, systemImage: "person.crop.circle.badge.checkmark")
                                        .font(LisaTheme.heading(15))
                                }
                                LisaButton(title: store.isGenerating ? L10n.text("Préparation…") : L10n.text("Relever le défi"), icon: "play.fill") {
                                    store.startTournament()
                                }
                                .disabled(store.isGenerating)
                                LisaButton(title: L10n.text("Voir le classement"), icon: "list.number", tint: LisaTheme.paper) {
                                    gameCenter.showLeaderboard()
                                }
                            } else {
                                LisaButton(title: gameCenter.isAuthenticating ? L10n.text("Connexion…") : L10n.text("Se connecter à Game Center"), icon: "person.crop.circle", tint: LisaTheme.mint) {
                                    gameCenter.authenticate()
                                }
                                .disabled(gameCenter.isAuthenticating)
                            }
                        }
                    }
                }
                if gameCenter.isConfigured {
                    LisaCard {
                        VStack(alignment: .leading, spacing: 15) {
                            Text(L10n.text("À armes égales")).font(LisaTheme.heading(21))
                            rule("square.grid.3x3", L10n.text("La même grille pour chaque joueur"), L10n.text("Un nouveau départ le lundi à 00 h UTC."))
                            rule("stopwatch", L10n.text("Le meilleur temps l’emporte"), L10n.text("Chaque erreur ajoute 60 secondes au score."))
                            rule("lightbulb", L10n.text("Sans coup de pouce"), L10n.text("Une aide consultée exclut la partie du classement, mais tu peux toujours la terminer."))
                        }
                    }
                } else {
                    LisaCard {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "leaf.fill").font(.title2).foregroundStyle(LisaTheme.muted)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(L10n.text("À chacun son rythme")).font(LisaTheme.heading(20))
                                Text(L10n.text("En attendant, les défis du jour et le voyage sont là pour entretenir ta logique."))
                                    .font(LisaTheme.body()).foregroundStyle(LisaTheme.muted)
                            }
                        }
                    }
                }
                if let message = gameCenter.statusMessage {
                    Text(L10n.text(message)).font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .foregroundStyle(LisaTheme.ink)
            .padding(24)
        }
        .background(LisaBackground())
        .navigationTitle(L10n.text("Tournois"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rule(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 20)).frame(width: 25).foregroundStyle(LisaTheme.muted)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(LisaTheme.heading(15))
                Text(detail).font(LisaTheme.body(14)).foregroundStyle(LisaTheme.muted)
            }
        }
    }
}
