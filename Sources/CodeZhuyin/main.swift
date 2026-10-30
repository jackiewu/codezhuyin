import Cocoa
import InputMethodKit
import CodeZhuyinCore

// 必須與 Info.plist 的 InputMethodConnectionName 一字不差
let kConnectionName = "io.github.jackiewu.inputmethod.CodeZhuyin_Connection"

// install / uninstall 子命令：TIS 註冊／停用後直接結束，供 install.sh 呼叫
if CommandLine.arguments.count > 1 {
    switch CommandLine.arguments[1] {
    case "install":
        InputSourceInstaller.register()
        exit(0)
    case "uninstall":
        InputSourceInstaller.disable()
        exit(0)
    case "guide", "learned":
        // 開發用：直接開啟視窗，供產生說明文件截圖（scripts/capture-shots.sh）
        SettingKey.registerDefaults()
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        if CommandLine.arguments[1] == "guide" {
            GuideWindowController.shared.show()
        } else {
            let store = UserPhraseStore(
                fileURL: FileManager.default
                    .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                    .appendingPathComponent("CodeZhuyin/userphrases.json"))
            LearnedDataWindowController.shared.show(store: store)
        }
        app.run()
    default:
        FileHandle.standardError.write(Data("用法：CodeZhuyin [install|uninstall]\n".utf8))
        exit(1)
    }
}

guard let bundleID = Bundle.main.bundleIdentifier else {
    FileHandle.standardError.write(Data("錯誤：必須以 CodeZhuyin.app 形式執行\n".utf8))
    exit(1)
}

SettingKey.registerDefaults()
Theme.applyAppearance()

// IMKServer 必須以強參考存活整個行程，否則系統連不上輸入法
let server = IMKServer(name: kConnectionName, bundleIdentifier: bundleID)
guard server != nil else {
    Log.general.error("IMKServer 建立失敗")
    exit(1)
}
Log.general.notice("碼注音已啟動 v\(Updater.currentVersion, privacy: .public)（connection: \(kConnectionName, privacy: .public)）")

// pkill（install.sh 熱更新）／登出送 SIGTERM：學習資料是延後寫檔的，結束前先存
// 記下是誰送的 SIGTERM（使用者回報「常被切回 ABC」時，紀錄裡查得到兇手）：
// sigaction 只存下 pid，名稱留給主執行緒的 DispatchSource 查
var termSenderPID: pid_t = 0
var termAction = sigaction()
termAction.__sigaction_u.__sa_sigaction = { _, info, _ in
    if let info { termSenderPID = info.pointee.si_pid }
}
termAction.sa_flags = SA_SIGINFO
sigaction(SIGTERM, &termAction, nil)
let terminationSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
terminationSource.setEventHandler {
    var path = [CChar](repeating: 0, count: 4096)
    let sender = proc_pidpath(termSenderPID, &path, UInt32(path.count)) > 0 ? String(cString: path) : "未知"
    Log.general.notice("碼注音收到 SIGTERM，送出者 pid \(termSenderPID, privacy: .public)：\(sender, privacy: .public)")
    CodeZhuyinInputController.userPhrases.flush()
    SmartInput.stop()  // 模型伺服器跟著關（萬一沒關到，外層 sh 也會在 2 秒內收掉）
    exit(0)
}
terminationSource.resume()

NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
