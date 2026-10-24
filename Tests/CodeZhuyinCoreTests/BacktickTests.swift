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

@Test func 中文後面接反引號_中文與反引號一起上屏() {
    let engine = InputEngine(lexicon: 測試詞庫)
    type(engine, "su3cl3")  // 你好
    let output = engine.handle(.character("`"))
    #expect(output == InputEngine.Output(handled: true, commitText: "你好`"))
    #expect(engine.isIdle)
}

@Test func 行內程式碼_反引號前打到一半的鍵當英文() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.autoSpacing = false
    #expect(engine.handle(.character("`")) == .ignored)
    type(engine, "foo")  // 被組字器吃成注音，但還沒成音節
    let output = engine.handle(.character("`"))
    #expect(output == InputEngine.Output(handled: true, commitText: "foo`"))
    #expect(engine.isIdle)
}

@Test func 中文加行內程式碼() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.autoSpacing = false
    type(engine, "su3")  // 你
    type(engine, "ls")   // 組字中：ㄠ→ㄋ（被當注音）
    let output = engine.handle(.character("`"))
    #expect(output == InputEngine.Output(handled: true, commitText: "你ls`"))
}

@Test func 底線與括號也是半形直出() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.autoSpacing = false
    for ch: Character in ["_", "(", ")", "[", "]", "{", "}", "<", ">", "=", "'", "\"", "!", "?", ":", "~", "\\", "|"] {
        #expect(engine.handle(.character(ch)) == .ignored, "空組字區的 \(ch) 要完全放行")
    }
    type(engine, "foo")
    #expect(engine.handle(.character("_")) == InputEngine.Output(handled: true, commitText: "foo_"))
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

// MARK: - 打指令：英文後的空白與 .

private let 指令詞典 = EnglishDetector(words: ["brew", "install", "llama", "google"])

@Test func 英文後空白直接出英文加空格() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.englishDetector = 指令詞典
    type(engine, "brew install ")
    #expect(engine.sheetView() == nil)
    #expect(engine.preedit().text == "brew install ")
}

@Test func 英文後的點照英文打() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.englishDetector = 指令詞典
    type(engine, "brew install llama.cpp")
    #expect(engine.handle(.enter).commitText == "brew install llama.cpp")
}

@Test func 英文空白後接中文照常組字() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.englishDetector = 指令詞典
    type(engine, "google su3")
    #expect(engine.handle(.enter).commitText == "google 你")
}

@Test func 分號Tab照鍵盤原樣送出() {
    // 大千的 ; 是 ㄤ：要分號就 ; Tab
    let engine = InputEngine(lexicon: 測試詞庫)
    _ = engine.handle(.character(";"))
    _ = engine.handle(.tab)
    #expect(engine.handle(.enter).commitText == ";")
}

@Test func 兩個字母的英文後接冒號() {
    // db: zcgpay → 舊版 db 顯示成 ㄖ，冒號按了沒反應
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.autoSpacing = false
    type(engine, "db")
    #expect(engine.englishHint == "db")
    #expect(engine.preedit().text == "db")
    #expect(engine.handle(.character(":")) == InputEngine.Output(handled: true, commitText: "db:"))
    #expect(engine.isIdle)
}

@Test func 組不出字的注音遇到點就當英文() {
    // 網址 jy.origin：j y . ＝ ㄗㄨㄡ，任何聲調都沒有這個音 → 前面是英文，. 照打，後面接續英文
    let engine = InputEngine(lexicon: 測試詞庫)
    type(engine, "jy.ori")
    #expect(engine.preedit().text == "jy.ori")
    #expect(engine.handle(.enter).commitText == "jy.ori")
}

@Test func 組得出字的注音照常吃點() {
    let engine = InputEngine(lexicon: 測試詞庫)
    type(engine, "ru,4")  // ㄐㄧㄝˋ 界
    #expect(engine.preedit().text == "界")
}

@Test func 英文後的點之後接續英文() {
    // google.com：. 之後的 com 不該再被當注音
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.englishDetector = 指令詞典
    type(engine, "google.com")
    #expect(engine.preedit().text == "google.com")
    #expect(engine.handle(.enter).commitText == "google.com")
}

// MARK: - 全形標點模式：英文後面的 : _ 不能被吞掉

@Test func 全形模式英文後的冒號照打() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.fullWidthPunctuation = true
    type(engine, "https")
    #expect(engine.handle(.character(":")) == .consumed)
    #expect(engine.preedit().text.hasPrefix("https:"))
}

@Test func 全形模式英文後的底線照打() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.fullWidthPunctuation = true
    type(engine, "config")
    #expect(engine.handle(.character("_")) == .consumed)
    #expect(engine.preedit().text.hasPrefix("config_"))
}
