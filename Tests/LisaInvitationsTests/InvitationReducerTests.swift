import XCTest
@testable import LisaInvitations

final class InvitationReducerTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 10000)
    func event(_ id: String = "invite", actor: String = "host", modifier: String? = nil, kind: String = "invite", offset: Double = 0, expiry: Double = 600) -> InvitationEvent {
        InvitationEvent(id: id, invitationID: "invite", actor: actor, lastModifier: modifier ?? actor, kind: kind, timestamp: start.addingTimeInterval(offset), expiry: start.addingTimeInterval(expiry), difficulty: "hard", senderName: "Host")
    }
    func reduce(_ events: [InvitationEvent], user: String = "guest", now: Double = 10) -> [LisaInvitation] {
        InvitationReducer.reduce(events, roomID: "room", members: ["host", "guest", "other"], currentUser: user, now: start.addingTimeInterval(now))
    }
    func testTamperedOriginAndNonMembersRejected() {
        XCTAssertTrue(reduce([event(modifier: "guest")]).isEmpty)
        XCTAssertTrue(reduce([event(actor: "outsider")]).isEmpty)
        XCTAssertTrue(reduce([event(expiry: 601)]).isEmpty)
    }
    func testFirstVoteWinsAndDuplicateDoesNotInflateCount() {
        let output = reduce([event(), event("a", actor: "guest", kind: "accept", offset: 1), event("b", actor: "guest", kind: "decline", offset: 2), event("c", actor: "guest", kind: "accept", offset: 3)])
        XCTAssertEqual(output.first?.status, .accepted)
        XCTAssertEqual(output.first?.acceptedCount, 1)
    }
    func testOnlySenderCanCancelAndSenderCannotVote() {
        XCTAssertEqual(reduce([event(), event("a", actor: "guest", kind: "cancel", offset: 1)]).first?.status, .pending)
        XCTAssertEqual(reduce([event(), event("a", kind: "accept", offset: 1)]).first?.acceptedCount, 0)
        XCTAssertEqual(reduce([event(), event("a", kind: "cancel", offset: 1)]).first?.status, .cancelled)
    }
    func testDeadlineAndForgedReply() {
        XCTAssertEqual(reduce([event(), event("a", actor: "guest", kind: "accept", offset: 601)], now: 602).first?.status, .expired)
        XCTAssertEqual(reduce([event(), event("a", actor: "guest", modifier: "other", kind: "accept", offset: 1)]).first?.status, .pending)
    }
    func testGroupResponsesAreIndependent() {
        let result = reduce([event(), event("a", actor: "guest", kind: "decline", offset: 1), event("b", actor: "other", kind: "accept", offset: 2)])
        XCTAssertEqual(result.first?.status, .declined)
        XCTAssertEqual(result.first?.acceptedCount, 1)
    }
    func testExpiryBoundaryAlsoExpiresAcceptedInvitations() {
        let events = [event(), event("reply", actor: "guest", kind: "accept", offset: 1)]
        XCTAssertEqual(reduce(events, now: 599.99).first?.status, .accepted)
        XCTAssertEqual(reduce(events, now: 600).first?.status, .expired)
        XCTAssertEqual(reduce(events, now: 600).first?.acceptedCount, 1)
    }
    func testLocalExpiryMatchesReducerAndPreservesIdentity() {
        let invitation = reduce([event()]).first!
        XCTAssertEqual(invitation.expired(at: start.addingTimeInterval(599)).status, .pending)
        let expired = invitation.expired(at: start.addingTimeInterval(600))
        XCTAssertEqual(expired.status, .expired)
        XCTAssertEqual(expired.id, invitation.id)
        XCTAssertEqual(expired.roomID, invitation.roomID)
        XCTAssertEqual(expired.expired(at: start.addingTimeInterval(601)), expired)
    }
    func testFutureOriginAndInvalidExpiryRejected() {
        XCTAssertTrue(reduce([event(offset: 20)], now: 10).isEmpty)
        XCTAssertTrue(reduce([event(expiry: 0)]).isEmpty)
        XCTAssertTrue(reduce([event(expiry: -1)]).isEmpty)
    }
    func testPreOriginFutureAndUnrelatedRepliesIgnored() {
        let unrelated = InvitationEvent(id: "other-reply", invitationID: "unrelated", actor: "guest", lastModifier: "guest", kind: "accept", timestamp: start.addingTimeInterval(1), expiry: nil, difficulty: "", senderName: "")
        let output = reduce([event(), event("pre", actor: "guest", kind: "accept", offset: -1), event("future", actor: "guest", kind: "accept", offset: 20), unrelated])
        XCTAssertEqual(output.first?.status, .pending)
        XCTAssertEqual(output.first?.acceptedCount, 0)
    }
    func testDeterministicDuplicateOrderAndAccountSpecificVote() {
        let votes = [event(), event("b", actor: "guest", kind: "decline", offset: 1), event("a", actor: "guest", kind: "accept", offset: 1)]
        XCTAssertEqual(reduce(votes).first?.status, .accepted)
        XCTAssertEqual(reduce(votes.reversed()).first?.status, .accepted)
        XCTAssertEqual(reduce(votes, user: "other").first?.status, .pending)
    }
    func testCancelledStatePersistsAfterExpiryAndLateCancellationIgnored() {
        XCTAssertEqual(reduce([event(), event("cancel", kind: "cancel", offset: 1)], now: 601).first?.status, .cancelled)
        XCTAssertEqual(reduce([event(), event("cancel", kind: "cancel", offset: 601)], now: 602).first?.status, .expired)
    }
    func testRoomsReduceIndependentlyAndHistoryIsBounded() {
        let roomA = InvitationReducer.reduce([event()], roomID: "A", members: ["host", "guest"], currentUser: "guest", now: start.addingTimeInterval(10))
        let roomB = InvitationReducer.reduce([event(), event("reply", actor: "guest", kind: "accept", offset: 1)], roomID: "B", members: ["host", "guest"], currentUser: "guest", now: start.addingTimeInterval(10))
        XCTAssertEqual(roomA.first?.status, .pending)
        XCTAssertEqual(roomB.first?.status, .accepted)
        XCTAssertEqual(roomB.first?.roomID, "B")
        let events = (0..<120).map { index in
            InvitationEvent(id: "id-\(index)", invitationID: "id-\(index)", actor: "host", lastModifier: "host", kind: "invite", timestamp: start, expiry: start.addingTimeInterval(600), difficulty: "hard", senderName: "Host")
        }
        XCTAssertEqual(reduce(events).count, 100)
        XCTAssertTrue(reduce([event()], now: 30 * 86400 + 1).isEmpty)
    }
}
