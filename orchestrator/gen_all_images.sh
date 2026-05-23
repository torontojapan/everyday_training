#!/usr/bin/env bash
# Generate all cat character images + app icon from prompts.json.
# Usage: ./gen_all_images.sh
# Requires: OPENAI_API_KEY (primary) or GEMINI_API_KEY/GOOGLE_API_KEY (fallback).

set -euo pipefail

REPO_ROOT="/Users/jun/Documents/Business_Project_Management/serial_training"
PROMPTS_JSON="$REPO_ROOT/assets/cat_character/prompts.json"

if [[ ! -f "$PROMPTS_JSON" ]]; then
  echo "Missing prompts file: $PROMPTS_JSON" >&2
  exit 1
fi

if [[ -z "${OPENAI_API_KEY:-}" && -z "${GEMINI_API_KEY:-}" && -z "${GOOGLE_API_KEY:-}" && -z "${NANOBANANA_API_KEY:-}" ]]; then
  echo "No image API key set. Export one of:" >&2
  echo "  - OPENAI_API_KEY (primary: OpenAI gpt-image-1)" >&2
  echo "  - GEMINI_API_KEY / GOOGLE_API_KEY / NANOBANANA_API_KEY (fallback: gemini-2.5-flash-image)" >&2
  exit 1
fi

cd "$REPO_ROOT"

COUNT=$(jq '.images | length' "$PROMPTS_JSON")
echo "Generating $COUNT images..."

for i in $(seq 0 $((COUNT - 1))); do
  OUT=$(jq -r ".images[$i].out" "$PROMPTS_JSON")
  PROMPT=$(jq -r ".images[$i].prompt" "$PROMPTS_JSON")
  SIZE=$(jq -r ".images[$i].size // \"1024x1024\"" "$PROMPTS_JSON")
  echo ""
  echo "[$((i+1))/$COUNT] $OUT"
  ./orchestrator/gen_image.sh --prompt "$PROMPT" --out "$REPO_ROOT/$OUT" --size "$SIZE" || {
    echo "  failed (continuing)" >&2
  }
done

echo ""
echo "Done. Generated images:"
find "$REPO_ROOT/assets" -name "*.png" -type f 2>/dev/null | sort
echo ""
echo "Failures (if any):"
find "$REPO_ROOT/assets" -name "*.MISSING" -type f 2>/dev/null | sort
