import XCTest
import Combine
import SudokuCore
@testable import SudokuLisa

@MainActor
final class HintCoachTests: XCTestCase {
    private func game() -> GameSession {
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var givens = solution
        givens[0] = 0
        givens[40] = 0
        return GameSession(puzzle: Puzzle(givens: givens, solution: solution, difficulty: .quick, seed: 1))
    }

    func testRequestPublishesCandidatesAndRejectsChangedBoard() async throws {
        let coach = HintCoachModel()
        var session = game()
        coach.request(session)
        for _ in 0..<100 where coach.isWorking { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(coach.isWorking)
        XCTAssertNotNil(coach.hint)
        XCTAssertEqual(coach.candidates.count, 81)
        XCTAssertEqual(coach.candidates[0], [1])
        XCTAssertTrue(coach.matches(session))
        session.elapsedSeconds = 25
        session.toggleNote(1, at: 0)
        XCTAssertTrue(coach.matches(session), "Clock and handwritten notes do not invalidate a logical deduction")
        _ = session.enter(1, at: 0)
        XCTAssertFalse(coach.matches(session), "A result for an earlier board must never apply to an edited one")
    }

    func testCancellationDoesNotPublishObsoleteHint() async throws {
        let coach = HintCoachModel()
        coach.request(game())
        coach.cancel()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(coach.isWorking)
        XCTAssertNil(coach.hint)
        XCTAssertTrue(coach.candidates.isEmpty)
        XCTAssertFalse(coach.matches(game()))
    }

    func testLatestRequestOwnsPublishedResult() async throws {
        let coach = HintCoachModel()
        let first = game()
        var second = first
        _ = second.enter(1, at: 0)
        coach.request(first)
        coach.request(second)
        for _ in 0..<100 where coach.isWorking { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(coach.hint?.index, 40)
        XCTAssertTrue(coach.matches(second))
        XCTAssertFalse(coach.matches(first))
    }
    func testPeriodicSnapshotDoesNotInvalidateWholeStore() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LisaStore(saveURL: directory.appendingPathComponent("save.json"))
        store.session = game()
        var invalidations = 0
        let subscription = store.objectWillChange.sink { invalidations += 1 }
        for _ in 0..<5 { store.tick() }
        XCTAssertEqual(store.clock.seconds, 5)
        XCTAssertEqual(invalidations, 0, "The dedicated clock updates; saving a snapshot must not redraw 81 cells")
        await store.flushPendingSaves()
        withExtendedLifetime(subscription) {}
    }

}
