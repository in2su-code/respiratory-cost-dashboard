#!/usr/bin/env python3
"""data/*.csv → Supabase 적재 (DB 비밀번호 불필요, `supabase login` 만 되어 있으면 된다).

서버 키(service_role)는 CLI 로 읽어 메모리에서만 쓰고 출력하거나 저장하지 않는다.
다시 실행해도 안전하다(테이블을 비운 뒤 다시 채움).
사용: python3 build.py --refresh && python3 supabase/load_data.py
"""
import csv
import json
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def project_ref():
    ref_file = ROOT / "supabase" / ".temp" / "project-ref"
    if not ref_file.exists():
        sys.exit("먼저 `supabase link --project-ref <ref>` 를 실행하세요.")
    return ref_file.read_text().strip()


def service_key(ref):
    out = subprocess.run(["supabase", "projects", "api-keys", "--project-ref", ref, "-o", "json"],
                         capture_output=True, text=True, check=True).stdout
    keys = json.loads(out[out.index("["):])  # 앞에 경고 문구가 붙을 수 있다
    for k in keys:
        if k.get("name") == "service_role" or k.get("type") == "secret":
            return k["api_key"]
    sys.exit("service_role 키를 찾지 못했습니다.")


# 테이블: (기본키 컬럼, 정수 컬럼)
TABLES = {
    "institution": ("yid", set()),
    "patient": ("jid", {"birth_yr"}),
    "sick_master": ("sickcd", set()),
    "code_table": ("code_type", set()),
    "sido_code": ("sido_cd", set()),
    "claim": ("mid", {"vst_ddcnt", "recu_ddcnt", "rvd_rpe_tamt_amt", "rvd_slf_brdn_amt", "rvd_insup_brdn_amt"}),
}
BATCH = 2000


def main():
    ref = project_ref()
    key = service_key(ref)
    base = f"https://{ref}.supabase.co/rest/v1"
    headers = {"apikey": key, "Content-Type": "application/json", "Prefer": "return=minimal"}
    if key.startswith("eyJ"):  # 예전 방식(JWT) 키는 Authorization 헤더도 필요
        headers["Authorization"] = f"Bearer {key}"

    def call(method, url, body=None):
        req = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            urllib.request.urlopen(req).read()
        except urllib.error.HTTPError as e:
            sys.exit(f"{method} {url.split('/rest/v1/')[1][:40]} → {e.code} {e.read().decode()[:300]}")

    for table, (pk, ints) in TABLES.items():
        with (ROOT / "data" / f"{table}.csv").open(encoding="utf-8") as f:
            rows = []
            for r in csv.DictReader(f):
                row = {k: (None if v == "" else v) for k, v in r.items()}
                for c in ints:
                    if row[c] is not None:
                        row[c] = int(row[c])
                rows.append(row)
        call("DELETE", f"{base}/{table}?{pk}=not.is.null")
        for i in range(0, len(rows), BATCH):
            call("POST", f"{base}/{table}", json.dumps(rows[i:i + BATCH], ensure_ascii=False).encode())
        print(f"{table:12} {len(rows):>7,}행 적재")


if __name__ == "__main__":
    main()
