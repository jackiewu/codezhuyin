# 碼注音 CodeZhuyin

給工程師用的 macOS 繁體中文注音輸入法：**中英混打不用切換，反引號 `` ` `` 與鍵盤上的 ASCII 標點直接輸出。**

```
這個 API 回傳 `null` 的時候要先檢查 `user_id` 欄位
```

上面這一行全程不用按 Caps Lock、不用切輸入法，`` ` ``、`_` 也不會跳出符號表或變成全形。

本專案以 [融鍵 BlendKey](https://github.com/0rigind1865-bit/BlendKey)（MIT）為基底改寫，詞庫來自 [小麥注音 McBopomofo](https://github.com/openvanilla/McBopomofo)（MIT）。

## 跟一般注音輸入法不一樣的地方

| 行為 | 一般注音（含 0c、BlendKey） | 碼注音 |
| --- | --- | --- |
| `` ` `` | 開符號表 | 直接輸出 `` ` ``，``` 區塊也一樣 |
| `'` `[` `]` `<` `>` `?` `!` `:` | 轉成全形 、「」，。？！： | 預設半形原樣（偏好設定可開全形） |
| `` `foo` `` 這種打到一半接標點 | 標點被吞掉，或 foo 變注音 | 打到一半的鍵當英文送出，再送標點 |
| 中英切換 | 要按 Caps Lock／Shift | 自動偵測；Shift 單擊仍可手動切 |

其他功能沿用 BlendKey：整句組字、使用者學習、英文自動偵測與並列選字、Shift＋字母英文段、長按直出、聯想詞、本機 AI 補句與同音校正（Breeze-7B，選用）。

## 安裝（下載版）

1. 到 [Releases](../../releases) 下載 `latest-main` 裡的 `CodeZhuyin-x.y.z.zip`，解壓縮
2. 沒有付費開發者憑證，macOS 會擋下安裝檔（新版 macOS 右鍵打開也沒用）。打開終端機，在解壓出來的資料夾執行：
   ```bash
   xattr -dr com.apple.quarantine . && ./安裝碼注音.command
   ```
   或是雙擊被擋之後，到「系統設定 › 隱私權與安全性」按「仍要打開」
3. 依畫面指示登出再登入
4. 系統設定 › 鍵盤 › 輸入來源 › 編輯 › ＋ › 繁體中文 › 加入「碼注音」

## 從原始碼建置

需求：macOS 14 以上、Xcode 26（Swift 6.2）。

```bash
swift test              # 核心邏輯單元測試（不需安裝輸入法）
scripts/install.sh      # 建置、打包、安裝到 ~/Library/Input Methods
scripts/make-release.sh # 打包可散布的 zip
```

詞庫 `Resources/data/data.txt` 已隨 repo 提供；要重新產生可執行 `scripts/build-data.sh`。
首次安裝要登出再登入，之後重跑 `scripts/install.sh` 會直接熱更新。

不安裝也能試組字管線：`swift run codezhuyin-cli`。

## 怎麼測反引號

切到碼注音後，在任何編輯器依序打：

- `` ` `` → 出現 `` ` ``（不會跳符號表）
- `` ``` `` → 三個反引號
- `` ` ``、`foo`、`` ` `` → `` `foo` ``
- `su3cl3`、`` ` `` → `你好` 之後接 `` ` ``

## 文件

- [介紹與安裝說明網頁](https://jackiewu.github.io/codezhuyin/)（原始檔 `docs/index.html`）
- [設計與參考比較](docs/DESIGN.md)
- [BlendKey 原始說明](docs/upstream-BlendKey-README.md)（完整功能與快捷鍵）

## 授權

MIT。見 [LICENSE](LICENSE)；詞庫授權見 `Resources/data/LICENSE-McBopomofo.txt`。
