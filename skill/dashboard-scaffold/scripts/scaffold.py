#!/usr/bin/env python3
"""대시보드 프로젝트 최소 구조를 만든다. 사용법은 SKILL.md 참고."""
import argparse
import json
import re
import urllib.request
from pathlib import Path

ASSETS = Path(__file__).resolve().parent.parent / "assets"
FILES = {  # 템플릿 → 대상 경로
    "build.py.tpl": "build.py",
    "index.html.tpl": "index.html",
    "README.md.tpl": "README.md",
    "requirements.md.tpl": "docs/requirements.md",
    "gitignore.tpl": ".gitignore",
}


def discover_tabs(sheet_id):
    """공개 시트의 htmlview 에서 탭 이름과 gid 를 읽는다."""
    url = f"https://docs.google.com/spreadsheets/d/{sheet_id}/htmlview"
    html = urllib.request.urlopen(url).read().decode("utf-8", "replace")
    found = re.findall(r'items\.push\(\{name: "([^"]*)", pageUrl: "[^"]*?gid\\?x?3?d?=?(\d+)"', html)
    if not found:  # 형식이 달라도 gid 만이라도
        found = re.findall(r'name: "([^"]*)".*?[?&]gid(?:=|\\x3d)(\d+)', html)
    # 설명용 README 탭은 데이터가 아니므로 제외한다 (필요하면 --tabs 로 직접 지정)
    return {n: int(g) for n, g in found if n.lower() != "readme"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("target")
    ap.add_argument("--sheet-url", default="")
    ap.add_argument("--tabs", default="", help="이름:gid,이름:gid")
    ap.add_argument("--title", default="대시보드")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()

    sheet_id = ""
    if a.sheet_url:
        m = re.search(r"/d/([\w-]+)", a.sheet_url)
        if not m:
            ap.error("시트 URL 에서 ID 를 찾지 못했습니다")
        sheet_id = m.group(1)

    tabs = {}
    if a.tabs:
        tabs = {k: int(v) for k, v in (p.split(":") for p in a.tabs.split(","))}
    elif sheet_id:
        try:
            tabs = discover_tabs(sheet_id)
        except Exception as e:  # 비공개 시트 등
            print("탭 자동 탐색 실패:", e, "→ --tabs 로 직접 지정하세요")

    subs = {
        "{{TITLE}}": a.title,
        "{{SHEET_ID}}": sheet_id,
        "{{TABS}}": json.dumps(tabs, ensure_ascii=False, indent=4),
    }
    root = Path(a.target)
    for tpl, rel in FILES.items():
        dest = root / rel
        if dest.exists() and not a.force:
            print("건너뜀(이미 있음):", dest)
            continue
        text = (ASSETS / tpl).read_text(encoding="utf-8")
        for k, v in subs.items():
            text = text.replace(k, v)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text, encoding="utf-8")
        print("생성:", dest)
    (root / "data").mkdir(exist_ok=True)
    print(f"탭 {len(tabs)}개:", ", ".join(tabs) or "(없음)")


if __name__ == "__main__":
    main()
