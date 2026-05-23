#!/usr/bin/env bash
# Generate all cat character images via Codex CLI's image_generation tool (ChatGPT auth).
# No API key required — uses existing Codex login.
# Usage: ./gen_all_images_codex.sh [--parallel N]

set -euo pipefail

REPO_ROOT="/Users/jun/Documents/Business_Project_Management/serial_training"
PROMPTS_JSON="$REPO_ROOT/assets/cat_character/prompts.json"
LOG_DIR="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR"

PARALLEL=1
if [[ "${1:-}" == "--parallel" && -n "${2:-}" ]]; then
  PARALLEL="$2"
fi

if [[ ! -f "$PROMPTS_JSON" ]]; then
  echo "Missing prompts file: $PROMPTS_JSON" >&2
  exit 1
fi

cd "$REPO_ROOT"

COUNT=$(jq '.images | length' "$PROMPTS_JSON")
TS=$(date +%Y%m%d_%H%M%S)
echo "Generating $COUNT images (parallel: $PARALLEL) via Codex image_generation tool..."

generate_one() {
  local idx="$1"
  local out prompt log
  out=$(jq -r ".images[$idx].out" "$PROMPTS_JSON")
  prompt=$(jq -r ".images[$idx].prompt" "$PROMPTS_JSON")
  log="$LOG_DIR/codex_image_$(printf '%02d' "$idx")_${TS}.log"

  mkdir -p "$(dirname "$REPO_ROOT/$out")"

  echo "[$((idx+1))/$COUNT] -> $out"
  codex exec \
    -s workspace-write \
    --skip-git-repo-check \
    --cd "$REPO_ROOT" \
    "Use your image_generation tool to generate one PNG image with this prompt: $prompt . Then save (or cp from your generated_images directory) the final PNG to ./$out . Confirm with 'ls -la ./$out'. If image generation fails or is unavailable, exit with an error message — do not create a placeholder." \
    > "$log" 2>&1

  if [[ -f "$REPO_ROOT/$out" ]]; then
    echo "  OK: $out ($(stat -f%z "$REPO_ROOT/$out" 2>/dev/null || stat -c%s "$REPO_ROOT/$out") bytes)"
  else
    echo "  FAIL: $out (see $log)"
    return 1
  fi
}

export -f generate_one
export REPO_ROOT PROMPTS_JSON LOG_DIR TS COUNT

if [[ "$PARALLEL" -gt 1 ]]; then
  seq 0 $((COUNT - 1)) | xargs -n1 -P"$PARALLEL" -I{} bash -c 'generate_one "$@"' _ {}
else
  for i in $(seq 0 $((COUNT - 1))); do
    generate_one "$i" || true
  done
fi

echo ""
echo "=== Generated files ==="
find "$REPO_ROOT/assets" -name "*.png" -type f 2>/dev/null | sort
echo ""
echo "=== Failures (if any) ==="
find "$REPO_ROOT/assets" -name "*.MISSING" -type f 2>/dev/null
