#!/usr/bin/env bash
# Codex execution wrapper (Execute agent)
# Usage: ./run_codex.sh <prompt_file>

set -euo pipefail

REPO_ROOT="/Users/jun/Documents/Business_Project_Management/serial_training"
PROMPT_FILE="${1:-}"

if [[ -z "$PROMPT_FILE" || ! -f "$PROMPT_FILE" ]]; then
  echo "Usage: $0 <prompt_file>" >&2
  exit 1
fi

TS=$(date +%Y%m%d_%H%M%S)
LOG_DIR="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/codex_${TS}.log"

cd "$REPO_ROOT"

echo "=== Codex Exec @ $TS ===" | tee "$LOG_FILE"
echo "Prompt: $PROMPT_FILE" | tee -a "$LOG_FILE"
echo "Repo:   $REPO_ROOT" | tee -a "$LOG_FILE"
echo "---" | tee -a "$LOG_FILE"

codex exec \
  -s workspace-write \
  --skip-git-repo-check \
  --cd "$REPO_ROOT" \
  < "$PROMPT_FILE" 2>&1 | tee -a "$LOG_FILE"

echo "---" | tee -a "$LOG_FILE"
echo "Log saved to: $LOG_FILE"
