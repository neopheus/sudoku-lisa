import XCTest
import SudokuCore
@testable import SudokuLisa

@MainActor
final class LogicalAssistanceTests: XCTestCase {
    private func game() -> GameSession {
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var givens = solution
        givens[0] = 0; givens[40] = 0
        return GameSession(puzzle: Puzzle(givens: givens, solution: solution, difficulty: .quick, seed: 1))
    }
    private func wait(_ model: LogicalAssistanceModel) async throws {
        for _ in 0..<200 where model.isWorking { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(model.isWorking)
    }
    func testRapidEditsAndNewGameIdentity() async throws {
        let model = LogicalAssistanceModel()
        model.trailEnabled = true
        var session = game()
        let firstID = UUID(), secondID = UUID()
        model.request(session, id: firstID)
        _ = session.enter(1, at: 0)
        model.request(session, id: firstID)
        model.request(session, id: secondID)
        try await wait(model)
        XCTAssertTrue(model.matches(session, id: secondID))
        XCTAssertFalse(model.matches(session, id: firstID))
        XCTAssertEqual(model.snapshot?.deduction?.action, .placement(index: 40, value: session.puzzle.solution[40]))
        session.elapsedSeconds = 100
        session.toggleNote(9, at: 40)
        XCTAssertTrue(model.matches(session, id: secondID))
    }
    func testPauseCancelResumeAndHide() async throws {
        let model = LogicalAssistanceModel()
        let session = game(), id = UUID()
        model.candidatesEnabled = true
        model.trailEnabled = true
        model.focusDigit = 1
        model.request(session, id: id)
        model.cancel()
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertNil(model.snapshot)
        XCTAssertTrue(model.isActive)
        model.request(session, id: id)
        try await wait(model)
        XCTAssertTrue(model.matches(session, id: id))
        let deduction = try XCTUnwrap(model.snapshot?.deduction)
        let coach = HintCoachModel()
        coach.present(deduction, game: session, candidates: model.snapshot!.candidates)
        XCTAssertEqual(coach.hint?.deduction, deduction)
        let firstPresentation = coach.presentationID
        coach.present(deduction, game: session, candidates: model.snapshot!.candidates)
        XCTAssertNotEqual(firstPresentation, coach.presentationID)
        model.hide()
        XCTAssertFalse(model.isActive)
        XCTAssertNil(model.snapshot)
    }
    func testSavedContextsKeepAssistanceIndependent() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("save.json")
        let puzzle = game().puzzle
        let store = LisaStore(saveURL: url, generator: { _, _ in puzzle })
        store.start(.quick, mode: "Libre", seedOverride: 1)
        for _ in 0..<200 where store.isGenerating { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(store.isGenerating)
        store.session?.recordLogicalAssistance()
        store.session?.toggleNote(8, at: 0)
        store.session?.fillEmptyNotes()
        store.changed()
        store.start(.quick, mode: "Voyage", seedOverride: 2)
        for _ in 0..<200 where store.isGenerating { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(store.isGenerating)
        XCTAssertFalse(try XCTUnwrap(store.session).usedLogicalAssistance)
        store.save()
        await store.flushPendingSaves()
        let reopened = LisaStore(saveURL: url)
        XCTAssertFalse(try XCTUnwrap(reopened.session).usedLogicalAssistance)
        XCTAssertTrue(reopened.resume(mode: "Libre"))
        XCTAssertTrue(try XCTUnwrap(reopened.session).usedLogicalAssistance)
        XCTAssertEqual(reopened.session?.notes[0], [8])
        reopened.session?.undo()
        XCTAssertEqual(reopened.session?.notes[40], [])
        XCTAssertTrue(try XCTUnwrap(reopened.session).usedLogicalAssistance)
        XCTAssertTrue(reopened.resume(mode: "Voyage"))
        XCTAssertFalse(try XCTUnwrap(reopened.session).usedLogicalAssistance)
        await reopened.flushPendingSaves()
    }

    func testHistoryMigrationAndAssistedRoundTrip() throws {
        let record = FinishedGame(date: Date(), difficulty: .quick, seconds: 20, mistakes: 0, hints: 0, mode: "Voyage", usedLogicalAssistance: true)
        let data = try JSONEncoder().encode(record)
        XCTAssertTrue(try JSONDecoder().decode(FinishedGame.self, from: data).usedLogicalAssistance)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "usedLogicalAssistance")
        let legacy = try JSONDecoder().decode(FinishedGame.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(legacy.usedLogicalAssistance)
    }
}
