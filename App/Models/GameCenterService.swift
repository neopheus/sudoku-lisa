import SudokuCore
import SwiftUI
import UIKit
@preconcurrency import GameKit

/// Optional, real Game Center integration. Requires an App Store Connect
/// recurring leaderboard, weekly Monday 00:00 UTC, ascending elapsed seconds.
@MainActor
final class GameCenterService: NSObject, ObservableObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterService()
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var statusMessage: String?

    private var leaderboardID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "LisaLeaderboardID") as? String,
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return id
    }
    var isConfigured: Bool { leaderboardID != nil }
    var playerName: String? { isAuthenticated ? GKLocalPlayer.local.displayName : nil }

    func authenticate() {
        guard isConfigured, !isAuthenticating else { return }
        isAuthenticating = true
        statusMessage = nil
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            Task { @MainActor in
                guard let self else { return }
                if let controller {
                    guard let presenter = self.presenter else {
                        self.isAuthenticating = false
                        self.statusMessage = "La connexion n’a pas pu s’ouvrir. Réessayez dans un instant."
                        return
                    }
                    presenter.present(controller, animated: true)
                } else {
                    self.isAuthenticating = false
                    self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                    if error != nil || !self.isAuthenticated {
                        self.statusMessage = "Connexion indisponible. Vous pouvez continuer à jouer en solo."
                    } else { self.statusMessage = "Vous êtes prêt pour le tournoi !" }
                }
            }
        }
    }

    func showLeaderboard() {
        guard let leaderboardID, isAuthenticated else { return }
        guard let presenter else {
            statusMessage = "Le classement n’a pas pu s’ouvrir. Réessayez dans un instant."
            return
        }
        let controller = GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: .global, timeScope: .allTime)
        controller.gameCenterDelegate = self
        presenter.present(controller, animated: true)
    }

    /// The caller must verify the completed puzzle belongs to the current weekly
    /// tournament. Hints exclude a run; every mistake adds 60 seconds.
    func submit(seconds: Int, mistakes: Int, hints: Int) {
        guard let leaderboardID, isAuthenticated, !isSubmitting else { return }
        guard hints == 0 else {
            statusMessage = "Belle partie ! Les parties avec aide restent hors classement."
            return
        }
        guard seconds >= 0, mistakes >= 0, seconds <= 604_800, mistakes <= 10_000 else { return }
        isSubmitting = true
        let score = max(1, seconds) + mistakes * 60
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID]) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.isSubmitting = false
                self.statusMessage = error == nil
                    ? "Votre temps a rejoint le classement !"
                    : "Votre temps n’a pas pu être envoyé. Votre victoire reste enregistrée sur cet iPhone."
            }
        }
    }

    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        Task { @MainActor in gameCenterViewController.dismiss(animated: true) }
    }

    private var presenter: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.first(where: { $0.activationState == .foregroundActive })?.windows.first(where: \.isKeyWindow)
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
}
