#!/usr/bin/env bash
# Gemini evaluation wrapper (Evaluate agent — INDEPENDENT)
# Usage: ./run_gemini_eval.sh <phase_num> <prompt_file>

set -euo pipefail

REPO_ROOT="/Users/jun/Documents/Business_Project_Management/serial_training"
PHASE_NUM="${1:-}"
PROMPT_FILE="${2:-}"

if [[ -z "$PHASE_NUM" || -z "$PROMPT_FILE" || ! -f "$PROMPT_FILE" ]]; then
  echo "Usage: $0 <phase_num> <prompt_file>" >&2
  exit 1
fi

TS=$(date +%Y%m%d_%H%M%S)
LOG_DIR="$REPO_ROOT/logs"
ARTIFACT_DIR="$REPO_ROOT/artifacts/phase${PHASE_NUM}"
mkdir -p "$LOG_DIR" "$ARTIFACT_DIR"
LOG_FILE="$LOG_DIR/gemini_eval_phase${PHASE_NUM}_${TS}.log"
OUT_FILE="$ARTIFACT_DIR/evaluation.md"

cd "$REPO_ROOT"

echo "=== Gemini Evaluation: Phase ${PHASE_NUM} @ ${TS} ===" | tee "$LOG_FILE"
echo "Prompt:    $PROMPT_FILE" | tee -a "$LOG_FILE"
echo "Output:    $OUT_FILE" | tee -a "$LOG_FILE"
echo "Workspace: app/ + specs/ ONLY (artifacts/ EXCLUDED for independence)" | tee -a "$LOG_FILE"
echo "---" | tee -a "$LOG_FILE"

# Run Gemini in plan (read-only) mode with only app/ and specs/ in context.
# Use --yolo to skip approval prompts but kept read-only via --approval-mode plan.
gemini \
  --approval-mode plan \
  --include-directories "$REPO_ROOT/app","$REPO_ROOT/specs" \
  --output-format text \
  -p "$(cat "$PROMPT_FILE")" 2>&1 | tee -a "$LOG_FILE" | tee "$OUT_FILE"

echo "---" | tee -a "$LOG_FILE"
echo "Evaluation saved to: $OUT_FILE"
echo "Log saved to: $LOG_FILE"
