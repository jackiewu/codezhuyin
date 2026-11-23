import Testing
@testable import CodeZhuyinCore

private let 情境詞庫 = Lexicon(dataText: """
# format org.openvanilla.mcbopomofo.sorted
ㄙ 私 -5.0
ㄙ 思 -4.5
ㄧㄠˋ 要 -3.0
ㄧㄠˋ 鑰 -9.0
ㄩㄝˋ 鑰 -10.0
ㄉㄢ 單 -5.0
ㄕㄢˋ 單 -8.0
ㄆㄧㄣˇ 品 -6.0
ㄉㄢ-ㄆㄧㄣˇ 單品 -7.0
""")

@Test func 推注音_破音字用整詞讀音() {
    #expect(情境詞庫.guessReading(of: "單品")?.reading == "ㄉㄢ-ㄆㄧㄣˇ")
    let guess = 情境詞庫.guessReading(of: "私鑰")
    #expect(guess?.reading == "ㄙ-ㄧㄠˋ")
    #expect(guess?.choices[1] == ["ㄧㄠˋ", "ㄩㄝˋ"])
    #expect(情境詞庫.guessReading(of: "私咖") == nil)  // 咖 查不到
}

@Test func 打開的情境詞優先出現_關掉就沒有() {
    let store = ContextStore(fileURL: nil)
    var pack = ContextPack(name: "資安", terms: [ContextTerm(value: "私鑰", reading: "ㄙ-ㄧㄠˋ")])
    store.upsert(pack)
    let engine = InputEngine(lexicon: 情境詞庫)
    engine.contextUnigrams = { store.unigrams(reading: $0) }
    for key in "n ul4" { _ = engine.handle(key == " " ? .space : .character(key)) }  // ㄙ＋一聲、ㄧㄠˋ
    #expect(engine.preedit().text == "私鑰")

    pack.enabled = false
    store.upsert(pack)
    #expect(store.unigrams(reading: "ㄙ-ㄧㄠˋ").isEmpty)
}

@Test func 情境英文詞另外列出() {
    let store = ContextStore(fileURL: nil)
    store.upsert(ContextPack(name: "咖啡", terms: [ContextTerm(value: "Chemex", reading: nil), ContextTerm(value: "單品", reading: "ㄉㄢ-ㄆㄧㄣˇ")]))
    #expect(store.englishWords == ["Chemex"])
    store.upsert(ContextPack(name: "關掉的", enabled: false, terms: [ContextTerm(value: "V60", reading: nil)]))
    #expect(store.englishWords == ["Chemex"])
}

@Test func 解析AI回覆_容許說明文字與別名() {
    let reply = """
    好的，以下是情境 JSON：
    ```json
    {"name": "咖啡烘豆", "description": "手沖、杯測",
     "terms": [{"term": "耶加雪菲"}, {"term": "Chemex"}, {"term": "UV烘焙"}, {"term": "豆"}],
     "keywords": ["V60", "耶加雪菲"]}
    ```
    希望有幫助！
    """
    let draft = ContextImport.parse(reply)
    #expect(draft?.name == "咖啡烘豆")
    #expect(draft?.chinese == ["耶加雪菲"])
    #expect(draft?.english == ["Chemex", "V60"])
    #expect(draft?.skipped.map { $0.0 } == ["UV烘焙", "豆"])
    #expect(ContextImport.parse("沒有 JSON") == nil)
}

@Test func 既有情境匯入_合併略過重複_保留改過的注音() {
    var pack = ContextPack(name: "資安", terms: [
        ContextTerm(value: "私鑰", reading: "ㄙ-ㄩㄝˋ"),  // 使用者改過的讀音
        ContextTerm(value: "Vault", reading: nil),
    ])
    let added = pack.importTerms([
        ContextTerm(value: "私鑰", reading: "ㄙ-ㄧㄠˋ"),
        ContextTerm(value: "單品", reading: "ㄉㄢ-ㄆㄧㄣˇ"),
        ContextTerm(value: "Vault", reading: nil),
        ContextTerm(value: "SOPS", reading: nil),
    ], replacing: false)
    #expect(added == 2)
    #expect(pack.terms.map(\.value) == ["私鑰", "Vault", "單品", "SOPS"])
    #expect(pack.terms[0].reading == "ㄙ-ㄩㄝˋ")
}

@Test func 既有情境匯入_取代只留新的詞() {
    var pack = ContextPack(name: "資安", terms: [
        ContextTerm(value: "私鑰", reading: "ㄙ-ㄩㄝˋ"),
        ContextTerm(value: "Vault", reading: nil),
    ])
    let added = pack.importTerms([
        ContextTerm(value: "私鑰", reading: "ㄙ-ㄧㄠˋ"),
        ContextTerm(value: "SOPS", reading: nil),
    ], replacing: true)
    #expect(added == 1)
    #expect(pack.terms.map(\.value) == ["私鑰", "SOPS"])
    #expect(pack.terms[0].reading == "ㄙ-ㄩㄝˋ")  // 舊詞沿用改過的讀音
}

@Test func 情境匯出的JSON可以再匯入() {
    let pack = ContextPack(name: "咖啡", detail: "手沖", terms: [
        ContextTerm(value: "單品", reading: "ㄉㄢ-ㄆㄧㄣˇ"),
        ContextTerm(value: "V60", reading: nil),
    ])
    let draft = ContextImport.parse(ContextImport.export(pack))
    #expect(draft?.name == "咖啡")
    #expect(draft?.detail == "手沖")
    #expect(draft?.chinese == ["單品"])
    #expect(draft?.english == ["V60"])
    #expect(ContextImport.prompt(adding: pack).contains("單品"))
}
