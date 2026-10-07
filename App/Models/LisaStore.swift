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
    var numberFirst = false
    var poulpiStarEquipped = false

    init() {}
    private enum CodingKeys: String, CodingKey { case sound, music, animatedDecor, haptics, autoCheck, highlightPeers, highlightDuplicates, errorLimit, darkMode, paperMode, showTimer, numberFirst, poulpiStarEquipped }
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
        numberFirst = try c.decodeIfPresent(Bool.self, forKey: .numberFirst) ?? false
        poulpiStarEquipped = try c.decodeIfPresent(Bool.self, forKey: .poulpiStarEquipped) ?? false
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

/// The puzzle and its reward context travel together, including across app launches.
struct SavedModeGame: Codable, Sendable, Identifiable {
    var id = UUID()
    var session: GameSession
    let mode: String
    let day: String?
    let eventID: String?
    let tournamentID: String?
    let journeyStage: Int?
    var recorded: Bool
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
    var savedGames: [String: SavedModeGame]?
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
    // Snapshots are not UI state: periodic saves must not redraw the whole board.
    // Session, mode and presentation changes already publish real menu updates.
    private(set) var savedGames: [String: SavedModeGame] = [:]
    @Published var generationError: String?
    @Published var isGenerating = false
    @Published var showGame = false
    @Published var showVictory = false
    @Published var saveError: String?
    var milestones = GameMilestones()
    private var recorded = false
    private var currentGameID = UUID()
    private var activeJourneyStage: Int?
    private var generationID: UUID?
    private var generationTask: Task<Void, Never>?
    // Keep the previous worker until it exits; its successor waits before entering the engine.
    private var generationWorker: Task<Puzzle, Error>?
    private let generatePuzzle: @Sendable (Difficulty, UInt64) throws -> Puzzle
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

    init(saveURL: URL? = nil, generator: @escaping @Sendable (Difficulty, UInt64) throws -> Puzzle = { difficulty, seed in
        return try SudokuGenerator.generateCancellable(difficulty: difficulty, seed: seed,
                                                       deadline: Date().addingTimeInterval(2),
                                                       cancellation: { Task.isCancelled })
    }) {
        self.generatePuzzle = generator
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
                if let saves = data.savedGames {
                    guard saves.allSatisfy({ key, game in
                        key == game.mode && ["Libre", "Quotidien", "Voyage", "Événement", "Tournoi"].contains(key)
                            && (game.journeyStage == nil || (1...25).contains(game.journeyStage!))
                    }) else {
                        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid per-mode game context"))
                    }
                }
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
                savedGames = data.savedGames ?? [:]
                if let saved = savedGames[mode] {
                    session = saved.session
                    activeDay = saved.day
                    activeEvent = saved.eventID
                    activeTournament = saved.tournamentID
                    activeJourneyStage = saved.journeyStage
                    recorded = saved.recorded
                    currentGameID = saved.id
                } else if let session {
                    // The original v1 save is migrated in memory without rewriting on launch.
                    activeJourneyStage = mode == "Voyage" ? min(max(1, eventWins + (recorded ? 0 : 1)), 25) : nil
                    savedGames[mode] = currentSavedGame(session)
                }
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
            activeJourneyStage = 5
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
        if let snapshot { savedGames[mode] = currentSavedGame(snapshot) }
        let data = SaveData(session: snapshot, settings: settings, history: history, completedDays: completedDays, eventWins: eventWins, mode: mode, activeDay: activeDay, eventMedals: eventMedals, activeEvent: activeEvent, activeTournament: activeTournament, savedGames: savedGames)
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
        cancelGeneration()
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

    private func currentSavedGame(_ session: GameSession) -> SavedModeGame {
        SavedModeGame(id: currentGameID, session: session, mode: mode, day: activeDay,
                      eventID: activeEvent, tournamentID: activeTournament,
                      journeyStage: activeJourneyStage, recorded: recorded)
    }

    func savedGame(mode: String, date: Date? = nil) -> SavedModeGame? {
        let saved: SavedModeGame?
        if self.mode == mode, var session {
            session.elapsedSeconds = clock.seconds
            saved = currentSavedGame(session)
        } else { saved = savedGames[mode] }
        guard let saved, !saved.session.isComplete else { return nil }
        if mode == "Quotidien", let date, saved.day != Self.dayKey(date) { return nil }
        return saved
    }

    func hasSavedGame(mode: String, date: Date? = nil) -> Bool { savedGame(mode: mode, date: date) != nil }

    @discardableResult func resume(mode: String, date: Date? = nil) -> Bool {
        guard let saved = savedGame(mode: mode, date: date) else { return false }
        cancelGeneration()
        save()
        restore(saved)
        showGame = true
        save()
        return true
    }

    @discardableResult func resumeLastGame() -> Bool { resume(mode: mode) }

    private func restore(_ saved: SavedModeGame) {
        mode = saved.mode
        activeDay = saved.day
        activeEvent = saved.eventID
        activeTournament = saved.tournamentID
        activeJourneyStage = saved.journeyStage
        currentGameID = saved.id
        session = saved.session
        clock.seconds = saved.session.elapsedSeconds
        recorded = saved.recorded
        showVictory = false
        milestones = GameMilestones()
        _ = milestones.record(before: Array(repeating: 0, count: 81), after: saved.session.values,
                              solution: saved.session.puzzle.solution, revealsCorrectness: false)
    }

    func cancelGeneration() {
        generationID = nil
        generationWorker?.cancel()
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
    }

    func start(_ difficulty: Difficulty, mode: String = "Libre", date: Date? = nil, seedOverride: UInt64? = nil, eventID: String? = nil, tournamentID: String? = nil) {
        guard canPersist else { saveError = Self.loadFailureMessage; return }
        cancelGeneration()
        save() // Preserve the old board before requesting a replacement.
        let id = UUID()
        generationID = id
        generationError = nil
        isGenerating = true
        let day = mode == "Quotidien" ? Self.dayKey(date ?? Date()) : nil
        let stage = mode == "Voyage" ? min(eventWins + 1, 25) : nil
        let seed = seedOverride ?? day.map(Self.stableSeed) ?? date.map { Self.stableSeed(Self.dayKey($0)) } ?? UInt64.random(in: 1...UInt64.max)
        let previousWorker = generationWorker
        let generator = generatePuzzle
        let worker = Task.detached(priority: .userInitiated) {
            if let previousWorker { _ = await previousWorker.result }
            try Task.checkCancellation()
            return try generator(difficulty, seed)
        }
        generationWorker = worker
        generationTask = Task { [weak self] in
            let result = await worker.result
            guard let self, !Task.isCancelled, self.generationID == id else { return }
            self.generationID = nil
            self.generationTask = nil
            self.isGenerating = false
            switch result {
            case .success(let puzzle):
                // Context changes only after a complete, current generation result exists.
                self.save()
                let saved = SavedModeGame(session: GameSession(puzzle: puzzle), mode: mode,
                                          day: day, eventID: eventID, tournamentID: tournamentID,
                                          journeyStage: stage, recorded: false)
                self.restore(saved)
                self.showGame = true
                self.save()
            case .failure:
                self.generationError = L10n.text("La grille n’a pas pu être préparée. Votre partie est conservée. Réessayez.")
            }
        }
    }

    func changed() {
        if session?.isComplete == true { synchronizeElapsedTime() }
        if session?.isComplete == true && !recorded, let game = session {
            recorded = true
            history.append(FinishedGame(date: Date(), difficulty: game.puzzle.difficulty, seconds: game.elapsedSeconds, mistakes: game.mistakes, hints: game.hintsUsed, mode: mode))
            if mode == "Quotidien", let activeDay { completedDays.insert(activeDay) }
            if mode == "Voyage", (activeJourneyStage ?? eventWins + 1) == eventWins + 1, eventWins < 25 { eventWins += 1 }
            if mode == "Événement", let activeEvent { eventMedals.insert(activeEvent) }
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
    private func seasonalProgress(_ key: String) -> Int {
        (1...10).filter { eventMedals.contains(key + "-" + String($0)) }.count
    }
    private func nextSeasonEvent(_ key: String) -> String? {
        (1...10).first { !eventMedals.contains(key + "-" + String($0)) }.map { key + "-" + String($0) }
    }
    var seasonProgress: Int { seasonalProgress(seasonKey) }
    var seasonTitle: String {
        switch Calendar.current.component(.month, from: Date()) {
        case 3...5: return L10n.text("Les petits bourgeons")
        case 6...8: return L10n.text("Le soleil en poche")
        case 9...11: return L10n.text("Les feuilles dorées")
        default: return L10n.text("La fabrique des flocons")
        }
    }
    func startSeason() {
        guard let eventID = nextSeasonEvent(seasonKey) else { return }
        start(seasonProgress < 3 ? .easy : seasonProgress < 7 ? .medium : .hard,
              mode: "Événement", seedOverride: Self.stableSeed("season-v1-" + eventID), eventID: eventID)
    }

    var hasPoulpiStarReward: Bool { eventWins >= 5 }
    var poulpiStarEquipped: Bool { hasPoulpiStarReward && settings.poulpiStarEquipped }

    func equipPoulpiStar(_ equipped: Bool) {
        guard !equipped || hasPoulpiStarReward else { return }
        settings.poulpiStarEquipped = equipped
    }

    func startJourney() {
        guard eventWins < 25 else { return }
        let difficulty: Difficulty = [.easy, .easy, .medium, .hard, .expert][min(eventWins / 5, 4)]
        start(difficulty, mode: "Voyage")
    }

    var victoryContinuationTitle: String {
        switch mode {
        case "Libre": return L10n.text("Une autre grille")
        case "Voyage" where eventWins < 25: return L10n.text("Prochaine étape")
        case "Événement" where canContinueSeason: return L10n.text("Prochain défi")
        default: return L10n.text("Retour à l’accueil")
        }
    }

    private var canContinueSeason: Bool {
        guard let activeEvent else { return false }
        let key = String(activeEvent.prefix(7))
        return nextSeasonEvent(key) != nil
    }

    func continueAfterVictory() {
        guard session?.isComplete == true else { return }
        changed() // Idempotent even if victory presentation raced the final edit.
        switch mode {
        case "Libre":
            if let difficulty = session?.puzzle.difficulty { start(difficulty) }
        case "Voyage" where eventWins < 25: startJourney()
        case "Événement" where canContinueSeason:
            // Continue the season that belongs to this puzzle, even after a month boundary.
            guard let activeEvent else { return }
            let key = String(activeEvent.prefix(7))
            let progress = seasonalProgress(key)
            guard let next = nextSeasonEvent(key) else { return }
            start(progress < 3 ? .easy : progress < 7 ? .medium : .hard,
                  mode: "Événement", seedOverride: Self.stableSeed("season-v1-" + next), eventID: next)
        default:
            showVictory = false
            showGame = false
        }
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
