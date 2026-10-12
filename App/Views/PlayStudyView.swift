import SwiftUI
import SudokuCore

struct PlayStudyView: View {
    @AppStorage(L10n.languagePreferenceKey) private var languagePreference = L10n.systemLanguage
    @ObservedObject var study: LisaPlayStudy
    @State private var exportURL: URL?
    @State private var preparing = false
    @State private var exportFailed = false
    @State private var resetPresented = false

    var body: some View {
        Form {
            Section {
                Text(L10n.text("Ce bilan reste sur votre iPhone. Il compte vos actions pendant 90 jours pour aider à améliorer le jeu. Aucune grille, aucun compte et aucun envoi automatique."))
                Toggle(L10n.text("Conserver mon bilan local"), isOn: $study.enabled)
                    .disabled(study.storageUnavailable || preparing).accessibilityIdentifier("playStudyEnabled")
            }
            if study.storageUnavailable {
                Section { Text(L10n.text("Le bilan est indisponible. Votre progression de jeu est préservée. Vous pouvez effacer le bilan pour recommencer.")) }
            } else {
                Section(L10n.text("Depuis le début du bilan")) {
                    row("Parties commencées", event: .gameStarted)
                    row("Parties terminées", event: .gameCompleted)
                    row("Parties reprises", event: .gameResumed)
                    row("Indices consultés", event: .hintViewed)
                    row("Souvenirs regardés", event: .souvenirViewed)
                }
                Section {
                    Button(L10n.text("Préparer le partage du bilan")) {
                        preparing = true
                        exportURL = nil
                        Task {
                            defer { preparing = false }
                            do { exportURL = try await study.export() }
                            catch { exportFailed = true }
                        }
                    }.disabled(preparing).accessibilityIdentifier("preparePlayStudyExport")
                    if preparing { ProgressView() }
                    if let exportURL {
                        ShareLink(item: exportURL) { Label(L10n.text("Partager le bilan"), systemImage: "square.and.arrow.up") }
                            .accessibilityIdentifier("sharePlayStudy")
                    }
                    Text(L10n.text("Vous choisissez si vous partagez ce fichier et avec qui. Effacer le bilan ne change ni vos parties ni vos souvenirs."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Button(L10n.text("Effacer le bilan"), role: .destructive) { resetPresented = true }
                    .disabled(preparing).accessibilityIdentifier("resetPlayStudy")
            }
        }
        .navigationTitle(L10n.text("Bilan des essais"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L10n.text("Effacer le bilan ?"), isPresented: $resetPresented, titleVisibility: .visible) {
            Button(L10n.text("Effacer le bilan"), role: .destructive) {
                exportURL = nil
                preparing = true
                Task {
                    await study.reset()
                    preparing = false
                }
            }
            Button(L10n.text("Annuler"), role: .cancel) {}
        }
        .alert(L10n.text("Partage indisponible"), isPresented: $exportFailed) {
            Button(L10n.text("D’accord"), role: .cancel) {}
        } message: { Text(L10n.text("Le bilan n’a pas pu être préparé. Réessayez.")) }
    }

    private func row(_ key: String, event: PlayStudyEvent) -> some View {
        LabeledContent(L10n.text(key), value: study.snapshot.count(event).formatted(.number.locale(L10n.locale)))
    }
}
