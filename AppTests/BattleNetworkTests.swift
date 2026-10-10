import XCTest
import Combine
import SudokuCore
@testable import SudokuLisa

@MainActor
final class BattleNetworkTests: XCTestCase {
    private let battleID = UUID()
    private let initialRound = UUID()

    private func puzzle() -> Puzzle {
        let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
        var givens = solution
        givens[0] = 0; givens[40] = 0
        return Puzzle(givens: givens, solution: solution, difficulty: .easy, seed: 42)
    }

    private func packet(_ sequence: UInt64, _ message: BattleMessage, round: UUID? = nil) throws -> Data {
        try JSONEncoder().encode(BattleEnvelope(battleID: battleID, roundID: round ?? initialRound, sequence: sequence, message: message))
    }

    private func guest() throws -> (BattleService, ManualBattleClock, RecordingBattleTransport) {
        let clock = ManualBattleClock()
        let transport = RecordingBattleTransport(localPlayerID: "player", peers: [BattleParticipant(id: "host", name: "Host")])
        let service = BattleService(clock: clock)
        service.connect(transport: transport)
        try service.receive(packet(1, .hello(difficulty: .easy)), from: "host")
        try service.receive(packet(2, .pong(sent: 100, host: 100)), from: "host")
        return (service, clock, transport)
    }

    private func playingGuest() throws -> (BattleService, ManualBattleClock, RecordingBattleTransport) {
        let (service, clock, transport) = try guest()
        try service.receive(packet(3, .puzzle(puzzle())), from: "host")
        try service.receive(packet(4, .start(103)), from: "host")
        clock.advance(to: 103)
        XCTAssertEqual(service.state, .playing)
        return (service, clock, transport)
    }

    func testElapsedTicksOnlyPublishVisibleSecondsToTimer() throws {
        let (service, clock, transport) = try playingGuest()
        var serviceChanges = 0
        var visibleSeconds: [Int] = []
        let serviceSubscription = service.objectWillChange.sink { serviceChanges += 1 }
        let timerSubscription = service.elapsedClock.$seconds.dropFirst().sink { visibleSeconds.append($0) }
        let initialPackets = transport.packets.count

        clock.advance(to: 103.25)
        XCTAssertEqual(service.elapsed, 0.25)
        XCTAssertTrue(visibleSeconds.isEmpty)
        clock.advance(to: 103.5)
        clock.advance(to: 103.75)
        clock.advance(to: 104)
        XCTAssertEqual(service.elapsed, 1)
        XCTAssertEqual(visibleSeconds, [1])
        XCTAssertEqual(serviceChanges, 0)
        XCTAssertEqual(transport.packets.count - initialPackets, 2, "Progress remains at two packets per second")
        XCTAssertTrue(service.canEdit)
        withExtendedLifetime((serviceSubscription, timerSubscription)) {}
        service.leave()
    }

    func testFinishKeepsFractionalElapsedTimeIndependentOfTimerDisplay() throws {
        let (service, clock, transport) = try playingGuest()
        clock.advance(to: 103.25)
        service.select(0); service.enter(1)
        service.select(40); service.enter(9)
        XCTAssertEqual(service.elapsedClock.seconds, 0)
        XCTAssertEqual(service.elapsed, 0.25)
        let finish = try XCTUnwrap(transport.packets.last { if case .finish = $0.message { return true }; return false })
        guard case .finish(_, let seconds) = finish.message else { return XCTFail("Expected finish packet") }
        XCTAssertEqual(seconds, 0.25)
        clock.advance(to: 104)
        XCTAssertEqual(service.elapsed, 0.25, "Completed timer freezes at the exact finish time")
        service.leave()
    }

    func testCountdownOnlyPublishesChangedSecondsAndStillStartsOnTime() throws {
        let (service, clock, _) = try guest()
        try service.receive(packet(3, .puzzle(puzzle())), from: "host")
        try service.receive(packet(4, .start(103)), from: "host")
        var values: [Int] = []
        let subscription = service.$countdown.dropFirst().sink { values.append($0) }
        clock.advance(to: 100.25)
        clock.advance(to: 100.5)
        clock.advance(to: 100.75)
        XCTAssertTrue(values.isEmpty)
        XCTAssertFalse(service.canEdit)
        clock.advance(to: 101)
        clock.advance(to: 101.25)
        clock.advance(to: 102)
        clock.advance(to: 103)
        XCTAssertEqual(values, [2, 1, 0])
        XCTAssertEqual(service.state, .playing)
        XCTAssertTrue(service.canEdit)
        withExtendedLifetime(subscription) {}
        service.leave()
    }

    func testLobbyBackgroundReturnRestoresRemoteConnectionBeforeReady() throws {
        // A lobby that ignores active(true) permanently blocks the host's canStart.
        let clock = ManualBattleClock()
        let transport = RecordingBattleTransport(localPlayerID: "host", peers: [BattleParticipant(id: "peer", name: "Peer")])
        let service = BattleService(clock: clock)
        service.connect(transport: transport)
        let hello = try XCTUnwrap(transport.packets.first)
        func receive(_ sequence: UInt64, _ message: BattleMessage) throws {
            let envelope = BattleEnvelope(battleID: hello.battleID, roundID: hello.roundID, sequence: sequence, message: message)
            service.receive(try JSONEncoder().encode(envelope), from: "peer")
        }
        try receive(1, .active(false))
        XCTAssertEqual(service.participants.first { $0.id == "peer" }?.status, .interrupted)
        try receive(2, .active(true))
        try receive(3, .ready(true))
        service.setReady(true)
        XCTAssertEqual(service.participants.first { $0.id == "peer" }?.status, .connected)
        XCTAssertTrue(service.canStart)
        service.leave()
    }

    func testDelayedAndDuplicateControlPacketsSurviveNewerHeartbeat() throws {
        let (service, clock, transport) = try guest()
        try service.receive(packet(3, .puzzle(puzzle())), from: "host")
        try service.receive(packet(20, .heartbeat), from: "host")
        try service.receive(packet(4, .start(103)), from: "host")
        try service.receive(packet(4, .start(103)), from: "host")
        XCTAssertEqual(service.state, .countdown)
        XCTAssertEqual(transport.packets.filter { if case .startAcknowledged = $0.message { return true }; return false }.count, 1)
        clock.advance(to: 103)
        XCTAssertEqual(service.state, .playing)
        service.leave()
    }

    func testTooLateStartCancelsInsteadOfStartingOutOfSync() throws {
        let (service, clock, _) = try guest()
        try service.receive(packet(3, .puzzle(puzzle())), from: "host")
        clock.advance(to: 102)
        try service.receive(packet(4, .start(103)), from: "host")
        XCTAssertEqual(service.state, .cancelled)
        XCTAssertFalse(service.canEdit)
        service.leave()
    }

    func testLoadedGuestCancelsWhenHostNeverSchedulesStart() throws {
        let (service, clock, _) = try guest()
        try service.receive(packet(3, .puzzle(puzzle())), from: "host")
        clock.advance(to: 121)
        XCTAssertEqual(service.state, .cancelled)
        XCTAssertFalse(service.canEdit)
        service.leave()
    }

    func testBackgroundDuringCountdownCancelsBeforeGridBecomesEditable() throws {
        let (service, clock, transport) = try guest()
        try service.receive(packet(3, .puzzle(puzzle())), from: "host")
        try service.receive(packet(4, .start(103)), from: "host")
        service.setActive(false)
        clock.advance(to: 103)
        XCTAssertEqual(service.state, .cancelled)
        XCTAssertFalse(service.canEdit)
        XCTAssertTrue(transport.disconnected)
        service.leave()
    }

    func testHostSilenceInterruptsThenCancelsAfterThirtySeconds() throws {
        let (service, clock, transport) = try playingGuest()
        clock.advance(to: 109)
        XCTAssertEqual(service.participants.first { $0.id == "host" }?.status, .interrupted)
        clock.advance(to: 131)
        XCTAssertEqual(service.state, .cancelled)
        XCTAssertTrue(transport.disconnected)
        service.leave()
    }

    func testConnectionEventRestoresInterruptedPeerAndHostDisconnectCancels() throws {
        let (service, clock, _) = try playingGuest()
        clock.advance(to: 109)
        XCTAssertEqual(service.participants.first { $0.id == "host" }?.status, .interrupted)
        service.connectionChanged(playerID: "host", connected: true)
        XCTAssertEqual(service.participants.first { $0.id == "host" }?.status, .connected)
        service.connectionChanged(playerID: "host", connected: false)
        XCTAssertEqual(service.state, .cancelled)
        service.leave()
    }

    func testLobbyBackgroundBroadcastsActivityAndClearsReadiness() throws {
        let (service, _, transport) = try guest()
        service.setReady(true)
        service.setActive(false)
        XCTAssertEqual(service.participants.first { $0.id == "player" }?.ready, false)
        XCTAssertTrue(transport.packets.contains { if case .active(false) = $0.message { return true }; return false })
        service.setActive(true)
        XCTAssertTrue(transport.packets.contains { if case .active(true) = $0.message { return true }; return false })
        XCTAssertEqual(service.state, .lobby)
        service.leave()
    }

    func testBriefBackgroundSuspendsTicksAndResumesWithCurrentElapsedTime() throws {
        let (service, clock, transport) = try playingGuest()
        service.setActive(false)
        let count = transport.packets.count
        clock.advance(to: 110)
        XCTAssertEqual(transport.packets.count, count)
        XCTAssertEqual(service.elapsed, 0)
        service.setActive(true)
        try service.receive(packet(5, .heartbeat), from: "host")
        clock.advance(to: 111)
        XCTAssertEqual(service.state, .playing)
        XCTAssertEqual(service.elapsed, 8)
        XCTAssertTrue(service.canEdit)
        service.leave()
    }

    func testLongBackgroundForfeitsAndCannotResumeEditing() throws {
        let (service, clock, transport) = try playingGuest()
        service.setActive(false)
        clock.advance(to: 133)
        service.setActive(true)
        XCTAssertEqual(service.participants.first { $0.id == "player" }?.status, .didNotFinish)
        XCTAssertFalse(service.canEdit)
        XCTAssertTrue(transport.packets.contains { if case .forfeit = $0.message { return true }; return false })
        service.leave()
    }

    func testReorderedLiveProgressDoesNotRollBackOpponentAndUndoProgressCanDecrease() throws {
        let (service, _, _) = try playingGuest()
        try service.receive(packet(10, .progress(fraction: 0.75, mistakes: 3)), from: "host")
        try service.receive(packet(9, .progress(fraction: 0.25, mistakes: 2)), from: "host")
        XCTAssertEqual(service.participants.first { $0.id == "host" }?.progress, 0.75)
        try service.receive(packet(11, .progress(fraction: 0.5, mistakes: 3)), from: "host")
        XCTAssertEqual(service.participants.first { $0.id == "host" }?.progress, 0.5)
        service.leave()
    }

    func testRematchRejectsPreviousRoundResultsAndFinishesOncePerRound() throws {
        let (service, clock, _) = try playingGuest()
        var deliveries: [UUID] = []
        service.onRoundFinished = { round, _ in deliveries.append(round) }
        let results = [BattleResult(playerID: "player", name: "Guest", seconds: 2, status: .finished), BattleResult(playerID: "host", name: "Host", seconds: 3, status: .finished)]
        try service.receive(packet(5, .results(results)), from: "host")
        try service.receive(packet(5, .results(results)), from: "host")
        XCTAssertEqual(deliveries, [initialRound])
        let nextRound = UUID()
        try service.receive(packet(6, .lobby, round: nextRound), from: "host")
        XCTAssertEqual(service.state, .lobby)
        XCTAssertNil(service.session)
        XCTAssertTrue(service.results.isEmpty)
        try service.receive(packet(7, .results(results)), from: "host")
        try service.receive(packet(8, .start(106)), from: "host")
        XCTAssertEqual(service.state, .lobby)
        try service.receive(packet(9, .puzzle(puzzle()), round: nextRound), from: "host")
        try service.receive(packet(10, .start(106), round: nextRound), from: "host")
        clock.advance(to: 106)
        try service.receive(packet(11, .results(results), round: nextRound), from: "host")
        XCTAssertEqual(service.state, .finished)
        XCTAssertEqual(service.roundID, nextRound)
        XCTAssertEqual(deliveries, [initialRound, nextRound])
        service.leave()
    }

    func testFinishRetriesUntilHostAcknowledgesWithoutFinalizingGuestEarly() throws {
        let (service, clock, transport) = try playingGuest()
        service.select(0); service.enter(1)
        service.select(40); service.enter(9)
        XCTAssertEqual(service.session?.isComplete, true)
        XCTAssertFalse(service.canEdit)
        XCTAssertEqual(service.state, .playing)
        func finishes() -> [BattleEnvelope] {
            transport.packets.filter { if case .finish = $0.message { return true }; return false }
        }
        XCTAssertEqual(finishes().count, 1)
        clock.advance(to: 104)
        XCTAssertEqual(finishes().count, 2)
        let result = BattleResult(playerID: "player", name: "Guest", seconds: 0, status: .finished)
        try service.receive(packet(5, .finishAccepted(result)), from: "host")
        clock.advance(to: 105)
        XCTAssertEqual(finishes().count, 2)
        XCTAssertEqual(service.state, .playing)
        XCTAssertEqual(service.results.count, 1)
        service.leave()
    }

    func testSendFailureCancelsWithoutLeavingEditableSession() throws {
        let (service, _, transport) = try playingGuest()
        transport.failSends = true
        service.setActive(false)
        XCTAssertEqual(service.state, .cancelled)
        XCTAssertFalse(service.canEdit)
        XCTAssertTrue(transport.disconnected)
        service.leave()
    }
}

@MainActor
private final class ManualBattleClock: BattleClock {
    var now: Double = 100
    private var ticks: [UUID: @MainActor () -> Void] = [:]
    func startTicks(_ tick: @escaping @MainActor () -> Void) -> () -> Void {
        let id = UUID()
        ticks[id] = tick
        return { [weak self] in self?.ticks[id] = nil }
    }
    func advance(to value: Double) {
        precondition(value >= now)
        now = value
        for tick in Array(ticks.values) { tick() }
    }
}

@MainActor
private final class RecordingBattleTransport: BattleTransport {
    let localPlayerID: String
    let localPlayerName = "Guest"
    let peers: [BattleParticipant]
    var packets: [BattleEnvelope] = []
    var disconnected = false
    var failSends = false
    init(localPlayerID: String, peers: [BattleParticipant]) { self.localPlayerID = localPlayerID; self.peers = peers }
    func send(_ data: Data, reliably: Bool, to playerID: String?) throws {
        if failSends { throw BattleProtocolError.invalidPacket }
        packets.append(try BattleEnvelope.decode(data))
    }
    func disconnect() { disconnected = true }
}
