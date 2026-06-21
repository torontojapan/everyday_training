#!/usr/bin/env python3
"""
parity_guard.py — Android↔iOS パリティの「ドリフト源」を構造的に禁止する CI/pre-commit ガード。

背景: 2026-06 のセッションで、生 fontSize / ハードコード色 / FontWeight.Black が ~150 箇所に散在し、
iOS build 12 とフォント weight/size がズレていた(SSIM では検出不能な 1段・1px 差)。
本ガードは「全テキストはデザイントークン(AppType)経由」「全色はパレット経由」を強制し、
ズレの発生源をコンパイル前に止める。詳細方針 = docs/PARITY_100_PLAN.md。

ルール(app-android の presentation 配下):
  1. 生 `fontSize = N.sp`            → 禁止。AppType.<token> を使う(iOS Dynamic Type サイズを内包)。
  2. `Color(0x........)` リテラル     → 禁止。palette/AppTheme トークンを使う。
  3. `FontWeight.Black`             → 禁止。iOS は `.heavy`(= FontWeight.ExtraBold)。Black は大抵ドリフト。

例外: iOS 側も同値をハードコードしている等の正当な箇所は、その行に
  `// parity-allow: <理由>`
を付ければ免除(= 明示的にレビュー済みであることの記録)。

使い方:
  python3 tools/parity/parity_guard.py            # 違反一覧 + 件数。違反>0 で exit 1(CI 用)。
  python3 tools/parity/parity_guard.py --update-baseline   # 現状を既知ベースラインとして記録(段階導入)。
  python3 tools/parity/parity_guard.py --strict   # ベースラインを無視し、全違反で fail(クリーン化後はこれ)。
ベースライン運用: 既存違反は baseline に固定し、**新規違反のみ** fail。徐々に baseline を減らし 0 にする。
"""
import os
import re
import sys
import json

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCAN_DIR = os.path.join(ROOT, "app-android/app/src/main/java/com/goexercise/app/presentation")
BASELINE = os.path.join(ROOT, "tools/parity/parity_guard_baseline.json")

# ファイル単位の除外(テーマ定義そのもの・トークン定義は生値を持って当然)。
EXCLUDE_BASENAMES = set()
EXCLUDE_PATHPARTS = ("/ui/theme/",)

RULES = [
    ("raw_fontSize", re.compile(r"\bfontSize\s*=\s*\d+(\.\d+)?\.sp"),
     "生 fontSize 禁止 → AppType.<token>(iOS サイズ内包)を使う"),
    ("hardcoded_color", re.compile(r"\bColor\(0x[0-9A-Fa-f]{6,8}\b"),
     "ハードコード色 禁止 → palette/AppTheme トークンを使う"),
    ("fontweight_black", re.compile(r"\bFontWeight\.Black\b"),
     "FontWeight.Black 禁止 → iOS .heavy = FontWeight.ExtraBold"),
]
ALLOW = re.compile(r"//\s*parity-allow")


def scan():
    violations = []
    for dirpath, _, files in os.walk(SCAN_DIR):
        if any(p in dirpath.replace(os.sep, "/") for p in EXCLUDE_PATHPARTS):
            continue
        for fn in files:
            if not fn.endswith(".kt") or fn in EXCLUDE_BASENAMES:
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, ROOT)
            for i, line in enumerate(open(path, encoding="utf-8"), 1):
                if ALLOW.search(line):
                    continue
                for rule_id, pat, _ in RULES:
                    if pat.search(line):
                        violations.append({"rule": rule_id, "file": rel, "line": i,
                                           "text": line.strip()[:120]})
    return violations


def key(v):
    return f"{v['rule']}|{v['file']}|{v['text']}"  # 行番号は変動するので除外


def main():
    args = sys.argv[1:]
    violations = scan()
    if "--update-baseline" in args:
        json.dump(sorted(key(v) for v in violations), open(BASELINE, "w"), ensure_ascii=False, indent=0)
        print(f"baseline 記録: {len(violations)} 件 → {os.path.relpath(BASELINE, ROOT)}")
        return 0
    baseline = set()
    if "--strict" not in args and os.path.exists(BASELINE):
        baseline = set(json.load(open(BASELINE)))
    new = [v for v in violations if key(v) not in baseline]
    by_rule = {}
    for v in violations:
        by_rule.setdefault(v["rule"], 0)
        by_rule[v["rule"]] += 1
    print("=== parity_guard: ドリフト源スキャン ===")
    for rid, pat, desc in RULES:
        print(f"  {rid}: {by_rule.get(rid,0)} 件 — {desc}")
    print(f"  ベースライン既知: {len(baseline)} / 新規違反: {len(new)}")
    if new:
        print("\n--- 新規違反(要修正)---")
        for v in new[:200]:
            print(f"  [{v['rule']}] {v['file']}:{v['line']}  {v['text']}")
        print(f"\nNG: 新規違反 {len(new)} 件。トークン/パレット経由にするか、正当なら行末に `// parity-allow: 理由`。")
        return 1
    print("\nOK: 新規ドリフト源なし。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
