import SwiftUI
import QuartzCore
import SudokuCore
import os

/// One shared main-thread cadence probe, active only while animated surfaces are visible.
/// This measures display-link scheduling pressure, not GPU render time.
@MainActor
final class LisaRenderBudget: ObservableObject {
    static let shared = LisaRenderBudget()
    @Published private(set) var level = 0
    @Published private(set) var frameRate = 60
    private var policy = AnimationBudget()
    private var clients: Set<UUID> = []
    private var link: CADisplayLink?
    private var observers: [NSObjectProtocol] = []
    private var lastTimestamp: CFTimeInterval = 0
    private var elapsed: Double = 0
    private var frames = 0
    private var late = 0
    private var foreground = true
    private var rendererPressure: Double = 0
    private let metricsEnabled = ProcessInfo.processInfo.environment["LISA_RENDER_METRICS"] == "1"
    private let logger = Logger(subsystem: "com.xavier.sudokulisa", category: "AnimationBudget")

    var particleCount: Int { [24, 14, 7][level] }
    func cadence(_ requested: Double) -> Double {
        if requested >= 60 { return Double(frameRate) }
        return min(requested, [30, 20, 12][level])
    }

    private init() {
        refresh()
        for name in [ProcessInfo.thermalStateDidChangeNotification, Notification.Name.NSProcessInfoPowerStateDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.foreground = false; self?.updatePlayback() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.foreground = true; self?.updatePlayback() }
        })
    }

    func setActive(_ active: Bool, client: UUID) {
        if active { clients.insert(client) } else { clients.remove(client) }
        updatePlayback()
    }

    private func updatePlayback() {
        if foreground && !clients.isEmpty {
            guard link == nil else { return }
            let probe = DisplayProbe(owner: self)
            let newLink = CADisplayLink(target: probe, selector: #selector(DisplayProbe.tick(_:)))
            link = newLink
            refresh()
            newLink.add(to: .main, forMode: .common)
        } else {
            link?.invalidate(); link = nil
            resetWindow()
        }
    }

    func renderedWindow(client: UUID, fps: Double, lateFraction: Double) {
        guard foreground, clients.contains(client) else { return }
        rendererPressure = max(rendererPressure, lateFraction)
        if metricsEnabled {
        logger.info("SceneKit delivered \(fps, format: .fixed(precision: 1)) fps; late \(lateFraction, format: .fixed(precision: 2))")
        }
    }

    private func resetWindow() {
        lastTimestamp = 0; elapsed = 0; frames = 0; late = 0; rendererPressure = 0
    }

    private func refresh() {
        let process = ProcessInfo.processInfo
        let hot = process.thermalState == .serious || process.thermalState == .critical
        let newLevel = AnimationBudget.effectiveLevel(measured: policy.level, lowPower: process.isLowPowerModeEnabled, hot: hot)
        let newRate = AnimationBudget.frameRate(maximum: UIScreen.main.maximumFramesPerSecond, level: newLevel, lowPower: process.isLowPowerModeEnabled, hot: hot)
        if level != newLevel { level = newLevel }
        if frameRate != newRate { frameRate = newRate; resetWindow() }
        link?.preferredFrameRateRange = CAFrameRateRange(minimum: Float(min(30, newRate)), maximum: Float(newRate), preferred: Float(newRate))
    }

    fileprivate func tick(_ display: CADisplayLink) {
        guard lastTimestamp > 0 else { lastTimestamp = display.timestamp; return }
        let delta = display.timestamp - lastTimestamp
        lastTimestamp = display.timestamp
        guard delta > 0 else { resetWindow(); return }
        if delta >= 0.25 {
            // An active long stall is pressure, not an idle/background sample.
            policy.sample(lateFraction: 1)
            resetWindow(); refresh(); return
        }
        frames += 1; elapsed += delta
        if delta > 1.35 / Double(frameRate) { late += 1 }
        guard elapsed >= 2 else { return }
        let fraction = Double(late) / Double(frames)
        if metricsEnabled {
        logger.info("Display cadence \(Double(self.frames) / self.elapsed, format: .fixed(precision: 1)) fps; late \(fraction, format: .fixed(precision: 2)); detail \(self.level); target \(self.frameRate)")
        }
        policy.sample(lateFraction: max(fraction, rendererPressure))
        rendererPressure = 0
        elapsed = 0; frames = 0; late = 0
        refresh()
    }
}

@MainActor
private final class DisplayProbe: NSObject {
    weak var owner: LisaRenderBudget?
    init(owner: LisaRenderBudget) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) { owner?.tick(link) }
}
