#!/bin/zsh
set -euo pipefail

# ===== 輔助函數 =====
fail() { echo "❌ $1" >&2; exit 1; }

# ===== 檢查依賴 =====
command -v ffmpeg >/dev/null 2>&1 || fail "找不到 ffmpeg，請先安裝。"

# ===== 參數處理 =====
if [ $# -ne 1 ]; then
  echo "❌ 用法錯誤：請提供一個影片檔案名稱"
  echo "✅ 用法範例：$0 input.mp4"
  exit 1
fi

INPUT_FILE="$1"
if [ ! -f "$INPUT_FILE" ]; then
  fail "找不到影片檔案：$INPUT_FILE"
fi

# ===== 檔案路徑設定 =====
BASENAME="${INPUT_FILE%.*}"
OUTPUT_DIR="./output"

# 封面檔名 (從影片中擷取)
COVER_FILE="${BASENAME}_temp_cover.jpg"
# 最終輸出檔名，以區分原始檔案
FINAL_OUTPUT="${OUTPUT_DIR}/${BASENAME}.mp4"

# 檢查輸出檔案是否已存在，避免覆蓋
if [ -f "$FINAL_OUTPUT" ]; then
  fail "輸出檔案已存在：$FINAL_OUTPUT"
fi

echo "🔎 來源影片：$INPUT_FILE"
echo "🖼 目標封面：$COVER_FILE（將由第 10 秒擷取）"
echo "🎯 輸出影片：$FINAL_OUTPUT"

# ---

### 處理步驟

# ===== 步驟 1. 產生封面（第 10 秒截圖）=====
echo "🖼 產生封面（第 10 秒）：$COVER_FILE"
ffmpeg -y -ss 10 -i "$INPUT_FILE" -frames:v 1 "$COVER_FILE"

# ===== 步驟 2. 重新封裝並嵌入封面 =====
echo "🔄 正在將封面圖片嵌入影片：$INPUT_FILE → $FINAL_OUTPUT"
# 使用 noglob 避免 Zsh 解析 ?
noglob ffmpeg -y \
  -i "$INPUT_FILE" -i "$COVER_FILE" \
  -map 0 -map 1:v:0 \
  -c copy \
  -c:v:1 mjpeg -disposition:v:1 attached_pic \
  -metadata:s:v:1 title="Cover" \
  -movflags +faststart \
  "$FINAL_OUTPUT"

# ===== 步驟 3. 清理 =====
echo "🧹 移除臨時封面檔案：$COVER_FILE"
rm -f "$COVER_FILE"

echo "✅ 完成！"
echo "📁 輸出路徑：$FINAL_OUTPUT"
echo "⚠️ 注意：原始影片檔案並未被移動或刪除。"