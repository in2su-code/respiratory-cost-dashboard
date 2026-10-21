#!/usr/bin/env python3
"""시트 다운로드 → 집계 → data/<지표명>.json

지표 추가: `metric_<이름>()` 함수를 쓰면 data/<이름>.json 으로 저장된다.
실행: python3 build.py            (CSV가 없는 탭만 내려받음)
      python3 build.py --refresh  (전부 다시 내려받음)
"""
import csv
import json
import sys
import urllib.request
from pathlib import Path

SHEET_ID = "1nPuY8AKFAs2r9da4xUBV3WMKdLEBZJGpmd3kP7xKNvU"
TABS = {
    "claim": 78768174,
    "patient": 80354650,
    "institution": 991582107,
    "sick_master": 1345263105,
    "code_table": 173633388,
    "sido_code": 2036727743,
    "hospital_open": 1356575315,
    "claim_sick": 1877573041,
    "claim_rx": 2056573466,
    "drug_ingredient": 2109510048
}  # 탭 이름: gid

DATA = Path(__file__).resolve().parent / "data"


def fetch(refresh=False):
    DATA.mkdir(exist_ok=True)
    for name, gid in TABS.items():
        dest = DATA / f"{name}.csv"
        if dest.exists() and not refresh:
            continue
        url = f"https://docs.google.com/spreadsheets/d/{SHEET_ID}/export?format=csv&gid={gid}"
        dest.write_bytes(urllib.request.urlopen(url).read())
        print("내려받음", dest.name)


def read(name):
    with (DATA / f"{name}.csv").open(encoding="utf-8") as f:
        return list(csv.DictReader(f))


# ---- 지표 (이름 규칙: metric_<이름> → data/<이름>.json → <section data-metric="<이름>">) ----

def metric_overview():
    """탭별 행 수. 첫 지표이자 파이프라인 점검용."""
    return {name: len(read(name)) for name in TABS}


def metric_resp_claims():
    """호흡기(J코드) 명세서 한 줄씩. 화면의 모든 차트가 이 하나를 읽어 필터·집계한다.

    용량을 줄이려고 열 기반으로 저장하고, 코드값은 dims 의 인덱스로 둔다.
    """
    class_nm = {r["code"]: r["code_nm"] for r in read("code_table") if r["code_type"] == "종별코드"}
    cl_of = {r["yid"]: r["cl_cd"] for r in read("institution")}
    sick_nm = {r["sickcd"]: r["krnm"] for r in read("sick_master")}

    rows = [c for c in read("claim") if c["main_sick"].startswith("J")]
    classes = sorted({cl_of[c["yid"]] for c in rows})
    sicks = sorted({c["main_sick"] for c in rows})
    months = sorted({c["recu_fr_dd"][:7] for c in rows})
    ci, si, mi = ({v: i for i, v in enumerate(xs)} for xs in (classes, sicks, months))

    return {
        "dims": {
            "classes": [{"cd": c, "nm": class_nm.get(c, c)} for c in classes],
            "sicks": [{"cd": s, "nm": sick_nm.get(s, s)} for s in sicks],
            "months": months,
        },
        "m": [mi[c["recu_fr_dd"][:7]] for c in rows],
        "s": [si[c["main_sick"]] for c in rows],
        "c": [ci[cl_of[c["yid"]]] for c in rows],
        "f": [1 if c["fom_tp_cd"] == "021" else 0 for c in rows],  # 1 = 입원
        "a": [int(c["rvd_rpe_tamt_amt"]) for c in rows],
    }


# ------------------------------------------------------------------------------------------

if __name__ == "__main__":
    fetch(refresh="--refresh" in sys.argv)
    for key, fn in sorted(globals().items()):
        if key.startswith("metric_") and callable(fn):
            out = DATA / f"{key[len('metric_'):]}.json"
            out.write_text(json.dumps(fn(), ensure_ascii=False, indent=1), encoding="utf-8")
            print("저장", out.name)
