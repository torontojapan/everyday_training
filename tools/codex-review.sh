#!/usr/bin/env bash
# =============================================================================
# codex-review.sh — Codex(レビュー/監査)を **絶対にハングさせない** 安全ラッパ
# =============================================================================
# 背景(2026-06-23 の事故): 生の `codex exec` を
#   (1) --sandbox 指定なし → `git diff` 実行の承認待ちで無限ハング
#   (2) 出力を `| tail` にパイプ → 完全バッファで進捗もハングも見えない
#   (3) タイムアウトなし → 7.5 時間空転
#   (4) stdin 未クローズ → "Reading additional input from stdin..." で待機
# の 4 条件で実行した結果、7.5 時間ハングして空転した。本ラッパはこの 4 つを
# **構造的に封じる**。Codex を回すときは **必ずこのスクリプト経由**で実行すること
# (生 `codex exec` は使わない)。CLAUDE.md にも明記。
#
# 使い方:
#   tools/codex-review.sh "レビュー用プロンプト文字列"
#   tools/codex-review.sh -f path/to/prompt.txt
#   tools/codex-review.sh -t 600 -o /tmp/myreview.out "..."   # timeout 600s / 出力先指定
#
# 仕様:
#   - codex exec --skip-git-repo-check --sandbox read-only   (承認待ちを発生させない)
#   - stdin は </dev/null                                     (stdin 待ちを発生させない)
#   - 出力は **ファイルへ直接** 書く(tail 等にパイプしない)   (バッファ・ハング検知不能を回避)
#   - 自前のハードタイムアウト(既定 420s)で **プロセスツリーごと kill** (空転を物理的に停止)
#   - 終了後、最終メッセージ部分(最後の "codex" 以降〜"tokens used" 手前)を標準出力へ抽出
#   - 終了コード: 0=正常 / 124=タイムアウト(GNU timeout 互換) / それ以外=codex の失敗
# =============================================================================
set -u

TIMEOUT=420
OUTFILE=""
PROMPT_FILE=""

while getopts "t:o:f:h" opt; do
  case "$opt" in
    t) TIMEOUT="$OPTARG" ;;
    o) OUTFILE="$OPTARG" ;;
    f) PROMPT_FILE="$OPTARG" ;;
    h) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "usage: $0 [-t timeout_sec] [-o outfile] [-f promptfile | <prompt...>]" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

if ! command -v codex >/dev/null 2>&1; then
  echo "ERROR: codex CLI が見つかりません (npm i -g @openai/codex)。" >&2
  exit 127
fi

# プロンプトの取得(-f ファイル or 残り引数)。
if [ -n "$PROMPT_FILE" ]; then
  [ -f "$PROMPT_FILE" ] || { echo "ERROR: prompt file not found: $PROMPT_FILE" >&2; exit 2; }
  PROMPT="$(cat "$PROMPT_FILE")"
else
  PROMPT="$*"
fi
[ -n "${PROMPT//[[:space:]]/}" ] || { echo "ERROR: 空のプロンプトです。" >&2; exit 2; }

# 出力先(未指定なら mktemp)。
if [ -z "$OUTFILE" ]; then
  OUTFILE="$(mktemp -t codex-review.XXXXXX)"
fi
: > "$OUTFILE"

# プロセスツリーを末端から確実に kill(node シム + Rust バイナリ等の子孫も含む)。
kill_tree() {
  local p="$1" c
  for c in $(pgrep -P "$p" 2>/dev/null); do kill_tree "$c"; done
  kill -KILL "$p" 2>/dev/null
}

# --- codex を **読み取り専用 sandbox / stdin 遮断 / ファイル出力** で起動 ---
codex exec --skip-git-repo-check --sandbox read-only "$PROMPT" </dev/null >>"$OUTFILE" 2>&1 &
CODEX_PID=$!

# --- 自前ハードタイムアウト(5s 間隔ポーリング)---
elapsed=0
RC=0
while kill -0 "$CODEX_PID" 2>/dev/null; do
  if [ "$elapsed" -ge "$TIMEOUT" ]; then
    echo "" >>"$OUTFILE"
    echo "===TIMEOUT after ${TIMEOUT}s — killing codex process tree===" >>"$OUTFILE"
    kill_tree "$CODEX_PID"
    RC=124
    break
  fi
  sleep 5
  elapsed=$((elapsed + 5))
done

if [ "$RC" -ne 124 ]; then
  wait "$CODEX_PID" 2>/dev/null
  RC=$?
fi

# --- 結果の要約抽出(最後の "codex" 行以降〜"tokens used" 手前)---
echo "----- codex-review.sh: outfile=$OUTFILE  rc=$RC  elapsed=${elapsed}s -----"
if [ "$RC" -eq 124 ]; then
  echo "TIMEOUT: codex を ${TIMEOUT}s で停止しました(プロセスは kill 済)。プロンプトを絞るか -t を延ばして再実行。"
fi
# 最終メッセージ抽出(なければ末尾を出す)。環境ノイズ(xcodebuild/DVT 等)は除去。
awk '
  /^codex$/ { start=NR; buf=""; capturing=1; next }
  /^tokens used$/ { capturing=0 }
  capturing { buf = buf $0 "\n" }
  END { printf "%s", buf }
' "$OUTFILE" | grep -vE 'xcodebuild|DVTFilePath|DVTDeveloperPaths|confstr|xcrun_db|couldn.t create cache' | tail -60

exit "$RC"
