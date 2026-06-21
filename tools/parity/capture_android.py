#!/usr/bin/env python3
"""Android(emulator go_test)を adb 駆動して 画面×状態 を撮影する。

これまで手動で行っていた「sqlite で記録注入 → アプリ起動 → 画面遷移 → screencap」を
再現可能なレシピとして codify する。iOS golden と**同一データ**にするためのシードもここで行う。

前提: emulator 起動済 / APK インストール済 / `adb` が PATH。Mock 撮影が要る画面(友達/ランキング)は
local.properties の SUPABASE を空にして再ビルド・再インストールしてから実行する。

使い方:
  python3 capture_android.py --pkg com.goexercise.app --out-dir /tmp/and_caps --recipes home,record_empty,settings
  python3 capture_android.py --seed-streak 14            # 14日連続を sqlite 注入だけ行う
"""
import argparse
import datetime
import json
import re
import subprocess
import time
import uuid

PKG = "com.goexercise.app"
DB = "databases/goexercise.db"


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


def adb(*a):
    return sh("adb", *a)


def adb_shell(cmd):
    return sh("adb", "shell", cmd)


def run_as_sqlite(sql):
    """run-as で sqlite を実行(debuggable ビルド前提)。"""
    adb("shell", f"run-as {PKG} sh -c 'echo \"{sql}\" | sqlite3 {DB}'")


def seed_streak(days, today=None, breed_records="strength", end_offset=0, skip_recent=0):
    """days 日連続の workout_records を注入(iOS と同じ epochDay 基準)。

    end_offset: 連続の終端を today から N 日前にずらす(N=1 → 昨日まで連続=今日未記録。
                **milestone-eve** に使う: seed_streak(6, end_offset=1) → 今日記録すると 7 日連続=節目発火)。
    skip_recent: 連続の中で**直近 N 日を記録しない**(× 未達成日を作る。**rescue-use** の適用対象が要る画面用)。
    """
    today = today or datetime.date.today()
    epoch = datetime.date(1970, 1, 1)
    end = today - datetime.timedelta(days=end_offset)  # 連続の最終日
    lines = ["DELETE FROM workout_records;"]
    for i in range(skip_recent, days):
        d = end - datetime.timedelta(days=i)
        ed = (d - epoch).days
        ms = int(datetime.datetime(d.year, d.month, d.day, 9, 0).timestamp() * 1000)
        ex = [{"id": str(uuid.uuid4()), "name": "スクワット", "reps": 20, "sets": 3, "category": "strength"}]
        # SQL の単一引用符文字列内なので **二重引用符はエスケープ不要**。単一引用符だけ '' に倍化する。
        # (旧実装は " を \" にしていたため JSON が壊れ、decode 失敗→exercises 空→活動日に数えられなかった)
        exj = json.dumps(ex, ensure_ascii=False).replace("'", "''")
        lines.append(f"INSERT INTO workout_records (id,dateEpochDay,categoryRaw,exercisesJson,memo,createdAtEpochMs,updatedAtEpochMs) "
                     f"VALUES ('{uuid.uuid4()}',{ed},'strength','{exj}',NULL,{ms},{ms});")
    # ファイル経由で流す(長文の quoting 回避)。
    sql = "\n".join(lines)
    open("/tmp/_seed.sql", "w").write(sql)
    adb("push", "/tmp/_seed.sql", "/data/local/tmp/_seed.sql")
    adb("shell", f"run-as {PKG} sh -c 'cat /data/local/tmp/_seed.sql | sqlite3 {DB}'")


def launch():
    adb("shell", "am", "force-stop", PKG)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(4)


def deeplink(uri):
    adb("shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", uri, PKG)
    time.sleep(2)


def dump():
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    return adb("shell", "cat", "/sdcard/ui.xml")


def find_center(text):
    """text を含むノードの中心座標 (x,y) を返す。無ければ None。"""
    s = dump()
    m = re.search(r'text="[^"]*' + re.escape(text) + r'[^"]*"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', s)
    if not m:
        return None
    x1, y1, x2, y2 = map(int, m.groups())
    return ((x1 + x2) // 2, (y1 + y2) // 2)


def tap(x, y):
    adb("shell", "input", "tap", str(x), str(y))
    time.sleep(1.5)


def tap_text(text):
    c = find_center(text)
    if c:
        tap(*c)
        return True
    return False


def screenshot(path):
    with open(path, "wb") as f:
        f.write(subprocess.run(["adb", "exec-out", "screencap", "-p"], capture_output=True).stdout)


# ---- 画面レシピ(タブ座標は 1080x2400 基準。必要に応じ find_text で補正)----
# タブの y は ボトムナビ項目の中心(~2250)。2280 はラベル下端(2279)より下でタップが外れる(2026-06-21 実証)。
TABS = {"home": (108, 2250), "history": (324, 2250), "weight": (540, 2250),
        "friends": (756, 2250), "settings": (972, 2250)}


def recipe(name, out):
    if name == "home":
        launch(); screenshot(out)
    elif name == "settings":
        launch(); tap(*TABS["settings"]); screenshot(out)
    elif name == "record_empty":
        # CTA は状態で文言が変わる(「今日の運動を記録する」/「もう一種目する」/「ただいま記録」)。
        launch()
        if not (tap_text("記録する") or tap_text("もう一種目") or tap_text("ただいま記録")):
            tap_text("記録")
        screenshot(out)
    elif name == "history":
        launch(); tap(*TABS["history"]); screenshot(out)
    elif name == "weight_paywall":
        launch(); tap(*TABS["weight"]); screenshot(out)
    else:
        raise SystemExit(f"unknown recipe: {name}")


# iPhone 17 Pro Max は論理幅 440pt。emulator go_test は 1080x2400@420dpi=411dp で **約6.5%狭く**、
# 幅依存レイアウト(履歴の凡例「未達成」等)が iOS で収まるのに Android で切れる **偽差分**を生む。
# density=393 にすると 1080/(393/160)=439.7dp ≈ 440pt で iPhone 17 Pro Max に一致する(2026-06-19 実証)。
IOS_MATCHED_DENSITY = 393


def set_ios_matched_density():
    """撮影前に論理幅を iPhone 17 Pro Max(440dp)へ合わせる。元に戻すには `adb shell wm density reset`。"""
    adb("shell", "wm", "density", str(IOS_MATCHED_DENSITY))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default="/tmp/and_caps")
    ap.add_argument("--recipes", default="")
    ap.add_argument("--seed-streak", type=int)
    ap.add_argument("--end-offset", type=int, default=0,
                    help="連続の終端を today から N 日前へ(N=1=昨日まで=milestone-eve。今日記録で +1 日=節目発火)")
    ap.add_argument("--skip-recent", type=int, default=0,
                    help="直近 N 日を記録せず × 未達成日を作る(rescue-use の適用対象が要る画面用)")
    ap.add_argument("--match-ios-width", action="store_true",
                    help="撮影前に density=393 を適用し論理幅を iPhone 17 Pro Max(440dp)へ揃える")
    a = ap.parse_args()
    if a.match_ios_width:
        set_ios_matched_density()
        print(f"set density {IOS_MATCHED_DENSITY} (≈440dp, iPhone 17 Pro Max width)")
    if a.seed_streak:
        seed_streak(a.seed_streak, end_offset=a.end_offset, skip_recent=a.skip_recent)
        print(f"seeded {a.seed_streak}-day streak (end_offset={a.end_offset}, skip_recent={a.skip_recent})")
        return
    import os
    os.makedirs(a.out_dir, exist_ok=True)
    for r in [x for x in a.recipes.split(",") if x]:
        out = os.path.join(a.out_dir, f"{r}.png")
        recipe(r, out)
        print("captured", out)


if __name__ == "__main__":
    main()
