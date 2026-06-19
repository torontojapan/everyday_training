#!/usr/bin/env python3
"""Android↔iOS パリティ差分エンジン。

iOS build 12 の golden スクショと Android 実スクショを「同一視覚状態で撮った」前提で受け取り、
- ステータスバー/ナビ等の chrome を上下クロップ
- 同一寸法へリサイズ
- SSIM(知覚類似度)+ ピクセル差分ヒートマップ
を算出し、横並び合成画像と HTML レポートを出力する。

合格基準(docs/PARITY_100_PLAN.md): SSIM >= しきい値(既定 0.97)。
SwiftUI↔Compose はレンダラ/フォントが別なので 1px 完全一致は原理的に不可能 → 知覚的に区別不能を基準にする。

使い方:
  単発:   python3 diff.py <ios.png> <android.png> [--out composite.png] [--top 0.05 --bottom 0.04]
  バッチ: python3 diff.py --pairs pairs.json --out-dir report/   (pairs.json は下記 build_report の形式)
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image
from skimage.metrics import structural_similarity as ssim


def load_rgb(path):
    return np.asarray(Image.open(path).convert("RGB"))


def crop_chrome(img, top_frac, bottom_frac):
    """上(ステータスバー)・下(ホームインジケータ/ジェスチャバー)を割合でクロップ。"""
    h = img.shape[0]
    t = int(h * top_frac)
    b = h - int(h * bottom_frac)
    return img[t:b]


def align(ios, andr, top, bottom):
    """両画像から chrome をクロップし、Android を iOS の寸法へリサイズして揃える。"""
    ios_c = crop_chrome(ios, top, bottom)
    and_c = crop_chrome(andr, top, bottom)
    h, w = ios_c.shape[:2]
    and_r = np.asarray(Image.fromarray(and_c).resize((w, h), Image.LANCZOS))
    return ios_c, and_r


def apply_masks(img, masks):
    """masks: [[x,y,w,h], ...] を 0..1 の割合で受け取り、その矩形を灰色で塗りつぶす(SSIM 対象外化)。
    猫・大きな数字・候補リスト等の**可変データ領域**を無視し、構造/色/レイアウト/アイコンの差だけを測るため。"""
    if not masks:
        return img
    out = img.copy()
    h, w = out.shape[:2]
    for (mx, my, mw, mh) in masks:
        x0, y0 = int(w * mx), int(h * my)
        x1, y1 = int(w * (mx + mw)), int(h * (my + mh))
        out[y0:y1, x0:x1] = 128
    return out


def compute(ios_path, and_path, top=0.05, bottom=0.04, masks=None):
    ios = load_rgb(ios_path)
    andr = load_rgb(and_path)
    ios_c, and_c = align(ios, andr, top, bottom)
    if masks:
        ios_c = apply_masks(ios_c, masks)
        and_c = apply_masks(and_c, masks)
    # グレースケール SSIM(構造)+ カラー SSIM(channel_axis)。
    score, ssim_map = ssim(ios_c, and_c, channel_axis=2, full=True)
    # 差分ヒートマップ(チャンネル平均の絶対差を増幅)。
    diff = np.abs(ios_c.astype(int) - and_c.astype(int)).mean(axis=2)
    heat = np.clip(diff * 3, 0, 255).astype(np.uint8)
    heat_rgb = np.stack([heat, np.zeros_like(heat), 255 - heat], axis=2)  # 赤=差大 / 青=差小
    return score, ios_c, and_c, heat_rgb


def composite(ios_c, and_c, heat, score, threshold, out_path):
    """iOS | Android | 差分ヒートマップ を横並びにし、SSIM とラベルを焼き込む。"""
    h = ios_c.shape[0]
    panels = [ios_c, and_c, heat]
    gap = 12
    W = sum(p.shape[1] for p in panels) + gap * (len(panels) - 1)
    canvas = np.full((h + 40, W, 3), 245, np.uint8)
    x = 0
    for p in panels:
        canvas[40:40 + h, x:x + p.shape[1]] = p
        x += p.shape[1] + gap
    img = Image.fromarray(canvas)
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    ok = score >= threshold
    d.text((6, 6), f"iOS    |    Android    |    diff    SSIM={score:.4f}  {'PASS' if ok else 'FAIL'}",
           fill=(0, 130, 0) if ok else (200, 0, 0))
    img.save(out_path)


def build_report(pairs, out_dir, threshold):
    """pairs: [{name, ios, android, top?, bottom?}] → 合成画像群 + index.html + results.json。"""
    os.makedirs(out_dir, exist_ok=True)
    rows = []
    for p in pairs:
        name = p["name"]
        top = p.get("top", 0.05)
        bottom = p.get("bottom", 0.04)
        masks = p.get("masks")
        try:
            score, ios_c, and_c, heat = compute(p["ios"], p["android"], top, bottom, masks)
            comp = os.path.join(out_dir, f"{name}.png")
            composite(ios_c, and_c, heat, score, threshold, comp)
            rows.append({"name": name, "ssim": round(float(score), 4),
                         "pass": bool(score >= threshold), "composite": f"{name}.png"})
        except Exception as e:
            rows.append({"name": name, "ssim": None, "pass": False, "error": str(e)})
    rows.sort(key=lambda r: (r["pass"], r["ssim"] if r["ssim"] is not None else -1))
    with open(os.path.join(out_dir, "results.json"), "w") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)
    html = ["<html><head><meta charset='utf-8'><style>",
            "body{font-family:sans-serif} .fail{background:#fdd} .pass{background:#dfd}",
            "img{width:100%;max-width:1100px;border:1px solid #ccc} td{padding:6px;vertical-align:top}",
            "</style></head><body>",
            f"<h2>Android↔iOS parity diff (threshold SSIM≥{threshold})</h2>",
            f"<p>PASS {sum(1 for r in rows if r['pass'])}/{len(rows)}</p><table>"]
    for r in rows:
        cls = "pass" if r["pass"] else "fail"
        if r["ssim"] is None:
            html.append(f"<tr class='{cls}'><td>{r['name']}</td><td>ERROR: {r.get('error')}</td></tr>")
        else:
            html.append(f"<tr class='{cls}'><td><b>{r['name']}</b><br>SSIM {r['ssim']}<br>{'PASS' if r['pass'] else 'FAIL'}</td>"
                        f"<td><img src='{r['composite']}'></td></tr>")
    html.append("</table></body></html>")
    with open(os.path.join(out_dir, "index.html"), "w") as f:
        f.write("\n".join(html))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ios", nargs="?")
    ap.add_argument("android", nargs="?")
    ap.add_argument("--out")
    ap.add_argument("--pairs")
    ap.add_argument("--out-dir", default="parity_report")
    ap.add_argument("--threshold", type=float, default=0.97)
    ap.add_argument("--top", type=float, default=0.05)
    ap.add_argument("--bottom", type=float, default=0.04)
    a = ap.parse_args()
    if a.pairs:
        pairs = json.load(open(a.pairs))
        rows = build_report(pairs, a.out_dir, a.threshold)
        failed = [r["name"] for r in rows if not r["pass"]]
        print(f"PASS {len(rows)-len(failed)}/{len(rows)}  threshold={a.threshold}")
        for r in rows:
            print(f"  {'PASS' if r['pass'] else 'FAIL'}  {r['ssim']}  {r['name']}")
        print(f"report: {os.path.join(a.out_dir,'index.html')}")
        sys.exit(1 if failed else 0)
    if not (a.ios and a.android):
        ap.error("need ios+android, or --pairs")
    score, ios_c, and_c, heat = compute(a.ios, a.android, a.top, a.bottom)
    if a.out:
        composite(ios_c, and_c, heat, score, a.threshold, a.out)
    print(f"SSIM={score:.4f}  {'PASS' if score>=a.threshold else 'FAIL'} (threshold {a.threshold})")
    sys.exit(0 if score >= a.threshold else 1)


if __name__ == "__main__":
    main()
