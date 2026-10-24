import Foundation

/// 詞庫單元：一個讀音底下的候選詞與分數（ln 機率，越大越常見）
public struct Unigram: Equatable, Sendable {
    public let value: String
    public let score: Double

    public init(value: String, score: Double) {
        self.value = value
        self.score = score
    }
}

/// 詞庫：data.txt 格式（`讀音 詞 分數`，讀音的音節以 - 連接）。
/// 載入後唯讀，可跨執行緒共享。
public final class Lexicon: Sendable {
    private let map: [String: [Unigram]]
    /// 單字 → 它的讀音（常用的在前）：幫情境詞推注音用
    private let charReadings: [String: [String]]
    /// 詞庫中最長的詞（音節數），詞圖搜尋的跨距上限
    public let maxSpan: Int

    public init(dataText: String) {
        var building: [String: [Unigram]] = [:]
        var span = 1
        for line in dataText.split(separator: "\n") {
            if line.isEmpty || line.hasPrefix("#") { continue }
            let fields = line.split(separator: " ")
            guard fields.count == 3, let score = Double(fields[2]) else { continue }
            let reading = String(fields[0])
            building[reading, default: []].append(Unigram(value: String(fields[1]), score: score))
            let syllables = 1 + reading.count(where: { $0 == "-" })
            if syllables > span { span = syllables }
        }
        for key in building.keys where building[key]!.count > 1 {
            building[key]!.sort { $0.score > $1.score }
        }
        var chars: [String: [(String, Double)]] = [:]
        for (reading, unigrams) in building where !reading.contains("-") {
            for unigram in unigrams where unigram.value.count == 1 {
                chars[unigram.value, default: []].append((reading, unigram.score))
            }
        }
        charReadings = chars.mapValues { $0.sorted { $0.1 > $1.1 }.map(\.0) }
        map = building
        maxSpan = span
    }

    public convenience init(contentsOf url: URL) throws {
        self.init(dataText: try String(contentsOf: url, encoding: .utf8))
    }

    /// 依分數由高到低
    public func unigrams(_ reading: String) -> [Unigram] {
        map[reading] ?? []
    }

    /// 這個字的讀音，常用的在前（查不到是空陣列）
    public func readings(ofCharacter char: String) -> [String] {
        charReadings[char] ?? []
    }

    /// 推一個詞的注音：先找整個詞在詞庫裡的讀音（破音字選對），找不到就每個字取最常用的讀音。
    /// 每個字的候選讀音也一併回傳，讓使用者改破音字。查不到讀音的字回傳 nil
    public func guessReading(of word: String) -> (reading: String, choices: [[String]])? {
        let chars = word.map(String.init)
        let choices = chars.map { Array(readings(ofCharacter: $0).prefix(4)) }
        guard !chars.isEmpty, choices.allSatisfy({ !$0.isEmpty }) else { return nil }
        // 整詞查得到的讀音組合優先（每字最多 4 種，詞長 ≤ 6 才試，避免組合爆炸）
        if chars.count <= 6 {
            var combos: [[String]] = [[]]
            for options in choices {
                combos = combos.flatMap { prefix in options.map { prefix + [$0] } }
            }
            for combo in combos {
                let reading = combo.joined(separator: "-")
                if unigrams(reading).contains(where: { $0.value == word }) {
                    return (reading, choices)
                }
            }
        }
        return (choices.map { $0[0] }.joined(separator: "-"), choices)
    }

    public var entryCount: Int {
        map.values.reduce(0) { $0 + $1.count }
    }
}
