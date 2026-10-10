import XCTest
@testable import SudokuCore

final class BattleProtocolTests: XCTestCase {
    private func puzzle() -> Puzzle {
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var givens = solution; for cell in [0, 40, 80] { givens[cell] = 0 }
        return Puzzle(givens: givens, solution: solution, difficulty: .easy, seed: 1)
    }
    func testInterruptionGraceUsesMonotonicBoundaryAndRejectsInvalidClocks() {
        XCTAssertFalse(BattleValidation.interruptionExpired(since: 100, now: 129.999))
        XCTAssertTrue(BattleValidation.interruptionExpired(since: 100, now: 130))
        XCTAssertTrue(BattleValidation.interruptionExpired(since: 100, now: 131))
        XCTAssertFalse(BattleValidation.interruptionExpired(since: 100, now: 99))
        XCTAssertFalse(BattleValidation.interruptionExpired(since: .nan, now: 130))
    }
    func testHostElectionIndependentOfRosterOrder() {
        XCTAssertEqual(BattleValidation.hostID(in: ["z", "a", "b"]), "a")
        XCTAssertEqual(BattleValidation.hostID(in: ["b", "z", "a"]), "a")
        XCTAssertNil(BattleValidation.hostID(in: []))
    }
    func testPacketBoundsVersionAndRoundIdentityRoundTrip() throws {
        let battle = UUID(), round = UUID()
        let original = BattleEnvelope(battleID: battle, roundID: round, sequence: 19, message: .puzzle(puzzle()))
        let data = try JSONEncoder().encode(original)
        let decoded = try BattleEnvelope.decode(data)
        XCTAssertEqual(decoded.battleID, battle); XCTAssertEqual(decoded.roundID, round); XCTAssertEqual(decoded.sequence, 19)
        XCTAssertThrowsError(try BattleEnvelope.decode(Data(repeating: 32, count: BattleEnvelope.maximumBytes + 1)))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]); json["version"] = 999
        XCTAssertThrowsError(try BattleEnvelope.decode(JSONSerialization.data(withJSONObject: json)))
    }
    func testFinishRequiresActualSolutionAndPlausibleFiniteClock() {
        let grid = puzzle()
        XCTAssertTrue(BattleValidation.validFinish(values: grid.solution, puzzle: grid, claimedElapsed: 10, hostElapsed: 10.2))
        XCTAssertTrue(BattleValidation.validFinish(values: grid.solution, puzzle: grid, claimedElapsed: 2, hostElapsed: 10), "Delayed reliable finish receipts remain valid")
        XCTAssertFalse(BattleValidation.validFinish(values: grid.givens, puzzle: grid, claimedElapsed: 10, hostElapsed: 10))
        for seconds in [-1, Double.nan, .infinity, 30] {
            XCTAssertFalse(BattleValidation.validFinish(values: grid.solution, puzzle: grid, claimedElapsed: seconds, hostElapsed: 10))
        }
    }
    func testTieWindowDoesNotChainAndDNFHasNoRank() {
        let input = [10.0, 10.5, 10.8].enumerated().map { BattleResult(playerID: String($0.offset), name: "Player", seconds: $0.element, status: .finished) }
            + [BattleResult(playerID: "dnf", name: "Away", seconds: nil, status: .didNotFinish)]
        XCTAssertEqual(BattleValidation.ranked(input.reversed()).map(\.rank), [1, 1, 3, nil])
    }
    func testNoErrorEliminationAndUndoCanReduceProgress() {
        let puzzle = puzzle(); var game = GameSession(puzzle: puzzle)
        for index in 0..<6 { game.enter(index % 2 == 0 ? 9 : 8, at: 0) }
        XCTAssertEqual(game.mistakes, 6); XCTAssertTrue(game.isEditable(0))
        game.erase(at: 0); game.toggleNote(1, at: 0); game.undo(); XCTAssertTrue(game.notes[0].isEmpty)
        game.enter(puzzle.solution[0], at: 0); XCTAssertEqual(game.progress, 1.0 / 3)
        game.undo(); XCTAssertEqual(game.progress, 0)
    }
    func testRejectMalformedLiveProgress() {
        XCTAssertTrue(BattleValidation.validProgress(0.5, mistakes: 100))
        XCTAssertFalse(BattleValidation.validProgress(.nan, mistakes: 0)); XCTAssertFalse(BattleValidation.validProgress(1.1, mistakes: 0))
        XCTAssertFalse(BattleValidation.validProgress(0, mistakes: -1))
    }
}

extension BattleProtocolTests {
    func testControlPacketsSurviveNewerLivePacketsAndRejectSpoofedOrStaleRounds() {
        let battle = UUID(), round = UUID(), next = UUID()
        var ledger = BattleRoundLedger(battleID: battle, roundID: round, hostID: "host", playerIDs: ["host", "guest"])
        func packet(_ sequence: UInt64, _ message: BattleMessage, roundID: UUID? = nil) -> BattleEnvelope {
            BattleEnvelope(battleID: battle, roundID: roundID ?? round, sequence: sequence, message: message)
        }
        XCTAssertTrue(ledger.admit(packet(20, .heartbeat), sender: "host", mayAdoptHostRound: false))
        XCTAssertTrue(ledger.admit(packet(19, .start(100)), sender: "host", mayAdoptHostRound: false))
        XCTAssertFalse(ledger.admit(packet(19, .start(100)), sender: "host", mayAdoptHostRound: false))
        XCTAssertFalse(ledger.admit(packet(21, .ready(true)), sender: "stranger", mayAdoptHostRound: true))
        XCTAssertFalse(ledger.admit(packet(21, .lobby, roundID: next), sender: "guest", mayAdoptHostRound: true))
        XCTAssertTrue(ledger.admit(packet(21, .lobby, roundID: next), sender: "host", mayAdoptHostRound: true))
        XCTAssertFalse(ledger.admit(packet(22, .start(100)), sender: "host", mayAdoptHostRound: false))
    }
    func testAllLoadAndStartAcknowledgementsRequiredAndRematchResetsRoundState() {
        var ledger = BattleRoundLedger(battleID: UUID(), roundID: UUID(), hostID: "a", playerIDs: ["a", "b", "c"])
        ledger.markLoaded("a"); ledger.markLoaded("b"); ledger.markLoaded("stranger"); XCTAssertFalse(ledger.allLoaded)
        ledger.markLoaded("c"); XCTAssertTrue(ledger.allLoaded)
        XCTAssertTrue(ledger.canScheduleStart(active: true, connectedPlayerIDs: ["a", "b", "c"]))
        XCTAssertFalse(ledger.canScheduleStart(active: false, connectedPlayerIDs: ["a", "b", "c"]), "Prepared grid must not start after host goes inactive")
        XCTAssertFalse(ledger.canScheduleStart(active: true, connectedPlayerIDs: ["a", "b"]), "Prepared grid must not start while a guest is interrupted")
        ledger.acknowledgeStart("a"); ledger.acknowledgeStart("b"); XCTAssertFalse(ledger.allAcknowledged)
        ledger.acknowledgeStart("c"); XCTAssertTrue(ledger.allAcknowledged)
        ledger.beginRound(UUID()); XCTAssertFalse(ledger.allLoaded); XCTAssertFalse(ledger.allAcknowledged)
    }
    func testHostFinishingDoesNotFinalizeMatchAndResultsAreIdempotent() {
        var ledger = BattleRoundLedger(battleID: UUID(), roundID: UUID(), hostID: "host", playerIDs: ["host", "guest", "away"])
        let hostFinish = BattleResult(playerID: "host", name: "Host", seconds: 30, status: .finished)
        XCTAssertTrue(ledger.record(hostFinish)); XCTAssertNil(ledger.completedResult(for: "host")); XCTAssertFalse(ledger.isFinalized); XCTAssertFalse(ledger.record(hostFinish))
        XCTAssertFalse(ledger.record(BattleResult(playerID: "guest", name: "Guest", seconds: .infinity, status: .finished)))
        XCTAssertTrue(ledger.record(BattleResult(playerID: "guest", name: "Guest", seconds: 40, status: .finished)))
        XCTAssertFalse(ledger.isFinalized)
        XCTAssertTrue(ledger.record(BattleResult(playerID: "away", name: "Away", seconds: nil, status: .didNotFinish)))
        XCTAssertTrue(ledger.isFinalized)
        XCTAssertEqual(ledger.completedResult(for: "host")?.rank, 1)
        XCTAssertNil(ledger.completedResult(for: "away"), "Forfeit is never eligible for a completion reward")
        ledger.beginRound(UUID()); XCTAssertTrue(ledger.results.isEmpty); XCTAssertFalse(ledger.isFinalized); XCTAssertNil(ledger.completedResult(for: "host"))
    }
}


extension BattleProtocolTests {
    func testRematchRejectsDelayedLiveLaneAndPreservesNewRoundSequenceBudget() {
        let battle = UUID(), oldRound = UUID(), nextRound = UUID()
        var ledger = BattleRoundLedger(battleID: battle, roundID: oldRound, hostID: "host", playerIDs: ["host", "peer"])
        let lobby = BattleEnvelope(battleID: battle, roundID: nextRound, sequence: 2, message: .lobby)
        XCTAssertTrue(ledger.admit(lobby, sender: "host", mayAdoptHostRound: true))
        // A live sequence may exceed the latest control sequence, but cannot revive an old round.
        let delayed = BattleEnvelope(battleID: battle, roundID: oldRound, sequence: 500, message: .progress(fraction: 1, mistakes: 0))
        XCTAssertFalse(ledger.admit(delayed, sender: "host", mayAdoptHostRound: true))
        XCTAssertEqual(ledger.roundID, nextRound)
        let current = BattleEnvelope(battleID: battle, roundID: nextRound, sequence: 3, message: .progress(fraction: 0.1, mistakes: 0))
        XCTAssertTrue(ledger.admit(current, sender: "host", mayAdoptHostRound: false), "Rejected packets must not consume the current round's live sequence")
    }

    func testAdoptingRematchClearsResultsAndRequiresFreshLoadAcknowledgements() {
        let battle = UUID(), oldRound = UUID(), nextRound = UUID()
        var ledger = BattleRoundLedger(battleID: battle, roundID: oldRound, hostID: "host", playerIDs: ["host", "peer"])
        ledger.markLoaded("host"); ledger.markLoaded("peer")
        ledger.acknowledgeStart("host"); ledger.acknowledgeStart("peer")
        ledger.record(BattleResult(playerID: "host", name: "Host", seconds: 2, status: .finished))
        ledger.record(BattleResult(playerID: "peer", name: "Peer", seconds: 3, status: .finished))
        let lobby = BattleEnvelope(battleID: battle, roundID: nextRound, sequence: 10, message: .lobby)
        XCTAssertTrue(ledger.admit(lobby, sender: "host", mayAdoptHostRound: true))
        XCTAssertTrue(ledger.results.isEmpty)
        XCTAssertFalse(ledger.isFinalized)
        XCTAssertFalse(ledger.canScheduleStart(active: true, connectedPlayerIDs: ["host", "peer"]))
        XCTAssertFalse(ledger.allAcknowledged)
        let staleFinish = BattleEnvelope(battleID: battle, roundID: oldRound, sequence: 99, message: .finish(values: [], elapsed: 2))
        XCTAssertFalse(ledger.admit(staleFinish, sender: "peer", mayAdoptHostRound: true))
        XCTAssertEqual(ledger.roundID, nextRound)
    }
}
