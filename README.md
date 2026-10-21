# 호흡기 진료비 편차 대시보드

기관 종별(상급종합병원, 종합병원, 병원, 의원)에 따라 호흡기 질환 진료비가 얼마나 다른지, 같은 상병끼리 비교해도 차이가 남는지 보는 웹 대시보드입니다.

**바로 보기: https://in2su-code.github.io/respiratory-cost-dashboard/**

> 오즈코딩 헬스케어 SQL 3기 실습용 표본 데이터(`kr_claims`)로 만들었습니다. 실제 청구 데이터가 아닙니다.

## 이 대시보드로 알 수 있는 것

- 호흡기(J코드) 외래 명세서 13,232건, 2024-01 ~ 2025-12
- 종별 건당 진료비 중앙값: 상급종합병원 49,500원, 종합병원 29,000원, 병원 20,000원, 의원 16,600원
- 같은 상병(급성 기관지염 J209)끼리도 상급종합병원 45,400원 대 의원 15,700원으로 격차가 남음
  (연령·성별·중증도는 보정하지 않았으므로 "상병을 맞춰도 격차가 남는다"까지만 말할 수 있습니다)

## 화면 사용법

위에서 아래로 읽습니다. 맨 위 필터가 모든 차트에 함께 적용됩니다.

| 영역 | 보는 법 |
|---|---|
| 필터 | 기간(시작·끝 월), 상병, 종별, "입원 포함" 체크 (기본은 외래만) |
| KPI 카드 | 명세서 수, 총진료비, 건당 평균·중앙값·P90, 종별 중앙값 격차(최고/최저) |
| 월별 추이 | 월별 명세서 수 막대와 건당 진료비 P50·P90 선. 월 표본이 5건 미만이면 선을 끊음 |
| 종별 분포 | 박스플롯. 상자 = P25~P75, 굵은 선 = 중앙값, 선 끝 = P90. 종별 필터는 적용되지 않음(비교용) |
| 상병 × 종별 | 같은 상병 안에서 종별 중앙값이 상병 전체 중앙값의 몇 배인지 색으로 표시(붉을수록 높음). 상병 이름을 누르면 상병 필터가 바뀜 |
| 상병 비중 | 상병별 건수와 비율 (상병 필터는 적용되지 않음) |

표본이 30건 미만인 칸은 "표본 부족"으로 표시하고 분포를 그리지 않습니다. 진료비는 명세서 총진료비(본인부담 + 보험자부담)입니다.

## 내 컴퓨터에서 실행

필요한 것: Python 3 (추가 설치 패키지 없음)

```bash
git clone https://github.com/in2su-code/respiratory-cost-dashboard.git
cd respiratory-cost-dashboard
python3 -m http.server
```

브라우저에서 http://localhost:8000/ 을 엽니다. 집계 데이터(`data/resp_claims.json`)가 저장소에 들어 있어 바로 보입니다.

## 데이터 갱신 (월 1회)

원본 구글 시트가 갱신되면 아래를 실행합니다. 시트는 "링크가 있는 모든 사용자"가 볼 수 있어야 합니다.

```bash
python3 build.py --refresh
```

```bash
git add -A && git commit -m "데이터 갱신" && git push
```

push 후 1~2분 뒤 배포 사이트에 반영됩니다. 원본 CSV는 `.gitignore`로 제외되어 올라가지 않습니다.

## 폴더 구조

```
build.py              시트 다운로드 → 집계 → data/*.json
index.html            대시보드 (HTML+CSS+JS 한 파일, 차트는 직접 그린 SVG)
data/                 resp_claims.json(화면이 읽는 집계), overview.json, CSV(git 제외)
docs/requirements.md  요구사항 (인터뷰 결과)
docs/reproduce.md     처음부터 같은 결과를 만드는 프롬프트와 절차
docs/data_dictionary.md, docs/data_profile.md   데이터 설명
skill/dashboard-scaffold/   이 구조를 새 프로젝트에 재사용하는 Claude 스킬
```

## 같은 방식으로 새 대시보드 만들기

[docs/reproduce.md](docs/reproduce.md)에 데이터 파악부터 배포까지 실제로 쓴 프롬프트가 순서대로 정리되어 있습니다. 구조 생성만 하려면:

```bash
mkdir -p ~/.claude/skills && cp -R skill/dashboard-scaffold ~/.claude/skills/
python3 ~/.claude/skills/dashboard-scaffold/scripts/scaffold.py ./my-dashboard --sheet-url "<시트 URL>" --title "<제목>"
```

## 지표 목록

| 이름 | 정의 | 데이터 |
|---|---|---|
| overview | 탭별 행 수 (파이프라인 점검용) | 전체 |
| resp_claims | 호흡기(J) 명세서 한 줄씩(월·상병·종별·입원여부·총진료비). 화면의 5개 섹션이 이 JSON 하나를 읽어 브라우저에서 필터·집계 | claim, institution, sick_master, code_table |

## 디자인 시스템

[Montage](https://github.com/wanteddev/montage-web)(원티드 웹 디자인 시스템)의 토큰을 `index.html` 맨 위 CSS 변수로 옮겨 썼습니다: 시맨틱 색(라이트·다크), 타이포그래피 단계(title3, headline1, heading1, body2), 모서리 12/8px, Pretendard 글꼴. 컴포넌트 라이브러리(`@montage-ui/core`)는 쓰지 않아 빌드 단계가 없습니다.

## 한계

- 기관명이 없어 개별 병원은 비교하지 못하고 종별 비교만 합니다.
- 환자 3,000명 규모 표본이며, 법정감염병 급수가 붙은 호흡기 상병은 인플루엔자(J101)뿐이라 감염병만 따로 깊게 보기는 어렵습니다.
- 공개 배포용입니다. 실제 식약처·심평원 데이터에는 공개 저장소와 Pages를 쓰면 안 됩니다.

## 성장 규칙

`build.py` 300줄↑ → `metrics/` 분리 · `index.html` 500줄↑ → css/js 분리 · 페이지 2개↑ → `pages/`
