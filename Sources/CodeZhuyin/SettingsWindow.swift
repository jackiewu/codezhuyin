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
    static let horizontalCandidates = "horizontalCandidates"
    static let caretMark = "caretMark"  // 句中插入點用 ‸ 記號（關＝用 app 的游標）
    static let rawKeysPreedit = "rawKeysPreedit"  // 組字區顯示按鍵、注音標在下面
    static let catGuard = "catGuard"  // 貓貓模式：偵測亂按就鎖住輸入
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
            horizontalCandidates: false,
            caretMark: false,
            rawKeysPreedit: true,
            catGuard: true,
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

// MARK: - 配色（淺色／深色各一組，跟系統外觀切換）

enum Theme {
    private static func dynamic(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
    private static func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
    /// 品牌色：靛藍
    static let brand = dynamic(rgb(0x4F46E5), rgb(0x818CF8))
    static let brandSoft = dynamic(rgb(0x4F46E5, 0.10), rgb(0x818CF8, 0.18))
    static let logo = LinearGradient(colors: [Color(nsColor: rgb(0x6366F1)), Color(nsColor: rgb(0x8B5CF6))],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
    static let sidebar = dynamic(rgb(0xF3F3F7), rgb(0x1C1C21))
    static let page = dynamic(rgb(0xFAFAFC), rgb(0x141418))
    static let card = dynamic(.white, rgb(0x232329))
    static let cardBorder = dynamic(rgb(0x000000, 0.07), rgb(0xFFFFFF, 0.08))
    static let well = dynamic(rgb(0xF1F1F6), rgb(0x2C2C33))
    static let key = dynamic(.white, rgb(0x3A3A42))
}

// MARK: - 共用元件（卡片式設定列，參考 0c／隨便打 的設定頁）

/// 一張圓角卡片，裡面的列以分隔線隔開
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.card)
                    .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.cardBorder)
            )
    }
}

/// 卡片裡的一列：標題＋說明，右邊放開關或按鈕。indent＝子選項（掛在上一列底下）
struct Row<Accessory: View>: View {
    let title: String
    var detail: String? = nil
    var indent = false
    var showDivider = true
    @ViewBuilder var accessory: Accessory

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if indent {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: title).font(.system(size: 13, weight: .semibold))
                    if let detail {
                        Text(verbatim: detail)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                accessory
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.leading, indent ? 12 : 0)
            if showDivider { Divider().padding(.leading, 16) }
        }
    }
}

/// 開關列
struct ToggleRow: View {
    let title: String
    var detail: String? = nil
    var indent = false
    var last = false
    @Binding var isOn: Bool
    var body: some View {
        Row(title: title, detail: detail, indent: indent, showDivider: !last) {
            Toggle("", isOn: $isOn).toggleStyle(.switch).labelsHidden().controlSize(.small).tint(Theme.brand)
        }
    }
}

/// 頁首：大標題＋一句說明
struct PageHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: title).font(.system(size: 26, weight: .bold))
            Text(verbatim: subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }
}

/// 卡片上方的小節標題
struct SectionTitle: View {
    let text: String
    var note: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: text).font(.system(size: 15, weight: .bold))
            if let note { Text(verbatim: note).font(.system(size: 11.5)).foregroundStyle(.secondary) }
        }
        .padding(.top, 8)
    }
}

/// 鍵帽：總覽頁示範「你按的鍵」
private struct KeyCap: View {
    let label: String
    var body: some View {
        Text(verbatim: label)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .lineLimit(1)
            .fixedSize()  // 不讓 HStack 把鍵帽擠扁（舊版 Space 被擠成直的）
            .frame(minWidth: 14)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.key)
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Theme.cardBorder)
            )
    }
}

/// 總覽頁的示範卡：標題、按鍵序列、送出的字、說明
private struct DemoCard: View {
    let title: String
    let subtitle: String
    let keys: [String]
    let output: String
    let note: String
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).font(.system(size: 16, weight: .bold))
                    Text(verbatim: subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                FlowKeys(keys: keys)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.well)
                    )
                Text(verbatim: output)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.brand)
                Text(verbatim: note)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// 鍵帽換行排列：依實際寬度自動換行
private struct FlowKeys: View {
    let keys: [String]
    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in KeyCap(label: key) }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let last = rows.count - 1
            rows[last].width += rows[last].indices.isEmpty ? size.width : size.width + spacing
            rows[last].height = max(rows[last].height, size.height)
            rows[last].indices.append(index)
        }
        return rows
    }
}

// MARK: - 頁面

private enum Page: String, CaseIterable, Identifiable {
    case overview, mixed, chinese, candidates, voice, smart, learning, contexts, update
    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "總覽"
        case .mixed: return "中英混打"
        case .chinese: return "中文輸入"
        case .candidates: return "選字窗"
        case .voice: return "語音輸入"
        case .smart: return "智慧輸入"
        case .learning: return "學習資料"
        case .contexts: return "情境"
        case .update: return "更新"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "house"
        case .mixed: return "character.bubble"
        case .chinese: return "keyboard"
        case .candidates: return "rectangle.split.3x1"
        case .voice: return "mic"
        case .smart: return "sparkles"
        case .learning: return "brain"
        case .contexts: return "square.stack.3d.up"
        case .update: return "arrow.down.circle"
        }
    }

    /// 側欄分組
    static let groups: [(String?, [Page])] = [
        (nil, [.overview]),
        ("打字", [.mixed, .chinese, .candidates]),
        ("詞庫", [.contexts, .learning]),
        ("進階", [.voice, .smart]),
        ("系統", [.update]),
    ]
}

private struct SettingsView: View {
    @AppStorage(SettingKey.shiftToggle) private var shiftToggle = true
    @AppStorage(SettingKey.englishHint) private var englishHint = true
    @AppStorage(SettingKey.fullWidthPunctuation) private var fullWidthPunctuation = false
    @AppStorage(SettingKey.backtickSymbolSheet) private var backtickSymbolSheet = false
    @AppStorage(SettingKey.simplifiedOutput) private var simplifiedOutput = false
    @AppStorage(SettingKey.spaceCommitsEnglish) private var spaceCommitsEnglish = true
    @AppStorage(SettingKey.horizontalCandidates) private var horizontalCandidates = false
    @AppStorage(SettingKey.caretMark) private var caretMark = false
    @AppStorage(SettingKey.rawKeysPreedit) private var rawKeysPreedit = true
    @AppStorage(SettingKey.catGuard) private var catGuard = true
    @AppStorage(SettingKey.autoSpacing) private var autoSpacing = true
    @AppStorage(SettingKey.pageSize) private var pageSize = 9
    @AppStorage(SettingKey.fuzzyReading) private var fuzzyReading = false
    @AppStorage(SettingKey.associations) private var associations = true
    @AppStorage(SettingKey.smartInput) private var smartInput = false
    @AppStorage(SettingKey.aiCompletion) private var aiCompletion = true
    @AppStorage(SettingKey.smartCorrection) private var smartCorrection = true
    @AppStorage(SettingKey.voiceInput) private var voiceInput = true
    @State private var page: Page = .overview
    @State private var showingResetAlert = false
    @State private var didReset = false
    @State private var copiedModelCommand = false

    /// 由控制器注入：清除學習資料、開啟學習資料視窗
    var onReset: () -> Void = {}
    var onShowLearnedData: () -> Void = {}

    private var smartInputReady: Bool { SmartInput.serverPath != nil && SmartInput.modelExists }

    private static let modelDownloadCommand = """
        mkdir -p ~/Library/Application\\ Support/CodeZhuyin/models && curl -L -o ~/Library/Application\\ Support/CodeZhuyin/models/Breeze-7B-Base-v1_0.Q3_K_M.gguf https://huggingface.co/mradermacher/Breeze-7B-Base-v1_0-GGUF/resolve/main/Breeze-7B-Base-v1_0.Q3_K_M.gguf
        """

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) { content }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.page)
        }
        .frame(width: 820, height: 600)
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

    // MARK: 側欄

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Text(verbatim: "碼")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.logo))
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "碼注音").font(.system(size: 16, weight: .bold))
                    Text(verbatim: "CodeZhuyin").font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 18)

            ForEach(Array(Page.groups.enumerated()), id: \.offset) { _, group in
                if let name = group.0 {
                    Text(verbatim: name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.top, 12)
                        .padding(.bottom, 2)
                }
                ForEach(group.1) { item in sidebarItem(item) }
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(.green).frame(width: 7, height: 7)
                Text(verbatim: "就緒 · \(simplifiedOutput ? "簡中" : "繁中") · 大千")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            Text(verbatim: "v\(Updater.currentVersion)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
        }
        .padding(12)
        .frame(width: 200)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.sidebar)
    }

    private func sidebarItem(_ item: Page) -> some View {
        let selected = page == item
        return Button {
            page = item
        } label: {
            HStack(spacing: 9) {
                Image(systemName: item.icon)
                    .frame(width: 18)
                    .foregroundStyle(selected ? Theme.brand : Color.secondary)
                Text(verbatim: item.title)
                    .foregroundStyle(selected ? Theme.brand : Color.primary)
                Spacer()
            }
            .font(.system(size: 13, weight: selected ? .semibold : .regular))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Theme.brandSoft : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: 內容

    @ViewBuilder private var content: some View {
        switch page {
        case .overview: overviewPage
        case .mixed: mixedPage
        case .chinese: chinesePage
        case .candidates: candidatesPage
        case .voice: voicePage
        case .smart: smartPage
        case .learning: learningPage
        case .contexts: ContextsPage()
        case .update: UpdatePage()
        }
    }

    private var overviewPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: "總覽", subtitle: "給工程師的注音：中英混打不用切換，反引號與鍵盤上的標點照打。")
            SectionTitle(text: "三件事，都不用切換", note: "下面是你按的鍵和最後送出的字")
            HStack(alignment: .top, spacing: 12) {
                DemoCard(
                    title: "反引號直出", subtitle: "Markdown、行內程式碼",
                    keys: ["`", "f", "o", "o", "`"], output: "`foo`",
                    note: "` 不開符號表；打到一半的鍵遇到標點就當英文送出。"
                )
                DemoCard(
                    title: "中英混打", subtitle: "英文直接打",
                    keys: ["b", "r", "e", "w", "Space", "i", "n", "s", "t", "a", "l", "l"],
                    output: "brew install",
                    note: "認出英文就照打，空白是空格、. 不會變成 ㄡ。"
                )
                DemoCard(
                    title: "半形標點", subtitle: "鍵盤上有什麼就出什麼",
                    keys: ["s", "u", "3", "c", "l", "3", "_", "("],
                    output: "你好_(",
                    note: "_ ( ) [ ] = ' 等都是半形。要全形到「中文輸入」打開。"
                )
            }
            .fixedSize(horizontal: false, vertical: true)
            SectionTitle(text: "快速開關")
            Card {
                ToggleRow(title: "中英自動偵測", detail: "中文裡直接打英文單字，不用切換。", isOn: $englishHint)
                ToggleRow(title: "輸出簡體中文", detail: "選字窗與送出的字都換成簡體（選單列也能切換）。", isOn: $simplifiedOutput)
                ToggleRow(title: "橫式選字窗", detail: "←→ 選字、↑↓ 翻頁。", last: true, isOn: $horizontalCandidates)
            }
        }
    }

    private var mixedPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: "中英混打", subtitle: "打英文不用按 Caps Lock，輸入法自己判斷這串是英文還是注音。")
            Card {
                ToggleRow(title: "中英自動偵測", detail: "中打英時 Tab 上英文；英文模式打注音會自動切回中文。", isOn: $englishHint)
                ToggleRow(
                    title: "英文後的空白＝英文加空格",
                    detail: "brew install llama.cpp 直接打：空白送出英文加空格，. , / ; - 照英文打。關掉時空白改開中英並列選字（開著時按 ↓）。",
                    indent: true, isOn: $spaceCommitsEnglish
                )
                ToggleRow(title: "中英之間自動加空白", detail: "我愛 mac：漢字與英數字相鄰處補一個空格。", isOn: $autoSpacing)
                ToggleRow(title: "Shift 單擊切換中／英", detail: "Shift＋字母永遠直接輸出英文字母。", last: true, isOn: $shiftToggle)
            }
            SectionTitle(text: "保護")
            Card {
                ToggleRow(
                    title: "貓貓模式",
                    detail: "貓踩鍵盤、小孩亂按時（一瞬間按下一堆鍵，或同一個鍵壓著不放）自動鎖住輸入。Esc 連按兩下或停手 5 秒解鎖。",
                    last: true, isOn: $catGuard
                )
            }
        }
    }

    private var chinesePage: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: "中文輸入", subtitle: "標點、繁簡與相似音。預設全部半形，跟英文鍵盤一樣。")
            SectionTitle(text: "輸出")
            Card {
                ToggleRow(title: "輸出簡體中文", detail: "选字窗与送出的字都是简体。词库与学习资料仍是繁体。", isOn: $simplifiedOutput)
                ToggleRow(title: "全形標點", detail: "' [ ] < > ? ! : 等鍵轉成 、「」，。？！：。", isOn: $fullWidthPunctuation)
                ToggleRow(title: "反引號 ` 開符號表", detail: "關閉＝` 直接輸出（建議，Markdown 與程式碼用）。", last: true, isOn: $backtickSymbolSheet)
            }
            SectionTitle(text: "組字")
            Card {
                ToggleRow(title: "相似音修正", detail: "ㄓㄗ、ㄕㄙ、ㄣㄥ 打錯也找得到。正確讀音仍排最前面。", isOn: $fuzzyReading)
                ToggleRow(title: "聯想詞", detail: "打字時提示你常接的下一個詞，Tab＋數字選。", last: true, isOn: $associations)
            }
        }
    }

    private var candidatesPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: "選字窗", subtitle: "空白或 ↓ 打開，數字鍵直接選。")
            Card {
                ToggleRow(title: "橫式選字窗", detail: "候選字排成一列：←→ 選字、↑↓ 翻頁。關掉是直式清單。", isOn: $horizontalCandidates)
                ToggleRow(
                    title: "組字區顯示按鍵",
                    detail: "打字時看到的是按下的鍵（ui、su），注音標在下方小標籤。關掉就跟以前一樣直接顯示注音。",
                    isOn: $rawKeysPreedit
                )
                ToggleRow(
                    title: "用 ‸ 標示插入點",
                    detail: "←→ 回頭改字時，預設用 app 本身的游標標示位置；少數 app 看不到游標時再打開這個。",
                    isOn: $caretMark
                )
                Row(title: "每頁字數", detail: "一頁顯示幾個候選字。", showDivider: false) {
                    Picker("", selection: $pageSize) {
                        Text("7").tag(7)
                        Text("9").tag(9)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 90)
                }
            }
        }
    }

    private var voicePage: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: "語音輸入", subtitle: "使用 Mac 內建語音辨識，在本機執行、不連網。")
            Card {
                ToggleRow(
                    title: "單按右 Option 開始講話",
                    detail: "再按一下結束、Esc 取消。打一半的字會先送出，講的話接在後面。",
                    last: true, isOn: $voiceInput
                )
            }
        }
    }

    private var smartPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: "智慧輸入", subtitle: "停手時在背景跑本機模型，不影響打字速度，也不連網。")
            Card {
                ToggleRow(
                    title: "啟用智慧輸入（Breeze-7B）",
                    detail: "開啟時約佔 4 GB 記憶體，3 分鐘沒打字自動關閉。建議 16 GB 以上的 Mac 使用。",
                    isOn: $smartInput
                )
                .disabled(!smartInputReady)
                .onChange(of: smartInput) { _, _ in syncSmartInput() }
                ToggleRow(title: "AI 補句", detail: "提示列最前面出現 ✨，按 → 接受。", indent: true, isOn: $aiCompletion)
                    .disabled(!smartInput || !smartInputReady)
                    .onChange(of: aiCompletion) { _, _ in syncSmartInput() }
                ToggleRow(title: "AI 校正", detail: "停手時自動改掉組字區的同音錯字。", indent: true, last: true, isOn: $smartCorrection)
                    .disabled(!smartInput || !smartInputReady)
                    .onChange(of: smartCorrection) { _, _ in syncSmartInput() }
            }
            if !smartInputReady {
                SectionTitle(text: "還需要準備")
                Card {
                    Row(
                        title: "llama.cpp",
                        detail: SmartInput.serverPath == nil ? "在終端機執行 brew install llama.cpp" : "已安裝"
                    ) {
                        Image(systemName: SmartInput.serverPath == nil ? "xmark.circle" : "checkmark.circle.fill")
                            .foregroundStyle(SmartInput.serverPath == nil ? Color.secondary : Color.green)
                    }
                    Row(
                        title: "模型檔（約 3.7 GB）",
                        detail: SmartInput.modelExists ? "已下載" : "複製指令貼到終端機執行，下載完重新打開這頁。",
                        showDivider: false
                    ) {
                        if SmartInput.modelExists {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Button(copiedModelCommand ? "已複製" : "複製下載指令") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(Self.modelDownloadCommand, forType: .string)
                                copiedModelCommand = true
                            }
                        }
                    }
                }
            }
        }
    }

    private var learningPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(
                title: "學習資料",
                subtitle: "記住你選過的字、自動學成新詞、記錄詞與詞的接續習慣。只存在本機，不會離開這台電腦。"
            )
            Card {
                Row(title: "檢視學習資料", detail: "看看碼注音學到了什麼，也可以逐筆刪除。") {
                    Button("開啟…") { onShowLearnedData() }
                }
                Row(title: "清除全部", detail: didReset ? "已清除。" : "內建詞庫不受影響。", showDivider: false) {
                    Button("清除…", role: .destructive) { showingResetAlert = true }
                }
            }
            Text(verbatim: "詞庫：小麥注音（MIT）；英文詞表：macOS 內建；基底：融鍵 BlendKey（MIT）。設定即時生效。")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    /// 開關一動就立刻啟動／關閉 Breeze（不用等下一次打字）
    private func syncSmartInput() {
        SmartInput.setEnabled(smartInput && (aiCompletion || smartCorrection))
    }
}

/// 更新頁：打開就自動檢查一次
/// 一行可複製的終端機指令
private struct CommandRow: View {
    let title: String
    let detail: String
    let command: String
    var last = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: title).font(.system(size: 13, weight: .semibold))
                    Text(verbatim: detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    Text(verbatim: command)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.well))
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(command, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        Label(copied ? "已複製" : "複製", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            if !last { Divider().padding(.leading, 16) }
        }
    }
}

private struct UpdatePage: View {
    @State private var status = "檢查中…"
    @State private var available: Updater.Release?
    @State private var busy = false
    @State private var progress: Updater.Progress?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(title: "更新", subtitle: "從 GitHub Releases 的 latest-main 下載，main 每次更新都會自動重建。")
            Card {
                Row(title: "目前版本", detail: "\(Updater.currentVersion)（\(Updater.currentCommit.prefix(7))）") {
                    Button("檢查更新") { check() }.disabled(busy)
                }
                Row(title: available.map { "有新版：\($0.title)" } ?? "狀態", detail: status, showDivider: progress != nil) {
                    if let release = available, progress == nil {
                        Button("下載並安裝") { install(release) }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.brand)
                            .disabled(busy)
                    } else if busy, progress == nil {
                        ProgressView().controlSize(.small)
                    }
                }
                if let progress {
                    VStack(alignment: .leading, spacing: 6) {
                        if let fraction = progress.fraction {
                            ProgressView(value: fraction).tint(Theme.brand)
                        } else {
                            ProgressView().progressViewStyle(.linear).tint(Theme.brand)
                        }
                        Text(verbatim: progress.text)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            if let release = available, !release.notes.isEmpty {
                SectionTitle(text: "新版內容")
                Card {
                    Text(verbatim: release.notes.components(separatedBy: "\n---").first ?? release.notes)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
            SectionTitle(text: "疑難排解", note: "安裝後會自動重啟，學習資料會保留，不用登出")
            Card {
                CommandRow(
                    title: "更新後版本號沒變？",
                    detail: "舊的輸入法行程還在跑。貼到終端機執行，再點一下任何輸入框就會載入新版；仍不行就登出再登入。",
                    command: Updater.restartCommand
                )
                CommandRow(
                    title: "檢查不到新版（repo 是 private）",
                    detail: "需要已登入的 GitHub CLI。",
                    command: Updater.ghSetupCommand,
                    last: true
                )
            }
        }
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
                status = "按「下載並安裝」更新，約 10 秒。"
            case .failed(let message):
                available = nil
                status = message
            }
        }
    }

    private func install(_ release: Updater.Release) {
        busy = true
        status = "更新中，完成後輸入法會自動重啟。"
        progress = Updater.Progress(fraction: nil, text: "連線中…")
        Updater.install(release, progress: { progress = $0 }) { error in
            if let error {
                busy = false
                progress = nil
                status = error
                return
            }
            available = nil
            progress = Updater.Progress(fraction: 1, text: "已完成")
            status = "已完成！碼注音即將重新啟動，切到任何輸入框就會載入新版。"
            // 讓使用者看到完成訊息再結束行程（視窗會跟著關閉）
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { Updater.restart() }
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
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
