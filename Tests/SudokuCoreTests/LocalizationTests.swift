import XCTest
@testable import SudokuCore

final class LocalizationTests: XCTestCase {
    func testEveryLanguageHasEveryKeyAndCompatiblePlaceholders() throws {
        let french = try strings("fr")
        XCTAssertGreaterThan(french.count, 300)
        for language in L10n.supportedLanguages {
            let values = try strings(language)
            XCTAssertEqual(Set(values.keys), Set(french.keys), language)
            for (key, source) in french {
                let translated = try XCTUnwrap(values[key])
                XCTAssertFalse(translated.isEmpty, "\(language): \(key)")
                XCTAssertEqual(translated.components(separatedBy: "%@").count,
                               source.components(separatedBy: "%@").count, "\(language): \(key)")
            }
            XCTAssertEqual(L10n.bundle(for: language).localizedString(forKey: "Facile", value: nil, table: nil), values["Facile"])
        }
    }

    func testPluralRulesIncludingRussianTeensAndCompoundNumbers() {
        XCTAssertEqual(L10n.count("days", 1, language: "en"), "1 day")
        XCTAssertEqual(L10n.count("days", 2, language: "en"), "2 days")
        XCTAssertEqual(L10n.count("wins", 0, language: "fr"), "0 victoire")
        XCTAssertEqual(L10n.count("wins", 2, language: "fr"), "2 victoires")
        XCTAssertEqual(L10n.count("days", 2, language: "de"), "2 Tage")
        XCTAssertEqual(L10n.count("days", 2, language: "es"), "2 días")
        for (value, expected) in [(0, "0 дней"), (1, "1 день"), (2, "2 дня"), (5, "5 дней"), (11, "11 дней"), (21, "21 день"), (22, "22 дня"), (25, "25 дней"), (111, "111 дней")] {
            XCTAssertEqual(L10n.count("days", value, language: "ru"), expected)
        }
    }

    func testManualLanguageOverridesSystemAndCanReturnToAutomatic() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: L10n.languagePreferenceKey)
        defer {
            if let previous { defaults.set(previous, forKey: L10n.languagePreferenceKey) }
            else { defaults.removeObject(forKey: L10n.languagePreferenceKey) }
        }
        defaults.set("en", forKey: L10n.languagePreferenceKey)
        XCTAssertEqual(L10n.text("Facile"), "Easy")
        XCTAssertEqual(L10n.count("days", 2), "2 days")
        defaults.set("ru", forKey: L10n.languagePreferenceKey)
        XCTAssertEqual(L10n.text("Facile"), "Лёгкий")
        XCTAssertEqual(L10n.count("days", 22), "22 дня")
        XCTAssertEqual(L10n.locale.language.languageCode?.identifier, "ru")
        XCTAssertEqual(L10n.resolvedLanguage(preference: "system", preferredLanguages: ["es-MX", "fr"]), "es")
        XCTAssertEqual(L10n.resolvedLanguage(preference: "unknown", preferredLanguages: ["de-DE"]), "de")
        XCTAssertEqual(L10n.resolvedLanguage(preference: nil, preferredLanguages: ["fr"]), "fr")
        XCTAssertEqual(L10n.resolvedLanguage(preference: "en", preferredLanguages: ["fr"]), "en")
    }

    private func strings(_ language: String) throws -> [String: String] {
        let url = try XCTUnwrap(L10n.bundle(for: language).url(forResource: "Localizable", withExtension: "strings"))
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
    }
}
