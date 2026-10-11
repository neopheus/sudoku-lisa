import SwiftUI
import CloudKit
import LisaInvitations
import SudokuCore

@MainActor final class LisaSocialNavigation: ObservableObject {
    static let shared = LisaSocialNavigation()
    @Published var openInbox = false
    @Published var openBattle = false
    @Published var switchingToBattle = false
    @Published var inboxPresented = false
}

/// Shared across root, solo and Battle, so full-screen presentations do not hide invitations.
struct LisaInvitationsAccessory: View {
    var compact = false
    @ObservedObject private var invitations = LisaInvitationStore.shared
    @ObservedObject private var navigation = LisaSocialNavigation.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingInbox = false
    @State private var openBattleOnDismiss = false
    @State private var dismissedBanner: String?
    private var incoming: LisaInvitation? {
        invitations.invitations.first { $0.isIncoming && $0.status == .pending && $0.expiresAt > Date() && $0.id != dismissedBanner }
    }
    var body: some View {
        HStack(spacing: 10) {
            if let invitation = incoming, !compact {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("%@ souhaite jouer avec vous", invitation.senderName)).font(.subheadline.weight(.semibold))
                    Button(L10n.text("Voir l’invitation")) { showingInbox = true }
                        .font(.subheadline).accessibilityIdentifier("invitationBannerOpen")
                }
                Spacer(minLength: 0)
                Button { dismissedBanner = invitation.id } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel(L10n.text("Plus tard"))
            } else if !compact { Spacer(minLength: 0) }
            Button { showingInbox = true } label: {
                Label {
                    if invitations.pendingCount > 0 && !compact { Text("\(invitations.pendingCount)").monospacedDigit() }
                } icon: { Image(systemName: invitations.pendingCount > 0 ? "bell.badge.fill" : "bell") }
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(L10n.text("Invitations"))
            .accessibilityValue(String(invitations.pendingCount))
            .accessibilityIdentifier("invitationInboxOpen")
        }
        .font(compact ? .system(size: 20, weight: .bold) : .body)
        .padding(.horizontal, compact ? 0 : 12)
        .background(compact ? AnyShapeStyle(.clear) : AnyShapeStyle(.regularMaterial))
        .sheet(isPresented: $showingInbox, onDismiss: {
            navigation.inboxPresented = false
            if openBattleOnDismiss { openBattleOnDismiss = false; navigation.openBattle = true }
        }) {
            LisaInvitationsView { openBattleOnDismiss = true; showingInbox = false }
        }
        .onChange(of: showingInbox) { _, presented in navigation.inboxPresented = presented }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && navigation.openInbox { showingInbox = true; navigation.openInbox = false }
        }
        .onChange(of: navigation.openInbox) { _, requested in
            guard requested, scenePhase == .active else { return }
            showingInbox = true; navigation.openInbox = false
        }
        .onAppear {
            if navigation.openInbox { showingInbox = true; navigation.openInbox = false }
        }
    }
}

struct LisaInvitationsView: View {
    @ObservedObject private var invitations = LisaInvitationStore.shared
    @ObservedObject private var notifications = LisaSocialNotifications.shared
    @Environment(\.dismiss) private var dismiss
    @State private var roomName = ""
    @State private var alias = UserDefaults.standard.string(forKey: "lisaSocialAlias") ?? "Poulpi"
    @State private var difficulty = Difficulty.easy
    @State private var share: ShareItem?
    @State private var busy = false
    @State private var actionError = false
    @State private var leavingRoom: LisaFriendRoom?
    let onBattle: () -> Void
    private struct ShareItem: Identifiable { let id = UUID(); let value: CKShare }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(L10n.text("Répondez ici pour indiquer votre disponibilité. La partie se rejoint ensuite dans Battle sur l’iPhone."))
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(L10n.text("Activer les notifications")) { Task { await LisaSocialNotifications.shared.requestAuthorization() } }
                    if let message = notifications.permissionMessage { Text(L10n.text(message)).font(.footnote) }
                }
                if invitations.errorMessage != nil || actionError {
                    Section {
                        Text(L10n.text("Les invitations sont indisponibles. Vérifiez iCloud et votre connexion, puis réessayez."))
                            .foregroundStyle(.secondary)
                        Button(L10n.text("Réessayer")) { Task { actionError = false; await invitations.refresh() } }
                    }
                }
                Section(L10n.text("Invitations")) {
                    if invitations.invitations.isEmpty {
                        Text(L10n.text("Aucune invitation pour le moment.")).foregroundStyle(.secondary)
                    }
                    ForEach(invitations.invitations) { invitation in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(invitation.senderName).font(.headline)
                            Text(Difficulty(rawValue: invitation.difficulty)?.label ?? L10n.text("Sudoku"))
                            Text(status(invitation)).font(.subheadline).foregroundStyle(.secondary)
                            if invitation.status == .pending && invitation.expiresAt > Date() {
                                if invitation.isIncoming {
                                    HStack {
                                        Button(L10n.text("Je suis disponible")) { perform { await invitations.respond(to: invitation, accepting: true) } }
                                            .buttonStyle(.borderedProminent)
                                        Button(L10n.text("Refuser"), role: .destructive) { perform { await invitations.respond(to: invitation, accepting: false) } }
                                            .buttonStyle(.bordered)
                                    }
                                } else {
                                    Button(L10n.text("Annuler l’invitation"), role: .destructive) { perform { await invitations.cancel(invitation) } }
                                }
                                Text(invitation.expiresAt, style: .time).font(.caption).foregroundStyle(.secondary)
                            }
                            if invitation.status == .accepted && invitation.expiresAt > Date() {
                                Button(L10n.text("Ouvrir Battle sur l’iPhone"), action: onBattle).buttonStyle(.bordered)
                            }
                        }.padding(.vertical, 5)
                    }
                }
                Section(L10n.text("Mes amis Lisa")) {
                    TextField(L10n.text("Votre surnom"), text: $alias)
                        .onChange(of: alias) { _, value in
                            invitations.displayName = String(value.prefix(40))
                            UserDefaults.standard.set(invitations.displayName, forKey: "lisaSocialAlias")
                        }
                    Picker(L10n.text("Difficulté"), selection: $difficulty) {
                        ForEach(Difficulty.allCases) { Text($0.label).tag($0) }
                    }
                    ForEach(invitations.rooms) { room in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(room.title).font(.headline)
                            Button(L10n.text("Proposer une partie")) { perform { await invitations.send(room: room, difficulty: difficulty.rawValue) } }
                                .buttonStyle(.bordered).disabled(room.memberCount < 2 || room.memberCount > 4)
                            Button(L10n.text("Quitter le cercle"), role: .destructive) { leavingRoom = room }
                            if room.isOwner {
                                Button(L10n.text("Gérer les amis")) { presentShare(room) }.buttonStyle(.bordered)
                            }
                        }
                    }
                    TextField(L10n.text("Nom du cercle d’amis"), text: $roomName)
                    Button(L10n.text("Ajouter des amis")) {
                        busy = true
                        Task {
                            defer { busy = false }
                            do { share = ShareItem(value: try await invitations.createRoom(name: roomName.trimmingCharacters(in: .whitespacesAndNewlines))) }
                            catch { actionError = true }
                        }
                    }.disabled(roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text(L10n.text("Partagez un accès privé avec vos amis. Ils doivent l’accepter une première fois avec iCloud."))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .disabled(busy)
            .overlay { if busy || invitations.isLoading { ProgressView().padding().background(.regularMaterial, in: Capsule()) } }
            .confirmationDialog(L10n.text("Quitter le cercle ? Son propriétaire le supprime pour tous les membres."), isPresented: Binding(get: { leavingRoom != nil }, set: { if !$0 { leavingRoom = nil } }), titleVisibility: .visible) {
                Button(L10n.text("Quitter le cercle"), role: .destructive) {
                    if let room = leavingRoom { perform { await invitations.leaveRoom(room) } }
                    leavingRoom = nil
                }
            }
            .navigationTitle(L10n.text("Invitations"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Fermer")) { dismiss() } } }
            .refreshable { await invitations.refresh() }
            .task { invitations.displayName = String(alias.prefix(40)); await invitations.refresh() }
            .sheet(item: $share, onDismiss: { Task { await invitations.refresh() } }) { item in
                LisaCloudSharingView(share: item.value, container: invitations.container) { actionError = true }
            }
        }
    }
    private func perform(_ operation: @escaping @MainActor () async -> Void) {
        busy = true
        Task { await operation(); busy = false }
    }
    private func presentShare(_ room: LisaFriendRoom) {
        busy = true
        Task {
            defer { busy = false }
            do { share = ShareItem(value: try await invitations.share(for: room)) }
            catch { actionError = true }
        }
    }
    private func status(_ invitation: LisaInvitation) -> String {
        if invitation.status == .pending && invitation.expiresAt <= Date() { return L10n.text("Invitation expirée") }
        switch invitation.status {
        case .pending: return L10n.text("En attente de réponse")
        case .accepted: return L10n.text("Disponibilité confirmée — rejoignez Battle sur l’iPhone")
        case .declined: return L10n.text("Invitation refusée")
        case .cancelled: return L10n.text("Invitation annulée")
        case .expired: return L10n.text("Invitation expirée")
        }
    }
}

private struct LisaCloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let onError: @MainActor () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onError: onError) }
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onError: @MainActor () -> Void
        init(onError: @escaping @MainActor () -> Void) { self.onError = onError }
        func itemTitle(for csc: UICloudSharingController) -> String? { "Lisa Sudoku" }
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Task { @MainActor in self.onError(); await LisaInvitationStore.shared.refresh() }
        }
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            Task { @MainActor in await LisaInvitationStore.shared.refresh() }
        }
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            Task { @MainActor in await LisaInvitationStore.shared.refresh() }
        }
    }
}
