import SwiftUI
import LisaInvitations
import UserNotifications

struct WatchHomeView: View {
    @EnvironmentObject private var notifications: WatchNotificationDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var previewCompanion = false
    var body: some View {
        NavigationStack {
            List {
                NavigationLink { WatchCompanionView() } label: { Label("watch.companion", systemImage: "heart.fill") }
                NavigationLink { WatchInboxView() } label: { Label("watch.invitations", systemImage: "envelope.fill") }
                NavigationLink { WatchMiniGameView() } label: { Label("watch.mini", systemImage: "square.grid.2x2.fill") }
            }
            .navigationTitle("Lisa")
            .navigationDestination(isPresented: $notifications.openInbox) { WatchInboxView() }
            #if DEBUG
            .navigationDestination(isPresented: $previewCompanion) { WatchCompanionView() }
            .onAppear { previewCompanion = ProcessInfo.processInfo.arguments.contains("--watch-poulpi-preview") }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await LisaInvitationStore.shared.refresh() } }
        }
    }
}

struct WatchCompanionView: View {
    @EnvironmentObject private var progress: WatchProgressStore
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                WatchPoulpiView(appearance: progress.snapshot?.appearance ?? .init()).frame(height: 150)
                Text("watch.greeting").font(.headline)
                if let snapshot = progress.snapshot {
                    Text("watch.games \(snapshot.completedGames)")
                    Text("watch.streak \(snapshot.currentStreak)")
                    Text(snapshot.updatedAt, format: .dateTime.day().month().hour().minute())
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("watch.noProgress").font(.caption)
                }
            }.padding(.horizontal, 8)
        }.navigationTitle("Poulpi")
    }
}

struct WatchInboxView: View {
    @ObservedObject private var store = LisaInvitationStore.shared
    @State private var requestingNotifications = false
    @State private var notificationMessage: String?
    var body: some View {
        List {
            Text("watch.invitationExplanation").font(.caption)
            if store.isLoading { ProgressView() }
            if let message = store.errorMessage { Text(LocalizedStringKey(message)).font(.caption).foregroundStyle(.orange) }
            if store.invitations.isEmpty && !store.isLoading { Text("watch.noInvitations").font(.caption) }
            ForEach(store.invitations) { invitation in
                WatchInvitationRow(invitation: invitation)
            }
            Button("watch.refresh") { Task { await store.refresh() } }.disabled(store.isLoading)
            Button("watch.notifications") {
                requestingNotifications = true
                Task {
                    do {
                        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                        notificationMessage = String(localized: granted ? "watch.notificationsEnabled" : "watch.notificationsDenied")
                    } catch { notificationMessage = error.localizedDescription }
                    requestingNotifications = false
                }
            }.disabled(requestingNotifications)
            if let notificationMessage { Text(notificationMessage).font(.caption2) }
        }.navigationTitle("watch.invitations").task { await store.refresh() }
    }
}

struct WatchInvitationRow: View {
    let invitation: LisaInvitation
    @ObservedObject private var store = LisaInvitationStore.shared
    @State private var responding = false
    var body: some View {
        let current = invitation.expired(at: Date())
        VStack(alignment: .leading, spacing: 5) {
            Text(invitation.senderName).font(.headline)
            Text(invitation.expiresAt, format: .dateTime.hour().minute()).font(.caption2)
            Text(LocalizedStringKey("watch.status.\(current.status.rawValue)")).font(.caption)
            if current.isIncoming && current.status == .pending {
                Button("watch.accept") { respond(true) }.disabled(responding || store.isLoading)
                Button("watch.decline", role: .destructive) { respond(false) }.disabled(responding || store.isLoading)
            }
            if current.status == .accepted { Text("watch.openPhone").font(.caption2) }
        }.accessibilityIdentifier("watch.invitation.\(invitation.id)")
    }
    private func respond(_ accepting: Bool) {
        guard !responding, !store.isLoading, let account = store.currentUserID else { return }
        responding = true
        Task {
            defer { responding = false }
            // Reconcile account, expiry and another device's response before acting.
            await store.refresh()
            guard store.currentUserID == account, store.errorMessage == nil,
                  let latest = store.invitations.first(where: { $0.id == invitation.id && $0.roomID == invitation.roomID }),
                  latest.isIncoming, latest.status == .pending, latest.expiresAt > Date() else { return }
            await store.respond(to: latest, accepting: accepting)
        }
    }
}

struct WatchMiniGameView: View {
    @State private var game = MiniSudoku()
    @State private var selected: Int?
    var body: some View {
        ScrollView {
            VStack(spacing: 7) {
                Text("watch.miniRules").font(.caption2)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 4), spacing: 2) {
                    ForEach(0..<16) { index in
                        Button { selected = index } label: {
                            Text(game.cells[index] == 0 ? "·" : String(game.cells[index]))
                                .font(.system(size: 20, weight: game.clues[index] == 0 ? .regular : .bold, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .foregroundStyle(game.hasConflict(index) ? Color.red : Color.primary)
                                .background(selected == index ? Color.purple.opacity(0.6) : Color.secondary.opacity(index / 8 == index % 4 / 2 ? 0.25 : 0.12))
                        }.buttonStyle(.plain)
                            .accessibilityLabel(Text("watch.cell \(index / 4 + 1) \(index % 4 + 1) \(game.cells[index])"))
                            .accessibilityIdentifier("watch.mini.cell.\(index)")
                    }
                }
                HStack(spacing: 4) {
                    ForEach(1...4, id: \.self) { value in
                        Button(String(value)) { if let selected { game.set(value, at: selected) } }
                    }
                }.disabled(selected.map { !game.isEditable($0) } ?? true)
                HStack {
                    Button { if let selected { game.set(0, at: selected) } } label: { Image(systemName: "eraser") }.accessibilityLabel("watch.erase")
                    Button { game.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(game.history.isEmpty).accessibilityLabel("watch.undo")
                }
                if game.isComplete { Text("watch.solved").foregroundStyle(.green) }
                Button("watch.newGame") { game = MiniSudoku(); selected = nil }
            }.padding(.horizontal, 4)
        }.navigationTitle("watch.mini")
    }
}
