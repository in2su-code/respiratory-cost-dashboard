# 건강보험 청구 대시보드

## 실행

```bash
python3 build.py              # 시트 다운로드 + 집계 (--refresh 로 재다운로드)
python3 -m http.server        # http://localhost:8000
```

## 구조

```
build.py              시트 → data/*.json (metric_<이름>() 함수 하나 = JSON 하나)
index.html            대시보드 (<section data-metric="<이름>"> 하나 = JSON 하나)
data/                 CSV(git 제외)와 집계 JSON
docs/requirements.md  요구사항(인터뷰 결과)
```

## 지표 목록

| 이름 | 정의 | 데이터 |
|---|---|---|
| overview | 탭별 행 수 (파이프라인 점검용) | 전체 |
| resp_claims | 호흡기(J) 명세서 한 줄씩(월·상병·종별·입원여부·총진료비). 화면의 5개 섹션(KPI, monthly_trend, cost_by_class, cost_by_class_sick, sick_mix)이 이 JSON 하나를 읽어 브라우저에서 필터·집계 | claim, institution, sick_master, code_table |

## 디자인 시스템

[Montage](https://github.com/wanteddev/montage-web)(원티드 웹 디자인 시스템)의 토큰을 `index.html` 맨 위 CSS 변수로 옮겨 썼다: 시맨틱 색(라이트·다크), 타이포그래피 단계(title3, headline1, heading1, body2), 모서리 12/8px, Pretendard 글꼴. 컴포넌트 라이브러리(`@montage-ui/core`, React+Emotion)는 쓰지 않아 빌드 단계가 없다. 토큰 값이 바뀌면 `packages/theme/src/theme/`를 기준으로 `:root` 블록만 고치면 된다.

## 성장 규칙

build.py 300줄↑ → `metrics/` 분리 · index.html 500줄↑ → css/js 분리 · 페이지 2개↑ → `pages/`
