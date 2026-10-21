# 碼注音設計文件

## 目標

1. 繁體中文注音（大千鍵盤），中英混打不用 Caps Lock 切換
2. **反引號 `` ` `` 與鍵盤上的 ASCII 標點原樣輸出**（最重要），不跳符號表、不轉全形
3. AI 智慧選字（整句組字、同音校正），全部在本機
4. 體驗接近目前在用的 0c：候選窗、中英判斷

## 參考比較（2026-10 調查）

| 專案 | 平台 | 開源 | 中英混打 | AI | 反引號／標點 | 對我們的價值 |
| --- | --- | --- | --- | --- | --- | --- |
| [0c 靈犀注音](https://0c.biggo.com/) | Win/Linux/macOS(arm64) | 未標示 | Beta，預設關；Tab 補英文、8 萬英文詞、拼字更正 | 本機 Transformer 選字＋標點，比新酷音首選錯誤少約 60%（官方數字） | `=` 開 emoji、Enter 自動補逗號，`` ` `` 無法輸出 | UI／手感標竿，不能拿原始碼 |
| [隨便打](https://cerry0524.github.io/suibianda/) | macOS 14+（Win/Linux beta） | 未標示（免費） | 7.5 萬英文詞判邊界，英文 typo 修正，nginx 這類技術詞不動 | 五層：詞庫即時組字 → CKIP BERT 整句重讀 → Qwen3.5-0.8B（MLX）流暢度，背景跑不擋打字 | `%` `:` `.` 半形、程式碼後括號與底線半形、Tab 切命名風格 | **AI 分層設計最值得抄**：打字路徑不等模型 |
| [BlendKey 融鍵](https://github.com/0rigind1865-bit/BlendKey) | macOS 14+ | **MIT** | 英文詞典＋覆寫偵測、反向偵測自動切回、Shift 英文段 | llama.cpp＋Breeze-7B，同音字文法限制校正、補句 | `` ` `` 開符號表，預設全形標點 | **直接當基底**：Swift＋InputMethodKit、核心與殼分層、101 個單元測試 |
| [晶晶 ZingIME](https://zingime.com/) | macOS 14.7+ | 否（付費試用） | 混打不切換、Tab 英文預測 | 上下文選同音字 | 未說明 | 產品方向參考 |
| [創音 TronIn](https://tronin.1tron.ai/) | macOS 13+（Apple 晶片） | 否（免費） | 中英雙解讀並保留另一解、右 Shift 英文模式 | 使用習慣學習 | 中文狀態符號鍵開標點選單；但英文／程式碼中的 `_` `'` 直接輸出；Option 出半形 | 「程式碼情境符號直出」規則可參考 |
| [jarvis-voice](https://github.com/urusaqqrun/jarvis-voice) | macOS | MIT | — | 語音轉文字＋LLM 清理 | — | 不是輸入法；未來語音輸入可參考（BlendKey 已有內建語音） |

結論：沒有一個現成方案同時滿足「開源可改」與「`` ` `` 原樣輸出」，BlendKey 架構最接近需求且是 MIT，所以以它為基底改寫，而不是從零刻 IMK 殼與注音引擎。

## 架構

```
NSEvent ─▶ CodeZhuyinInputController（IMK 殼，AppKit）
              │  KeyInput（平台無關按鍵）
              ▼
          InputEngine（CodeZhuyinCore，純 Swift、可單元測試）
              ├─ SyllableComposer   大千鍵位 → 注音音節
              ├─ SentenceDecoder    詞圖＋動態規劃整句組字（小麥注音詞庫）
              ├─ EnglishDetector    英文詞典＋覆寫啟發式
              ├─ ChineseTypingDetector  英文段中偵測到注音就切回
              ├─ UserPhraseStore    選字學習、自動造詞、詞對接續
              └─ 標點規則（本專案改動重點，見下）
          SmartInput（選用）── llama.cpp server ── Breeze-7B GGUF（本機）
```

### 標點規則（碼注音改動）

大千鍵盤佔用了 `- ; , . /` 與數字列，其他標點鍵都不是注音鍵，處理順序：

1. `` ` ``：一律走「程式碼標點直出」，除非偏好設定打開「反引號開符號表」
2. 其他非注音標點（`_ ( ) [ ] { } < > = ' " ! ? : ~ \ |` 等）：預設同樣直出；打開「全形標點」才轉 ，。「」
3. 程式碼標點直出：
   - 組字器裡有還沒成音節的按鍵 → 當英文原樣（`foo`、`user_id` 的 user）
   - 組字區有已組好的中文 → 一起上屏
   - 最後把標點鍵原樣交給 app；組字區全空時完全不經手，跟英文鍵盤一樣

測試：`Tests/CodeZhuyinCoreTests/BacktickTests.swift`。

## 路線圖

- **v0.1（現在）**：BlendKey 基底＋反引號／半形標點規則、改名可與 BlendKey 並存、GitHub Actions 自動建置 zip
- **v0.2**：程式碼情境模式——標點直出後自動進英文段（`foo_bar`、`fn(x)` 後半不再被當注音）；`;` 長按出分號
- **v0.3**：AI 分層（學隨便打）：打字路徑只用詞庫，停手後背景用小模型（MLX，Apple 晶片）整句重排同音字，取代或補強 Breeze-7B（模型小很多、記憶體低）
- **v0.4**：候選窗 UI 往 0c 靠攏；英文拼字更正；技術詞庫（git、npm、k8s 等）
