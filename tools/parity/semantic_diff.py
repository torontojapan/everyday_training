#!/usr/bin/env python3
"""semantic_diff.py — iOS↔Android の「画面の意味ツリー(可視テキスト要素)」を構造照合する。

背景 / 位置づけ(docs/PARITY_100_PLAN.md §D「本命」):
  SSIM/ピクセル差分は 1段 weight・1px 差に盲目で、欠落/余剰/並び替え要素も拾いにくい。
  そこで「各画面の可視テキスト要素(文言 + 正規化座標)」を iOS と Android で抽出し、
  **要素集合・並び順を等値検証**する。これは『種目セクション見出しの欠落』のような
  構造ドリフトを検出する(=今セッションで手作業発見したクラスのバグを自動化する)。

  注意(現状の到達点と限界):
   - v1 は **文言 + 位置(読み順)** の照合。**font size/weight/色は OS の既定 a11y/semantics
     ツリーに出ない**ため未対応(将来: Compose semantics に解決済 TextStyle を載せる/iOS は
     Inspectable な dump を足す)。size/weight/色は当面 parity_guard(--strict)+ golden 目視が担う。
   - データ依存の文言(連続数・日付・友達名)は `--ignore-dynamic` で正規化照合する。

抽出:
  Android: emulator 上の現在画面を `uiautomator dump` → 可視 text ノード(bounds 付き)。
    python3 semantic_diff.py android <screen-name> --out /tmp/sem/<screen>.and.json
  iOS: XCUITest が各画面で app.debugDescription(アクセシビリティ階層)を attachment 保存 →
    `xcresulttool export` で取り出した .txt を渡す。
    python3 semantic_diff.py ios <screen-name> /path/to/<screen>.debugdesc.txt --out /tmp/sem/<screen>.ios.json
  照合:
    python3 semantic_diff.py compare /tmp/sem/<screen>.ios.json /tmp/sem/<screen>.and.json
"""
import html
import json
import re
import subprocess
import sys


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


# ---- Android: uiautomator dump → text nodes ----
# 注意: uiautomator dump は **可視ノードのみ**。スクロール画面は --scroll で上スワイプしながら
# 一意テキストを累積し、iOS debugDescription(全階層)と公平に比較する。
def _dump_nodes():
    sh("adb", "shell", "uiautomator", "dump", "/sdcard/ui.xml")
    xml = sh("adb", "shell", "cat", "/sdcard/ui.xml")
    out = []
    for m in re.finditer(r'text="([^"]+)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml):
        t = html.unescape(m.group(1))  # uiautomator XML は & を &amp; 等にエスケープする
        x1, y1, x2, y2 = map(int, m.groups()[1:])
        out.append((t, (x1 + x2) / 2 / 1080, (y1 + y2) / 2 / 2400))
    return out


def extract_android(screen, scroll=False):
    seen = {}
    passes = 6 if scroll else 1
    for _ in range(passes):
        for t, nx, ny in _dump_nodes():
            seen.setdefault(t, (nx, ny))  # 初出の位置を保持(読み順の目安)
        if scroll:
            sh("adb", "shell", "input", "swipe", "540", "1900", "540", "700", "250")
            import time
            time.sleep(0.6)
    nodes = [{"text": t, "nx": round(nx, 3), "ny": round(ny, 3)} for t, (nx, ny) in seen.items()]
    nodes.sort(key=lambda n: (round(n["ny"], 2), n["nx"]))
    return {"screen": screen, "platform": "android", "nodes": nodes}


# ---- iOS: XCUITest debugDescription(階層 dump)→ text nodes ----
# 行例:  StaticText, 0x..., {{24.0, 120.0}, {80.0, 22.0}}, label: '今週'
IOS_LINE = re.compile(r"(StaticText|Button|TextField|SecureTextField)[^,]*,.*\{\{([\d.\-]+), ([\d.\-]+)\}, \{([\d.\-]+), ([\d.\-]+)\}\}.*?(?:label|value|placeholderValue): '([^']*)'")


def extract_ios(screen, path, screen_w=440.0, screen_h=956.0):
    nodes = []
    for line in open(path, encoding="utf-8", errors="ignore"):
        m = IOS_LINE.search(line)
        if not m:
            continue
        _, x, y, w, h, label = m.groups()
        if not label.strip():
            continue
        cx = (float(x) + float(w) / 2) / screen_w
        cy = (float(y) + float(h) / 2) / screen_h
        nodes.append({"text": label, "nx": round(cx, 3), "ny": round(cy, 3)})
    nodes.sort(key=lambda n: (round(n["ny"], 2), n["nx"]))
    return {"screen": screen, "platform": "ios", "nodes": nodes}


# ---- 動的文言の正規化(数値/日付/件数を伏せる)----
def norm(t):
    t = re.sub(r"\d+", "#", t)
    return t.strip()


def compare(ios, android, ignore_dynamic=True):
    def key(n):
        return norm(n["text"]) if ignore_dynamic else n["text"]
    iset = [key(n) for n in ios["nodes"]]
    aset = [key(n) for n in android["nodes"]]
    from collections import Counter
    ic, ac = Counter(iset), Counter(aset)
    only_ios = list((ic - ac).elements())
    only_and = list((ac - ic).elements())
    # 読み順(共通要素の相対順)違い
    common = [t for t in iset if t in ac]
    common_a = [t for t in aset if t in ic]
    order_mismatch = common != common_a
    return {
        "screen": ios.get("screen"),
        "ios_only": only_ios,          # iOS にあって Android に無い(=欠落の疑い)
        "android_only": only_and,      # Android にあって iOS に無い(=余剰の疑い)
        "order_mismatch": order_mismatch,
        "ios_count": len(iset), "android_count": len(aset),
        "match": not only_ios and not only_and and not order_mismatch,
    }


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__); return
    cmd = a[0]
    out = None
    if "--out" in a:
        out = a[a.index("--out") + 1]
    if cmd == "android":
        res = extract_android(a[1], scroll="--scroll" in a)
    elif cmd == "ios":
        res = extract_ios(a[1], a[2])
    elif cmd == "compare":
        ios = json.load(open(a[1])); android = json.load(open(a[2]))
        res = compare(ios, android, ignore_dynamic="--exact" not in a)
        print(json.dumps(res, ensure_ascii=False, indent=2))
        sys.exit(0 if res["match"] else 1)
    else:
        print("unknown cmd"); sys.exit(2)
    txt = json.dumps(res, ensure_ascii=False, indent=2)
    if out:
        open(out, "w", encoding="utf-8").write(txt)
        print(f"wrote {out} ({len(res['nodes'])} nodes)")
    else:
        print(txt)


if __name__ == "__main__":
    main()
