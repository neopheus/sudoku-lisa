import XCTest
import SudokuCore
@testable import SudokuLisa

final class FirstJourneyTests: XCTestCase {
    private func url() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("save.json")
    }

    private static func puzzle(_ difficulty: Difficulty, _ seed: UInt64) -> Puzzle {
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var givens = solution
        for index in [0, 40, 80] { givens[index] = 0 }
        return Puzzle(givens: givens, solution: solution, difficulty: difficulty, seed: seed)
    }

    @MainActor private func wait(_ store: LisaStore) async throws {
        for _ in 0..<200 {
            if !store.isGenerating { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Generation timed out")
    }

    @MainActor func testFirstJourneyResumesExactlyAndAwardsOneSouvenir() async throws {
        let path = try url()
        let store = LisaStore(saveURL: path, generator: Self.puzzle)
        store.settings.sound = false
        store.settings.haptics = false
        store.recordStudyLaunch()
        store.startRecommendedJourney()
        store.startRecommendedJourney() // Double taps must not queue a second puzzle.
        try await wait(store)
        XCTAssertEqual(store.session?.puzzle.difficulty, .quick)
        XCTAssertEqual(store.playStudy.snapshot.count(.gameStarted), 1)
        XCTAssertEqual(store.playStudy.snapshot.count(.firstJourneySelected), 1)
        XCTAssertFalse(store.playStudy.snapshot.existingPlayer)
        store.finishIntroduction()
        let originalID = store.currentGameID
        store.session?.toggleNote(3, at: 40)
        store.clock.seconds = 19
        store.save()
        await store.flushPendingSaves()

        let reopened = LisaStore(saveURL: path, generator: Self.puzzle)
        reopened.startRecommendedJourney()
        XCTAssertFalse(reopened.isGenerating)
        XCTAssertEqual(reopened.currentGameID, originalID)
        XCTAssertEqual(reopened.clock.seconds, 19)
        XCTAssertEqual(reopened.session?.notes[40], [3])
        XCTAssertNil(reopened.introductionID)
        reopened.session?.undo()
        XCTAssertEqual(reopened.session?.notes[40], [])
        for index in [0, 40, 80] { reopened.session?.enter(Self.puzzle(.quick, 1).solution[index], at: index) }
        reopened.recordFirstMove(); reopened.recordFirstMove()
        reopened.changed(); reopened.changed()
        XCTAssertEqual(reopened.journeyProgress.souvenirs, [SceneryStop.journey(stage: 1)!])
        XCTAssertEqual(reopened.playStudy.snapshot.count(.firstMove), 1)
        XCTAssertEqual(reopened.playStudy.snapshot.count(.gameCompleted), 1)
        await reopened.flushPendingSaves()
        let final = LisaStore(saveURL: path, generator: Self.puzzle)
        XCTAssertEqual(final.journeyProgress.souvenirs, reopened.journeyProgress.souvenirs)
        final.continueAfterVictory()
        try await wait(final)
        XCTAssertEqual(final.session?.puzzle.difficulty, .easy)
        XCTAssertEqual(final.activeScenery, SceneryStop.journey(stage: 2))
        await final.flushPendingSaves()
    }

    @MainActor func testFailedGenerationDoesNotCountAsStartedOrAwardSouvenir() async throws {
        let store = LisaStore(saveURL: try url(), generator: { _, _ in throw CancellationError() })
        store.startRecommendedJourney()
        try await wait(store)
        XCTAssertNotNil(store.generationError)
        XCTAssertNil(store.session)
        XCTAssertEqual(store.playStudy.snapshot.count(.gameStarted), 0)
        XCTAssertEqual(store.journeyProgress.souvenirs.count, 0)
        await store.flushPendingSaves()
    }

    @MainActor func testStudyExportExcludesIdentityAndResetPreservesGame() async throws {
        let store = LisaStore(saveURL: try url(), generator: Self.puzzle)
        store.start(.hard)
        try await wait(store)
        let original = store.session
        let originalID = store.currentGameID
        store.playStudy.enabled = false
        store.playStudy.record(.hintViewed)
        XCTAssertEqual(store.playStudy.snapshot.count(.hintViewed), 0)
        let exported = try await store.playStudy.export()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: exported)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["schemaVersion", "windowDays", "elapsedDays", "existingPlayer", "recordingEnabled", "recordingInterrupted", "appVersion", "appBuild", "days"])
        XCTAssertEqual(object["recordingInterrupted"] as? Bool, true)
        await store.playStudy.reset()
        XCTAssertFalse(FileManager.default.fileExists(atPath: exported.path))
        XCTAssertFalse(store.playStudy.enabled)
        XCTAssertEqual(store.playStudy.snapshot.count(.gameStarted), 0)
        XCTAssertEqual(store.currentGameID, originalID)
        XCTAssertEqual(store.session?.puzzle, original?.puzzle)
        await store.flushPendingSaves()
    }

    @MainActor func testUnreadableStudyCannotBlockGameOrBeOverwrittenAutomatically() async throws {
        let path = try url()
        let studyURL = path.appendingPathExtension("study.json")
        let bytes = Data("invalid report, preserve".utf8)
        try bytes.write(to: studyURL)
        let store = LisaStore(saveURL: path, generator: Self.puzzle)
        store.startRecommendedJourney()
        try await wait(store)
        XCTAssertNotNil(store.session)
        XCTAssertFalse(store.needsSaveRecovery)
        XCTAssertTrue(store.playStudy.storageUnavailable)
        await store.flushPendingSaves()
        XCTAssertEqual(try Data(contentsOf: studyURL), bytes)
        await store.playStudy.reset()
        XCTAssertFalse(store.playStudy.storageUnavailable)
        XCTAssertNoThrow(try JSONDecoder().decode(PlayStudy.self, from: Data(contentsOf: studyURL)))
    }
}
