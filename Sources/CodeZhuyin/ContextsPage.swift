import Cocoa
import SwiftUI
import UniformTypeIdentifiers
import CodeZhuyinCore

/// 情境詞庫：全行程共用一份，存在 Application Support/CodeZhuyin/contexts.json
enum Contexts {
    static let store: ContextStore = {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("CodeZhuyin/contexts.json")
        let store = ContextStore(fileURL: url)
        store.onChange = { LexiconStore.refreshEnglish() }
        return store
    }()
}

/// 設定頁用的可觀察包裝：改動寫回 store，再重讀一次讓畫面更新
final class ContextModel: ObservableObject {
    @Published private(set) var packs: [ContextPack] = Contexts.store.packs

    func upsert(_ pack: ContextPack) {
        Contexts.store.upsert(pack)
        packs = Contexts.store.packs
    }

    func remove(_ id: UUID) {
        Contexts.store.remove(id: id)
        packs = Contexts.store.packs
    }

    func duplicate(_ id: UUID) -> ContextPack? {
        let copy = Contexts.store.duplicate(id: id)
        packs = Contexts.store.packs
        return copy
    }

    /// 存成一個檔案（全部情境，含注音與開關）。回傳給畫面顯示的結果
    func backupAll() -> String? {
        guard let data = Contexts.store.backupData() else { return "備份失敗：沒辦法產生檔案" }
        let panel = NSSavePanel()
        panel.title = "備份全部情境"
        panel.allowedContentTypes = [.json]
        let day = Date().formatted(.iso8601.year().month().day())
        panel.nameFieldStringValue = "碼注音情境備份-\(day).json"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return "已備份 \(packs.count) 個情境到 \(url.lastPathComponent)"
        } catch {
            return "備份失敗：\(error.localizedDescription)"
        }
    }

    /// 從備份檔還原：同名的合併，沒有的加回來，不會刪掉現有的情境
    func restoreBackup() -> String? {
        let panel = NSOpenPanel()
        panel.title = "從備份還原情境"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let data = try? Data(contentsOf: url), let result = Contexts.store.restore(from: data) else {
            return "看不懂這個檔案：要用「備份全部」存出來的檔案（單一情境的 JSON 請用情境裡的「匯入 JSON…」）"
        }
        packs = Contexts.store.packs
        return "已還原：新增 \(result.newPacks) 個情境、合併 \(result.mergedPacks) 個同名情境，共加入 \(result.newTerms) 個詞"
    }

    /// 把一個詞變成情境詞：中文推注音、英文直接收。回傳 nil 和不能加的原因
    static func makeTerm(_ text: String) -> (ContextTerm?, String?) {
        let word = text.trimmingCharacters(in: .whitespaces)
        switch ContextImport.classify(word) {
        case .english:
            return (ContextTerm(value: word, reading: nil), nil)
        case .chinese:
            guard let lexicon = LexiconStore.lexicon else { return (nil, "詞庫還沒載入，稍等一下") }
            guard let guess = lexicon.guessReading(of: word) else { return (nil, "有字查不到注音") }
            return (ContextTerm(value: word, reading: guess.reading), nil)
        case .skip(let reason):
            return (nil, reason)
        }
    }

    /// 破音字的其他讀法：每個有多種讀音的字，換掉那一個音節
    static func alternatives(for term: ContextTerm) -> [(label: String, reading: String)] {
        guard let reading = term.reading, let lexicon = LexiconStore.lexicon,
              let guess = lexicon.guessReading(of: term.value) else { return [] }
        let current = reading.split(separator: "-").map(String.init)
        let chars = term.value.map(String.init)
        guard current.count == chars.count else { return [] }
        var result: [(String, String)] = []
        for (i, options) in guess.choices.enumerated() where options.count > 1 {
            for option in options where option != current[i] {
                var changed = current
                changed[i] = option
                result.append(("「\(chars[i])」讀 \(option)", changed.joined(separator: "-")))
            }
        }
        return result
    }
}

// MARK: - 頁面

struct ContextsPage: View {
    @StateObject private var model = ContextModel()
    @State private var expanded: Set<UUID> = []
    @State private var showingImport = false
    /// 匯入到既有情境：哪一個情境的「匯入 JSON…」被按了
    @State private var importTarget: ContextPack?
    @State private var backupMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PageHeader(
                title: "情境",
                subtitle: "一個領域的專有名詞和英文詞（公司專案、產品名、同事名字）。打開的情境，裡面的詞會優先出現。"
            )
            HStack(spacing: 8) {
                Button {
                    showingImport = true
                } label: {
                    Label("用 AI 產生…", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand)
                Button {
                    let pack = ContextPack(name: "新情境")
                    model.upsert(pack)
                    expanded.insert(pack.id)
                } label: {
                    Label("新增空白情境", systemImage: "plus")
                }
                Spacer()
                Button {
                    if let message = model.backupAll() { backupMessage = message }
                } label: {
                    Label("備份全部…", systemImage: "square.and.arrow.down")
                }
                .help("把全部情境（含注音與開關）存成一個 JSON 檔")
                .disabled(model.packs.isEmpty)
                Button {
                    if let message = model.restoreBackup() { backupMessage = message }
                } label: {
                    Label("從備份還原…", systemImage: "arrow.counterclockwise")
                }
                .help("同名的情境合併（重複的詞略過），沒有的情境加回來，不會刪掉現有的")
            }
            if let backupMessage {
                Text(verbatim: backupMessage)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.brand)
            }
            if model.packs.isEmpty {
                Card {
                    Row(
                        title: "還沒有情境",
                        detail: "按「用 AI 產生」輸入領域關鍵字（例如：咖啡烘豆、手沖），把提示詞貼給 ChatGPT、Claude 或 Gemini，再把回覆貼回來就好。也可以新增空白情境，自己一個一個加詞。",
                        showDivider: false
                    ) { EmptyView() }
                }
            }
            ForEach(model.packs) { pack in
                PackCard(
                    pack: pack,
                    isExpanded: expanded.contains(pack.id),
                    onToggleExpand: {
                        if expanded.contains(pack.id) { expanded.remove(pack.id) } else { expanded.insert(pack.id) }
                    },
                    onSave: { model.upsert($0) },
                    onDelete: { model.remove(pack.id) },
                    onImportJSON: { importTarget = pack },
                    onDuplicate: {
                        if let copy = model.duplicate(pack.id) { expanded.insert(copy.id) }
                    }
                )
            }
        }
        .sheet(isPresented: $showingImport) {
            ContextImportSheet(existing: model.packs) { pack in
                model.upsert(pack)
                expanded.insert(pack.id)
            }
        }
        .sheet(item: $importTarget) { target in
            ContextImportSheet(existing: model.packs, target: target) { pack in
                model.upsert(pack)
                expanded.insert(pack.id)
            }
        }
    }
}

private struct PackCard: View {
    let pack: ContextPack
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onSave: (ContextPack) -> Void
    let onDelete: () -> Void
    let onImportJSON: () -> Void
    let onDuplicate: () -> Void

    @State private var newWord = ""
    @State private var copiedJSON = false
    @State private var addError: String?
    @State private var name = ""
    @State private var confirmingDelete = false

    var body: some View {
        Card {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: pack.name).font(.system(size: 14, weight: .semibold))
                    if !pack.detail.isEmpty {
                        Text(verbatim: pack.detail).font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                    Text(verbatim: "\(pack.chineseCount) 個詞 · \(pack.englishCount) 個英文詞\(pack.enabled ? "" : " · 已關閉")")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { pack.enabled },
                    set: { var changed = pack; changed.enabled = $0; onSave(changed) }
                ))
                .toggleStyle(.switch).labelsHidden().controlSize(.small).tint(Theme.brand)
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text(verbatim: "名稱").font(.system(size: 12)).foregroundStyle(.secondary)
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                            .onSubmit(rename)
                        Button("儲存名稱", action: rename).disabled(name.isEmpty || name == pack.name)
                        Spacer()
                        Button("匯入 JSON…", action: onImportJSON)
                            .help("貼上 JSON，合併進這個情境或取代裡面的詞")
                        Menu(copiedJSON ? "已複製" : "複製") {
                            Button("建立副本（複製整個情境）", action: onDuplicate)
                            Button("複製成 JSON（可以改完再匯入）") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(ContextImport.export(pack), forType: .string)
                                copiedJSON = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copiedJSON = false }
                            }
                        }
                        .fixedSize()
                        Button("刪除情境", role: .destructive) { confirmingDelete = true }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    Divider()
                    ForEach(pack.terms) { term in termRow(term) }
                    HStack(spacing: 8) {
                        TextField("加詞：中文詞或英文詞，按 Enter", text: $newWord)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(add)
                        Button("加入", action: add).disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    Text(verbatim: addError ?? "中文詞會自動推注音，破音字可以在詞的「…」改；英文詞中英混打時會被認得。")
                        .font(.system(size: 11))
                        .foregroundStyle(addError == nil ? Color.secondary : Color.red)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                }
            }
        }
        .onAppear { name = pack.name }
        .onChange(of: pack.name) { _, newValue in name = newValue }
        .alert("刪除「\(pack.name)」？", isPresented: $confirmingDelete) {
            Button("取消", role: .cancel) {}
            Button("刪除", role: .destructive, action: onDelete)
        } message: {
            Text("裡面的 \(pack.terms.count) 個詞會一起刪除。")
        }
    }

    private func termRow(_ term: ContextTerm) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(verbatim: term.value).font(.system(size: 14, weight: .medium)).frame(minWidth: 110, alignment: .leading)
                Text(verbatim: term.readingDisplay ?? "英文詞：中英混打會認得")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    let options = ContextModel.alternatives(for: term)
                    ForEach(options.indices, id: \.self) { i in
                        Button(options[i].label) { replace(term, reading: options[i].reading) }
                    }
                    Button("刪除", role: .destructive) { remove(term) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            Divider().padding(.leading, 16)
        }
    }

    private func add() {
        let (term, error) = ContextModel.makeTerm(newWord)
        guard let term else { addError = error; return }
        guard !pack.terms.contains(where: { $0.value == term.value }) else { addError = "已經有「\(term.value)」了"; return }
        var changed = pack
        changed.terms.append(term)
        onSave(changed)
        newWord = ""
        addError = nil
    }

    private func remove(_ term: ContextTerm) {
        var changed = pack
        changed.terms.removeAll { $0.id == term.id }
        onSave(changed)
    }

    private func replace(_ term: ContextTerm, reading: String) {
        var changed = pack
        guard let i = changed.terms.firstIndex(where: { $0.id == term.id }) else { return }
        changed.terms[i].reading = reading
        onSave(changed)
    }

    private func rename() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var changed = pack
        changed.name = trimmed
        onSave(changed)
    }
}

// MARK: - 用外部 AI 產生

private struct ContextImportSheet: View {
    let existing: [ContextPack]
    /// 有值＝匯入到這個既有情境（可選合併或取代）；nil＝用 AI 產生新情境
    var target: ContextPack? = nil
    let onImport: (ContextPack) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var keywords = ""
    @State private var copied = false
    @State private var reply = ""
    @State private var parseError: String?
    @State private var draftName = ""
    @State private var draftDetail = ""
    @State private var candidates: [Candidate] = []
    @State private var skipped: [(String, String)] = []
    @State private var previewing = false
    @State private var replacing = false

    struct Candidate: Identifiable {
        let id = UUID()
        var term: ContextTerm
        var include: Bool
        var polyphonic: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: title)
                .font(.system(size: 18, weight: .bold))
            if previewing { preview } else { input }
        }
        .padding(24)
        .frame(width: 600, height: 520)
    }

    private var title: String {
        if let target { return "匯入 JSON 到「\(target.name)」" }
        return previewing ? "匯入「\(draftName)」" : "用外部 AI 產生情境"
    }

    /// 目前畫面上的目標情境（用最新的一份，避免開著視窗時又在別處改過）
    private var currentTarget: ContextPack? {
        guard let target else { return nil }
        return existing.first(where: { $0.id == target.id }) ?? target
    }

    private var input: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let target = currentTarget {
                Text(verbatim: "貼上情境 JSON（格式同「用 AI 產生」：name、description、words、english），下一步可以選合併或取代。")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                HStack {
                    Text(verbatim: "想請 AI 補詞：提示詞會附上這個情境現有的 \(target.terms.count) 個詞，請它只給新的。")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Button(copied ? "已複製" : "複製補詞提示詞") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(ContextImport.prompt(adding: target), forType: .string)
                        copied = true
                    }
                }
            } else {
                Text(verbatim: "碼注音不連網：提示詞由你貼給 AI，回覆也由你貼回來。")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Text(verbatim: "① 輸入領域關鍵字").font(.system(size: 13, weight: .semibold))
                HStack {
                    TextField("例如：咖啡烘豆、手沖、杯測", text: $keywords).textFieldStyle(.roundedBorder)
                    Button(copied ? "已複製" : "複製提示詞") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(ContextImport.prompt(keywords: keywords), forType: .string)
                        copied = true
                    }
                    .disabled(keywords.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if copied {
                Text(verbatim: "提示詞已複製，貼到 ChatGPT、Claude 或 Gemini 的對話框。")
                    .font(.system(size: 11.5)).foregroundStyle(Theme.brand)
            }
            Text(verbatim: target == nil ? "② 貼上 AI 的回覆" : "貼上 JSON 或 AI 的回覆").font(.system(size: 13, weight: .semibold))
            TextEditor(text: $reply)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.well))
            Text(verbatim: parseError ?? "回覆裡夾著說明文字或 ```json 區塊也沒關係。")
                .font(.system(size: 11.5))
                .foregroundStyle(parseError == nil ? Color.secondary : Color.red)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("檢查並匯入…", action: check)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand)
                    .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let target = currentTarget {
                Picker("", selection: $replacing) {
                    Text(verbatim: "合併：加進新詞，重複的略過").tag(false)
                    Text(verbatim: "取代：只留這次的詞").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if replacing {
                    let removed = target.terms.count(where: { term in
                        !candidates.contains { $0.include && $0.term.value == term.value }
                    })
                    Text(verbatim: removed == 0
                         ? "原本的詞都在這次的 JSON 裡，不會刪到詞。破音字改過的讀音會保留。"
                         : "原本的 \(target.terms.count) 個詞中，有 \(removed) 個不在這次的 JSON 裡，會被移除。破音字改過的讀音會保留。")
                        .font(.system(size: 11.5)).foregroundStyle(removed == 0 ? Color.secondary : Color.orange)
                }
            } else {
                HStack {
                    TextField("情境名稱", text: $draftName).textFieldStyle(.roundedBorder)
                }
                if existing.contains(where: { $0.name == draftName }) {
                    Text(verbatim: "已經有同名的情境，匯入會加進那個情境（重複的詞略過）。")
                        .font(.system(size: 11.5)).foregroundStyle(.orange)
                }
            }
            List {
                ForEach($candidates) { $candidate in
                    HStack(spacing: 10) {
                        Toggle("", isOn: $candidate.include).labelsHidden()
                        Text(verbatim: candidate.term.value).font(.system(size: 13, weight: .medium)).frame(minWidth: 110, alignment: .leading)
                        Text(verbatim: candidate.term.readingDisplay ?? "英文詞")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        if isExisting(candidate.term) {
                            Text(verbatim: "已有").font(.system(size: 11)).foregroundStyle(.tertiary)
                        } else if candidate.polyphonic {
                            Text(verbatim: "破音字，匯入後可在「…」改").font(.system(size: 11)).foregroundStyle(.orange)
                        }
                    }
                }
                ForEach(skipped.indices, id: \.self) { i in
                    let item = skipped[i]
                    HStack(spacing: 10) {
                        Image(systemName: "minus.circle").foregroundStyle(.tertiary)
                        Text(verbatim: item.0).font(.system(size: 13)).foregroundStyle(.secondary).frame(minWidth: 110, alignment: .leading)
                        Text(verbatim: item.1).font(.system(size: 11.5)).foregroundStyle(.red)
                    }
                }
            }
            HStack {
                let count = candidates.count(where: { $0.include })
                let fresh = candidates.count(where: { $0.include && !isExisting($0.term) })
                Text(verbatim: summary(count: count, fresh: fresh)).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button("返回") { previewing = false }
                Button("匯入", action: commit)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brand)
                    .disabled(target == nil
                              ? count == 0 || draftName.trimmingCharacters(in: .whitespaces).isEmpty
                              : replacing ? count == 0 : fresh == 0)
            }
        }
    }

    private func check() {
        guard let draft = ContextImport.parse(reply) else {
            parseError = "看不懂這段回覆：找不到 JSON，或裡面沒有詞。"
            return
        }
        parseError = nil
        draftName = draft.name.isEmpty ? keywords : draft.name
        draftDetail = draft.detail
        skipped = draft.skipped
        candidates = []
        for word in draft.chinese {
            if let guess = LexiconStore.lexicon?.guessReading(of: word) {
                let polyphonic = guess.choices.contains { $0.count > 1 }
                candidates.append(Candidate(term: ContextTerm(value: word, reading: guess.reading), include: true, polyphonic: polyphonic))
            } else {
                skipped.append((word, "有字查不到注音"))
            }
        }
        for word in draft.english {
            candidates.append(Candidate(term: ContextTerm(value: word, reading: nil), include: true, polyphonic: false))
        }
        previewing = true
    }

    /// 這個詞目標情境裡已經有了（只在匯入到既有情境時標示）
    private func isExisting(_ term: ContextTerm) -> Bool {
        currentTarget?.terms.contains(where: { $0.value == term.value }) ?? false
    }

    private func summary(count: Int, fresh: Int) -> String {
        guard target != nil else { return "將加入 \(count) 個詞" }
        if replacing { return "取代後共 \(count) 個詞（新詞 \(fresh) 個）" }
        let duplicate = count - fresh
        return duplicate == 0 ? "將加入 \(fresh) 個新詞" : "將加入 \(fresh) 個新詞，\(duplicate) 個已有的略過"
    }

    private func commit() {
        let terms = candidates.filter(\.include).map(\.term)
        var pack: ContextPack
        if let target = currentTarget {
            pack = target
            pack.importTerms(terms, replacing: replacing)
        } else {
            let name = draftName.trimmingCharacters(in: .whitespaces)
            pack = existing.first(where: { $0.name == name }) ?? ContextPack(name: name, detail: draftDetail)
            pack.importTerms(terms, replacing: false)
        }
        if pack.detail.isEmpty { pack.detail = draftDetail }
        onImport(pack)
        dismiss()
    }
}
