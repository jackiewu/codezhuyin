import Testing
@testable import CodeZhuyinCore

@Test func 按鍵抽象可比較() {
    #expect(KeyInput.space == KeyInput.space)
    #expect(KeyInput.character("a") != KeyInput.character("b"))
}
