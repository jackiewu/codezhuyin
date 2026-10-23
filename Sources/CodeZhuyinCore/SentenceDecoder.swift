/// 組字區元素：一個已完成的注音音節，或一段直出文字（英文、標點）。
public enum Element: Equatable, Sendable {
    case reading(String)  // canonical 注音（含調號），如 "ㄋㄧˇ"
    case literal(String)  // 直出片段，原樣上屏

    public var readingValue: String? {
        if case .reading(let r) = self { return r }
        return nil
    }
}

/// 詞圖上走出來的一段：elements[start..<start+length] 對應的詞
public struct DecodedSegment: Equatable, Sendable {
    public let start: Int
    public let length: Int
    public let value: String
    public let reading: String?  // literal 段為 nil

    public init(start: Int, length: Int, value: String, reading: String?) {
        self.start = start
        self.length = length
        self.value = value
        self.reading = reading
    }

    public var end: Int { start + length }
}

/// 整句解碼：音節串 → 詞圖 → 最佳路徑（unigram 分數 DP）。
/// pin（使用者指定的候選）強制走過，等長重疊的其他節點一律跳過。
public struct SentenceDecoder {
    private let lexicon: Lexicon
    /// 使用者學習加權：(讀音, 詞) → 額外分數
    public var scoreBonus: ((String, String) -> Double)?
    /// 使用者自造詞：讀音 → 額外候選（與內建詞庫合流）
    public var extraUnigrams: ((String) -> [Unigram])?
    /// 使用者語料的詞對加分：(前詞, 後詞) → 加分（沒打過就 0）
    public var transitionBonus: ((String, String) -> Double)?
    /// 詞對加分的權重：2.0 由 --eval --train 掃描而得
    /// （同句打 1 次 87%、3 次 96%；未學過的句子完全不受影響）
    public var transitionWeight = 2.0
    /// 每個跨距取幾個候選進詞圖：>1 才讓上下文有選擇餘地
    public var candidateDepth = 4
    /// 相似音（ㄓㄗ、ㄕㄙ、ㄣㄥ…互通）：開啟後打錯也找得到字
    public var fuzzyEnabled = false
    /// 相似音候選的罰分：確保正確讀音永遠排在前面，只在沒有更好選擇時遞補
    private let fuzzyPenalty = -6.0
    /// 未知讀音（詞庫查不到的單音節）的懲罰分數
    private let unknownPenalty = -17.0
    /// 每節點固定罰分：偏好長詞路徑，補償 unigram 獨立性假設低估長詞的問題。
    /// −2.0 由 codezhuyin-cli --eval 對 90 句自然語句掃描而得（80%→83%）。
    /// ponytail: 從詞庫片語推的 char-bigram 實測會倒退（見 commit 說明），
    /// 真要再進一步需要連續文本語料的詞對統計。
    private let nodePenalty = -2.0

    public init(lexicon: Lexicon) {
        self.lexicon = lexicon
    }

    /// 詞圖搜尋跨距：至少留 6，使用者自造詞不受小詞庫的 maxSpan 限制
    private var searchSpan: Int { max(lexicon.maxSpan, 6) }

    private func adjusted(_ unigram: Unigram, reading: String) -> Double {
        unigram.score + (scoreBonus?(reading, unigram.value) ?? 0)
    }

    /// 內建詞庫＋使用者詞＋相似音變體合流，同值保留調整後分數較高者
    private func allUnigrams(_ reading: String) -> [Unigram] {
        let extras = extraUnigrams?(reading) ?? []
        guard fuzzyEnabled || !extras.isEmpty else { return lexicon.unigrams(reading) }
        var pool = lexicon.unigrams(reading) + extras
        if fuzzyEnabled {
            for variant in FuzzyReading.variants(of: reading) {
                pool += lexicon.unigrams(variant).map {
                    Unigram(value: $0.value, score: $0.score + fuzzyPenalty)
                }
            }
        }
        var best: [String: Unigram] = [:]
        for unigram in pool {
            if let current = best[unigram.value],
               adjusted(current, reading: reading) >= adjusted(unigram, reading: reading) {
                continue
            }
            best[unigram.value] = unigram
        }
        return Array(best.values)
    }

    /// 詞圖上的一個狀態：以某位置結尾的節點，及走到它的最佳分數與回溯指標
    private struct State {
        let segment: DecodedSegment
        let score: Double
        let prevIndex: Int  // states[segment.start] 的索引；-1 代表句首
    }

    /// Viterbi：逐節點保留狀態，轉移時加上使用者語料的詞對加分
    public func walk(_ elements: [Element], pins: [DecodedSegment] = []) -> [DecodedSegment] {
        let n = elements.count
        guard n > 0 else { return [] }

        var states = [[State]](repeating: [], count: n + 1)

        // 只「跨過」pin 邊界的詞段不能走；把 pin 整個包在裡面、而且那幾個字跟 pin 一樣的詞可以走：
        // 先選了「私」再打 ㄧㄠˋ，要能組出詞庫裡的「私鑰」，而不是被釘死成「私」＋「要」
        func conflictsWithPin(start: Int, end: Int) -> Bool {
            pins.contains { pin in
                let overlaps = pin.start < end && start < pin.end
                let exact = pin.start == start && pin.end == end
                let inside = start <= pin.start && pin.end <= end
                return overlaps && !exact && !inside
            }
        }
        func containedPins(start: Int, end: Int) -> [DecodedSegment] {
            pins.filter { start <= $0.start && $0.end <= end && !($0.start == start && $0.end == end) }
        }

        for end in 1...n {
            let earliest = max(0, end - searchSpan)
            for start in earliest..<end {
                guard start == 0 || !states[start].isEmpty else { continue }
                guard !conflictsWithPin(start: start, end: end) else { continue }
                let inner = containedPins(start: start, end: end)
                var candidates = nodes(elements, start: start, end: end, pins: pins)
                if !inner.isEmpty {
                    // 一個音節一個字才能對位；吻合的詞跟 pin 同等待遇（0 分），同分時仍依詞頻排
                    candidates = candidates.compactMap { node in
                        let chars = Array(node.segment.value)
                        guard chars.count == end - start, inner.allSatisfy({ pin in
                            String(chars[(pin.start - start)..<(pin.end - start)]) == pin.value
                        }) else { return nil }
                        return Node(segment: node.segment, score: node.score * 0.01)
                    }
                }
                for node in candidates {
                    let base = node.score + nodePenalty
                    if start == 0 {
                        states[end].append(State(segment: node.segment, score: base, prevIndex: -1))
                        continue
                    }
                    var bestScore = -Double.infinity
                    var bestPrev = -1
                    for (index, previous) in states[start].enumerated() {
                        let bonus = transitionBonus.map {
                            transitionWeight * $0(previous.segment.value, node.segment.value)
                        } ?? 0
                        let score = previous.score + base + bonus
                        if score > bestScore {
                            bestScore = score
                            bestPrev = index
                        }
                    }
                    if bestPrev >= 0 {
                        states[end].append(State(segment: node.segment, score: bestScore, prevIndex: bestPrev))
                    }
                }
            }
        }

        var result: [DecodedSegment] = []
        var position = n
        var index = states[n].enumerated().max { $0.element.score < $1.element.score }?.offset ?? -1
        while position > 0, index >= 0 {
            let state = states[position][index]
            result.append(state.segment)
            position = state.segment.start
            index = state.prevIndex
        }
        return result.reversed()
    }

    /// 候選字窗用：從 start 起所有跨距的候選，長詞在前、同長依分數（含學習加權）
    public func candidateSegments(_ elements: [Element], start: Int) -> [DecodedSegment] {
        var segments: [DecodedSegment] = []
        for length in stride(from: min(elements.count - start, searchSpan), through: 1, by: -1) {
            guard let reading = joinedReading(elements, start: start, end: start + length) else { continue }
            let ranked = allUnigrams(reading)
                .sorted { adjusted($0, reading: reading) > adjusted($1, reading: reading) }
            for unigram in ranked {
                segments.append(DecodedSegment(start: start, length: length, value: unigram.value, reading: reading))
            }
        }
        return segments
    }

    /// 按 ↓ 開的候選：先列從詞段開頭起算的整個詞（「一件」「一見」），
    /// 再列「結束在游標左邊那個字」的較短詞與單字（「件」「鍵」），最後才是其餘從開頭起算的短詞與單字。
    /// 這樣游標停在「一件」後面時，「件」可以單獨換成「鍵」，不用先把游標移回去。
    public func candidateSegments(_ elements: [Element], segmentStart start: Int, length: Int, index: Int) -> [DecodedSegment] {
        let fromStart = candidateSegments(elements, start: start)
        guard index > start else { return fromStart }
        var tail: [DecodedSegment] = []
        for tailStart in (start + 1)...index {
            guard let reading = joinedReading(elements, start: tailStart, end: index + 1) else { continue }
            tail += allUnigrams(reading)
                .sorted { adjusted($0, reading: reading) > adjusted($1, reading: reading) }
                .map { DecodedSegment(start: tailStart, length: index + 1 - tailStart, value: $0.value, reading: reading) }
        }
        let whole = fromStart.filter { $0.length >= length }
        return whole + tail + fromStart.filter { $0.length < length }
    }

    private struct Node {
        let segment: DecodedSegment
        let score: Double
    }

    private func nodes(_ elements: [Element], start: Int, end: Int, pins: [DecodedSegment]) -> [Node] {
        // pin 精確命中：只走 pin
        if let pin = pins.first(where: { $0.start == start && $0.end == end }) {
            return [Node(segment: pin, score: 0)]  // 使用者欽點，分數歸零（最高待遇）
        }
        let length = end - start
        if length == 1, case .literal(let text) = elements[start] {
            return [Node(segment: DecodedSegment(start: start, length: 1, value: text, reading: nil), score: -0.1)]
        }
        guard let reading = joinedReading(elements, start: start, end: end) else { return [] }
        let unigrams = allUnigrams(reading)
        if !unigrams.isEmpty {
            // 取前 K 名進詞圖：只留第一名的話，詞對加分沒有可選的對象
            let ranked = unigrams
                .sorted { adjusted($0, reading: reading) > adjusted($1, reading: reading) }
                .prefix(max(1, candidateDepth))
            return ranked.map { unigram in
                Node(
                    segment: DecodedSegment(start: start, length: length, value: unigram.value, reading: reading),
                    score: adjusted(unigram, reading: reading)
                )
            }
        }
        if length == 1 {
            // 詞庫沒有的讀音：原樣顯示注音，重罰但仍可通行
            return [Node(segment: DecodedSegment(start: start, length: 1, value: reading, reading: reading), score: unknownPenalty)]
        }
        return []
    }

    private func joinedReading(_ elements: [Element], start: Int, end: Int) -> String? {
        var parts: [String] = []
        for index in start..<end {
            guard let reading = elements[index].readingValue else { return nil }
            parts.append(reading)
        }
        return parts.joined(separator: "-")
    }
}
