/// 貓貓模式：偵測貓踩鍵盤（或小孩亂按）就鎖住輸入（純邏輯，殼層把 keyDown 餵進來）。
/// 規則：
/// 1. 一瞬間按下很多個不同的鍵（0.03 秒內 4 個、0.08 秒內 5 個）：人打字再快也做不到
/// 2. 同一個字母、空白鍵連發超過 2.5 秒（貓坐在鍵盤上）。刪除鍵、方向鍵不算，長按刪字是正常操作
/// 鎖住後所有按鍵都吞掉；Esc 連按兩下（2 秒內）或停手 5 秒解鎖
public struct CatPawDetector: Sendable {

    public enum Action: Equatable, Sendable {
        case pass      // 正常按鍵，照常處理
        case lockNow   // 剛判定是貓：吞掉並顯示鎖定
        case swallow   // 鎖定中：吞掉
        case unlockNow // 解鎖（這個鍵本身也吞掉）
    }

    public static let quietUnlockSeconds = 5.0

    public private(set) var isLocked = false
    private var recent: [(keyCode: UInt16, at: Double)] = []
    private var holdKey: UInt16?
    private var holdStart = 0.0
    private var lastKeyAt = -100.0
    private var lastEscapeAt = -100.0

    private static let escape: UInt16 = 53
    /// 長按是正常操作的鍵：Delete、Forward Delete、方向鍵、Page Up/Down、Home/End
    private static let holdable: Set<UInt16> = [51, 117, 123, 124, 125, 126, 116, 121, 115, 119]

    public init() {}

    public mutating func process(keyCode: UInt16, isRepeat: Bool, at time: Double) -> Action {
        defer { lastKeyAt = time }
        if isLocked {
            if time - lastKeyAt >= Self.quietUnlockSeconds {
                unlock()
                return .pass  // 停手夠久，這個鍵是人按的
            }
            guard keyCode == Self.escape, !isRepeat else { return .swallow }
            if time - lastEscapeAt <= 2.0 {
                unlock()
                return .unlockNow
            }
            lastEscapeAt = time
            return .swallow
        }

        if isRepeat {
            if holdKey != keyCode { holdKey = keyCode; holdStart = time }
            if !Self.holdable.contains(keyCode), time - holdStart >= 2.5 { return lock() }
            return .pass
        }
        holdKey = keyCode
        holdStart = time

        recent.append((keyCode, time))
        recent.removeAll { time - $0.at > 0.08 }
        if distinctKeys(within: 0.08, now: time) >= 5 || distinctKeys(within: 0.03, now: time) >= 4 {
            return lock()
        }
        return .pass
    }

    /// 停手夠久就解鎖（殼層的計時器呼叫，用來收掉鎖定提示）
    public mutating func unlockIfQuiet(at time: Double) -> Bool {
        guard isLocked, time - lastKeyAt >= Self.quietUnlockSeconds else { return false }
        unlock()
        return true
    }

    private func distinctKeys(within window: Double, now: Double) -> Int {
        Set(recent.filter { now - $0.at <= window }.map { $0.keyCode }).count
    }

    private mutating func lock() -> Action {
        isLocked = true
        recent.removeAll()
        holdKey = nil
        lastEscapeAt = -100
        return .lockNow
    }

    private mutating func unlock() {
        isLocked = false
        recent.removeAll()
        holdKey = nil
        lastEscapeAt = -100
    }
}
