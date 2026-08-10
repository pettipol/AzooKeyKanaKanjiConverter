public enum KeyboardLanguage: String, Codable, Equatable, Sendable {
    case en_US
    case ja_JP
    case el_GR
    /// Copaky fork: Italian. It shares the Latin QWERTY layout with `en_US`, but its predictions come
    /// from the Italian system dictionary (`UITextChecker` "it-IT") instead of the English one, so an
    /// Italian typist is not offered English words on every keystroke.
    /// Copakyフォーク: イタリア語。英語と同じラテン文字配列を使うが、予測は英語ではなく
    /// イタリア語のシステム辞書（UITextChecker "it-IT"）から行う。
    case it_IT
    case none

    /// Languages written with the Latin alphabet: for these, a purely roman-alphabet input is a word
    /// in its own right and must be offered as a candidate, not treated as romaji awaiting conversion.
    /// ラテン文字を使う言語かどうか。ローマ字入力をそのまま単語候補として扱うべき場合に真。
    public var usesLatinScript: Bool {
        switch self {
        case .en_US, .it_IT:
            return true
        case .ja_JP, .el_GR, .none:
            return false
        }
    }
}
