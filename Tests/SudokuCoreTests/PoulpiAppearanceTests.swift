import XCTest
@testable import SudokuCore

final class PoulpiAppearanceTests: XCTestCase {
    func testSixFreeColorsAndExclusiveAccessoryRoundTrip() throws {
        XCTAssertEqual(PoulpiColor.allCases.count, 6)
        for color in PoulpiColor.allCases {
            for accessory in PoulpiAccessory.allCases {
                let appearance = PoulpiAppearance(color: color, accessory: accessory)
                XCTAssertEqual(try JSONDecoder().decode(PoulpiAppearance.self, from: JSONEncoder().encode(appearance)), appearance)
            }
        }
    }

    func testUnlockThresholdsAndRoundReceiptsAreIdempotent() {
        var rewards = PoulpiBattleRewards()
        XCTAssertTrue(rewards.isUnlocked(.none, journeyWins: 0))
        XCTAssertFalse(rewards.isUnlocked(.star, journeyWins: 4))
        XCTAssertTrue(rewards.isUnlocked(.star, journeyWins: 5))
        XCTAssertFalse(rewards.isUnlocked(.headband, journeyWins: 5))
        let first = UUID()
        XCTAssertTrue(rewards.record(roundID: first, won: false))
        XCTAssertTrue(rewards.isUnlocked(.headband, journeyWins: 0))
        XCTAssertFalse(rewards.record(roundID: first, won: true))
        XCTAssertEqual(rewards.wins, 0, "A duplicate completion cannot upgrade a loss to a win")
        for _ in 0..<4 { rewards.record(roundID: UUID(), won: true) }
        XCTAssertFalse(rewards.isUnlocked(.crown, journeyWins: 25))
        rewards.record(roundID: UUID(), won: true)
        XCTAssertTrue(rewards.isUnlocked(.crown, journeyWins: 0))
    }

    func testReceiptsStayBoundedAndTotalsSurviveRelaunch() throws {
        var rewards = PoulpiBattleRewards()
        let count = PoulpiBattleRewards.receiptLimit + 10
        for _ in 0..<count { rewards.record(roundID: UUID(), won: true) }
        let reopened = try JSONDecoder().decode(PoulpiBattleRewards.self, from: JSONEncoder().encode(rewards))
        XCTAssertEqual(reopened.finishedRounds, count)
        XCTAssertEqual(reopened.wins, count)
        XCTAssertEqual(reopened.recentRoundIDs.count, PoulpiBattleRewards.receiptLimit)
        var retried = reopened
        XCTAssertFalse(retried.record(roundID: reopened.recentRoundIDs.last!, won: true))
    }

    func testInvalidRewardDataIsRejected() {
        for json in [
            "{\"finishedRounds\":-1,\"wins\":0,\"recentRoundIDs\":[]}",
            "{\"finishedRounds\":1,\"wins\":2,\"recentRoundIDs\":[]}",
            "{\"finishedRounds\":0,\"wins\":0,\"recentRoundIDs\":[\"00000000-0000-0000-0000-000000000001\"]}"
        ] {
            XCTAssertThrowsError(try JSONDecoder().decode(PoulpiBattleRewards.self, from: Data(json.utf8)))
        }
    }
}
