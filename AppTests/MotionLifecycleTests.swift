import XCTest
import SwiftUI
import Combine
@testable import SudokuLisa

@MainActor
final class MotionLifecycleTests: XCTestCase {
    func testDecorClockResumesAfterCoverageBackgroundAndSettings() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("save.json")
        let store = LisaStore(saveURL: url)
        store.settings.animatedDecor = true
        let probe = ClockProbe()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: ClockProbeView(probe: probe).environmentObject(store))
        window.rootViewController = host
        window.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }

        func moving() async throws {
            let count = probe.frames
            for _ in 0..<60 where probe.frames < count + 3 { try await Task.sleep(for: .milliseconds(25)) }
            XCTAssertGreaterThanOrEqual(probe.frames, count + 3, "Visible animation must resume")
            XCTAssertGreaterThan(probe.time, 0)
        }
        func stopped() async throws {
            for _ in 0..<40 where probe.time != 0 { try await Task.sleep(for: .milliseconds(25)) }
            XCTAssertEqual(probe.time, 0)
            let count = probe.frames
            try await Task.sleep(for: .milliseconds(150))
            XCTAssertEqual(probe.frames, count, "Suspended decor must not keep ticking")
        }
        try await moving()
        probe.allowed = false
        try await stopped()
        probe.allowed = true
        try await moving()
        probe.phase = .background
        try await stopped()
        probe.phase = .active
        try await moving()
        store.settings.animatedDecor = false
        try await stopped()
        store.settings.animatedDecor = true
        try await moving()
        await store.flushPendingSaves()
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testPoulpiRendererResumesAfterRemovalAndPause() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let host = UIViewController()
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        let renderer = OctopusRenderView()
        host.view.addSubview(renderer)
        renderer.configure(mood: .idle, reaction: 0, animated: true)
        XCTAssertTrue(renderer.rendersContinuously)
        renderer.removeFromSuperview()
        XCTAssertFalse(renderer.rendersContinuously)
        host.view.addSubview(renderer)
        XCTAssertTrue(renderer.rendersContinuously)
        renderer.setPlayback(paused: true, speed: 1)
        XCTAssertFalse(renderer.rendersContinuously)
        renderer.setPlayback(paused: false, speed: 1)
        XCTAssertTrue(renderer.rendersContinuously)
        renderer.configure(mood: .idle, reaction: 0, animated: false)
        XCTAssertFalse(renderer.rendersContinuously)
        renderer.configure(mood: .idle, reaction: 0, animated: true)
        XCTAssertTrue(renderer.rendersContinuously)
    }
}

@MainActor
private final class ClockProbe: ObservableObject {
    @Published var allowed = true
    @Published var phase = ScenePhase.active
    var frames = 0
    var time = 0.0
}
private struct ClockProbeView: View {
    @ObservedObject var probe: ClockProbe
    var body: some View {
        LisaMotionClock(fps: 30) { time in
            Color.pink.onChange(of: time, initial: true) { _, value in
                probe.time = value
                probe.frames += 1
            }
        }
        .environment(\.lisaMotionAllowed, probe.allowed)
        .environment(\.scenePhase, probe.phase)
    }
}
