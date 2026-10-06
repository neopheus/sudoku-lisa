import Foundation

/// Shared by the app and its hint engine. Saved game identifiers stay language-independent.
public enum L10n {
    public static let supportedLanguages = ["fr", "en", "ru", "de", "es"]

    public static let languagePreferenceKey = "lisa.language"
    public static let systemLanguage = "system"

    public static var language: String {
        resolvedLanguage(preference: UserDefaults.standard.string(forKey: languagePreferenceKey),
                         preferredLanguages: Locale.preferredLanguages)
    }

    static func resolvedLanguage(preference: String?, preferredLanguages: [String]) -> String {
        if let preference, supportedLanguages.contains(preference) { return preference }
        return Bundle.preferredLocalizations(from: supportedLanguages, forPreferences: preferredLanguages).first ?? "fr"
    }

    public static var locale: Locale { Locale(identifier: language) }

    public static func nativeName(for language: String) -> String {
        switch language {
        case "fr": "Français"
        case "en": "English"
        case "ru": "Русский"
        case "de": "Deutsch"
        case "es": "Español"
        default: text("Langue de l’iPhone")
        }
    }

    private static let bundles = Dictionary(uniqueKeysWithValues: supportedLanguages.map { ($0, bundle(for: $0)) })
    private static var currentBundle: Bundle { bundles[language] ?? Bundle.module }

    static func bundle(for language: String) -> Bundle {
        guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return Bundle.module }
        return bundle
    }

    public static func text(_ key: String, _ arguments: String...) -> String {
        let value = currentBundle.localizedString(forKey: key, value: key, table: nil)
        // Plain strings may contain a literal percent sign (e.g. 100 % offline).
        guard !arguments.isEmpty else { return value }
        return String(format: value, locale: locale, arguments: arguments)
    }

    public static func count(_ key: String, _ value: Int) -> String {
        count(key, value, language: language)
    }

    static func count(_ key: String, _ value: Int, language: String) -> String {
        let format = bundle(for: language).localizedString(forKey: "count." + key, value: nil, table: nil)
        return String(format: format, locale: Locale(identifier: language), arguments: [value])
    }

    /// The calendar grid starts on Monday, so rotate the localized Sunday-first symbols.
    public static var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language)
        formatter.calendar = Calendar(identifier: .gregorian)
        let symbols = formatter.veryShortStandaloneWeekdaySymbols!
        return Array(symbols.dropFirst()) + [symbols[0]]
    }
}
