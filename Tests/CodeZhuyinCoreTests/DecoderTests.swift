import Testing
@testable import CodeZhuyinCore

let 測試詞庫 = Lexicon(dataText: """
# format org.openvanilla.mcbopomofo.sorted
ㄋㄧˇ 你 -4.0
ㄋㄧˇ 妳 -6.0
ㄋㄧˇ 擬 -7.0
ㄏㄠˇ 好 -4.5
ㄋㄧˇ-ㄏㄠˇ 你好 -6.0
ㄕˋ 是 -4.0
ㄕˋ-ㄐㄧㄝˋ 世界 -5.0
ㄐㄧㄝˋ 界 -7.0
ㄍㄠ 高 -5.5
ㄅㄚ 八 -5.0
ㄉㄚˇ 打 -5.0
ㄓ 知 -4.8
ㄕ 濕 -8.0
""")

@Test func 詞庫載入與排序() {
    #expect(測試詞庫.maxSpan == 2)
    #expect(測試詞庫.unigrams("ㄋㄧˇ").map(\.value) == ["你", "妳", "擬"])
    #expect(測試詞庫.unigrams("不存在").isEmpty)
}

@Test func 整句組句偏好長詞() {
    let decoder = SentenceDecoder(lexicon: 測試詞庫)
    let result = decoder.walk([.reading("ㄋㄧˇ"), .reading("ㄏㄠˇ")])
    #expect(result.map(\.value) == ["你好"])  // -6.0 勝過 你+好（-8.5）
}

@Test func pin_強制改字後重走() {
    let decoder = SentenceDecoder(lexicon: 測試詞庫)
    let pin = DecodedSegment(start: 0, length: 1, value: "妳", reading: "ㄋㄧˇ")
    let result = decoder.walk([.reading("ㄋㄧˇ"), .reading("ㄏㄠˇ")], pins: [pin])
    #expect(result.map(\.value) == ["妳", "好"])  // pin 拆散了「你好」
}

@Test func 未知讀音以注音原樣通行() {
    let decoder = SentenceDecoder(lexicon: 測試詞庫)
    let result = decoder.walk([.reading("ㄨㄤˋ"), .reading("ㄕˋ")])
    #expect(result.map(\.value) == ["ㄨㄤˋ", "是"])
}

@Test func 直出片段原樣走過() {
    let decoder = SentenceDecoder(lexicon: 測試詞庫)
    let result = decoder.walk([.reading("ㄕˋ"), .literal("O"), .literal("K")])
    #expect(result.map(\.value) == ["是", "O", "K"])
}

@Test func 候選長詞在前() {
    let decoder = SentenceDecoder(lexicon: 測試詞庫)
    let segments = decoder.candidateSegments([.reading("ㄋㄧˇ"), .reading("ㄏㄠˇ")], start: 0)
    #expect(segments.first?.value == "你好")
    #expect(segments.map(\.value).contains("妳"))
}

@Test func pin_吻合的詞可以把pin包進去() {
    // 先選了「私」再打 ㄧㄠˋ：要組出「私鑰」，不是被釘死成「私要」
    let lexicon = Lexicon(dataText: """
    # format org.openvanilla.mcbopomofo.sorted
    ㄙ 思 -7.0
    ㄙ 私 -9.0
    ㄧㄠˋ 要 -5.6
    ㄧㄠˋ 鑰 -11.8
    ㄙ-ㄧㄠˋ 私鑰 -15.2
    """)
    let decoder = SentenceDecoder(lexicon: lexicon)
    let pin = DecodedSegment(start: 0, length: 1, value: "私", reading: "ㄙ")
    #expect(decoder.walk([.reading("ㄙ"), .reading("ㄧㄠˋ")], pins: [pin]).map(\.value) == ["私鑰"])
    // 不吻合的詞仍然不能蓋過 pin
    let other = DecodedSegment(start: 0, length: 1, value: "思", reading: "ㄙ")
    #expect(decoder.walk([.reading("ㄙ"), .reading("ㄧㄠˋ")], pins: [other]).map(\.value) == ["思", "要"])
}

@Test func 單字選過很多次_不會把詞拆散() {
    // 「是」「測」都被選過很多次：仍然組出詞庫的「測試」，不是「測是」
    let lexicon = Lexicon(dataText: """
    # format org.openvanilla.mcbopomofo.sorted
    ㄘㄜˋ 策 -8.15
    ㄘㄜˋ 測 -8.56
    ㄕˋ 是 -4.56
    ㄕˋ 試 -8.06
    ㄘㄜˋ-ㄕˋ 測試 -10.2
    """)
    var decoder = SentenceDecoder(lexicon: lexicon)
    decoder.scoreBonus = { _, value in value == "是" ? 7.0 : value == "測" ? 5.0 : 0 }
    #expect(decoder.walk([.reading("ㄘㄜˋ"), .reading("ㄕˋ")]).map(\.value) == ["測試"])
    // 單獨一個音時，選過的字照樣排第一（加分要大過跟第一名的差距）
    #expect(decoder.walk([.reading("ㄘㄜˋ")]).map(\.value) == ["測"])
    decoder.scoreBonus = { _, value in value == "試" ? 4.0 : 0 }
    #expect(decoder.walk([.reading("ㄕˋ")]).map(\.value) == ["試"])
}

@Test func 選字只換選到的字_被切到的詞其餘的字不變() {
    // 在試試看 → 選「再試」：剩下的「試看」維持原樣，不被重組成「是看」
    let lexicon = Lexicon(dataText: """
    # format org.openvanilla.mcbopomofo.sorted
    ㄗㄞˋ 在 -5.02
    ㄗㄞˋ 再 -7.12
    ㄕˋ 是 -4.56
    ㄕˋ 試 -8.06
    ㄎㄢˋ 看 -6.37
    ㄗㄞˋ-ㄕˋ 在世 -11.54
    ㄗㄞˋ-ㄕˋ 再試 -13.48
    ㄕˋ-ㄕˋ-ㄎㄢˋ 試試看 -11.62
    """)
    let engine = InputEngine(lexicon: lexicon)
    engine.caretMarkEnabled = false
    for key in "y94g4g4d04" { _ = engine.handle(.character(key)) }
    #expect(engine.preedit().text == "在試試看")
    for _ in 0..<4 { _ = engine.handle(.arrowLeft) }
    _ = engine.handle(.arrowDown)
    guard let index = engine.sheetView()?.items.firstIndex(where: { $0.value == "再試" }) else {
        Issue.record("候選窗裡找不到「再試」")
        return
    }
    _ = engine.handle(.character(Character("\(index + 1)")))
    #expect(engine.preedit().text == "再試試看")
}

@Test func 選過詞改好的整句_下次打到一半補字也不會被改回() {
    // 改成「再試試看」上屏一次後，下次打到「再試試」再補「看」，前面不會被改回「在」
    let lexicon = Lexicon(dataText: """
    # format org.openvanilla.mcbopomofo.sorted
    ㄗㄞˋ 在 -5.02
    ㄗㄞˋ 再 -7.12
    ㄕˋ 是 -4.56
    ㄕˋ 試 -8.06
    ㄎㄢˋ 看 -6.37
    ㄗㄞˋ-ㄕˋ 在世 -11.54
    ㄗㄞˋ-ㄕˋ 再試 -13.48
    ㄕˋ-ㄕˋ-ㄎㄢˋ 試試看 -11.62
    """)
    let store = UserPhraseStore(fileURL: nil)
    let first = InputEngine(lexicon: lexicon)
    first.userPhrases = store
    first.caretMarkEnabled = false
    for key in "y94g4g4d04" { _ = first.handle(.character(key)) }
    for _ in 0..<4 { _ = first.handle(.arrowLeft) }
    _ = first.handle(.arrowDown)
    guard let index = first.sheetView()?.items.firstIndex(where: { $0.value == "再試" }) else {
        Issue.record("候選窗裡找不到「再試」")
        return
    }
    _ = first.handle(.character(Character("\(index + 1)")))
    #expect(first.handle(.enter).commitText == "再試試看")

    let second = InputEngine(lexicon: lexicon)
    second.userPhrases = store
    second.caretMarkEnabled = false
    for key in "y94g4g4d04" { _ = second.handle(.character(key)) }
    #expect(second.preedit().text == "再試試看")
}
