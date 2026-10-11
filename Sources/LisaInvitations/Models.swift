import Foundation

public struct LisaFriendRoom: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let isOwner: Bool
    public let memberCount: Int
    public init(id: String, title: String, isOwner: Bool, memberCount: Int = 1) { self.id = id; self.title = title; self.isOwner = isOwner; self.memberCount = memberCount }
}

public struct LisaInvitation: Identifiable, Codable, Sendable, Equatable {
    public enum Status: String, Codable, Sendable { case pending, accepted, declined, cancelled, expired }
    public let id: String
    public let roomID: String
    public let senderName: String
    public let difficulty: String
    public let createdAt: Date
    public let expiresAt: Date
    public let status: Status
    public let isIncoming: Bool
    public let acceptedCount: Int
    public func expired(at now: Date) -> Self {
        guard expiresAt <= now, status == .pending || status == .accepted else { return self }
        return Self(id: id, roomID: roomID, senderName: senderName, difficulty: difficulty, createdAt: createdAt, expiresAt: expiresAt, status: .expired, isIncoming: isIncoming, acceptedCount: acceptedCount)
    }
}

/// Identity comes from CloudKit record metadata, never a writable actor field.
struct InvitationEvent: Sendable {
    let id: String
    let invitationID: String
    let actor: String
    let lastModifier: String
    let kind: String
    let timestamp: Date
    let expiry: Date?
    let difficulty: String
    let senderName: String
}

enum InvitationReducer {
    static func reduce(_ events: [InvitationEvent], roomID: String, members: Set<String>, currentUser: String, now: Date) -> [LisaInvitation] {
        let valid = events.filter { $0.actor == $0.lastModifier && members.contains($0.actor) }
        return valid.filter { $0.kind == "invite" && $0.id == $0.invitationID }.compactMap { origin in
            guard let deadline = origin.expiry, deadline > origin.timestamp,
                  deadline.timeIntervalSince(origin.timestamp) <= 600,
                  origin.timestamp <= now, now.timeIntervalSince(origin.timestamp) <= 30 * 86400 else { return nil }
            let replies = valid.filter { $0.invitationID == origin.id && $0.id != origin.id && $0.timestamp >= origin.timestamp && $0.timestamp <= deadline && $0.timestamp <= now }
            let cancelled = replies.contains { $0.kind == "cancel" && $0.actor == origin.actor }
            var votes: [String: InvitationEvent] = [:]
            for reply in replies.sorted(by: { ($0.timestamp, $0.id) < ($1.timestamp, $1.id) }) where reply.actor != origin.actor && ["accept", "decline"].contains(reply.kind) {
                if votes[reply.actor] == nil { votes[reply.actor] = reply }
            }
            let accepted = votes.values.filter { $0.kind == "accept" }.count
            let status: LisaInvitation.Status
            if cancelled { status = .cancelled }
            else if deadline <= now { status = .expired }
            else if let vote = votes[currentUser] { status = vote.kind == "accept" ? .accepted : .declined }
            else if origin.actor == currentUser && accepted > 0 { status = .accepted }
            else { status = .pending }
            return LisaInvitation(id: origin.id, roomID: roomID, senderName: origin.senderName, difficulty: origin.difficulty, createdAt: origin.timestamp, expiresAt: deadline, status: status, isIncoming: origin.actor != currentUser, acceptedCount: accepted)
        }.sorted { $0.createdAt > $1.createdAt }.prefix(100).map { $0 }
    }
}
