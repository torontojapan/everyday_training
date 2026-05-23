#!/usr/bin/env bash
# Image generation wrapper: OpenAI primary, Nanobanana (Gemini 2.5 Flash Image) fallback
# Usage: ./gen_image.sh --prompt "<text>" --out <path> [--size 1024x1024]

set -euo pipefail

REPO_ROOT="/Users/jun/Documents/Business_Project_Management/serial_training"
LOG_DIR="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR"

PROMPT=""
OUT_PATH=""
SIZE="1024x1024"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) PROMPT="$2"; shift 2 ;;
    --out)    OUT_PATH="$2"; shift 2 ;;
    --size)   SIZE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PROMPT" || -z "$OUT_PATH" ]]; then
  echo "Usage: $0 --prompt <text> --out <path> [--size WxH]" >&2
  exit 1
fi

TS=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/image_gen_${TS}.log"
mkdir -p "$(dirname "$OUT_PATH")"

echo "=== Image Gen @ $TS ===" | tee "$LOG_FILE"
echo "Prompt: $PROMPT" | tee -a "$LOG_FILE"
echo "Out:    $OUT_PATH" | tee -a "$LOG_FILE"
echo "Size:   $SIZE" | tee -a "$LOG_FILE"

try_openai() {
  if [[ -z "${OPENAI_API_KEY:-}" ]]; then
    echo "[openai] OPENAI_API_KEY unset — skip" | tee -a "$LOG_FILE"
    return 1
  fi
  echo "[openai] generating via gpt-image-1..." | tee -a "$LOG_FILE"
  local RESP
  RESP=$(curl -sS https://api.openai.com/v1/images/generations \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg p "$PROMPT" --arg s "$SIZE" '{model:"gpt-image-1", prompt:$p, size:$s, n:1}')" \
    2>>"$LOG_FILE") || return 1
  local B64
  B64=$(echo "$RESP" | jq -r '.data[0].b64_json // empty')
  if [[ -z "$B64" ]]; then
    echo "[openai] no b64 in response: $RESP" | tee -a "$LOG_FILE"
    return 1
  fi
  echo "$B64" | base64 --decode > "$OUT_PATH"
  echo "[openai] saved: $OUT_PATH" | tee -a "$LOG_FILE"
  return 0
}

try_nanobanana() {
  # Nanobanana = Gemini 2.5 Flash Image. Requires GOOGLE_API_KEY or GEMINI_API_KEY.
  local KEY="${GEMINI_API_KEY:-${GOOGLE_API_KEY:-${NANOBANANA_API_KEY:-}}}"
  if [[ -z "$KEY" ]]; then
    echo "[nanobanana] no API key set (GEMINI_API_KEY/GOOGLE_API_KEY/NANOBANANA_API_KEY) — skip" | tee -a "$LOG_FILE"
    return 1
  fi
  echo "[nanobanana] generating via gemini-2.5-flash-image..." | tee -a "$LOG_FILE"
  local RESP
  RESP=$(curl -sS "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image-preview:generateContent?key=$KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg p "$PROMPT" '{contents:[{parts:[{text:$p}]}], generationConfig:{responseModalities:["IMAGE"]}}')" \
    2>>"$LOG_FILE") || return 1
  local B64
  B64=$(echo "$RESP" | jq -r '.candidates[0].content.parts[]? | select(.inlineData) | .inlineData.data' | head -1)
  if [[ -z "$B64" ]]; then
    echo "[nanobanana] no inline data in response. Raw: $RESP" | tee -a "$LOG_FILE"
    return 1
  fi
  echo "$B64" | base64 --decode > "$OUT_PATH"
  echo "[nanobanana] saved: $OUT_PATH" | tee -a "$LOG_FILE"
  return 0
}

if try_openai; then
  echo "OK (openai)"
  exit 0
fi
if try_nanobanana; then
  echo "OK (nanobanana)"
  exit 0
fi

echo "FAIL: all providers exhausted" | tee -a "$LOG_FILE"
touch "${OUT_PATH}.MISSING"
exit 2
