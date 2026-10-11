import XCTest
import SudokuCore
@testable import SudokuLisa

@MainActor final class LisaWatchBridgeTests: XCTestCase {
    private final class Transport: LisaWatchTransport {
        var available = true
        var reachable = true
        var failEnqueue = false
        var queued: [[String: Any]] = []
        var immediate: [[String: Any]] = []
        func enqueue(_ context: [String: Any]) throws {
            if failEnqueue { throw NSError(domain: "WatchTest", code: 1) }
            queued.append(context)
        }
        func sendImmediately(_ context: [String: Any]) { immediate.append(context) }
    }

    func testColorOnlyChangeUsesLiveAndBackgroundChannels() throws {
        let transport = Transport(), appearance = PoulpiAppearance(color: .gold, accessory: .star)
        let bridge = LisaWatchBridge(transport: transport)
        bridge.update(completedGames: 2, streak: 1, appearance: .init())
        bridge.update(completedGames: 2, streak: 1, appearance: appearance)
        XCTAssertEqual(transport.queued.count, 2)
        XCTAssertEqual(transport.immediate.count, 2)
        XCTAssertEqual(try XCTUnwrap(WatchProgressSnapshot(context: transport.immediate.last!)).appearance, appearance)
    }

    func testUnchangedValueRetriesFailedBackgroundDelivery() {
        let transport = Transport()
        let sender = LisaWatchBridge(transport: transport)
        transport.failEnqueue = true
        transport.reachable = false
        sender.update(completedGames: 2, streak: 1, appearance: .init(color: .lagoon))
        XCTAssertTrue(transport.queued.isEmpty)
        transport.failEnqueue = false
        sender.update(completedGames: 2, streak: 1, appearance: .init(color: .lagoon))
        XCTAssertEqual(transport.queued.count, 1)
        XCTAssertTrue(transport.immediate.isEmpty)
    }

    func testDisconnectedChangesCoalesceAndResendLatestOnConnection() throws {
        let transport = Transport()
        transport.available = false
        let bridge = LisaWatchBridge(transport: transport)
        bridge.update(completedGames: 2, streak: 1, appearance: .init(color: .coral))
        bridge.update(completedGames: 2, streak: 1, appearance: .init(color: .mint))
        XCTAssertTrue(transport.queued.isEmpty)
        transport.available = true
        bridge.send()
        XCTAssertEqual(transport.queued.count, 1)
        XCTAssertEqual(try XCTUnwrap(WatchProgressSnapshot(context: transport.queued[0])).appearance.color, .mint)
        bridge.send() // Watch foreground request: unchanged data must still be sent.
        XCTAssertEqual(transport.immediate.count, 2)
    }

    func testLiveDeliveryStillRunsIfBackgroundEnqueueFails() {
        let transport = Transport()
        transport.failEnqueue = true
        let bridge = LisaWatchBridge(transport: transport)
        bridge.update(completedGames: 0, streak: 0, appearance: .init(color: .gold))
        XCTAssertEqual(transport.immediate.count, 1)
    }
}
