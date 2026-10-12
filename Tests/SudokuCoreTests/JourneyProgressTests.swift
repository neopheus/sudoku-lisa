import XCTest
@testable import SudokuCore

final class JourneyProgressTests: XCTestCase {
    func testEveryCompletedStageAwardsExactlyItsOwnSouvenir() {
        for wins in 0...25 {
            let progress = JourneyProgress(completed: wins)
            XCTAssertEqual(progress.souvenirs.count, wins)
            XCTAssertEqual(Set(progress.souvenirs).count, wins)
            XCTAssertEqual(progress.latest, SceneryStop.journey(stage: wins))
            XCTAssertEqual(progress.next, SceneryStop.journey(stage: wins + 1))
            XCTAssertEqual(progress.completedWorlds, wins / 5)
        }
    }

    func testFirstStopIsExpressThenExistingWorldDifficultyCurveIsPreserved() {
        XCTAssertEqual(JourneyProgress(completed: 0).nextDifficulty, .quick)
        for (wins, difficulty) in [(1, Difficulty.easy), (4, .easy), (5, .easy), (10, .medium), (15, .hard), (20, .expert)] {
            XCTAssertEqual(JourneyProgress(completed: wins).nextDifficulty, difficulty)
        }
    }

    func testWorldBoundariesAndLegacyOutOfRangeProgress() {
        XCTAssertEqual(JourneyProgress(completed: -4).souvenirs, [])
        XCTAssertEqual(JourneyProgress(completed: 99).souvenirs.count, 25)
        XCTAssertNil(JourneyProgress(completed: 99).next)
        XCTAssertEqual(JourneyProgress(completed: 4).stepsToNextWorld, 1)
        XCTAssertEqual(JourneyProgress(completed: 5).stepsToNextWorld, 5)
        XCTAssertEqual(JourneyProgress(completed: 25).stepsToNextWorld, 0)
    }
}
