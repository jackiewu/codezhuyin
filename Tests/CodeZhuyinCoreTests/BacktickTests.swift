import Testing
@testable import CodeZhuyinCore

// 碼注音的核心承諾：反引號與鍵盤上的 ASCII 標點一律原樣輸出，不開符號表、不轉全形。

private func type(_ engine: InputEngine, _ keys: String) {
    for key in keys {
        _ = engine.handle(key == " " ? .space : .character(key))
    }
}

@Test func 預設是半形標點且反引號不開符號表() {
    let engine = InputEngine(lexicon: 測試詞庫)
    #expect(!engine.fullWidthPunctuation)
    #expect(!engine.backtickOpensSymbolSheet)
}

@Test func 空組字區的反引號完全放行() {
    let engine = InputEngine(lexicon: 測試詞庫)
    #expect(engine.handle(.character("`")) == .ignored)
    #expect(engine.sheetView() == nil)
    #expect(engine.isIdle)
}

@Test func 連打三個反引號都放行_程式碼區塊() {
    let engine = InputEngine(lexicon: 測試詞庫)
    for _ in 0..<3 {
        #expect(engine.handle(.character("`")) == .ignored)
    }
    #expect(engine.isIdle)
}

@Test func 中文後面接反引號_先上屏中文再放行() {
    let engine = InputEngine(lexicon: 測試詞庫)
    type(engine, "su3cl3")  // 你好
    let output = engine.handle(.character("`"))
    #expect(output == InputEngine.Output(handled: false, commitText: "你好"))
    #expect(engine.isIdle)
}

@Test func 行內程式碼_反引號前打到一半的鍵當英文() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.autoSpacing = false
    #expect(engine.handle(.character("`")) == .ignored)
    type(engine, "foo")  // 被組字器吃成注音，但還沒成音節
    let output = engine.handle(.character("`"))
    #expect(output == InputEngine.Output(handled: false, commitText: "foo"))
    #expect(engine.isIdle)
}

@Test func 中文加行內程式碼() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.autoSpacing = false
    type(engine, "su3")  // 你
    type(engine, "ls")   // 組字中：ㄠ→ㄋ（被當注音）
    let output = engine.handle(.character("`"))
    #expect(output == InputEngine.Output(handled: false, commitText: "你ls"))
}

@Test func 底線與括號也是半形直出() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.autoSpacing = false
    for ch: Character in ["_", "(", ")", "[", "]", "{", "}", "<", ">", "=", "'", "\"", "!", "?", ":", "~", "\\", "|"] {
        #expect(engine.handle(.character(ch)) == .ignored, "空組字區的 \(ch) 要完全放行")
    }
    type(engine, "foo")
    #expect(engine.handle(.character("_")) == InputEngine.Output(handled: false, commitText: "foo"))
}

@Test func 打開全形標點後反引號仍原樣輸出() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.fullWidthPunctuation = true
    #expect(engine.handle(.character("`")) == .ignored)
    #expect(engine.handle(.character("<")) == InputEngine.Output(handled: true, commitText: "，"))
}

@Test func 英文接續段裡的反引號也是原樣() {
    let engine = InputEngine(lexicon: 測試詞庫)
    _ = engine.handle(.englishLiteral("N"))
    type(engine, "pm`")
    #expect(engine.preedit().text.hasSuffix("Npm`"))
}
