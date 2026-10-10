import AVFoundation
import SudokuCore

enum LisaSound: String, CaseIterable, Sendable {
    case select, place, note, erase, hint, milestone, hello, victory
}

enum LisaMusicTrack: String, CaseIterable, Identifiable, Sendable {
    case marimbaPuzzle = "marimba-puzzle"
    case fishbowlAcrobatics = "fishbowl-acrobatics"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .marimbaPuzzle: L10n.text("Marimba Game Music")
        case .fishbowlAcrobatics: L10n.text("Fishbowl Acrobatics")
        }
    }
    var resourceName: String { "lisa-music-" + rawValue }
    var fileExtension: String { "mp3" }
}

/// Injectable session boundary; its methods are called only on the audio queue.
protocol LisaAudioSession: Sendable {
    func configureCategory() throws
    func setActive(_ active: Bool) throws
    var isOtherAudioPlaying: Bool { get }
}

private struct SystemLisaAudioSession: LisaAudioSession {
    func configureCategory() throws {
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
    }
    func setActive(_ active: Bool) throws {
        try AVAudioSession.sharedInstance().setActive(active, options: active ? [] : .notifyOthersOnDeactivation)
    }
    var isOtherAudioPlaying: Bool { AVAudioSession.sharedInstance().isOtherAudioPlaying }
}

/// Bounded player pool, bundled original sounds, and an optional quiet loop.
/// Ambient audio respects the silent switch and mixes with the user's audio.
final class LisaAudio: NSObject, @unchecked Sendable {
    @MainActor static let shared = LisaAudio()
    // All mutable state and AVFoundation objects are confined to this queue.
    // Player preparation/playback can also activate the session implicitly, so
    // moving only setActive off the main actor would still leave a hang risk.
    private let queue: DispatchQueue
    private let session: any LisaAudioSession
    private var effects: [LisaSound: AVAudioPlayer] = [:]
    private var music: AVAudioPlayer?
    private var currentMusicTrack: LisaMusicTrack = .marimbaPuzzle
    private var active = false
    private var interrupted = false
    private var musicWanted = false
    private var effectsEnabled = true
    private var sessionActive = false
    private var categoryConfigured = false
    private var paused = false
    private var routeSuspended = false
    private var lastEffect = Date.distantPast

    private override convenience init() {
        self.init(session: SystemLisaAudioSession(), queue: DispatchQueue(label: "com.lisa.audio", qos: .userInitiated))
    }

    init(session: any LisaAudioSession, queue: DispatchQueue, observesNotifications: Bool = true) {
        self.session = session
        self.queue = queue
        super.init()
        guard observesNotifications else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(interruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(secondaryAudioChanged(_:)), name: AVAudioSession.silenceSecondaryAudioHintNotification, object: nil)
    }

    @MainActor
    func configure(active: Bool? = nil, music: Bool? = nil, musicTrack: LisaMusicTrack? = nil, paused: Bool? = nil, effectsEnabled: Bool? = nil) {
        queue.async { [self] in
            configureOnQueue(active: active, music: music, musicTrack: musicTrack, paused: paused, effectsEnabled: effectsEnabled)
        }
    }

    private func configureOnQueue(active: Bool? = nil, music: Bool? = nil, musicTrack: LisaMusicTrack? = nil, paused: Bool? = nil, effectsEnabled: Bool? = nil) {
        dispatchPrecondition(condition: .onQueue(queue))
        if let active { self.active = active }
        if let music {
            if music != musicWanted { routeSuspended = false }
            musicWanted = music
        }
        if let musicTrack, currentMusicTrack != musicTrack {
            currentMusicTrack = musicTrack
            self.music?.stop()
            self.music = nil
        }
        if let paused { self.paused = paused; if !paused { routeSuspended = false } }
        if let effectsEnabled { self.effectsEnabled = effectsEnabled }
        if !self.effectsEnabled || !self.active || self.paused {
            for player in effects.values { player.stop() }
        }
        guard !self.active || interrupted || activateSession() else { return }
        updateMusic()
        if !self.active, sessionActive {
            do {
                try session.setActive(false)
                sessionActive = false
            } catch { /* Keep the known session state so the next stop can retry. */ }
        }
    }

    @MainActor
    func play(_ sound: LisaSound) {
        queue.async { [self] in playOnQueue(sound) }
    }

    private func activateSession() -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))
        if sessionActive { return true }
        do {
            if !categoryConfigured {
                try session.configureCategory()
                categoryConfigured = true
            }
            try session.setActive(true)
            sessionActive = true
            return true
        } catch { return false }
    }

    private func playOnQueue(_ sound: LisaSound) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard active, effectsEnabled, !paused, !interrupted, !routeSuspended else { return }
        // Avoid stacked taps and a final note playing underneath the victory melody.
        guard sound == .victory || sound == .milestone || Date().timeIntervalSince(lastEffect) > 0.045 else { return }
        guard activateSession() else { return }
        if sound == .victory || sound == .milestone { effects.values.forEach { $0.stop() } }
        if effects[sound] == nil { effects[sound] = player(named: sound.rawValue) }
        guard let player = effects[sound] else { return }
        player.currentTime = 0
        player.volume = sound == .select ? 0.45 : 0.7
        player.play()
        lastEffect = Date()
    }

    private func updateMusic() {
        guard active, musicWanted, !paused, !interrupted, !routeSuspended, sessionActive,
              !session.isOtherAudioPlaying else { music?.pause(); return }
        if music == nil {
            music = player(named: currentMusicTrack.resourceName, extension: currentMusicTrack.fileExtension)
            music?.numberOfLoops = -1
            music?.volume = 0.38
        }
        if music?.isPlaying == false { music?.play() }
    }

    private func player(named name: String) -> AVAudioPlayer? {
        player(named: "lisa-" + name, extension: "wav")
    }

    private func player(named name: String, extension fileExtension: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else { return nil }
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }

    @objc private func interruption(_ notification: Notification) {
        let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
        let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        queue.async { [self] in
            if type == AVAudioSession.InterruptionType.began.rawValue {
                interrupted = true
                sessionActive = false
                effects.values.forEach { $0.stop() }
                music?.pause()
            } else if type == AVAudioSession.InterruptionType.ended.rawValue {
                interrupted = false
                if AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) { configureOnQueue() }
            }
        }
    }

    @objc private func routeChanged(_ notification: Notification) {
        let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
        guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
        queue.async { [self] in
            // Headphones disconnected: silence until the player opts in again or resumes.
            routeSuspended = true
            music?.pause()
            effects.values.forEach { $0.stop() }
        }
    }

    @objc private func secondaryAudioChanged(_ notification: Notification) {
        let hint = notification.userInfo?[AVAudioSessionSilenceSecondaryAudioHintTypeKey] as? UInt
        queue.async { [self] in
            if hint == AVAudioSession.SilenceSecondaryAudioHintType.begin.rawValue { music?.pause() }
            else { updateMusic() }
        }
    }
}
