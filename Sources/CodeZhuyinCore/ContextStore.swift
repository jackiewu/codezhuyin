import Foundation

/// 情境：一個領域的專有名詞與英文詞（咖啡烘豆、公司專案…），打開的情境詞會優先出現。
/// 跟自動學習分開：這裡是使用者自己整理（或請外部 AI 產生 JSON 貼進來）的詞庫包。
public struct ContextPack: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var detail: String
    public var enabled: Bool
    public var terms: [ContextTerm]

    public init(id: UUID = UUID(), name: String, detail: String = "", enabled: Bool = true, terms: [ContextTerm] = []) {
        self.id = id
        self.name = name
        self.detail = detail
        self.enabled = enabled
        self.terms = terms
    }

    public var chineseCount: Int { terms.count(where: { $0.reading != nil }) }
    public var englishCount: Int { terms.count(where: { $0.reading == nil }) }
}

/// 情境裡的一個詞。reading＝詞庫格式的注音（ㄧㄝ-ㄐㄧㄚ-ㄒㄩㄝˇ-ㄈㄟ）；nil＝英文詞
public struct ContextTerm: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var value: String
    public var reading: String?

    public init(id: UUID = UUID(), value: String, reading: String?) {
        self.id = id
        self.value = value
        self.reading = reading
    }

    /// 顯示用的注音：音節之間空一格
    public var readingDisplay: String? { reading?.replacingOccurrences(of: "-", with: " ") }
}

public final class ContextStore {
    public private(set) var packs: [ContextPack] = []
    private let fileURL: URL?
    /// 情境詞的分數：比一般常用詞高、也贏過自動學成的詞（-8），打開的情境詞優先
    private let termScore = -6.0
    private var index: [String: [Unigram]] = [:]
    /// 情境有變動（加詞、開關）時通知殼層：重建英文詞表、重組句子
    public var onChange: (() -> Void)?

    /// - Parameter fileURL: nil 表示純記憶體（測試用）
    public init(fileURL: URL?) {
        self.fileURL = fileURL
        if let fileURL, let raw = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode([ContextPack].self, from: raw) {
            packs = stored
        }
        rebuildIndex()
    }

    /// 打開的情境裡，這個讀音的詞
    public func unigrams(reading: String) -> [Unigram] {
        index[reading] ?? []
    }

    /// 打開的情境裡的英文詞（給英文偵測用）
    public var englishWords: [String] {
        packs.filter(\.enabled).flatMap { $0.terms.filter { $0.reading == nil }.map(\.value) }
    }

    public func upsert(_ pack: ContextPack) {
        if let i = packs.firstIndex(where: { $0.id == pack.id }) {
            packs[i] = pack
        } else {
            packs.append(pack)
        }
        changed()
    }

    public func remove(id: UUID) {
        packs.removeAll { $0.id == id }
        changed()
    }

    private func changed() {
        rebuildIndex()
        save()
        onChange?()
    }

    private func rebuildIndex() {
        var building: [String: [Unigram]] = [:]
        for pack in packs where pack.enabled {
            for term in pack.terms {
                guard let reading = term.reading,
                      building[reading]?.contains(where: { $0.value == term.value }) != true else { continue }
                building[reading, default: []].append(Unigram(value: term.value, score: termScore))
            }
        }
        index = building
    }

    private func save() {
        guard let fileURL else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(packs).write(to: fileURL, options: .atomic)
    }
}

/// 外部 AI 回傳的情境 JSON。容許前後夾說明文字、```json 區塊，
/// 也接受常見的別名（terms／words、english／keywords、term／value）。
public enum ContextImport {
    public struct Draft: Equatable, Sendable {
        public var name: String
        public var detail: String
        public var chinese: [String]
        public var english: [String]
        /// 無法加入的詞與原因（中英夾雜、只有一個字）
        public var skipped: [(String, String)]

        public static func == (a: Draft, b: Draft) -> Bool {
            a.name == b.name && a.detail == b.detail && a.chinese == b.chinese && a.english == b.english
                && a.skipped.map { $0.0 } == b.skipped.map { $0.0 }
        }
    }

    /// 給外部 AI 的提示詞
    public static func prompt(keywords: String) -> String {
        """
        請幫我整理「\(keywords)」這個領域打字時常用、但一般輸入法容易選錯的詞，給我的注音輸入法當詞庫。
        只回傳一段 JSON，格式如下：
        {
          "name": "情境名稱（短）",
          "description": "一句話說明",
          "words": ["中文專有名詞或術語，2 到 8 個字"],
          "english": ["這個領域常用的英文詞、產品名、縮寫"]
        }
        規則：words 只放純中文、至少兩個字；英文、數字、中英夾雜的詞放 english；各 20 到 60 個，不要重複、不要解釋。
        """
    }

    public static func parse(_ text: String) -> Draft? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let data = String(text[start...end]).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let name = (object["name"] as? String) ?? ""
        let detail = (object["description"] as? String) ?? (object["detail"] as? String) ?? ""
        var raw: [String] = []
        for key in ["words", "terms", "chinese", "english", "keywords"] {
            for item in (object[key] as? [Any]) ?? [] {
                if let word = item as? String {
                    raw.append(word)
                } else if let dict = item as? [String: Any], let word = (dict["term"] ?? dict["value"] ?? dict["word"]) as? String {
                    raw.append(word)
                }
            }
        }
        var draft = Draft(name: name, detail: detail, chinese: [], english: [], skipped: [])
        var seen = Set<String>()
        for word in raw.map({ $0.trimmingCharacters(in: .whitespaces) }) where !word.isEmpty && seen.insert(word).inserted {
            switch classify(word) {
            case .chinese: draft.chinese.append(word)
            case .english: draft.english.append(word)
            case .skip(let reason): draft.skipped.append((word, reason))
            }
        }
        return draft.chinese.isEmpty && draft.english.isEmpty && draft.skipped.isEmpty ? nil : draft
    }

    public enum Kind: Equatable, Sendable { case chinese, english, skip(String) }

    public static func classify(_ word: String) -> Kind {
        let hasHan = word.unicodeScalars.contains { $0.properties.isIdeographic }
        let hasLatin = word.unicodeScalars.contains { $0.isASCII && ($0.properties.isAlphabetic || $0.properties.numericType != nil) }
        if hasHan && hasLatin { return .skip("中英夾雜，沒辦法用注音打") }
        if hasHan {
            guard word.unicodeScalars.allSatisfy({ $0.properties.isIdeographic }) else { return .skip("含有符號") }
            return word.count >= 2 ? .chinese : .skip("只有一個字，會蓋過所有同音字")
        }
        if hasLatin { return word.count >= 2 ? .english : .skip("太短") }
        return .skip("不是中文或英文")
    }
}
