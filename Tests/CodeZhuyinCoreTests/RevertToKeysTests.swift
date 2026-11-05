import Testing
@testable import CodeZhuyinCore

// 打成中文才發現是英文：Shift 換回當初按的鍵

private func type(_ engine: InputEngine, _ keys: String) {
    for key in keys {
        _ = engine.handle(key == " " ? .space : .character(key))
    }
}

@Test func 組字中照按的鍵送出() {
    let engine = InputEngine(lexicon: 測試詞庫)
    type(engine, "su3cl3")  // 你好
    #expect(engine.flushAsKeys() == "su3cl3")
    #expect(engine.isIdle)
    #expect(engine.lastCommit == nil)  // 送的是英文，沒有可換回的中文
}

@Test func 組字中照按的鍵送出_包含打到一半的注音() {
    let engine = InputEngine(lexicon: 測試詞庫)
    type(engine, "su3g")
    #expect(engine.flushAsKeys() == "su3g")
}

@Test func 上屏後記得文字和按鍵() {
    let engine = InputEngine(lexicon: 測試詞庫)
    type(engine, "su3cl3")
    let text = engine.flush()
    #expect(text == "你好")
    #expect(engine.lastCommit?.text == "你好")
    #expect(engine.lastCommit?.keys == "su3cl3")
}
