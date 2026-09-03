import Foundation
import Testing

/// Validates every `.xcstrings` catalog straight from its JSON source — no live model, no
/// simulator. Three catalogs exist: the app's UI strings, the App Shortcut phrase catalog beside
/// the `AppShortcutsProvider`, and the watch app's own.
///
/// This is the half `check_loc_drift` cannot see. Drift asks whether every string in the SOURCE
/// reached the catalog; this asks whether every string in the catalog reached every LOCALE. A
/// catalog can be perfectly drift-free and still ship raw English into five of the ten languages
/// the App Store listing promises.
///
/// `scripts/loc-check.sh` runs this same suite standalone rather than re-implementing it.
@Suite("Localization catalog integrity")
struct LocalizationIntegrityTests {
    @Test func appCatalogIsFullyLocalized() throws {
        try LocalizationCatalog.assertIntegrity(at: repoRoot().appending(path: "VillainArc/Localizable.xcstrings"))
    }

    @Test func appShortcutsCatalogIsFullyLocalized() throws {
        try LocalizationCatalog.assertIntegrity(at: repoRoot().appending(path: "VillainArc/AppShortcuts.xcstrings"))
    }

    @Test func watchCatalogIsFullyLocalized() throws {
        try LocalizationCatalog.assertIntegrity(at: repoRoot().appending(path: "VillainArcWatchApp/Localizable.xcstrings"))
    }

    /// `AppIntentVocabulary.plist` is a plain per-locale resource, not a catalog: nothing in the
    /// build, the drift check, or the catalog integrity above has an opinion about it, so a locale
    /// that never got one ships with no Siri examples for the system workout domain and says so
    /// nowhere. Every shipping locale carries the same three intents the SiriKit extension handles.
    @Test func siriVocabularyCoversEveryShippingLocale() throws {
        let root = repoRoot()
        let intents = ["INStartWorkoutIntent", "INCancelWorkoutIntent", "INEndWorkoutIntent"]
        var issues: [String] = []

        for locale in LocalizationCatalog.shippingLocales {
            let path = root.appending(path: "VillainArc/\(locale).lproj/AppIntentVocabulary.plist")
            guard let data = try? Data(contentsOf: path) else {
                issues.append("\(locale): no AppIntentVocabulary.plist")
                continue
            }
            guard let vocabulary = try? PropertyListDecoder().decode(SiriVocabulary.self, from: data) else {
                issues.append("\(locale): AppIntentVocabulary.plist has no IntentPhrases array")
                continue
            }
            for intent in intents {
                guard let entry = vocabulary.intentPhrases.first(where: { $0.intentName == intent }) else {
                    issues.append("\(locale): missing \(intent)")
                    continue
                }
                let examples = entry.intentExamples ?? []
                if examples.isEmpty { issues.append("\(locale): \(intent) has no examples") }
                // The app name is what Siri matches the phrase against, so it is never translated.
                for example in examples where !example.contains("Villain Arc") {
                    issues.append("\(locale): \(intent) example does not name the app: \(example)")
                }
            }
        }

        #expect(issues.isEmpty, "\(issues.count) Siri vocabulary issue(s):\n\(issues.sorted().joined(separator: "\n"))")
    }
}

/// The half of `AppIntentVocabulary.plist` this suite reads, decoded rather than cast out of an
/// `Any` tree: `PropertyListDecoder` is the safe form of the read, where
/// `PropertyListSerialization` takes an `UnsafeMutablePointer` for its format out-parameter.
private struct SiriVocabulary: Decodable {
    struct Phrase: Decodable {
        let intentName: String
        let intentExamples: [String]?

        enum CodingKeys: String, CodingKey {
            case intentName = "IntentName"
            case intentExamples = "IntentExamples"
        }
    }

    let intentPhrases: [Phrase]

    enum CodingKeys: String, CodingKey {
        case intentPhrases = "IntentPhrases"
    }
}

/// Walks up from this test file to the repo root (the directory holding the Xcode project) —
/// robust to the test bundle's actual working directory, which `xcodebuild` does not guarantee.
private func repoRoot(file: String = #filePath) -> URL {
    var url = URL(fileURLWithPath: file).deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: url.appendingPathComponent("VillainArc.xcodeproj").path) {
        let parent = url.deletingLastPathComponent()
        precondition(parent != url, "Walked up to the filesystem root without finding VillainArc.xcodeproj")
        url = parent
    }
    return url
}

/// A catalog's integrity rules, checked straight from the JSON.
enum LocalizationCatalog {
    /// The fleet's ten-language floor. Listing a locale is a promise the store makes on the app's
    /// behalf, so a locale is either complete here or it is not declared at all — half-covered is
    /// worse than absent, because the user chose the app believing the promise.
    static let shippingLocales = ["de", "en", "es", "fr", "it", "ja", "ko", "pt-BR", "ru", "zh-Hans"]

    /// English is the source language: its strings are the thing being translated FROM, and a key
    /// with no `en` entry simply is its own English value.
    static let sourceLocale = "en"

    struct IntegrityError: Error, CustomStringConvertible {
        let issues: [String]
        var description: String {
            let shown = issues.sorted().prefix(40)
            let more = issues.count > 40 ? "\n… and \(issues.count - 40) more" : ""
            return "\(issues.count) localization issue(s):\n" + shown.joined(separator: "\n") + more
        }
    }

    private struct Catalog: Decodable {
        let strings: [String: StringEntry]
    }

    private struct StringEntry: Decodable {
        let shouldTranslate: Bool?
        let localizations: [String: Localization]?
    }

    private struct Localization: Decodable {
        let stringUnit: StringUnit?
    }

    private struct StringUnit: Decodable {
        let state: String
        let value: String
    }

    static func assertIntegrity(at url: URL) throws {
        let catalog = try JSONDecoder().decode(Catalog.self, from: try Data(contentsOf: url))
        let name = url.lastPathComponent
        var issues: [String] = []

        for (key, entry) in catalog.strings {
            // A `shouldTranslate: false` key — a proper noun, a bare format shell, a notation
            // string — is the documented skip list: the same content in every language, on purpose.
            if entry.shouldTranslate == false { continue }

            let englishValue = entry.localizations?[sourceLocale]?.stringUnit?.value ?? key
            let englishArguments = argumentTypes(in: englishValue)
            // Whether MOST locales found something to translate here. Each locale is an
            // independent reading, so the majority is the reference for whether this string is
            // translatable at all.
            //
            // Some content survives translation intact on purpose — a brand ("Villain Arc Pro"), a
            // unit shell ("%lld bpm"), a training-split proper noun ("Push / Pull / Legs", which
            // the Latin-script locales keep and the CJK/Cyrillic ones render). A minority keeping
            // the English is that judgement call. A lone locale echoing English while everyone
            // else translated is a skipped string, which is the only thing this check is for.
            let translatedValues = shippingLocales.filter { $0 != sourceLocale }
                .compactMap { entry.localizations?[$0]?.stringUnit?.value }
            let mostLocalesTranslatedIt =
                translatedValues.count(where: { $0 != englishValue }) * 2 > translatedValues.count

            for locale in shippingLocales where locale != sourceLocale {
                guard let unit = entry.localizations?[locale]?.stringUnit, !unit.value.isEmpty else {
                    issues.append("\(name) \"\(key)\": missing or empty '\(locale)'")
                    continue
                }
                if unit.state != "translated" {
                    issues.append("\(name) \"\(key)\": '\(locale)' state is '\(unit.state)', not 'translated'")
                }
                // A translation that is just the English text back again is the exact shape a
                // half-finished locale pass leaves behind, and the only check that catches it
                // before a native speaker does. Restricted to prose: a short label can
                // legitimately match, three or more words coming back untouched cannot.
                if unit.value == englishValue, mostLocalesTranslatedIt, isProse(englishValue) {
                    issues.append("\(name) \"\(key)\": '\(locale)' is identical to the English source")
                }
                // A specifier mismatch is a crash-class hazard, not a cosmetic one: `String(format:)`
                // reads past the argument list, or reads an argument as the wrong type.
                let localeArguments = argumentTypes(in: unit.value)
                if localeArguments != englishArguments {
                    issues.append(
                        "\(name) \"\(key)\": argument slots differ — en=\(describe(englishArguments)) "
                            + "\(locale)=\(describe(localeArguments))"
                    )
                }
            }
        }

        if !issues.isEmpty { throw IntegrityError(issues: issues) }
    }

    /// Three or more words once the format specifiers are removed — the threshold above which a
    /// string is a sentence rather than a label, brand, or unit shell.
    private static func isProse(_ string: String) -> Bool {
        let withoutSpecifiers = string.replacing(specifierPattern, with: " ")
        return withoutSpecifiers.split(whereSeparator: { !$0.isLetter && $0 != "'" && $0 != "\u{2019}" })
            .count(where: { $0.count > 1 }) >= 3
    }

    /// Every `%@`, `%lld`, `%1$@`, `%.1f`, `%%` … token, **sorted**: a translation may legitimately
    /// reorder its clauses (that is what positional specifiers are for), so only the multiset has
    /// to match, never the order.
    /// No flag characters. Admitting printf's space flag makes `"50–70% of training max"` parse
    /// its `"% o"` as an octal conversion — which the plan-note strings in `PlanTemplate.swift`
    /// really contain, and which no translation reproduces once the following word is translated.
    private static let specifierPattern =
        /%(?:(\d+)\$)?[0-9]*(?:\.[0-9]+)?(?:ll|l|h|hh|z|q)?([dioux@fFeEgGcsp])/

    /// Which argument each slot consumes, and of what kind — the thing that actually has to match.
    ///
    /// Comparing specifier TOKENS is wrong in both directions here. It reports a false mismatch on
    /// every string whose English is positional (`%1$@ … %2$@`) and whose translation is not
    /// (`%@ … %@`) in the same order — 84 such pairs ship in this catalog today, all correct. And
    /// a sorted token multiset misses the case that genuinely crashes: a translation that reorders
    /// two non-positional specifiers of different types, so the format reads an Int as a String.
    /// Resolving each slot to its index — explicit where positional, appearance order otherwise —
    /// answers both.
    private static func argumentTypes(in string: String) -> [Int: String] {
        var types: [Int: String] = [:]
        var automatic = 0
        for match in string.matches(of: specifierPattern) {
            let conversion = String(match.2)
            let index: Int
            if let positional = match.1, let parsed = Int(positional) {
                index = parsed
            } else {
                automatic += 1
                index = automatic
            }
            types[index] = switch conversion {
            case "@": "String"
            case "f", "F", "e", "E", "g", "G": "Double"
            default: "Int"
            }
        }
        return types
    }

    private static func describe(_ types: [Int: String]) -> String {
        "[" + types.keys.sorted().map { "\($0):\(types[$0]!)" }.joined(separator: ", ") + "]"
    }
}
