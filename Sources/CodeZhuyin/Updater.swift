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
        /// 匿名可下載的網址（public repo 才有）；nil＝要走 gh
        let downloadURL: URL?
    }

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
            downloadURL: (zip?["browser_download_url"] as? String).flatMap(URL.init(string:))
        )
    }

    private enum GhResult { case success(Release), failure(String) }

    private static func checkWithGh() -> GhResult {
        guard let gh = ghPath else {
            return .failure("讀不到 GitHub 上的版本。repo 是 private 時需要 gh：在終端機執行 brew install gh && gh auth login")
        }
        let (status, output) = run(gh, ["release", "view", tag, "-R", repo, "--json", "targetCommitish,name"])
        guard status == 0, let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commit = json["targetCommitish"] as? String else {
            let reason = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure("gh 查詢失敗：\(reason.isEmpty ? "未知錯誤" : reason)（試試在終端機執行 gh auth login）")
        }
        return .success(Release(commit: commit, title: json["name"] as? String ?? tag, downloadURL: nil))
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

    /// 背景跑安裝腳本後立刻回傳。腳本最後會結束本行程（pkill），所以用 nohup 脫離，
    /// 進度與錯誤寫在 ~/Library/Logs/CodeZhuyin-update.log。
    static func install(_ release: Release) -> String? {
        let download: String
        if let url = release.downloadURL {
            download = "curl -fsSL -o \"$TMP/update.zip\" '\(url.absoluteString)'"
        } else if let gh = ghPath {
            download = "'\(gh)' release download \(tag) -R \(repo) -p 'CodeZhuyin-*.zip' -O \"$TMP/update.zip\""
        } else {
            return "找不到下載方式：請安裝 gh（brew install gh && gh auth login）"
        }
        let script = """
            set -euo pipefail
            exec >>"\(logURL.path)" 2>&1
            echo "== $(date) 更新到 \(release.commit)"
            TMP="$(mktemp -d)"
            trap 'rm -rf "$TMP"' EXIT
            \(download)
            /usr/bin/ditto -x -k "$TMP/update.zip" "$TMP/unzipped"
            APP="$(/usr/bin/find "$TMP/unzipped" -maxdepth 3 -name CodeZhuyin.app -type d | head -1)"
            [ -n "$APP" ] || { echo "zip 裡找不到 CodeZhuyin.app"; exit 1; }
            /usr/bin/xattr -dr com.apple.quarantine "$APP" || true
            DEST="$HOME/Library/Input Methods"
            mkdir -p "$DEST"
            /usr/bin/rsync -a --delete "$APP/" "$DEST/CodeZhuyin.app/"
            echo "已安裝，重啟輸入法"
            /usr/bin/pkill -x CodeZhuyin || true
            """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        process.arguments = ["/bin/bash", "-c", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return "無法啟動更新：\(error.localizedDescription)"
        }
        Log.general.info("更新：開始安裝 \(release.commit, privacy: .public)")
        return nil
    }
}
