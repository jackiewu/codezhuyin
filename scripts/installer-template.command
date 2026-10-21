#!/bin/bash
# 碼注音 CodeZhuyin 安裝程式——雙擊即可執行
cd "$(dirname "$0")"
clear

cat <<'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  碼注音 CodeZhuyin — 中英混輸零阻礙的注音輸入法
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

if [ ! -d "CodeZhuyin.app" ]; then
  echo "❌ 找不到 CodeZhuyin.app —— 請確認這個檔案與 CodeZhuyin.app 放在同一個資料夾。"
  echo
  read -n 1 -s -r -p "按任意鍵關閉…"
  exit 1
fi

DEST="$HOME/Library/Input Methods"

echo "正在安裝到：$DEST"
echo

# 從網路下載的檔案會被標記隔離屬性，移除後系統才肯載入
xattr -dr com.apple.quarantine "CodeZhuyin.app" 2>/dev/null

mkdir -p "$DEST"
if [ -d "$DEST/CodeZhuyin.app" ]; then
  echo "・偵測到舊版，先移除"
  pkill -x CodeZhuyin 2>/dev/null
  rm -rf "$DEST/CodeZhuyin.app"
fi

cp -R "CodeZhuyin.app" "$DEST/"
echo "・已複製 CodeZhuyin.app"

"$DEST/CodeZhuyin.app/Contents/MacOS/CodeZhuyin" install >/dev/null 2>&1
echo "・已向系統註冊輸入法"
echo

cat <<'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅ 安裝完成！還差最後兩步
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. 登出後再登入
     （macOS 的限制：新輸入法必須重新登入才會出現）

  2. 打開「系統設定 › 鍵盤 › 輸入來源 › 編輯 › ＋」
     選「繁體中文」→ 找到「碼注音」→ 加入

  之後從選單列切換到碼注音就能開始打字。
  第一次使用建議先看「操作說明」：
  切換到碼注音後，點選單列的碼注音圖示 › 操作說明…

EOF

read -n 1 -s -r -p "按任意鍵關閉…"
echo
