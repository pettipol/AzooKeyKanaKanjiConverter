// Copaky: Deterministic, lexicon-ranked correction for missing Italian word-final accents.
// Copaky: イタリア語の末尾アクセントを辞書順位で決定的に補正する。
public enum ItalianAccentAutocorrect: Sendable {
    /// Returns the preferred accented spelling for a complete unaccented Italian word.
    /// An initial capital is mirrored; all-caps and ambiguous words are left alone.
    public static func accentFix(forTypedWord typed: String) -> String? {
        guard typed.count > 1,
              ItalianFrequencyLexicon.isPredictableItalian(typed),
              typed.allSatisfy(\.isLetter),
              !isAllCaps(typed) else {
            return nil
        }

        let folded = ItalianFrequencyLexicon.fold(typed)
        guard typed.lowercased() == folded,
              let preferred = ItalianFrequencyLexicon.preferredAccentVariant(for: typed) else {
            return nil
        }
        return preferred
    }

    private static func isAllCaps(_ word: String) -> Bool {
        var uppercaseCount = 0
        for character in word {
            if character.isLowercase {
                return false
            }
            if character.isUppercase {
                uppercaseCount += 1
            }
        }
        return uppercaseCount >= 2
    }
}
