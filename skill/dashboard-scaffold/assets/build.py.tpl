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

SHEET_ID = "{{SHEET_ID}}"
TABS = {{TABS}}  # 탭 이름: gid

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


# ------------------------------------------------------------------------------------------

if __name__ == "__main__":
    fetch(refresh="--refresh" in sys.argv)
    for key, fn in sorted(globals().items()):
        if key.startswith("metric_") and callable(fn):
            out = DATA / f"{key[len('metric_'):]}.json"
            out.write_text(json.dumps(fn(), ensure_ascii=False, indent=1), encoding="utf-8")
            print("저장", out.name)
