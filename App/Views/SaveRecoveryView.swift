import SwiftUI
import SudokuCore

struct SaveRecoveryView: View {
    @EnvironmentObject private var store: LisaStore
    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?
    @State private var exportFailed = false
    @State private var confirmRestore = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L10n.text(store.needsSaveRecovery
                        ? "La sauvegarde n’a pas pu être chargée. Elle est conservée et l’enregistrement est suspendu pour protéger votre progression."
                        : "Votre progression est de nouveau enregistrée."))
                    if let message = store.recoveryMessage {
                        Text(L10n.text(message))
                            .accessibilityIdentifier("saveRecoveryStatus")
                    }
                    if store.isRecoveringSave {
                        ProgressView(L10n.text("Lecture de la sauvegarde…"))
                    }
                }
                if store.needsSaveRecovery {
                    Section {
                        Button(L10n.text("Réessayer la lecture")) {
                            Task { await store.retryLoadingSave() }
                        }
                        .accessibilityIdentifier("saveRecoveryRetry")
                        .disabled(store.isRecoveringSave)
                        if store.canRestoreBackup {
                            Button(L10n.text("Restaurer la copie de secours")) { confirmRestore = true }
                                .accessibilityIdentifier("saveRecoveryRestore")
                                .disabled(store.isRecoveringSave)
                        }
                    } footer: {
                        Text(L10n.text(store.canRestoreBackup
                            ? "Une copie de secours lisible est disponible. Elle peut contenir une progression plus ancienne."
                            : "Aucune copie de secours lisible n’est disponible."))
                    }
                }
                if store.needsSaveRecovery || store.preservedSaveURL != nil || exportURL != nil {
                    Section {
                        if let exportURL {
                            ShareLink(item: exportURL) {
                                Label(L10n.text("Partager l’original"), systemImage: "square.and.arrow.up")
                            }
                            .accessibilityIdentifier("saveRecoveryShare")
                        } else {
                            Button {
                                exportFailed = false
                                Task {
                                    do { exportURL = try await store.exportOriginalSave() }
                                    catch { exportFailed = true }
                                }
                            } label: {
                                Label(L10n.text("Exporter l’original"), systemImage: "square.and.arrow.up")
                            }
                            .accessibilityIdentifier("saveRecoveryExport")
                            .disabled(store.isRecoveringSave)
                        }
                        if exportFailed {
                            Text(L10n.text("L’original n’a pas pu être exporté. Il est conservé ; vous pouvez réessayer."))
                                .accessibilityIdentifier("saveRecoveryExportError")
                        }
                    } footer: {
                        Text(L10n.text("L’export crée une copie exacte du fichier original, sans le modifier."))
                    }
                }
            }
            .navigationTitle(L10n.text("Sauvegarde protégée"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Fermer")) {
                        store.saveError = nil
                        dismiss()
                    }
                    .accessibilityIdentifier("saveRecoveryClose")
                }
            }
            .confirmationDialog(L10n.text("Restaurer la copie de secours ?"), isPresented: $confirmRestore,
                                titleVisibility: .visible) {
                Button(L10n.text("Restaurer la copie de secours")) {
                    Task { await store.restoreBackup() }
                }
                Button(L10n.text("Annuler"), role: .cancel) {}
            } message: {
                Text(L10n.text("Votre progression reviendra à cette copie. L’original sera conservé séparément avant la restauration."))
            }
        }
    }
}
