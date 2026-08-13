import Foundation
import SwiftUtils

/// Copaky fork: bundled Italian frequency lexicon for prediction on the Latin tab.
///
/// Why this exists: `UITextChecker` completions for "it"/"it-IT" depend on the host device's
/// system lexicons and proved too thin in real typing (few or no suggestions, none for accented
/// prefixes). This lexicon makes Italian prediction deterministic and offline: 50 000 word forms
/// ranked by usage frequency, blended from three Leipzig Corpora Collection corpora (CC BY,
/// © Universität Leipzig / Sächsische Akademie der Wissenschaften / InfAI —
/// https://wortschatz.uni-leipzig.de) plus a small Copaky-authored supplement for interpersonal
/// words that published text under-represents. Attribution lives in the app's credits.
///
/// Copaky フォーク：ラテン文字タブ用のイタリア語頻度辞書。UITextChecker はイタリア語では
/// 実機で十分な補完を返さないため、5万語の頻度順リストを同梱して予測を決定的・オフラインにする。
/// 出典は Leipzig Corpora Collection（CC BY・要クレジット表記）＋Copaky 自作の日常語補完。
///
/// Design notes:
/// - Matching is case- and diacritic-insensitive on the PREFIX ("perche" finds "perché",
///   "citta" finds "città"), which doubles as the accent-fix suggestion Italians actually want.
/// - Entries are sorted by folded key at load; lookup is a binary search + bounded scan.
/// - The array is built once per process on first use (`static let` — thread-safe by the runtime)
///   and costs ~2 MB; `preload()` lets the keyboard warm it during converter setup instead of on
///   the first keystroke.
enum ItalianFrequencyLexicon {
    struct Entry: Sendable {
        let word: String
        let folded: String
        let rank: Int32
    }

    struct Suggestion: Sendable {
        let word: String
        let rank: Int
        /// true when the suggestion is exactly the typed prefix up to case/diacritics
        /// (e.g. typed "perche", suggestion "perché") — callers rank these highest.
        let isAccentVariantOfPrefix: Bool
    }

    /// Sorted by `folded`, then rank. Built on first access; the Swift runtime guarantees
    /// thread-safe one-time initialization for `static let`.
    private static let entries: [Entry] = loadEntries()

    private static func loadEntries() -> [Entry] {
        guard let url = Bundle.module.url(forResource: "it_words", withExtension: "txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            debug("ItalianFrequencyLexicon: resource it_words.txt missing from bundle")
            return []
        }
        var result: [Entry] = []
        result.reserveCapacity(50_000)
        var rank: Int32 = 0
        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let word = String(line)
            result.append(Entry(word: word, folded: fold(word), rank: rank))
            rank += 1
        }
        result.sort { ($0.folded, $0.rank) < ($1.folded, $1.rank) }
        return result
    }

    /// Case- and diacritic-folding used for both sides of the match.
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "it_IT"))
    }

    /// Force the lazy `entries` build now (converter warm-up path), so the one-time load and
    /// sort do not land on the user's first keystroke. The build runs on a background task:
    /// the warm-up call site is on the keyboard's main actor and a synchronous 50k-entry
    /// load+fold+sort (~0.15 s in debug on an M4) would visibly stall the first Italian
    /// activation. `static let` initialization is one-time and thread-safe, so a keystroke
    /// arriving before the build finishes simply blocks on the same initialization instead of
    /// running it twice. / 初期化はバックグラウンドで先行実行（static let は一度きり・スレッド安全）。
    static func preload() {
        Task.detached(priority: .userInitiated) {
            _ = entries.count
        }
    }

    /// Characters an Italian composition may contain and still be predictable.
    /// Includes the apostrophes iOS produces (straight and typographic) for elisions like "l'ho".
    static func isPredictableItalian(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy { ch in
            ch.isLetter && ch.unicodeScalars.allSatisfy { $0.isASCII || "àáâèéêìíîòóôùúûÀÁÂÈÉÊÌÍÎÒÓÔÙÚÛ".unicodeScalars.contains($0) }
                || ch == "'" || ch == "’"
        }
    }

    /// Top suggestions for a typed prefix, frequency-ranked, case-adapted to the prefix.
    /// The typed prefix itself is never returned.
    static func suggestions(forPrefix typed: String, limit: Int) -> [Suggestion] {
        guard limit > 0, !typed.isEmpty else {
            return []
        }
        let foldedPrefix = fold(typed)
        guard !foldedPrefix.isEmpty else {
            return []
        }
        var lo = 0
        var hi = entries.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if entries[mid].folded < foldedPrefix {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        var matched: [Entry] = []
        var i = lo
        while i < entries.count, entries[i].folded.hasPrefix(foldedPrefix) {
            matched.append(entries[i])
            i += 1
        }
        matched.sort { $0.rank < $1.rank }

        // Accent correction is DIRECTIONAL: only an unaccented typed prefix gets fold-equal
        // entries offered (and boosted) as accent fixes — "perche" → "perché". When the user
        // already typed accents, a fold-equal entry can only be a different (hence wrong or
        // redundant) spelling of what they typed, so it is dropped entirely: "perché" must never
        // suggest sideways to "perchè" or down to "perche".
        // アクセント補正は一方向のみ：入力に既にアクセントがある場合、同綴り異アクセントは出さない。
        let typedIsPlain = typed.lowercased() == foldedPrefix

        // Accent fixes ride OUTSIDE the limit: "sì" or "né" rank far below the first `limit`
        // completions of their prefix, and an accent fix that only sometimes surfaces is worse
        // than none. There are at most a couple of fold-equal entries per prefix.
        // アクセント補正候補は limit の枠外で必ず含める。
        var seen = Set<String>()
        var fixes: [Suggestion] = []
        var completions: [Suggestion] = []
        for entry in matched {
            let isFoldEqual = entry.folded == foldedPrefix
            if isFoldEqual && !typedIsPlain {
                continue
            }
            if !isFoldEqual && completions.count >= limit {
                continue
            }
            let adapted = adaptCase(of: entry.word, to: typed)
            if adapted == typed || !seen.insert(adapted).inserted {
                continue
            }
            let suggestion = Suggestion(
                word: adapted,
                rank: Int(entry.rank),
                isAccentVariantOfPrefix: isFoldEqual && typedIsPlain
            )
            if suggestion.isAccentVariantOfPrefix {
                fixes.append(suggestion)
            } else {
                completions.append(suggestion)
            }
        }
        return fixes + completions
    }

    /// Mirror the case of the typed prefix onto a suggestion: "Perch" → "Perché",
    /// "PERCH" → "PERCHÉ". Proper nouns stored capitalized ("Roma") stay capitalized.
    private static func adaptCase(of word: String, to typed: String) -> String {
        guard let first = typed.first else {
            return word
        }
        if typed.count >= 2, typed.allSatisfy({ !$0.isLowercase }), typed.contains(where: \.isUppercase) {
            return word.uppercased()
        }
        if first.isUppercase, let head = word.first, head.isLowercase {
            return word.prefix(1).uppercased() + word.dropFirst()
        }
        return word
    }
}
