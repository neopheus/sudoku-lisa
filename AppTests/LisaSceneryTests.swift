import XCTest
import SudokuCore
import AVFoundation
@testable import SudokuLisa

final class LisaSceneryTests: XCTestCase {
    private func url() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("save.json")
    }
    private static func puzzle(_ difficulty: Difficulty, _ seed: UInt64) -> Puzzle {
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        return Puzzle(givens: Array(repeating: 0, count: 81), solution: solution, difficulty: difficulty, seed: seed)
    }
    @MainActor private func wait(_ store: LisaStore) async throws {
        for _ in 0..<200 {
            if !store.isGenerating { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Generation did not finish")
    }
    @MainActor func testFreeStopAndPreviewSurviveRelaunchWithNotesAndUndo() async throws {
        let path = try url()
        let store = LisaStore(saveURL: path, generator: Self.puzzle)
        let preview = store.nextScenery
        store.start(.easy, seedOverride: 42)
        try await wait(store)
        XCTAssertEqual(store.activeScenery, preview)
        store.finishIntroduction()
        store.session?.toggleNote(7, at: 0)
        store.clock.seconds = 17
        store.save(); await store.flushPendingSaves()
        let restored = LisaStore(saveURL: path, generator: Self.puzzle)
        XCTAssertEqual(restored.activeScenery, store.activeScenery)
        XCTAssertEqual(restored.nextScenery, store.nextScenery)
        XCTAssertNil(restored.introductionID)
        XCTAssertEqual(restored.clock.seconds, 17)
        XCTAssertEqual(restored.session?.notes[0], [7])
        restored.session?.undo()
        XCTAssertEqual(restored.session?.notes[0], [])
        XCTAssertTrue(restored.resumeLastGame())
        XCTAssertNil(restored.introductionID)
        let next = restored.nextScenery
        restored.start(.easy, seedOverride: 42) // Even an identical puzzle is a new game.
        try await wait(restored)
        XCTAssertEqual(restored.activeScenery, next)
        XCTAssertNotEqual(restored.activeScenery?.world, store.activeScenery?.world)
        await restored.flushPendingSaves()
    }
    @MainActor func testIntroductionTimerSkipStaleCompletionAndBackground() async throws {
        let store = LisaStore(saveURL: try url(), generator: Self.puzzle)
        store.start(.easy); try await wait(store)
        let first = store.introductionID
        if !UIAccessibility.isReduceMotionEnabled {
            XCTAssertNotNil(first)
            store.tick(); XCTAssertEqual(store.clock.seconds, 0)
        }
        store.finishIntroduction(first)
        store.tick(); XCTAssertEqual(store.clock.seconds, 1)
        store.start(.easy); try await wait(store)
        let second = store.introductionID
        if let first { store.finishIntroduction(first); XCTAssertEqual(store.introductionID, second) }
        store.sceneActivityChanged(isActive: false)
        XCTAssertNil(store.introductionID)
        store.tick(); XCTAssertEqual(store.clock.seconds, 0)
        store.sceneActivityChanged(isActive: true)
        store.tick(); XCTAssertEqual(store.clock.seconds, 1)
        await store.flushPendingSaves()
    }
    @MainActor func testAllJourneyStopsAndRewardsRemainIdempotent() async throws {
        let store = LisaStore(saveURL: try url(), generator: Self.puzzle)
        for stage in 1...25 {
            store.startJourney(); try await wait(store)
            XCTAssertEqual(store.activeScenery, .journey(stage: stage))
            store.finishIntroduction()
            for index in 0..<81 { store.session?.enter(Self.puzzle(.easy, 0).solution[index], at: index) }
            store.changed(); store.changed()
            XCTAssertEqual(store.eventWins, stage)
            XCTAssertEqual(store.history.count, stage)
            XCTAssertEqual(store.activeScenery, .journey(stage: stage), "Winning must not replace the current scenery")
            XCTAssertEqual(store.nextScenery, .journey(stage: stage + 1))
        }
        store.continueAfterVictory()
        XCTAssertFalse(store.showGame)
        XCTAssertEqual(store.history.count, 25)
        await store.flushPendingSaves()
    }
    @MainActor func testLegacyMigrationStableAndDoesNotRewriteOriginal() async throws {
        for mode in ["Voyage", "Libre"] {
            let path = try url()
            var game = GameSession(puzzle: Self.puzzle(.easy, 42))
            game.toggleNote(3, at: 4)
            let session = try JSONSerialization.jsonObject(with: JSONEncoder().encode(game))
            let bytes = try JSONSerialization.data(withJSONObject: ["session": session,
                "settings": ["music": true, "musicTrack": "fishbowl-acrobatics"],
                "history": [], "completedDays": [], "eventWins": 7, "mode": mode])
            try bytes.write(to: path)
            let store = LisaStore(saveURL: path)
            await store.flushPendingSaves()
            XCTAssertEqual(try Data(contentsOf: path), bytes)
            XCTAssertEqual(store.activeScenery, mode == "Voyage" ? .journey(stage: 8) : .legacyFree(seed: 42))
            XCTAssertEqual(store.settings.musicTrack, "fishbowl-acrobatics")
            XCTAssertTrue(store.settings.music)
            XCTAssertNil(store.introductionID)
            store.save(); await store.flushPendingSaves()
            let reopened = LisaStore(saveURL: path)
            XCTAssertEqual(reopened.activeScenery, store.activeScenery)
            XCTAssertEqual(reopened.session?.notes[4], [3])
            reopened.session?.undo(); XCTAssertEqual(reopened.session?.notes[4], [])
        }
    }
    @MainActor func testDisabledDecorPaperAndOtherModesBypassIntroduction() async throws {
        let store = LisaStore(saveURL: try url(), generator: Self.puzzle)
        store.settings.animatedDecor = false
        store.start(.easy); try await wait(store); XCTAssertNil(store.introductionID)
        store.settings.animatedDecor = true; store.settings.paperMode = true
        store.startJourney(); try await wait(store); XCTAssertNil(store.introductionID)
        store.settings.paperMode = false
        let freePreview = store.savedGame(mode: "Libre")?.scenery
        for mode in ["Quotidien", "Tournoi", "Événement"] {
            store.start(.easy, mode: mode); try await wait(store)
            XCTAssertNil(store.activeScenery); XCTAssertNil(store.introductionID); XCTAssertNil(store.nextScenery)
        }
        XCTAssertTrue(store.resume(mode: "Libre"))
        XCTAssertEqual(store.activeScenery, freePreview)
        await store.flushPendingSaves()
    }
    @MainActor func testFailedGenerationDoesNotConsumePreview() async throws {
        let store = LisaStore(saveURL: try url(), generator: { _, _ in throw CancellationError() })
        let next = store.nextScenery
        store.start(.easy); try await wait(store)
        XCTAssertEqual(store.nextScenery, next)
        XCTAssertNil(store.activeScenery)
        XCTAssertNil(store.introductionID)
        await store.flushPendingSaves()
    }
    func testMusicDefaultsMigrationAndEveryBundledLoop() throws {
        XCTAssertEqual(LisaSettings().musicTrack, "automatic")
        XCTAssertFalse(LisaSettings().music)
        let old = try JSONDecoder().decode(LisaSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(old.musicTrack, "marimba-puzzle")
        for world in SceneryWorld.allCases {
            let resource = LisaMusicTrack.automatic.resource(world: world)
            let url = try XCTUnwrap(Bundle.main.url(forResource: resource.name, withExtension: resource.extension))
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertGreaterThan(player.duration, 40)
            XCTAssertLessThan(player.duration, 120)
            XCTAssertEqual(LisaMusicTrack.marimbaPuzzle.resource(world: world).name, "lisa-music-marimba-puzzle")
        }
    }
    @MainActor func testInvalidSceneryContextPreservesUnreadableSave() async throws {
        for invalidRoute in [false, true] {
            let path = try url()
            let store = LisaStore(saveURL: path, generator: Self.puzzle)
            store.start(.easy); try await wait(store)
            store.save(); await store.flushPendingSaves()
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
            if invalidRoute {
                json["freeSceneryRoute"] = ["remaining": [], "visits": [0, 0, 0, 0, 0]]
            } else {
                var games = try XCTUnwrap(json["savedGames"] as? [String: [String: Any]])
                games["Libre"]?["sceneryID"] = "missing-world-42"
                json["savedGames"] = games
            }
            let original = try JSONSerialization.data(withJSONObject: json)
            try original.write(to: path)
            let restored = LisaStore(saveURL: path)
            XCTAssertTrue(restored.needsSaveRecovery)
            restored.settings.music = true; restored.save()
            await restored.flushPendingSaves()
            XCTAssertEqual(try Data(contentsOf: path), original)
        }
    }

}
