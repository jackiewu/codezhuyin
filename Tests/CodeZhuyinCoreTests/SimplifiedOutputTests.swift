import Foundation
import Testing
@testable import CodeZhuyinCore

// 輸出簡體：殼層注入的轉換與這裡相同（ICU Hant-Hans）

private func 繁轉簡(_ text: String) -> String {
    text.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? text
}

@Test func 系統的繁轉簡可用() {
    #expect(繁轉簡("這個輸入法很好用") == "这个输入法很好用")
}

@Test func 開啟簡體後組字區與上屏都套用轉換() {
    let engine = InputEngine(lexicon: 測試詞庫)
    // 測試詞庫沒有繁簡不同的字，用假轉換驗證有套用
    engine.outputTransform = { $0 == "你" ? "伱" : $0 }
    for key in "su3" { _ = engine.handle(.character(key)) }
    #expect(engine.preedit().text == "伱")
    #expect(engine.handle(.enter).commitText == "伱")
}

@Test func 簡體不影響AI校正的原文() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.outputTransform = { $0 == "你" ? "伱" : $0 }
    for key in "su3cl3" { _ = engine.handle(.character(key)) }
    #expect(engine.preedit().text == "伱好")
    #expect(engine.correctionTarget?.text == "你好")
}

@Test func 候選窗顯示轉換後的字() {
    let engine = InputEngine(lexicon: 測試詞庫)
    engine.outputTransform = { $0.replacingOccurrences(of: "你", with: "伱") }
    for key in "su3" { _ = engine.handle(.character(key)) }
    _ = engine.handle(.space)
    #expect(engine.sheetView()?.items.contains { $0.value == "伱" } == true)
}
