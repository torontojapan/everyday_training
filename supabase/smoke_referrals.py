#!/usr/bin/env python3
"""
referrals RLS スモークテスト(実機不要)。
共有 Supabase バックエンドの `referrals` 表 + RLS が、iOS/Android クライアントの
紹介フローどおりに「正しく許可し・正しく拒否する」かを REST(PostgREST + GoTrue 匿名認証)
だけで検証する。schema.sql を本番に Run した直後・実ユーザーがいないうちに回すのが理想。

使い方:
    export SUPABASE_URL="https://<ref>.supabase.co"
    export SUPABASE_ANON_KEY="<anon public key>"
    python3 supabase/smoke_referrals.py
  または:
    python3 supabase/smoke_referrals.py --url https://... --key eyJ...

前提: Supabase の Authentication で "Anonymous sign-ins" が ON(schema.sql 手順 2)。
依存: 標準ライブラリのみ(curl/jq 不要)。

注意: 本番に匿名テストユーザー数件 + profiles/referrals 行を一時作成し、最後に本人行を
削除する。匿名 auth ユーザー自体は残るが PII 無し・cleanup_orphans cron で回収される。
気になるなら使い捨て/staging プロジェクトの URL/KEY を渡すこと。
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

PASS = 0
FAIL = 0


def log_ok(msg: str):
    global PASS
    PASS += 1
    print(f"  \033[32mPASS\033[0m {msg}")


def log_fail(msg: str):
    global FAIL
    FAIL += 1
    print(f"  \033[31mFAIL\033[0m {msg}")


def check(cond: bool, msg: str):
    (log_ok if cond else log_fail)(msg)


def req(method: str, url: str, headers: dict, body=None):
    """Return (status, parsed_json_or_text)."""
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(r) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, raw
    except urllib.error.URLError as e:
        return -1, str(e)


def anon_signup(base: str, anon: str):
    """GoTrue 匿名サインイン。(access_token, uid) を返す。"""
    status, body = req(
        "POST", f"{base}/auth/v1/signup",
        {"apikey": anon, "Content-Type": "application/json"},
        {"data": {}},
    )
    if status not in (200, 201) or not isinstance(body, dict):
        raise SystemExit(
            f"匿名サインイン失敗 (status={status}): {body}\n"
            f"→ Supabase の Authentication > 'Anonymous sign-ins' が ON か確認。"
        )
    token = body.get("access_token")
    uid = (body.get("user") or {}).get("id")
    if not token or not uid:
        raise SystemExit(f"サインイン応答に access_token/user.id が無い: {body}")
    return token, uid


def rest_headers(anon: str, token: str, prefer: str = None):
    h = {
        "apikey": anon,
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    if prefer:
        h["Prefer"] = prefer
    return h


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default=os.environ.get("SUPABASE_URL"))
    ap.add_argument("--key", default=os.environ.get("SUPABASE_ANON_KEY"))
    args = ap.parse_args()
    if not args.url or not args.key:
        raise SystemExit("SUPABASE_URL と SUPABASE_ANON_KEY を env か --url/--key で渡してください。")
    base = args.url.rstrip("/")
    anon = args.key
    rest = f"{base}/rest/v1"

    print("匿名ユーザーを3人作成中 (R=紹介者, E=新規/referee, X=第三者)…")
    tok_r, uid_r = anon_signup(base, anon)
    tok_e, uid_e = anon_signup(base, anon)
    tok_x, uid_x = anon_signup(base, anon)
    print(f"  R={uid_r[:8]}…  E={uid_e[:8]}…  X={uid_x[:8]}…")

    created = []  # (token, table, filter) for cleanup

    def mkprofile(token, uid, code, name):
        s, b = req("POST", f"{rest}/profiles",
                   rest_headers(anon, token, "return=representation"),
                   {"user_id": uid, "friend_code": code, "username": name.lower(), "display_name": name})
        created.append((token, "profiles", f"user_id=eq.{uid}"))
        return s, b

    try:
        print("\n[A] profiles 準備")
        s, _ = mkprofile(tok_r, uid_r, "SMOKER", "R")
        check(s in (200, 201), f"R プロフィール作成 (status={s})")
        s, _ = mkprofile(tok_e, uid_e, "SMOKEE", "E")
        check(s in (200, 201), f"E プロフィール作成 (status={s})")

        print("\n[B] 紹介 insert の RLS")
        # 1) E が自分を referee とする pending を作成 → 許可
        s, b = req("POST", f"{rest}/referrals",
                   rest_headers(anon, tok_e, "return=representation"),
                   {"referrer_user_id": uid_r, "referee_user_id": uid_e})
        created.append((tok_e, "referrals", f"referee_user_id=eq.{uid_e}"))
        check(s in (200, 201), f"E が pending 紹介を作成できる (status={s})")
        check(isinstance(b, list) and b and b[0].get("status") == "pending",
              "作成行の status が pending")

        # 2) E が「他人(R)を referee」として insert → RLS with check で拒否
        s, _ = req("POST", f"{rest}/referrals",
                   rest_headers(anon, tok_e),
                   {"referrer_user_id": uid_x, "referee_user_id": uid_r})
        check(s in (401, 403), f"E が他人を referee にした insert は拒否される (status={s})")

        # 3) E が二重に紹介 insert(別 referrer)→ referee 主キーで一意制約 409
        s, _ = req("POST", f"{rest}/referrals",
                   rest_headers(anon, tok_e),
                   {"referrer_user_id": uid_x, "referee_user_id": uid_e})
        check(s == 409, f"1人1紹介者: E の二重紹介は重複で拒否 (status={s})")

        # 4) 自己紹介(referrer==referee)→ check 制約で拒否
        s, _ = req("POST", f"{rest}/referrals",
                   rest_headers(anon, tok_x),
                   {"referrer_user_id": uid_x, "referee_user_id": uid_x})
        check(400 <= s < 500, f"自己紹介(referrer==referee)は制約で拒否 (status={s})")

        print("\n[C] 確定(confirm)の RLS")
        now_iso = datetime.now(timezone.utc).isoformat()
        s, b = req("PATCH", f"{rest}/referrals?referee_user_id=eq.{uid_e}",
                   rest_headers(anon, tok_e, "return=representation"),
                   {"status": "confirmed", "confirmed_at": now_iso})
        check(s == 200 and isinstance(b, list) and b and b[0].get("status") == "confirmed",
              f"E(referee)が自分の行を confirmed に更新できる (status={s})")

        # X が E の行を勝手に confirm/seen 更新 → RLS で 0 行
        s, b = req("PATCH", f"{rest}/referrals?referee_user_id=eq.{uid_e}",
                   rest_headers(anon, tok_x, "return=representation"),
                   {"seen_by_referrer": True})
        check(s == 200 and isinstance(b, list) and len(b) == 0,
              f"第三者 X は E/R の紹介行を更新できない(0行) (status={s})")

        print("\n[D] 取得(select)と seen 更新の RLS")
        s, b = req("GET", f"{rest}/referrals?referrer_user_id=eq.{uid_r}&status=eq.confirmed",
                   rest_headers(anon, tok_r))
        check(s == 200 and isinstance(b, list) and len(b) == 1,
              f"R(referrer)は自分の confirmed 紹介を取得できる (count={len(b) if isinstance(b, list) else '?'})")

        s, b = req("GET", f"{rest}/referrals?referrer_user_id=eq.{uid_r}",
                   rest_headers(anon, tok_x))
        check(s == 200 and isinstance(b, list) and len(b) == 0,
              f"第三者 X は R/E の紹介行を select できない(0行)")

        s, b = req("PATCH", f"{rest}/referrals?referrer_user_id=eq.{uid_r}&seen_by_referrer=eq.false",
                   rest_headers(anon, tok_r, "return=representation"),
                   {"seen_by_referrer": True})
        check(s == 200 and isinstance(b, list) and len(b) == 1,
              f"R(referrer)は seen_by_referrer を更新できる (count={len(b) if isinstance(b, list) else '?'})")

    finally:
        print("\n[cleanup] テスト行を削除中…")
        # referrals は referee 本人 or referrer 本人が削除可。profiles は本人。
        for token, table, flt in reversed(created):
            req("DELETE", f"{rest}/{table}?{flt}", rest_headers(anon, token))
        print("  done(匿名 auth ユーザーは cron で回収されます)")

    print(f"\n==== 結果: PASS={PASS}  FAIL={FAIL} ====")
    sys.exit(1 if FAIL else 0)


if __name__ == "__main__":
    main()
