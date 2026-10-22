import Cocoa
import SwiftUI

/// 偏好設定鍵（UserDefaults，@AppStorage 同鍵共用）
enum SettingKey {
    static let shiftToggle = "shiftToggle"
    static let englishHint = "englishHint"
    static let fullWidthPunctuation = "fullWidthPunctuation"
    static let backtickSymbolSheet = "backtickSymbolSheet"
    static let simplifiedOutput = "simplifiedOutput"
    static let spaceCommitsEnglish = "spaceCommitsEnglish"
    static let autoSpacing = "autoSpacing"
    static let pageSize = "pageSize"
    static let fuzzyReading = "fuzzyReading"
    static let associations = "associations"
    static let smartInput = "smartInput"  // 智慧輸入總開關：打勾才啟動 Breeze
    static let aiCompletion = "aiCompletion"
    static let smartCorrection = "smartCorrection"
    static let voiceInput = "voiceInput"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            shiftToggle: true,
            englishHint: true,
            fullWidthPunctuation: false,
            backtickSymbolSheet: false,
            simplifiedOutput: false,
            spaceCommitsEnglish: true,
            autoSpacing: true,
            pageSize: 9,
            fuzzyReading: false,
            associations: true,
            smartInput: false,
            aiCompletion: true,
            smartCorrection: true,
            voiceInput: true,
        ])
    }
}

private struct SettingsView: View {
    @AppStorage(SettingKey.shiftToggle) private var shiftToggle = true
    @AppStorage(SettingKey.englishHint) private var englishHint = true
    @AppStorage(SettingKey.fullWidthPunctuation) private var fullWidthPunctuation = false
    @AppStorage(SettingKey.backtickSymbolSheet) private var backtickSymbolSheet = false
    @AppStorage(SettingKey.simplifiedOutput) private var simplifiedOutput = false
    @AppStorage(SettingKey.spaceCommitsEnglish) private var spaceCommitsEnglish = true
    @AppStorage(SettingKey.autoSpacing) private var autoSpacing = true
    @AppStorage(SettingKey.pageSize) private var pageSize = 9
    @AppStorage(SettingKey.fuzzyReading) private var fuzzyReading = false
    @AppStorage(SettingKey.associations) private var associations = true
    @AppStorage(SettingKey.smartInput) private var smartInput = false
    @AppStorage(SettingKey.aiCompletion) private var aiCompletion = true
    @AppStorage(SettingKey.smartCorrection) private var smartCorrection = true
    @AppStorage(SettingKey.voiceInput) private var voiceInput = true
    @State private var showingResetAlert = false
    @State private var didReset = false

    /// 由控制器注入：清除學習資料、開啟學習資料視窗
    var onReset: () -> Void = {}
    var onShowLearnedData: () -> Void = {}

    private var smartInputReady: Bool { SmartInput.serverPath != nil && SmartInput.modelExists }

    private var smartInputNote: String {
        if SmartInput.serverPath == nil { return "需要 llama.cpp：在終端機執行 brew install llama.cpp" }
        if !SmartInput.modelExists {
            return "需要模型檔，放在：\(SmartInput.modelURL?.path ?? "")"
        }
        return "使用開源模型 Breeze（聯發科），在本機執行、不連網。開啟時約佔 4 GB 記憶體，關閉就釋放。"
    }

    /// 開關一動就立刻啟動／關閉 Breeze（不用等下一次打字）
    private func syncSmartInput() {
        SmartInput.setEnabled(smartInput && (aiCompletion || smartCorrection))
    }

    private var mixedTab: some View {
        Form {
            Section {
                Toggle("Shift 單擊切換中／英", isOn: $shiftToggle)
                Toggle("中英自動偵測（中打英 Tab 上字；英打注音自動切回）", isOn: $englishHint)
                Toggle("中英之間自動加空白（我愛 mac）", isOn: $autoSpacing)
                Toggle(isOn: $spaceCommitsEnglish) {
                    Text(verbatim: "英文後按空白＝英文加空格，. , / ; - 照英文打（brew install llama.cpp）")
                }
                Text(verbatim: "關閉時空白改開中英並列選字。開啟時要並列選字按 ↓。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Shift＋字母永遠直接輸出英文字母。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var chineseTab: some View {
        Form {
            Section {
                Toggle("輸出簡體中文（选字窗与上屏文字都是简体）", isOn: $simplifiedOutput)
                Toggle("全形標點（，。？！…）", isOn: $fullWidthPunctuation)
                // verbatim：字串字面量會被當 Markdown，成對的 ` 會變成程式碼樣式而消失
                Toggle(isOn: $backtickSymbolSheet) { Text(verbatim: "反引號 ` 開符號表（關閉＝` 直接輸出）") }
                Text(verbatim: "預設全部半形：` _ ( ) [ ] = 等鍵跟英文鍵盤一樣直接輸出，Markdown 與程式碼不用切換。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Toggle("相似音修正（ㄓㄗ、ㄕㄙ、ㄣㄥ 打錯也找得到）", isOn: $fuzzyReading)
                Text("開啟後正確讀音仍排最前面，相似音只在後面遞補。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Toggle("聯想詞（打字時提示你常接的下一個詞，Tab＋數字選）", isOn: $associations)

                Picker("候選字窗每頁字數", selection: $pageSize) {
                    Text("7").tag(7)
                    Text("9").tag(9)
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
    }

    private var voiceTab: some View {
        Form {
            Section {
                Toggle("單按右 Option 開始講話，再按一下結束", isOn: $voiceInput)
                Text("打一半的字會先送出，講的話接在後面。Esc 取消。使用 Mac 內建語音辨識，在本機執行、不連網。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var smartTab: some View {
        Form {
            Section {
                Toggle("啟用智慧輸入（Breeze）", isOn: $smartInput)
                    .disabled(!smartInputReady)
                    .onChange(of: smartInput) { _, _ in syncSmartInput() }
                Text(smartInputNote)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Group {
                    Toggle("AI 補句（提示列最前面 ✨，按 → 接受）", isOn: $aiCompletion)
                        .onChange(of: aiCompletion) { _, _ in syncSmartInput() }
                    Toggle("AI 校正（停手時自動改掉組字區的同音錯字）", isOn: $smartCorrection)
                        .onChange(of: smartCorrection) { _, _ in syncSmartInput() }
                }
                .padding(.leading, 16)
                .disabled(!smartInput || !smartInputReady)
            }
        }
        .formStyle(.grouped)
    }

    private var learningTab: some View {
        Form {
            Section {
                Text("碼注音會記住你選過的字、自動學成新詞，並記錄詞與詞的接續習慣，讓斷詞越用越準。資料只存在本機（Application Support），不會離開這台電腦。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("檢視學習資料…") { onShowLearnedData() }
                    Button("清除全部", role: .destructive) { showingResetAlert = true }
                    if didReset {
                        Text("已清除").font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            footer
        }
        .formStyle(.grouped)
    }

    private var footer: some View {
        Section {
            Text("設定即時生效。詞庫：小麥注音（MIT）；英文詞表：macOS 內建。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    var body: some View {
        TabView {
            mixedTab.tabItem { Label("中英混輸", systemImage: "character.bubble") }
            chineseTab.tabItem { Label("中文輸入", systemImage: "textformat") }
            voiceTab.tabItem { Label("語音", systemImage: "mic") }
            smartTab.tabItem { Label("智慧輸入", systemImage: "sparkles") }
            learningTab.tabItem { Label("學習資料", systemImage: "brain") }
            UpdateTab().tabItem { Label("更新", systemImage: "arrow.down.circle") }
        }
        .frame(width: 460, height: 420)
        .alert("清除全部學習資料？", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                onReset()
                didReset = true
            }
        } message: {
            Text("選字紀錄、自動學成的新詞、詞語接續習慣都會刪除，無法復原。內建詞庫不受影響。")
        }
    }
}

/// 更新分頁：打開就自動檢查一次
private struct UpdateTab: View {
    @State private var status = "檢查中…"
    @State private var available: Updater.Release?
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                LabeledContent("目前版本") {
                    Text(verbatim: "\(Updater.currentVersion)（\(Updater.currentCommit.prefix(7))）")
                        .textSelection(.enabled)
                }
                Text(verbatim: status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("檢查更新") { check() }
                        .disabled(busy)
                    if let release = available {
                        Button("下載並安裝") { install(release) }
                            .buttonStyle(.borderedProminent)
                            .disabled(busy)
                    }
                }
            }
            Section {
                Text(verbatim: "從 GitHub Releases 的 latest-main 下載（main 每次更新都會自動重建）。安裝後輸入法會自動重啟，不用登出；學習資料會保留。repo 是 private 時需要已登入的 gh（brew install gh && gh auth login）。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { check() }
    }

    private func check() {
        busy = true
        status = "檢查中…"
        Updater.check { result in
            busy = false
            switch result {
            case .upToDate:
                available = nil
                status = "已經是最新版。"
            case .available(let release):
                available = release
                status = "有新版：\(release.title)"
            case .failed(let message):
                available = nil
                status = message
            }
        }
    }

    private func install(_ release: Updater.Release) {
        busy = true
        if let error = Updater.install(release) {
            busy = false
            status = error
        } else {
            status = "下載安裝中，完成後輸入法會自動重啟（約 10 秒）。紀錄：\(Updater.logURL.path)"
        }
    }
}

/// 偏好設定視窗（單例）。LSUIElement 行程也能取得鍵盤焦點。
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    /// 由控制器設定：清除學習資料、開啟學習資料視窗
    var onReset: () -> Void = {}
    var onShowLearnedData: () -> Void = {}

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(onReset: onReset, onShowLearnedData: onShowLearnedData))
            let window = NSWindow(contentViewController: hosting)
            window.title = "碼注音偏好設定"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
