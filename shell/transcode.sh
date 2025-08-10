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
  fail "找不到檔案：$INPUT_FILE"
fi

# ===== 檔案路徑設定 =====
BASENAME="${INPUT_FILE%.*}"
OUTPUT_DIR="./output"
mkdir -p "$OUTPUT_DIR"

# 輸出檔名 (轉檔後會先產生在當前目錄)
OUTPUT_FILE="${BASENAME}_h265_480p.mp4"
# 最終輸出路徑 (會被搬移到此處)
FINAL_OUTPUT="${OUTPUT_DIR}/${INPUT_FILE}"
# 封面檔名 (從影片中擷取)
COVER_FILE="${BASENAME}.jpg"

# 檢查最終輸出檔案是否已存在，避免覆蓋
if [ -f "$FINAL_OUTPUT" ]; then
  fail "最終輸出檔案已存在：$FINAL_OUTPUT"
fi

echo "🔎 來源檔案：$INPUT_FILE"
echo "🖼 目標封面：$COVER_FILE（將由第 10 秒擷取）"
echo "🎯 轉檔輸出：$OUTPUT_FILE → ${FINAL_OUTPUT}"

# ---

### 處理步驟

# ===== 步驟 1. 產生封面（第 10 秒截圖）=====
echo "🖼 產生封面（第 10 秒）：$COVER_FILE"
ffmpeg -y -ss 10 -i "$INPUT_FILE" -frames:v 1 "$COVER_FILE"

# ===== 步驟 2. 轉檔 + 嵌入封面（attached_pic）=====
echo "🔄 開始轉檔並嵌入封面：$INPUT_FILE → $OUTPUT_FILE"
# 使用 noglob 避免 Zsh 解析 0:a? 和 0:s?
noglob ffmpeg -y \
  -i "$INPUT_FILE" -i "$COVER_FILE" \
  -map 0:v:0 -map 0:a? -map 0:s? -map 1:v:0 \
  -c:v libx265 -crf 26 -vf "scale=854:480" \
  -c:a copy -c:s copy \
  -c:v:1 mjpeg -disposition:v:1 attached_pic \
  -metadata:s:v:1 title="Cover" \
  -movflags +faststart \
  "$OUTPUT_FILE"

# ===== 步驟 3. 搬運檔案 =====
echo "📦 搬移轉檔影片檔案：$OUTPUT_FILE → $FINAL_OUTPUT"
# 確保輸出目錄存在
mkdir -p "$OUTPUT_DIR"
mv -f "$OUTPUT_FILE" "$FINAL_OUTPUT"

# ===== 步驟 4. 清理 =====
echo "🧹 移除原始影片和封面圖片：$INPUT_FILE, $COVER_FILE"
rm -f "$INPUT_FILE" "$COVER_FILE"

echo "✅ 完成！"
echo "📁 輸出路徑：$FINAL_OUTPUT"