@testable import KanaKanjiConverterModule
import XCTest

// Copaky: Tests for deterministic, whole-word Italian accent correction.
// Copaky: イタリア語の単語単位アクセント補正のテスト。
final class ItalianAccentAutocorrectTests: XCTestCase {
    func testFixesUnaccentedWordsAndAdaptsCase() {
        let cases = [
            "perche": "perché",
            "Perche": "Perché",
            "pErche": "perché",
            "PErche": "Perché",
            "cosi": "così",
            "citta": "città",
            "piu": "più",
            "gia": "già",
            "puo": "può",
            "verita": "verità",
            "universita": "università",
            "cioe": "cioè",
            "sara": "sarà",
        ]

        for (typed, expected) in cases {
            XCTAssertEqual(
                ItalianAccentAutocorrect.accentFix(forTypedWord: typed),
                expected,
                "unexpected accent fix for \(typed)"
            )
        }
    }

    func testLeavesAmbiguousValidOrUnsupportedWordsAlone() {
        let inputs = [
            "e", "si", "da", "la", "ne", "se", "te", "li", "di", "che", "po", "qui", "blu", "ciao",
            "perché", "PERCHE", "l'ho", "", "xqzv", "città",
        ]

        for typed in inputs {
            XCTAssertNil(
                ItalianAccentAutocorrect.accentFix(forTypedWord: typed),
                "must not autocorrect \(typed)"
            )
        }
    }
}
