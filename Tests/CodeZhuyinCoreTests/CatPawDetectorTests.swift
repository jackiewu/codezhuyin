import Testing
@testable import CodeZhuyinCore

@Test func 正常快打不會鎖() {
    var detector = CatPawDetector()
    // 每 0.06 秒一個鍵（每秒 16 鍵，比打字最快的人還快）
    for (i, key) in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].enumerated() {
        let r1 = detector.process(keyCode: UInt16(key), isRepeat: false, at: Double(i) * 0.06)
        #expect(r1 == .pass)
    }
    #expect(!detector.isLocked)
}

@Test func 一瞬間按下一堆鍵就鎖() {
    var detector = CatPawDetector()
    let actions = (0..<5).map { detector.process(keyCode: UInt16($0), isRepeat: false, at: 1.0 + Double($0) * 0.005) }
    #expect(actions == [.pass, .pass, .pass, .lockNow, .swallow])  // 0.03 秒內第 4 個鍵就鎖
    #expect(detector.isLocked)
    let r2 = detector.process(keyCode: 9, isRepeat: false, at: 1.5)
    #expect(r2 == .swallow)
}

@Test func 字母壓著不放就鎖_刪除鍵不算() {
    var detector = CatPawDetector()
    _ = detector.process(keyCode: 0, isRepeat: false, at: 0)
    var last = CatPawDetector.Action.pass
    for i in 1...40 { last = detector.process(keyCode: 0, isRepeat: true, at: 0.5 + Double(i) * 0.05) }
    #expect(last == .lockNow)

    var deleting = CatPawDetector()
    _ = deleting.process(keyCode: 51, isRepeat: false, at: 0)
    for i in 1...100 { _ = deleting.process(keyCode: 51, isRepeat: true, at: 0.5 + Double(i) * 0.05) }
    #expect(!deleting.isLocked)
}

@Test func Esc連按兩下解鎖() {
    var detector = CatPawDetector()
    for k in 0..<5 { _ = detector.process(keyCode: UInt16(k), isRepeat: false, at: Double(k) * 0.005) }
    let r3 = detector.process(keyCode: 53, isRepeat: false, at: 1.0)
    #expect(r3 == .swallow)
    let r4 = detector.process(keyCode: 53, isRepeat: false, at: 1.4)
    #expect(r4 == .unlockNow)
    let r5 = detector.process(keyCode: 0, isRepeat: false, at: 2.0)
    #expect(r5 == .pass)
}

@Test func 停手五秒自動解鎖() {
    var detector = CatPawDetector()
    for k in 0..<5 { _ = detector.process(keyCode: UInt16(k), isRepeat: false, at: Double(k) * 0.005) }
    let r6 = detector.unlockIfQuiet(at: 3.0)
    #expect(!r6)
    let r7 = detector.unlockIfQuiet(at: 5.1)
    #expect(r7)
    #expect(!detector.isLocked)
}
