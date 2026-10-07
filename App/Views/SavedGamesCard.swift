import SudokuCore
import SwiftUI

/// Each mode retains its own puzzle. The prominent current game already has a
/// resume button above; this card makes the other unfinished saves discoverable.
struct SavedGamesCard: View {
    @EnvironmentObject private var store: LisaStore
    private var otherGames: [SavedModeGame] {
        ["Libre", "Quotidien", "Voyage", "Événement", "Tournoi"].compactMap { mode in
            guard mode != store.mode || store.session?.isComplete != false else { return nil }
            return store.savedGame(mode: mode)
        }
    }
    var body: some View {
        let games = otherGames
        if !games.isEmpty {
            LisaCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.text("Parties en cours")).font(LisaTheme.heading(19))
                        .accessibilityIdentifier("saved-games")
                    ForEach(games) { game in
                        SavedGameRow(game: game) { _ = store.resume(mode: game.mode) }
                    }
                }
            }
        }
    }
}

private struct SavedGameRow: View {
    let game: SavedModeGame
    let resume: () -> Void
    private var context: String {
        switch game.mode {
        case "Quotidien":
            if let day = game.day { return L10n.text("Quotidien") + " · " + day }
        case "Événement":
            if let eventID = game.eventID { return L10n.text("Événement") + " · " + String(eventID.prefix(7)) }
        case "Voyage":
            if let stage = game.journeyStage { return L10n.text("Voyage · étape %@", String(stage)) }
        case "Tournoi":
            if let key = game.tournamentID { return L10n.text("Tournoi") + " · " + key }
        default: break
        }
        return L10n.text(game.mode)
    }
    var body: some View {
        Button(action: resume) {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(LisaTheme.actionInk)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context).font(LisaTheme.heading(15))
                    Text(game.session.puzzle.difficulty.label + " · " + LisaStore.time(game.session.elapsedSeconds))
                        .font(LisaTheme.body(12)).foregroundStyle(LisaTheme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(LisaTheme.muted)
            }
            .foregroundStyle(LisaTheme.ink)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(LisaPressStyle())
        .accessibilityLabel(L10n.text("Reprendre %@", context))
        .accessibilityIdentifier("saved-game-" + game.mode)
    }
}
