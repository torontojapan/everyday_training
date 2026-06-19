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


def seed_streak(days, today=None, breed_records="strength"):
    """today まで days 日連続の workout_records を注入(iOS と同じ epochDay 基準)。"""
    today = today or datetime.date.today()
    epoch = datetime.date(1970, 1, 1)
    lines = ["DELETE FROM workout_records;"]
    for i in range(days):
        d = today - datetime.timedelta(days=i)
        ed = (d - epoch).days
        ms = int(datetime.datetime(d.year, d.month, d.day, 9, 0).timestamp() * 1000)
        ex = [{"id": str(uuid.uuid4()), "name": "スクワット", "reps": 20, "sets": 3, "category": "strength"}]
        exj = json.dumps(ex, ensure_ascii=False).replace("'", "''").replace('"', '\\"')
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
TABS = {"home": (130, 2280), "history": (324, 2280), "weight": (540, 2280),
        "friends": (760, 2280), "settings": (970, 2280)}


def recipe(name, out):
    if name == "home":
        launch(); screenshot(out)
    elif name == "settings":
        launch(); tap(*TABS["settings"]); screenshot(out)
    elif name == "record_empty":
        launch(); tap_text("記録する"); screenshot(out)
    elif name == "history":
        launch(); tap(*TABS["history"]); screenshot(out)
    elif name == "weight_paywall":
        launch(); tap(*TABS["weight"]); screenshot(out)
    else:
        raise SystemExit(f"unknown recipe: {name}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default="/tmp/and_caps")
    ap.add_argument("--recipes", default="")
    ap.add_argument("--seed-streak", type=int)
    a = ap.parse_args()
    if a.seed_streak:
        seed_streak(a.seed_streak)
        print(f"seeded {a.seed_streak}-day streak")
        return
    import os
    os.makedirs(a.out_dir, exist_ok=True)
    for r in [x for x in a.recipes.split(",") if x]:
        out = os.path.join(a.out_dir, f"{r}.png")
        recipe(r, out)
        print("captured", out)


if __name__ == "__main__":
    main()
