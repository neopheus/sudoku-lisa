import Foundation
import AVFoundation
import XCTest
@testable import SudokuLisa

private final class RecordingAudioSession: LisaAudioSession, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []
    var activationStarted: XCTestExpectation?
    var activationGate: DispatchSemaphore?
    var failNextActivation = false

    var events: [String] { lock.withLock { recorded } }
    var isOtherAudioPlaying: Bool { false }
    func configureCategory() throws { record("category") }
    func setActive(_ active: Bool) throws {
        record(active ? "activate" : "deactivate")
        if active {
            activationStarted?.fulfill()
            activationGate?.wait()
            if failNextActivation {
                failNextActivation = false
                throw NSError(domain: "LisaAudioTests", code: 1)
            }
        }
    }
    private func record(_ event: String) {
        XCTAssertFalse(Thread.isMainThread, "Session operations must never block the UI thread")
        lock.withLock { recorded.append(event) }
    }
}

final class LisaAudioTests: XCTestCase {
    @MainActor
    func testBackgroundRequestFollowsAnInFlightActivationWithoutReactivation() async {
        let session = RecordingAudioSession()
        let queue = DispatchQueue(label: "LisaAudioTests.order")
        let started = expectation(description: "Activation started off main thread")
        let gate = DispatchSemaphore(value: 0)
        session.activationStarted = started
        session.activationGate = gate
        let audio = LisaAudio(session: session, queue: queue, observesNotifications: false)

        audio.configure(active: true)
        await fulfillment(of: [started], timeout: 2)
        audio.configure(active: false)
        // The main actor remains responsive even while activation is blocked.
        gate.signal()
        let drained = expectation(description: "Queued lifecycle change applied")
        queue.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertEqual(session.events, ["category", "activate", "deactivate"])
    }

    @MainActor
    func testRepeatedConfigurationAvoidsActivationAndFailedActivationRetries() async {
        let session = RecordingAudioSession()
        session.failNextActivation = true
        let queue = DispatchQueue(label: "LisaAudioTests.retry")
        let audio = LisaAudio(session: session, queue: queue, observesNotifications: false)
        audio.configure(active: true)
        audio.configure(music: false)
        audio.configure(paused: true)
        audio.configure(active: false)
        let drained = expectation(description: "All session operations completed")
        queue.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertEqual(session.events, ["category", "activate", "activate", "deactivate"])
    }
    @MainActor func testAutomaticMusicRetainsPlayerAndBoundsRapidCrossfades() async throws {
        let audio = LisaAudio(session: RecordingAudioSession(), queue: DispatchQueue(label: "LisaAudioTests.worlds"), observesNotifications: false)
        audio.configure(active: true, music: true, musicTrack: .automatic, world: .garden)
        let garden = await audio.playbackSnapshot()
        XCTAssertNotNil(garden.player)
        XCTAssertEqual(garden.resource, "lisa-world-garden.m4a")
        audio.configure(musicTrack: .automatic, world: .garden)
        let sameWorld = await audio.playbackSnapshot()
        XCTAssertEqual(sameWorld.player, garden.player)
        XCTAssertEqual(sameWorld.outgoingPlayers, 0)
        audio.configure(musicTrack: .automatic, world: .lagoon)
        let lagoon = await audio.playbackSnapshot()
        XCTAssertNotEqual(lagoon.player, garden.player)
        XCTAssertEqual(lagoon.outgoingPlayers, 1)
        audio.configure(musicTrack: .automatic, world: .stars)
        let stars = await audio.playbackSnapshot()
        XCTAssertEqual(stars.resource, "lisa-world-stars.m4a")
        XCTAssertEqual(stars.outgoingPlayers, 1)
        audio.configure(active: false)
        let background = await audio.playbackSnapshot()
        XCTAssertFalse(background.playing)
        XCTAssertEqual(background.outgoingPlayers, 0)
        audio.configure(active: true)
        let resumed = await audio.playbackSnapshot()
        XCTAssertEqual(resumed.player, stars.player)
        audio.configure(music: false)
        let muted = await audio.playbackSnapshot()
        XCTAssertFalse(muted.playing)
    }

    @MainActor func testInterruptionDuringCrossfadeSilencesBothPlayers() async {
        let audio = LisaAudio(session: RecordingAudioSession(), queue: DispatchQueue(label: "LisaAudioTests.interruption"))
        audio.configure(active: true, music: true, musicTrack: .automatic, world: .garden)
        _ = await audio.playbackSnapshot()
        audio.configure(musicTrack: .automatic, world: .frost)
        _ = await audio.playbackSnapshot()
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: nil,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        let interrupted = await audio.playbackSnapshot()
        XCTAssertFalse(interrupted.playing)
        XCTAssertEqual(interrupted.outgoingPlayers, 0)
        audio.configure(active: false)
    }

}
