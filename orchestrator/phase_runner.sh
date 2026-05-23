#!/usr/bin/env bash
# Phase runner: Execute -> Evaluate (Plan is produced by Orchestrator/Claude beforehand)
# Usage: ./phase_runner.sh <phase_num>
#
# Pre-requisite: artifacts/phase{N}/plan.md must exist (written by Orchestrator)
# Pre-requisite: orchestrator/prompts/execute_phase{N}.md and evaluate_phase{N}.md must exist

set -euo pipefail

REPO_ROOT="/Users/jun/Documents/Business_Project_Management/serial_training"
PHASE_NUM="${1:-}"

if [[ -z "$PHASE_NUM" ]]; then
  echo "Usage: $0 <phase_num>" >&2
  exit 1
fi

EXEC_PROMPT="$REPO_ROOT/orchestrator/prompts/execute_phase${PHASE_NUM}.md"
EVAL_PROMPT="$REPO_ROOT/orchestrator/prompts/evaluate_phase${PHASE_NUM}.md"
PLAN="$REPO_ROOT/artifacts/phase${PHASE_NUM}/plan.md"

for f in "$PLAN" "$EXEC_PROMPT" "$EVAL_PROMPT"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing required file: $f" >&2
    exit 1
  fi
done

echo "=== Phase ${PHASE_NUM} Runner ==="
echo "[1/2] Execute (Codex)..."
"$REPO_ROOT/orchestrator/run_codex.sh" "$EXEC_PROMPT"

echo ""
echo "[2/2] Evaluate (Gemini, INDEPENDENT)..."
"$REPO_ROOT/orchestrator/run_gemini_eval.sh" "$PHASE_NUM" "$EVAL_PROMPT"

echo ""
echo "=== Phase ${PHASE_NUM} cycle complete ==="
echo "Plan:       $PLAN"
echo "Execute:    $REPO_ROOT/artifacts/phase${PHASE_NUM}/execute_log.md"
echo "Evaluation: $REPO_ROOT/artifacts/phase${PHASE_NUM}/evaluation.md"
