import SwiftUI
import SudokuCore
import UIKit

struct LisaSettings: Codable, Sendable {
    var sound = true
    var music = false
    var animatedDecor = true
    var haptics = true
    var autoCheck = true
    var highlightPeers = true
    var highlightDuplicates = true
    var errorLimit = false
    var darkMode = false
    var paperMode = false
    var showTimer = true

    init() {}
    private enum CodingKeys: String, CodingKey { case sound, music, animatedDecor, haptics, autoCheck, highlightPeers, highlightDuplicates, errorLimit, darkMode, paperMode, showTimer }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? true
        music = try c.decodeIfPresent(Bool.self, forKey: .music) ?? false
        animatedDecor = try c.decodeIfPresent(Bool.self, forKey: .animatedDecor) ?? true
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
        autoCheck = try c.decodeIfPresent(Bool.self, forKey: .autoCheck) ?? true
        highlightPeers = try c.decodeIfPresent(Bool.self, forKey: .highlightPeers) ?? true
        highlightDuplicates = try c.decodeIfPresent(Bool.self, forKey: .highlightDuplicates) ?? true
        errorLimit = try c.decodeIfPresent(Bool.self, forKey: .errorLimit) ?? false
        darkMode = try c.decodeIfPresent(Bool.self, forKey: .darkMode) ?? false
        paperMode = try c.decodeIfPresent(Bool.self, forKey: .paperMode) ?? false
        showTimer = try c.decodeIfPresent(Bool.self, forKey: .showTimer) ?? true
    }
}

struct FinishedGame: Codable, Identifiable, Sendable {
    var id = UUID()
    let date: Date
    let difficulty: Difficulty
    let seconds: Int
    let mistakes: Int
    let hints: Int
    let mode: String
}

private struct SaveData: Codable, Sendable {
    var session: GameSession?
    var settings: LisaSettings
    var history: [FinishedGame]
    var completedDays: Set<String>
    var eventWins: Int
    var mode: String
    var activeDay: String?
    var eventMedals: Set<String>?
    var activeEvent: String?
    var activeTournament: String?
}

@MainActor
final class LisaStore: ObservableObject {
    @Published var session: GameSession? {
        didSet {
            if oldValue?.puzzle != session?.puzzle { clock.seconds = session?.elapsedSeconds ?? 0 }
            if oldValue?.values != session?.values {
                duplicateCells = session.map { BoardConflicts.indices(in: $0.values) } ?? []
            }
        }
    }
    let clock = LisaGameClock()
    private(set) var duplicateCells: Set<Int> = []
    @Published var settings = LisaSettings() { didSet {
        LisaAudio.shared.configure(music: settings.music, effectsEnabled: settings.sound)
        save()
    } }
    @Published var history: [FinishedGame] = []
    @Published var completedDays: Set<String> = []
    @Published var eventWins = 0
    @Published var eventMedals: Set<String> = []
    @Published var activeEvent: String?
    @Published var activeTournament: String?
    @Published var mode = "Libre"
    @Published var activeDay: String?
    @Published var isGenerating = false
    @Published var showGame = false
    @Published var showVictory = false
    @Published var saveError: String?
    var milestones = GameMilestones()
    private var recorded = false
    // @Published observers run during init: never persist a partially restored store.
    // A failed load keeps this gate closed, even after the error alert is dismissed.
    private var canPersist = false
    private static let loadFailureMessage = "La sauvegarde n’a pas pu être chargée. Elle est conservée et l’enregistrement est suspendu pour protéger votre progression."
    private let saveURL: URL
    private var backgroundSave = UIBackgroundTaskIdentifier.invalid
    private var backgroundSaveGeneration = 0
    private lazy var writer: SnapshotWriter<SaveData> = {
        let writer = SnapshotWriter<SaveData>(url: saveURL)
        writer.onResult = { [weak self] result in
            if case .failure = result { self?.saveError = "Votre progression n’a pas pu être enregistrée." }
        }
        return writer
    }()

    init(saveURL: URL? = nil) {
        let defaultDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.saveURL = saveURL ?? defaultDirectory.appendingPathComponent("sudoku-lisa-v1.json")
        let saveURL = self.saveURL
        let dir = saveURL.deletingLastPathComponent()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-reset") {
            try? FileManager.default.removeItem(at: saveURL)
            UserDefaults.standard.removeObject(forKey: L10n.languagePreferenceKey)
        }
        #endif
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: saveURL.path) {
                let data = try JSONDecoder().decode(SaveData.self, from: Data(contentsOf: saveURL))
                session = data.session
                settings = data.settings
                history = data.history
                completedDays = data.completedDays
                eventWins = data.eventWins
                eventMedals = data.eventMedals ?? []
                activeEvent = data.activeEvent
                activeTournament = data.activeTournament
                mode = data.mode
                activeDay = data.activeDay
                recorded = session?.isComplete ?? false
            }
            clock.seconds = session?.elapsedSeconds ?? 0
            canPersist = true
        } catch { saveError = Self.loadFailureMessage }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-reset"),
           ProcessInfo.processInfo.arguments.contains("--uitest-reduce-motion") {
            assert(UIAccessibility.isReduceMotionEnabled, "This test requires the simulator Reduce Motion setting")
        }
        // Deterministic, isolated UI fixture. Never touches a non-reset installation.
        if ProcessInfo.processInfo.arguments.contains("--uitest-reset"),
           ProcessInfo.processInfo.arguments.contains("--uitest-finale") {
            let solution = (0..<81).map { ($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1 }
            var givens = solution
            for index in [0, 40, 80] { givens[index] = 0 }
            session = GameSession(puzzle: Puzzle(givens: givens, solution: solution, difficulty: .quick, seed: 1))
            mode = "Voyage"
            eventWins = 4
            recorded = false
            if ProcessInfo.processInfo.arguments.contains("--uitest-zen") {
                settings.autoCheck = false
                settings.highlightDuplicates = false
            }
            save()
        }
        #endif
        clock.seconds = session?.elapsedSeconds ?? 0
        duplicateCells = session.map { BoardConflicts.indices(in: $0.values) } ?? []
        if let session {
            _ = milestones.record(before: Array(repeating: 0, count: 81), after: session.values,
                                  solution: session.puzzle.solution, revealsCorrectness: false)
        }
    }

    func save() {
        guard canPersist else { return }
        var snapshot = session
        snapshot?.elapsedSeconds = clock.seconds
        let data = SaveData(session: snapshot, settings: settings, history: history, completedDays: completedDays, eventWins: eventWins, mode: mode, activeDay: activeDay, eventMedals: eventMedals, activeEvent: activeEvent, activeTournament: activeTournament)
        writer.submit(data)
    }

    func tick() {
        guard session?.isComplete == false else { return }
        clock.seconds += 1
        if clock.seconds.isMultiple(of: 5) { save() }
    }

    func synchronizeElapsedTime() {
        guard let session, session.elapsedSeconds != clock.seconds else { return }
        self.session?.elapsedSeconds = clock.seconds
    }

    func saveForBackground() {
        save()
        guard backgroundSave == .invalid else { return }
        backgroundSaveGeneration += 1
        let generation = backgroundSaveGeneration
        backgroundSave = UIApplication.shared.beginBackgroundTask(withName: "Save Sudoku") { [weak self] in
            Task { @MainActor in self?.endBackgroundSave(generation: generation) }
        }
        Task {
            await flushPendingSaves()
            endBackgroundSave(generation: generation)
        }
    }

    func flushPendingSaves() async { await writer.flush() }

    private func endBackgroundSave(generation: Int) {
        guard generation == backgroundSaveGeneration, backgroundSave != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundSave)
        backgroundSave = .invalid
    }

    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var streak: Int {
        let calendar = Calendar.current
        var day = Date()
        if !completedDays.contains(Self.dayKey(day)) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while completedDays.contains(Self.dayKey(day)) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }

    func start(_ difficulty: Difficulty, mode: String = "Libre", date: Date? = nil, seedOverride: UInt64? = nil, eventID: String? = nil, tournamentID: String? = nil) {
        guard canPersist else { saveError = Self.loadFailureMessage; return }
        guard !isGenerating else { return }
        isGenerating = true
        self.mode = mode
        activeDay = mode == "Quotidien" ? date.map(Self.dayKey) : nil
        activeEvent = eventID
        activeTournament = tournamentID
        let seed: UInt64
        if let seedOverride { seed = seedOverride }
        else if let date {
            seed = Self.dayKey(date).utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        } else { seed = UInt64.random(in: 1...UInt64.max) }
        Task {
            let puzzle = await Task.detached(priority: .userInitiated) { SudokuGenerator.generate(difficulty: difficulty, seed: seed) }.value
            session = GameSession(puzzle: puzzle)
            clock.seconds = 0
            milestones = GameMilestones()
            recorded = false
            showVictory = false
            isGenerating = false
            showGame = true
            save()
        }
    }

    func changed() {
        if session?.isComplete == true { synchronizeElapsedTime() }
        if session?.isComplete == true && !recorded, let game = session {
            recorded = true
            history.append(FinishedGame(date: Date(), difficulty: game.puzzle.difficulty, seconds: game.elapsedSeconds, mistakes: game.mistakes, hints: game.hintsUsed, mode: mode))
            if let activeDay { completedDays.insert(activeDay) }
            if mode == "Voyage" { eventWins += 1 }
            if let activeEvent { eventMedals.insert(activeEvent) }
            if mode == "Tournoi", activeTournament == Self.tournamentKey() {
                GameCenterService.shared.submit(seconds: game.elapsedSeconds, mistakes: game.mistakes, hints: game.hintsUsed)
            }
            showVictory = true
            feedback(success: true)
        }
        save()
    }

    func feedback(success: Bool = false) {
        feedback(success ? .victory : .select)
    }

    func feedback(_ sound: LisaSound) {
        if settings.haptics {
            if sound == .victory || sound == .milestone {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else if sound == .place || sound == .hello {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
            } else { UISelectionFeedbackGenerator().selectionChanged() }
        }
        if settings.sound { LisaAudio.shared.play(sound) }
    }

    static func stableSeed(_ key: String) -> UInt64 {
        key.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
    }

    static func tournamentKey(date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear ?? 2026)-W\(components.weekOfYear ?? 1)"
    }

    func startTournament() {
        let key = Self.tournamentKey()
        start(.medium, mode: "Tournoi", seedOverride: Self.stableSeed("tournament-v1-" + key), tournamentID: key)
    }

    var seasonKey: String { String(Self.dayKey(Date()).prefix(7)) }
    var seasonProgress: Int { eventMedals.filter { $0.hasPrefix(seasonKey + "-") }.count }
    var seasonTitle: String {
        switch Calendar.current.component(.month, from: Date()) {
        case 3...5: return L10n.text("Les petits bourgeons")
        case 6...8: return L10n.text("Le soleil en poche")
        case 9...11: return L10n.text("Les feuilles dorées")
        default: return L10n.text("La fabrique des flocons")
        }
    }
    func startSeason() {
        guard seasonProgress < 10 else { return }
        let eventID = seasonKey + "-" + String(seasonProgress + 1)
        start(seasonProgress < 3 ? .easy : seasonProgress < 7 ? .medium : .hard,
              mode: "Événement", seedOverride: Self.stableSeed("season-v1-" + eventID), eventID: eventID)
    }

    var monthlyTrophies: [String] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return Set(completedDays.map { String($0.prefix(7)) }).filter { month in
            guard let date = formatter.date(from: month + "-01"), let range = formatter.calendar.range(of: .day, in: .month, for: date) else { return false }
            return range.allSatisfy { completedDays.contains(month + String(format: "-%02d", $0)) }
        }.sorted()
    }

    var longestStreak: Int {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = completedDays.compactMap { formatter.date(from: $0) }.sorted()
        var longest = 0, current = 0
        var previous: Date?
        for date in dates {
            current = previous.map { Calendar.current.dateComponents([.day], from: $0, to: date).day == 1 } == true ? current + 1 : 1
            longest = max(longest, current)
            previous = date
        }
        return longest
    }

    var bestTime: Int? { history.map(\.seconds).min() }
    var totalMinutes: Int { history.reduce(0) { $0 + $1.seconds } / 60 }
    static func time(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
}

/// Only the small timer label subscribes to these once-per-second updates.
@MainActor
final class LisaGameClock: ObservableObject {
    @Published var seconds = 0
}
