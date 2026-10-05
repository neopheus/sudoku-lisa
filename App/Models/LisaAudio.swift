import AVFoundation

enum LisaSound: String, CaseIterable {
    case select, place, note, erase, hint, milestone, hello, victory
}

/// Bounded player pool, bundled original sounds, and an optional quiet loop.
/// Ambient audio respects the silent switch and mixes with the user's audio.
@MainActor
final class LisaAudio: NSObject {
    static let shared = LisaAudio()
    private var effects: [LisaSound: AVAudioPlayer] = [:]
    private var music: AVAudioPlayer?
    private var active = false
    private var interrupted = false
    private var musicWanted = false
    private var paused = false
    private var routeSuspended = false
    private var lastEffect = Date.distantPast

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(interruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(secondaryAudioChanged(_:)), name: AVAudioSession.silenceSecondaryAudioHintNotification, object: nil)
    }

    func configure(active: Bool? = nil, music: Bool? = nil, paused: Bool? = nil, effectsEnabled: Bool? = nil) {
        if let active { self.active = active }
        if let music {
            if music != musicWanted { routeSuspended = false }
            musicWanted = music
        }
        if let paused { self.paused = paused; if !paused { routeSuspended = false } }
        if effectsEnabled == false || !self.active || self.paused {
            for player in effects.values { player.stop() }
        }
        if self.active && !interrupted {
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch { return }
        }
        updateMusic()
        if !self.active { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
    }

    func play(_ sound: LisaSound) {
        guard active, !paused, !interrupted, !routeSuspended else { return }
        // Avoid stacked taps and a final note playing underneath the victory melody.
        guard sound == .victory || sound == .milestone || Date().timeIntervalSince(lastEffect) > 0.045 else { return }
        if sound == .victory || sound == .milestone { effects.values.forEach { $0.stop() } }
        if effects[sound] == nil { effects[sound] = player(named: sound.rawValue) }
        guard let player = effects[sound] else { return }
        player.currentTime = 0
        player.volume = sound == .select ? 0.45 : 0.7
        player.play()
        lastEffect = Date()
    }

    private func updateMusic() {
        guard active, musicWanted, !paused, !interrupted, !routeSuspended,
              !AVAudioSession.sharedInstance().isOtherAudioPlaying else { music?.pause(); return }
        if music == nil {
            music = player(named: "ambience")
            music?.numberOfLoops = -1
            music?.volume = 0.38
        }
        if music?.isPlaying == false { music?.play() }
    }

    private func player(named name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: "lisa-" + name, withExtension: "wav") else { return nil }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }

    @objc nonisolated private func interruption(_ notification: Notification) {
        let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        Task { @MainActor in
            if type == AVAudioSession.InterruptionType.began.rawValue {
                interrupted = true
                effects.values.forEach { $0.stop() }
                music?.pause()
            } else if type == AVAudioSession.InterruptionType.ended.rawValue {
                interrupted = false
                if AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) { configure() }
            }
        }
    }

    @objc nonisolated private func routeChanged(_ notification: Notification) {
        let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
        guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
        Task { @MainActor in
            // Headphones disconnected: silence until the player opts in again or resumes.
            routeSuspended = true
            music?.pause()
            effects.values.forEach { $0.stop() }
        }
    }

    @objc nonisolated private func secondaryAudioChanged(_ notification: Notification) {
        let hint = notification.userInfo?[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt
        Task { @MainActor in
            if hint == AVAudioSession.SilenceSecondaryAudioHintType.begin.rawValue { music?.pause() }
            else { updateMusic() }
        }
    }
}
