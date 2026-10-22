import Foundation

/// 線上更新：比對 GitHub Releases 的 latest-main（main 每次推送由 CI 重建）與本機版本，
/// 有新版就下載 zip、解開、移除隔離屬性、覆蓋 ~/Library/Input Methods 裡的 app 並重啟行程。
/// 更新不用登出（同 install.sh 的熱更新）：舊行程結束後，下次聚焦輸入框系統會載入新版。
///
/// repo 是 private 時 GitHub API 不給匿名讀，改用使用者已登入的 gh CLI；
/// public 時直接用 API 與 curl，不需要任何工具。
enum Updater {
    static let repo = "jackiewu/codezhuyin"
    static let tag = "latest-main"

    struct Release: Equatable {
        let commit: String
        let title: String
        /// Release 說明（CHANGELOG 的未發佈段落）
        let notes: String
        /// 匿名可下載的網址（public repo 才有）；nil＝要走 gh
        let downloadURL: URL?
        /// zip 大小（bytes），用來算下載進度；不知道就是 nil
        var size: Int64? = nil
    }

    /// 安裝進度：fraction 為 nil 時只顯示文字（不確定進度）
    struct Progress: Equatable {
        let fraction: Double?
        let text: String
    }

    /// 舊行程沒自動重啟時，使用者自己執行的指令
    static let restartCommand = "pkill -x CodeZhuyin"
    static let ghSetupCommand = "brew install gh && gh auth login"

    enum CheckResult: Equatable {
        case upToDate(Release)
        case available(Release)
        case failed(String)
    }

    /// CI 打包時寫進 Info.plist 的 commit（本機 scripts/install.sh 建置的是 "dev"）
    static var currentCommit: String {
        Bundle.main.object(forInfoDictionaryKey: "CZBuildCommit") as? String ?? "dev"
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    static var ghPath: String? {
        ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/CodeZhuyin-update.log")
    }

    // MARK: - 檢查

    /// 結果一律回到主執行緒
    static func check(_ completion: @escaping (CheckResult) -> Void) {
        func finish(_ result: CheckResult) {
            DispatchQueue.main.async { completion(result) }
        }
        func judge(_ release: Release) -> CheckResult {
            release.commit == currentCommit ? .upToDate(release) : .available(release)
        }
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/tags/\(tag)")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        URLSession.shared.dataTask(with: request) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200, let data, let release = parseAPI(data) {
                return finish(judge(release))
            }
            // 404：private repo（或還沒有 release）→ 改問 gh
            DispatchQueue.global().async {
                switch checkWithGh() {
                case .success(let release): finish(judge(release))
                case .failure(let message): finish(.failed(message))
                }
            }
        }.resume()
    }

    private static func parseAPI(_ data: Data) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commit = json["target_commitish"] as? String else { return nil }
        let assets = json["assets"] as? [[String: Any]] ?? []
        let zip = assets.first { ($0["name"] as? String)?.hasSuffix(".zip") == true }
        return Release(
            commit: commit,
            title: json["name"] as? String ?? tag,
            notes: json["body"] as? String ?? "",
            downloadURL: (zip?["browser_download_url"] as? String).flatMap(URL.init(string:)),
            size: (zip?["size"] as? NSNumber)?.int64Value
        )
    }

    private enum GhResult { case success(Release), failure(String) }

    private static func checkWithGh() -> GhResult {
        guard let gh = ghPath else {
            return .failure("讀不到 GitHub 上的版本。repo 是 private 時需要 gh：在終端機執行 brew install gh && gh auth login")
        }
        let (status, output) = run(gh, ["release", "view", tag, "-R", repo, "--json", "targetCommitish,name,body,assets"])
        guard status == 0, let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commit = json["targetCommitish"] as? String else {
            let reason = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure("gh 查詢失敗：\(reason.isEmpty ? "未知錯誤" : reason)（試試在終端機執行 gh auth login）")
        }
        let assets = json["assets"] as? [[String: Any]] ?? []
        let zip = assets.first { ($0["name"] as? String)?.hasSuffix(".zip") == true }
        return .success(Release(
            commit: commit, title: json["name"] as? String ?? tag,
            notes: json["body"] as? String ?? "", downloadURL: nil,
            size: (zip?["size"] as? NSNumber)?.int64Value
        ))
    }

    private static func run(_ path: String, _ arguments: [String]) -> (Int32, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    // MARK: - 安裝

    /// 背景跑安裝腳本，結束時（主執行緒）回報：nil＝成功，否則是錯誤訊息。
    /// 進度與錯誤寫在 ~/Library/Logs/CodeZhuyin-update.log。
    /// 成功後由呼叫端結束本行程（restart），下次聚焦輸入框系統就載入新版。
    static func install(
        _ release: Release,
        progress: @escaping (Progress) -> Void = { _ in },
        completion: @escaping (String?) -> Void
    ) {
        let download: String
        if let url = release.downloadURL {
            download = "curl -fsSL -o \"$TMP/update.zip\" '\(url.absoluteString)'"
        } else if let gh = ghPath {
            download = "'\(gh)' release download \(tag) -R \(repo) -p 'CodeZhuyin-*.zip' -O \"$TMP/update.zip\""
        } else {
            return completion("找不到下載方式：請安裝 gh（brew install gh && gh auth login）")
        }
        // 暫存資料夾由這裡建立，才能邊下載邊讀檔案大小、讀目前步驟（stage 檔）
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodeZhuyin-update-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let script = """
            set -euo pipefail
            exec >>"\(logURL.path)" 2>&1
            echo "== $(date) 更新到 \(release.commit)"
            TMP='\(tmp.path)'
            trap 'rm -rf "$TMP"' EXIT
            \(download)
            echo 解壓縮 > "$TMP/stage"
            /usr/bin/ditto -x -k "$TMP/update.zip" "$TMP/unzipped"
            APP="$(/usr/bin/find "$TMP/unzipped" -maxdepth 3 -name CodeZhuyin.app -type d | head -1)"
            [ -n "$APP" ] || { echo "zip 裡找不到 CodeZhuyin.app"; exit 1; }
            /usr/bin/xattr -dr com.apple.quarantine "$APP" || true
            echo 安裝 > "$TMP/stage"
            DEST="$HOME/Library/Input Methods"
            mkdir -p "$DEST"
            /usr/bin/rsync -a --delete "$APP/" "$DEST/CodeZhuyin.app/"
            echo "已安裝"
            """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let timer = Timer(timeInterval: 0.3, repeats: true) { _ in
            progress(currentProgress(tmp: tmp, total: release.size))
        }
        RunLoop.main.add(timer, forMode: .common)
        process.terminationHandler = { finished in
            let ok = finished.terminationStatus == 0
            DispatchQueue.main.async {
                timer.invalidate()
                completion(ok ? nil : "更新失敗：\(lastLogLine() ?? "未知錯誤")（完整紀錄：\(logURL.path)）")
            }
        }
        do {
            try process.run()
        } catch {
            timer.invalidate()
            return completion("無法啟動更新：\(error.localizedDescription)")
        }
        Log.general.info("更新：開始安裝 \(release.commit, privacy: .public)")
    }

    private static func currentProgress(tmp: URL, total: Int64?) -> Progress {
        let stage = (try? String(contentsOf: tmp.appendingPathComponent("stage"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch stage {
        case "解壓縮": return Progress(fraction: 0.92, text: "下載完成，解壓縮中…")
        case "安裝": return Progress(fraction: 0.97, text: "安裝中…")
        default: break
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: tmp.appendingPathComponent("update.zip").path)
        let done = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let mb = { (bytes: Int64) in String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        guard let total, total > 0 else {
            return Progress(fraction: nil, text: done > 0 ? "下載中… \(mb(done))" : "連線中…")
        }
        let fraction = min(1, Double(done) / Double(total))
        return Progress(fraction: fraction * 0.9, text: "下載中… \(mb(done)) / \(mb(total))（\(Int(fraction * 100))%）")
    }

    private static func lastLogLine() -> String? {
        guard let text = try? String(contentsOf: logURL, encoding: .utf8) else { return nil }
        return text.split(separator: "\n").last.map(String.init)
    }

    /// 結束本行程讓系統載入新版（學習資料先存檔，同 SIGTERM 的處理）
    static func restart() {
        CodeZhuyinInputController.userPhrases.flush()
        SmartInput.stop()
        exit(0)
    }
}
