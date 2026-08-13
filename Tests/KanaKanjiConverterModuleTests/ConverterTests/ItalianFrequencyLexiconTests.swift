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

    // Codex adversarial review 2026-08-14: accent correction must be DIRECTIONAL and the corpus
    // must not contain apostrophe-stripped merges or wrong-accent variants. These pin both.

    func testAccentedInputNeverSuggestsSideways() {
        // typed WITH the correct accent: no fold-equal variant may come back (perchè, perche)
        let words = ItalianFrequencyLexicon.suggestions(forPrefix: "perché", limit: 10).map(\.word)
        XCTAssertFalse(words.contains("perchè"), "wrong-accent sibling offered for correct input: \(words)")
        XCTAssertFalse(words.contains("perche"), "unaccented downgrade offered for correct input: \(words)")
        XCTAssertFalse(words.contains { ItalianFrequencyLexicon.fold($0) == "perche" },
                       "no fold-equal of an already-accented prefix may be suggested: \(words)")
    }

    func testCorpusCarriesNoWrongAccentVariantOfCommonWords() {
        // plain input gets the accent fix — and exactly ONE: the correct spelling
        let fixes = ItalianFrequencyLexicon.suggestions(forPrefix: "perche", limit: 10)
            .filter(\.isAccentVariantOfPrefix).map(\.word)
        XCTAssertEqual(fixes, ["perché"], "plain 'perche' must offer only the correct 'perché', got \(fixes)")
        let comeFixes = ItalianFrequencyLexicon.suggestions(forPrefix: "come", limit: 10)
            .filter(\.isAccentVariantOfPrefix).map(\.word)
        XCTAssertTrue(comeFixes.isEmpty, "'come' must not be 'corrected' (comè is a stripped com'è): \(comeFixes)")
    }

    func testCorpusCarriesNoApostropheStrippedMerges() {
        let words = ItalianFrequencyLexicon.suggestions(forPrefix: "dell", limit: 30).map(\.word)
        for w in words where w.count > 5 {
            XCTAssertNil(w.range(of: "^(dell|dall|nell|sull|quell)[aeiouàèéìòù]", options: [.regularExpression, .caseInsensitive]),
                         "apostrophe-stripped merge in suggestions: \(w)")
        }
        let senz = ItalianFrequencyLexicon.suggestions(forPrefix: "senz", limit: 10).map(\.word)
        XCTAssertFalse(senz.contains("senzaltro"), "senz'altro must not appear merged: \(senz)")
    }

    func testShortAccentPairsSurvive() {
        // e/è, si/sì, ne/né are distinct words — the dedup must never eat them
        XCTAssertTrue(ItalianFrequencyLexicon.suggestions(forPrefix: "e", limit: 5).contains { $0.word == "è" })
        XCTAssertTrue(ItalianFrequencyLexicon.suggestions(forPrefix: "si", limit: 8).contains { $0.word == "sì" })
        XCTAssertTrue(ItalianFrequencyLexicon.suggestions(forPrefix: "ne", limit: 8).contains { $0.word == "né" })
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
