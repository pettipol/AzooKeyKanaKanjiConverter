@testable import KanaKanjiConverterModule
import XCTest

/// Copaky fork: tests for the bundled Italian frequency lexicon.
/// Copaky フォーク：同梱イタリア語頻度辞書のテスト。
final class ItalianFrequencyLexiconTests: XCTestCase {
    func testLexiconLoadsAllEntries() {
        ItalianFrequencyLexicon.preload()
        let top = ItalianFrequencyLexicon.suggestions(forPrefix: "d", limit: 3)
        XCTAssertFalse(top.isEmpty, "the bundled it_words.txt must load from Bundle.module")
    }

    func testPrefixCompletionRankedByFrequency() {
        let words = ItalianFrequencyLexicon.suggestions(forPrefix: "per", limit: 10).map(\.word)
        XCTAssertTrue(words.contains("perché"), "top Italian completions for 'per' must include 'perché', got \(words)")
        // "per" itself is the typed prefix and must never be suggested back
        XCTAssertFalse(words.contains("per"))
    }

    func testAccentInsensitivePrefixFindsAccentedWords() {
        let words = ItalianFrequencyLexicon.suggestions(forPrefix: "citta", limit: 8)
        XCTAssertTrue(words.contains { $0.word == "città" && $0.isAccentVariantOfPrefix },
                      "typed 'citta' must offer 'città' flagged as accent variant, got \(words.map(\.word))")
    }

    func testAccentedPrefixStillCompletes() {
        let words = ItalianFrequencyLexicon.suggestions(forPrefix: "perché", limit: 8).map(\.word)
        // completions that EXTEND an accented prefix (e.g. perché → perchè is folded away; longer forms exist)
        // at minimum the lookup must not crash or return garbage; "perché" itself must be filtered out
        XCTAssertFalse(words.contains("perché"))
    }

    func testSingleCharacterAccentFix() {
        let words = ItalianFrequencyLexicon.suggestions(forPrefix: "e", limit: 5)
        XCTAssertTrue(words.contains { $0.word == "è" && $0.isAccentVariantOfPrefix },
                      "typing 'e' must offer 'è' (the most common Italian accent fix), got \(words.map(\.word))")
    }

    func testCapitalizedPrefixCapitalizesSuggestions() {
        let words = ItalianFrequencyLexicon.suggestions(forPrefix: "Perch", limit: 5).map(\.word)
        XCTAssertTrue(words.contains("Perché"), "sentence-start typing must keep the capital, got \(words)")
    }

    func testUppercasePrefixUppercasesSuggestions() {
        let words = ItalianFrequencyLexicon.suggestions(forPrefix: "PERC", limit: 5).map(\.word)
        XCTAssertTrue(words.contains { $0 == $0.uppercased() && $0.count > 4 },
                      "all-caps typing must yield all-caps suggestions, got \(words)")
    }

    func testProperNounKeepsItsCapital() {
        let words = ItalianFrequencyLexicon.suggestions(forPrefix: "rom", limit: 10).map(\.word)
        XCTAssertTrue(words.contains("Roma"), "'Roma' is stored capitalized and must stay so, got \(words)")
    }

    func testCommonInterpersonalWordsArePresent() {
        // these are exactly the words a news corpus under-represents; the curated supplement
        // guarantees them — regression guard for future lexicon rebuilds
        for (prefix, expected) in [("cia", "ciao"), ("graz", "grazie"), ("buongio", "buongiorno")] {
            let words = ItalianFrequencyLexicon.suggestions(forPrefix: prefix, limit: 8).map(\.word)
            XCTAssertTrue(words.contains(expected), "'\(expected)' missing for prefix '\(prefix)': \(words)")
        }
    }

    func testPredictableItalianGate() {
        XCTAssertTrue(ItalianFrequencyLexicon.isPredictableItalian("perché"))
        XCTAssertTrue(ItalianFrequencyLexicon.isPredictableItalian("l'ho"))
        XCTAssertTrue(ItalianFrequencyLexicon.isPredictableItalian("un’altra"))
        XCTAssertFalse(ItalianFrequencyLexicon.isPredictableItalian("ciao1"))
        XCTAssertFalse(ItalianFrequencyLexicon.isPredictableItalian("こんにちは"))
        XCTAssertFalse(ItalianFrequencyLexicon.isPredictableItalian(""))
    }

    func testLookupIsFastEnoughForAKeystroke() {
        ItalianFrequencyLexicon.preload()
        let start = Date()
        for prefix in ["a", "pe", "che", "vorr", "città", "l'a", "Buon", "s", "st", "stra"] {
            _ = ItalianFrequencyLexicon.suggestions(forPrefix: prefix, limit: 10)
        }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.5, "10 lookups must be far below keystroke latency, took \(elapsed)s")
    }
}
