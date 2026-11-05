import Carbon
import Cocoa

/// 追查「碼注音被切成 ABC、在選單變灰」：系統每次換輸入法或改可用清單，就記下
/// 當下的前景 app、安全輸入狀態，以及系統怎麼看碼注音（能不能選、算不算能打英文）。
/// 紀錄寫進 ~/Library/Application Support/CodeZhuyin/switch-log.txt（只留最後 300 行），
/// 也寫進系統 log；選單的「複製切換紀錄」可以直接貼給開發者。
enum SwitchDiagnostics {
    private static let maxLines = 300
    private static var observers: [NSObjectProtocol] = []
    private static var lastLine = ""

    static let fileURL: URL? = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("CodeZhuyin/switch-log.txt")

    static func start() {
        let center = DistributedNotificationCenter.default()
        for (name, label) in [
            (kTISNotifySelectedKeyboardInputSourceChanged as String, "切換輸入法"),
            (kTISNotifyEnabledKeyboardInputSourcesChanged as String, "可用輸入法清單變動"),
        ] {
            observers.append(center.addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { _ in record(label) })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { _ in
            // 換 app 本身不記；只有換完碼注音變得不能選時才記（灰掉的瞬間）
            if ownSourceState().selectable == false { record("切換 app 後碼注音不能選") }
        })
        record("啟動")
    }

    /// 輸入法控制器的啟用／停用（client 是哪個 app）
    static func controller(_ event: String, client: Any?) {
        let bundle = (client as? IMKTextInput)?.bundleIdentifier() ?? "?"
        record("\(event)（\(bundle)）")
    }

    static func record(_ event: String) {
        let current = currentSourceID()
        let own = ownSourceState()
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
        let secure = securePID().map { "pid \($0) \(processName($0))" } ?? "無"
        let body = "\(event)｜目前：\(current)｜前景：\(front)｜安全輸入：\(secure)"
            + "（本程式看到 \(IsSecureEventInputEnabled() ? "開" : "關")）"
            + "｜碼注音 可選 \(flag(own.selectable)) 已啟用 \(flag(own.enabled)) 能打英文 \(flag(own.ascii))"
        // 同一狀態連續通知（系統常一次送好幾個）只記一次
        guard body != lastLine else { return }
        lastLine = body
        let line = "\(timestamp()) \(body)"
        Log.general.notice("碼注音切換紀錄 \(line, privacy: .public)")
        append(line)
    }

    /// 給選單「複製切換紀錄」用：最後 80 行加上版本
    static func recentText() -> String {
        let lines = readLines().suffix(80)
        return "碼注音 v\(Updater.currentVersion) 切換紀錄\n" + lines.joined(separator: "\n")
    }

    // MARK: - 系統狀態

    private static func currentSourceID() -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return "?" }
        return stringProperty(source, kTISPropertyInputSourceID) ?? "?"
    }

    private static func ownSourceState() -> (selectable: Bool?, enabled: Bool?, ascii: Bool?) {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let list = TISCreateInputSourceList(nil, true)?.takeRetainedValue() as? [TISInputSource],
              let own = list.first(where: { (stringProperty($0, kTISPropertyInputSourceID) ?? "").hasPrefix(bundleID) })
        else { return (nil, nil, nil) }
        return (boolProperty(own, kTISPropertyInputSourceIsSelectCapable),
                boolProperty(own, kTISPropertyInputSourceIsEnabled),
                boolProperty(own, kTISPropertyInputSourceIsASCIICapable))
    }

    /// 誰開著安全輸入（密碼欄位、終端機「安全鍵盤輸入」等）
    private static func securePID() -> pid_t? {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any],
              let pid = dict["kCGSSessionSecureInputPID"] as? Int, pid > 0 else { return nil }
        return pid_t(pid)
    }

    private static func processName(_ pid: pid_t) -> String {
        if let app = NSRunningApplication(processIdentifier: pid), let name = app.bundleIdentifier ?? app.localizedName {
            return name
        }
        var path = [CChar](repeating: 0, count: 4096)
        return proc_pidpath(pid, &path, UInt32(path.count)) > 0 ? String(cString: path) : "未知"
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    private static func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool? {
        guard let ptr = TISGetInputSourceProperty(source, key) else { return nil }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue())
    }

    private static func flag(_ value: Bool?) -> String {
        value.map { $0 ? "是" : "否" } ?? "?"
    }

    // MARK: - 檔案

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }()

    private static func timestamp() -> String { formatter.string(from: Date()) }

    private static func readLines() -> [String] {
        guard let url = fileURL, let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }

    private static func append(_ line: String) {
        guard let url = fileURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let lines = Array((readLines() + [line]).suffix(maxLines))
        try? (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
