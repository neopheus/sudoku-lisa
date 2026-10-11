import Foundation
import CloudKit
import Combine

@MainActor public final class LisaInvitationStore: ObservableObject {
    public static let shared = LisaInvitationStore()
    public let container: CKContainer
    @Published public private(set) var rooms: [LisaFriendRoom] = []
    @Published public private(set) var invitations: [LisaInvitation] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    public private(set) var currentUserID: String?
    public var displayName = "Poulpi"
    public var pendingCount: Int { invitations.filter { $0.isIncoming && $0.status == .pending && $0.expiresAt > Date() }.count }
    private struct Context { let database: CKDatabase; let root: CKRecord; let share: CKShare; let members: Set<String> }
    private var contexts: [String: Context] = [:]
    private var subscribedUser: String?
    private var generation = 0
    private var refreshRequested = false
    private var refreshTask: Task<Void, Never>?
    private var expiryTask: Task<Void, Never>?
    private var accountObserver: NSObjectProtocol?
    public init(container: CKContainer = CKContainer(identifier: "iCloud.com.xavier.sudokulisa")) {
        self.container = container
        accountObserver = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.clear(); await self?.refresh() }
        }
    }
    public func clearError() { errorMessage = nil }

    public enum StoreError: Error { case unavailableAccount, invalidRoom, participantLimit, notAuthorized, expired, fetchLimit }

    public func refresh() async {
        if let refreshTask { refreshRequested = true; await refreshTask.value; return }
        let task = Task { @MainActor in
            isLoading = true
            // A burst shares the active fetch and at most one follow-up fetch.
            // Notifications are hints; the next foreground refresh reconciles later changes.
            for _ in 0..<2 {
                refreshRequested = false
                await performRefresh()
                if !refreshRequested { break }
            }
            isLoading = false
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh() async {
        let refreshGeneration = generation
        do {
            guard try await container.accountStatus() == .available else { clear(); throw StoreError.unavailableAccount }
            let user = try await container.userRecordID().recordName
            if currentUserID != user { rooms = []; invitations = []; contexts = [:]; subscribedUser = nil; currentUserID = user }
            var newContexts: [String: Context] = [:]
            var newInvitations: [LisaInvitation] = []
            for database in [container.privateCloudDatabase, container.sharedCloudDatabase] {
                let zones = try await database.allRecordZones().filter { $0.zoneID.zoneName.hasPrefix("LisaFriends-") }
                guard zones.count <= 32 else { throw StoreError.fetchLimit }
                for zone in zones {
                    try Task.checkCancellation()
                    var token: CKServerChangeToken?
                    var records: [CKRecord.ID: CKRecord] = [:]
                    for page in 0..<12 {
                        try Task.checkCancellation()
                        let changes = try await database.recordZoneChanges(inZoneWith: zone.zoneID, since: token, resultsLimit: 200)
                        for (id, result) in changes.modificationResultsByID { records[id] = try result.get().record }
                        for deletion in changes.deletions { records.removeValue(forKey: deletion.recordID) }
                        token = changes.changeToken
                        guard records.count <= 2000 else { throw StoreError.fetchLimit }
                        if !changes.moreComing { break }
                        if page == 11 { throw StoreError.fetchLimit }
                    }
                    guard let root = records.values.first(where: { $0.recordType == "LisaFriendRoom" && $0.recordID.recordName == "room" }),
                          let shareID = root.share?.recordID else { continue }
                    let share: CKShare
                    if let cached = records[shareID] as? CKShare { share = cached }
                    else { guard let fetched = try await database.record(for: shareID) as? CKShare else { continue }; share = fetched }
                    guard share.publicPermission == .none else { continue }
                    let owner = share.owner.userIdentity.userRecordID?.recordName
                    guard Self.identity(root.creatorUserRecordID?.recordName, currentUser: user) == Self.identity(owner, currentUser: user) else { continue }
                    let members = Set(share.participants.filter { $0.role == .owner || $0.acceptanceStatus == .accepted }.compactMap { Self.identity($0.userIdentity.userRecordID?.recordName, currentUser: user) })
                    guard members.contains(user) else { continue }
                    let roomID = zone.zoneID.ownerName + "/" + zone.zoneID.zoneName
                    newContexts[roomID] = Context(database: database, root: root, share: share, members: members)
                    let events = records.values.filter { $0.parent?.recordID == root.recordID }.compactMap { Self.event($0, currentUser: user) }
                    let now = Date()
                    let reduced = await Task.detached(priority: .utility) {
                        InvitationReducer.reduce(events, roomID: roomID, members: members, currentUser: user, now: now)
                    }.value
                    if share.participants.count <= 4 { newInvitations += reduced }
                    if share.currentUserParticipant?.role == .owner {
                        let obsolete = records.values.filter { $0.recordType == "LisaInvitationEvent" && $0.parent?.recordID == root.recordID && ($0.creationDate ?? now) < now.addingTimeInterval(-30 * 86400) }.prefix(200).map(\.recordID)
                        if !obsolete.isEmpty {
                            let removal = try await database.modifyRecords(saving: [], deleting: obsolete, atomically: false)
                            for result in removal.deleteResults.values { _ = try result.get() }
                        }
                    }
                }
            }
            guard generation == refreshGeneration else { refreshRequested = true; return }
            contexts = newContexts
            rooms = newContexts.map { id, context in LisaFriendRoom(id: id, title: context.root["title"] as? String ?? "Poulpi", isOwner: context.share.currentUserParticipant?.role == .owner, memberCount: context.members.count) }.sorted { $0.title < $1.title }
            invitations = Array(newInvitations.sorted { $0.createdAt > $1.createdAt }.prefix(100))
            scheduleExpiry()
            errorMessage = nil
            if subscribedUser != user {
                for database in [container.privateCloudDatabase, container.sharedCloudDatabase] {
                    let subscription = CKDatabaseSubscription(subscriptionID: "lisa-invitations-v1")
                    let info = CKSubscription.NotificationInfo(); info.shouldSendContentAvailable = true
                    subscription.notificationInfo = info
                    _ = try await database.save(subscription)
                }
                subscribedUser = user
            }
        } catch {
            if case StoreError.fetchLimit = error {
                contexts = [:]; invitations = []; expiryTask?.cancel()
            }
            errorMessage = "invitations_unavailable"
        }
    }

    public func createRoom(name: String) async throws -> CKShare {
        guard try await container.accountStatus() == .available else { throw StoreError.unavailableAccount }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw StoreError.invalidRoom }
        let existing = try await container.privateCloudDatabase.allRecordZones().filter { $0.zoneID.zoneName.hasPrefix("LisaFriends-") }
        guard existing.count < 16 else { throw StoreError.fetchLimit }
        let zone = CKRecordZone(zoneName: "LisaFriends-" + UUID().uuidString)
        _ = try await container.privateCloudDatabase.save(zone)
        let root = CKRecord(recordType: "LisaFriendRoom", recordID: CKRecord.ID(recordName: "room", zoneID: zone.zoneID))
        root["title"] = String(name.prefix(80)) as CKRecordValue
        let share = CKShare(rootRecord: root); share.publicPermission = .none
        share[CKShare.SystemFieldKey.title] = String(name.prefix(80)) as CKRecordValue
        let savedShare: CKShare
        do {
            let result = try await container.privateCloudDatabase.modifyRecords(saving: [root, share], deleting: [], atomically: true)
            for value in result.saveResults.values { _ = try value.get() }
            guard let saved = try result.saveResults[share.recordID]?.get() as? CKShare else { throw StoreError.invalidRoom }
            savedShare = saved
        } catch {
            _ = try? await container.privateCloudDatabase.deleteRecordZone(withID: zone.zoneID)
            throw error
        }
        await refresh()
        return savedShare
    }
    public func acceptShare(_ metadata: CKShare.Metadata) async {
        do { _ = try await container.accept(metadata); await refresh() }
        catch { errorMessage = "invitations_unavailable" }
    }
    /// Owners delete their room for everyone; guests remove only their own shared zone.
    public func leaveRoom(_ room: LisaFriendRoom) async {
        do {
            let pieces = room.id.split(separator: "/", maxSplits: 1).map(String.init)
            guard pieces.count == 2, pieces[1].hasPrefix("LisaFriends-") else { throw StoreError.invalidRoom }
            let zoneID = CKRecordZone.ID(zoneName: pieces[1], ownerName: pieces[0])
            let database = room.isOwner ? container.privateCloudDatabase : container.sharedCloudDatabase
            _ = try await database.deleteRecordZone(withID: zoneID)
            await refresh()
        } catch { errorMessage = "invitations_unavailable" }
    }
    public func share(for room: LisaFriendRoom) async throws -> CKShare {
        guard let context = contexts[room.id], context.share.currentUserParticipant?.role == .owner else { throw StoreError.notAuthorized }
        return context.share
    }
    public func send(room: LisaFriendRoom, difficulty: String) async {
        do { try await write(roomID: room.id, invitation: nil, kind: "invite", difficulty: difficulty); await refresh() }
        catch { errorMessage = "invitations_unavailable" }
    }
    public func respond(to invitation: LisaInvitation, accepting: Bool) async {
        do {
            guard invitation.isIncoming, invitation.status == .pending else { throw StoreError.notAuthorized }
            try await write(roomID: invitation.roomID, invitation: invitation, kind: accepting ? "accept" : "decline", difficulty: "")
            await refresh()
        } catch { errorMessage = "invitations_unavailable" }
    }
    public func cancel(_ invitation: LisaInvitation) async {
        do {
            guard !invitation.isIncoming else { throw StoreError.notAuthorized }
            try await write(roomID: invitation.roomID, invitation: invitation, kind: "cancel", difficulty: "")
            await refresh()
        } catch { errorMessage = "invitations_unavailable" }
    }
    private func write(roomID: String, invitation: LisaInvitation?, kind: String, difficulty: String) async throws {
        guard let context = contexts[roomID], let user = currentUserID,
              try await container.accountStatus() == .available,
              try await container.userRecordID().recordName == user,
              let freshShare = try await context.database.record(for: context.share.recordID) as? CKShare,
              freshShare.publicPermission == .none, freshShare.participants.count <= 4 else { throw StoreError.notAuthorized }
        let members = Set(freshShare.participants.filter { $0.role == .owner || $0.acceptanceStatus == .accepted }.compactMap { Self.identity($0.userIdentity.userRecordID?.recordName, currentUser: user) })
        guard members.contains(user), members.count >= 2,
              freshShare.currentUserParticipant?.permission == .readWrite || freshShare.currentUserParticipant?.role == .owner else { throw StoreError.notAuthorized }
        if let invitation {
            let source = try await context.database.record(for: CKRecord.ID(recordName: invitation.id, zoneID: context.root.recordID.zoneID))
            guard source.parent?.recordID == context.root.recordID, let origin = Self.event(source, currentUser: user),
                  origin.kind == "invite", origin.id == origin.invitationID,
                  origin.actor == origin.lastModifier, members.contains(origin.actor),
                  let expiry = origin.expiry, expiry > Date(), expiry.timeIntervalSince(origin.timestamp) <= 600 else { throw StoreError.expired }
            guard kind == "cancel" ? origin.actor == user : origin.actor != user else { throw StoreError.notAuthorized }
        }
        let id = UUID().uuidString
        let record = CKRecord(recordType: "LisaInvitationEvent", recordID: CKRecord.ID(recordName: id, zoneID: context.root.recordID.zoneID))
        record.parent = CKRecord.Reference(recordID: context.root.recordID, action: .none)
        record["invitationID"] = (invitation?.id ?? id) as CKRecordValue
        record["kind"] = kind as CKRecordValue
        if kind == "invite" {
            record["expiry"] = Date().addingTimeInterval(600) as CKRecordValue
            record["difficulty"] = String(difficulty.prefix(40)) as CKRecordValue
            record["senderName"] = String(displayName.prefix(40)) as CKRecordValue
        }
        _ = try await context.database.save(record)
    }
    private static func identity(_ name: String?, currentUser: String) -> String? { name == CKCurrentUserDefaultName ? currentUser : name }
    private static func event(_ record: CKRecord, currentUser: String) -> InvitationEvent? {
        guard record.recordType == "LisaInvitationEvent", let actor = identity(record.creatorUserRecordID?.recordName, currentUser: currentUser),
              let modifier = identity(record.lastModifiedUserRecordID?.recordName, currentUser: currentUser), let date = record.creationDate,
              let invitation = record["invitationID"] as? String, let kind = record["kind"] as? String else { return nil }
        return InvitationEvent(id: record.recordID.recordName, invitationID: invitation, actor: actor, lastModifier: modifier, kind: kind, timestamp: date, expiry: record["expiry"] as? Date, difficulty: record["difficulty"] as? String ?? "", senderName: record["senderName"] as? String ?? "Poulpi")
    }
    private func scheduleExpiry() {
        expiryTask?.cancel()
        let now = Date()
        invitations = invitations.map { $0.expired(at: now) }
        guard let deadline = invitations.filter({ $0.status == .pending || $0.status == .accepted }).map(\.expiresAt).min() else { return }
        let interval = max(0.01, deadline.timeIntervalSince(now))
        expiryTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(interval)) } catch { return }
            guard let self else { return }
            self.scheduleExpiry()
        }
    }
    private func clear() { generation += 1; expiryTask?.cancel(); rooms = []; invitations = []; contexts = [:]; currentUserID = nil; subscribedUser = nil }
}
