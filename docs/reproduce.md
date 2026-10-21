# 재현 가이드: 시트 데이터 → 호흡기 진료비 편차 대시보드 → GitHub Pages

같은 결과를 처음부터 다시 만들기 위한 프롬프트 순서와 결정 사항. 각 단계의 프롬프트는 그대로 복사해 Claude Code에 붙여 넣으면 된다. `{중괄호}`는 본인 값으로 바꾼다.

- 최종 결과: https://in2su-code.github.io/respiratory-cost-dashboard/
- 저장소: https://github.com/in2su-code/respiratory-cost-dashboard
- 데이터: 구글 시트 `1nPuY8AKFAs2r9da4xUBV3WMKdLEBZJGpmd3kP7xKNvU` (오즈코딩 헬스케어 SQL 3기 실습 데이터 `kr_claims`, 탭 10개). 링크가 있는 모든 사용자가 볼 수 있어야 CSV 내보내기가 된다.

## 사전 준비

| 항목 | 내용 |
|---|---|
| 도구 | Python 3, git, Homebrew(`gh` 설치용) |
| 계정 | GitHub 계정 (배포 단계에서만 필요) |
| 스킬 | 이 저장소의 `skill/dashboard-scaffold/` 를 `~/.claude/skills/dashboard-scaffold/` 로 복사 |

```bash
mkdir -p ~/.claude/skills && cp -R skill/dashboard-scaffold ~/.claude/skills/
```

---

## 1단계. 데이터 파악

**프롬프트**

```
{구글 시트 URL}
대시보드 만들건데 데이터 파악해줘
```

**기대 결과**
- 탭 10개를 CSV로 내려받아 탭별 행 수, 컬럼, NULL 수, 고유값, 조인 키를 요약한다.
- 확인된 사실: 명세서 38,375건, 환자 3,000명, 기관 2,184곳, 기간 2024-01~2025-12, 총진료비 = 본인부담 + 보험자부담(전 건 일치), 환자·기관·상병코드 참조 무결성 문제 없음.
- 주의: `institution`(기관 ID만 있음)과 `hospital_open`(기관명 있음)은 연결 키가 없다. 모든 값이 텍스트라 앞자리 0 코드(`031`, `01`)가 보존되어 있다.

## 2단계. 프로젝트 구조 정하기 (작게 시작)

**프롬프트**

```
웹 대시보드를 만들건데, 프로젝트를 폴더와 파일을 구조화를 먼저 할거야. 이 구조를 반복가능한 형태로 만들고 싶어. 그 이후에 대시보드를 만들기 위한 인터뷰를 요청하자.
```

처음 만든 구조(Makefile, config, scripts, dashboard)가 복잡해서 다음 프롬프트로 다시 잡았다.

```
지금 현재 구조가 너무 복잡해. 균일하고 통일된 양식을 가지되 작게 시작해서 점차 발전하는 방향으로 디렉토리를 잡아보자. 다시 제안해줘
```

**최종 합의 구조 (파일 5개)**

```
build.py              시트 다운로드 → 집계 → data/*.json
index.html            대시보드 (HTML+CSS+JS 한 파일)
data/                 CSV(git 제외)와 집계 JSON
docs/requirements.md  인터뷰 결과
README.md
```

**통일 양식**: 지표 하나 = 함수 `metric_<이름>()` = `data/<이름>.json` = `<section data-metric="<이름>">`. 
**성장 규칙**: build.py 300줄↑ → `metrics/` 분리, index.html 500줄↑ → css/js 분리, 페이지 2개↑ → `pages/`, 갱신이 잦아지면 Makefile.

## 3단계. 구조를 스킬로 만들기

**프롬프트**

```
이 형태를 대시보드 만드는데 재사용할수 있도록 스킬로 만들어줘.
```

**결과**: `~/.claude/skills/dashboard-scaffold/` (사본: `skill/dashboard-scaffold/`).
- `scripts/scaffold.py`: 시트 URL에서 탭 이름과 gid를 자동으로 찾아 파일 5개를 만든다. 이미 있는 파일은 덮어쓰지 않고(`--force` 로만 덮어씀), 설명용 README 탭은 제외한다.
- 사용법: `python3 ~/.claude/skills/dashboard-scaffold/scripts/scaffold.py <폴더> --sheet-url "<URL>" --title "<제목>"`

**기존 프로젝트를 새 구조로 정리하는 프롬프트**

```
스킬로 현재 프로젝트를 새 구조로 정리해줘. Makefile, config, scripts, dashboard 폴더는 삭제해도 돼.
```

## 4단계. 요구사항 인터뷰

**프롬프트** (본인 역할과 목적을 먼저 말하고 부족한 부분은 인터뷰로 채우게 한다)

```
나는 식약처에 보건의료분석담당자야. 요즘 병원별로 진료비가 많이 차이난다는 이야기가 있어서 이거를 주기적으로 데이터를 확인해서 보고싶어. 감염병 특히 호흡기 질환에 대해서 딥다이브하게 보고싶어. 부족한 부분은 나한테 인터뷰를 해서 채워줘
```

**인터뷰 결과 (docs/requirements.md)**

| 항목 | 결정 |
|---|---|
| 분석 대상 | 주상병이 호흡기 J코드 전체 (13,285건, 외래 13,232건 + 입원 53건) |
| 비교 단위 | 기관 종별 (상급종합병원 `01`, 종합병원 `11`, 병원 `21`, 의원 `31`) |
| 진료비 지표 | 명세서(건)당 총진료비 (`rvd_rpe_tamt_amt`) |
| 보정 | 같은 상병끼리 비교 (연령·성별 보정 없음) |
| 편차 표현 | 분포 P25 / P50 / P75 / P90 (박스플롯) |
| 갱신 | 월 1회 |
| 용도 | 본인 분석 + 내부 보고 |
| 필터 | 지정 없음 → 기간, 상병, 종별, 입원 포함으로 정함 |

**가정**: 입원은 표본이 작아 기본 제외(토글), 표본 30건 미만은 "표본 부족" 표시.

## 5단계. 구현

**프롬프트**

```
좋아, 요구사항대로 대시보드 구현 시작해줘
```

**결과**
- `build.py` 에 `metric_resp_claims()`: 호흡기 명세서를 열 기반 JSON(`data/resp_claims.json`, 약 400KB)으로 저장. 종별 코드명은 `code_table`, 상병명은 `sick_master` 로 해석한다.
- `index.html`: 이 JSON 하나를 읽어 브라우저에서 필터·집계해 5개 섹션을 그린다 (KPI, 월별 추이, 종별 분포, 상병×종별 표, 상병 비중). 차트는 라이브러리 없이 SVG 로 직접 그렸다.
- 백분위수는 선형 보간(numpy 기본 방식)이다.

**검증 값 (외래, 2024-01~2025-12)**: 건수 13,232, 총진료비 299,500,400원, 건당 중앙값 18,300원, P90 38,600원. 종별 P50: 상급종합 49,500 / 종합병원 29,000 / 병원 20,000 / 의원 16,600원. 파이썬 `statistics` 로 따로 계산해 일치를 확인했다.

## 6단계. 아티팩트 프로토타입 (선택)

**프롬프트**

```
어떤형태로 나오는지 감이 안나오니깐 아티팩트로 간단하게 프로토타입으로 만들어줘.
```

`index.html` 의 데이터를 인라인으로 넣은 단일 파일을 만들어 Artifact 로 게시한다. 아티팩트 환경은 외부 글꼴 서버(Pretendard)를 막으므로 글꼴만 시스템 글꼴로 대체된다.

## 7단계. GitHub Pages 배포

**프롬프트**

```
현재 대시보드를 깃허브를 이용해서 배포하고싶어. 어떤 절차로 해야하는지 단계적으로 나에게 알려주고 너가 직접 할수 있는거는 직접할수있게 해줘
```

**절차**

| 단계 | 내용 | 누가 |
|---|---|---|
| 1 | `git init -b main`, 첫 커밋 (CSV는 `.gitignore`) | Claude |
| 2 | `brew install gh` | Claude |
| 3 | `gh auth login -h github.com -p https -w` (브라우저에서 코드 입력 후 Authorize) | **본인** (승인은 대신할 수 없음) |
| 4 | `gh repo create respiratory-cost-dashboard --public --source=. --remote=origin --push` | Claude (공개 저장소 생성은 자동 안전 검사가 한 번 막으므로 사용자가 허용해야 함) |
| 5 | Pages 켜기: `gh api -X POST repos/<아이디>/<저장소>/pages -f "source[branch]=main" -f "source[path]=/"` | Claude |
| 6 | 빌드 완료 후 주소·데이터 파일 응답 200 확인 | Claude |

**공개 범위 주의**: 무료 Pages 는 공개 저장소만 된다. 주소를 아는 누구나 `data/resp_claims.json` 을 받을 수 있다. 실습 표본 데이터라 공개했지만, 실제 식약처·심평원 데이터에는 쓰지 말고 비공개 호스팅을 써야 한다.

**월 1회 갱신**

```bash
python3 build.py --refresh
git add -A && git commit -m "데이터 갱신" && git push
```

## 8단계. 디자인 시스템 적용

**프롬프트**

```
https://github.com/wanteddev/montage-web 이 시스템을 적용해줘
```

**결정**: Montage 의 컴포넌트 라이브러리(`@montage-ui/core`, React+Emotion)는 쓰지 않고 **디자인 토큰만** `index.html` 의 CSS 변수로 옮겼다 (정적 페이지를 유지하고 빌드 단계를 늘리지 않기 위해).
- 출처: `packages/theme/src/theme/` (semantic, atomic, typography, radius)
- 색: 배경 `#F7F7F8`, 카드 `#FFFFFF`, 글자 `#171719`, 브랜드 `#0066FF`, 경고 `#E52222`. 다크는 `#0F0F10`, `#1B1C1E`, `#F7F7F8`, `#3385FF`, `#FF6363`
- 타이포: Pretendard, title3 / headline1 / heading1 / body2
- 모서리: 카드 12px, 입력칸 8px

```
변경한 디자인을 GitHub에 push해서 배포해줘
```

## 9단계. 과제 제출 정리

**프롬프트**

```
과제 제출을 해야하는데 이거 확인해줘 (독자·KPI·차트·인사이트를 자유 형식으로 정리)
```

**핵심 인사이트**: 같은 호흡기 질환이라도 상급종합병원의 건당 진료비 중앙값(49,500원)이 의원(16,600원)의 약 3배이고, 같은 상병(J209)끼리도 45,400원 대 15,700원으로 격차가 남는다. 단, 연령·성별·중증도는 보정하지 않았으므로 "환자 구성 차이만으로는 설명되지 않는다"가 아니라 "상병을 맞춰도 격차가 남는다"로 쓴다.

---

## 처음부터 재현하는 최단 순서

```bash
# 1. 스킬 설치
mkdir -p ~/.claude/skills && cp -R skill/dashboard-scaffold ~/.claude/skills/
# 2. 구조 생성 + 데이터 내려받기
python3 ~/.claude/skills/dashboard-scaffold/scripts/scaffold.py ./my-dashboard --sheet-url "<시트 URL>" --title "호흡기 진료비 편차 대시보드"
cd my-dashboard && python3 build.py
# 3. 이후는 위 4~8단계 프롬프트를 순서대로 사용
```

## 자주 막히는 곳

| 증상 | 원인과 해결 |
|---|---|
| CSV 내려받기가 HTML 이나 403 | 시트 공유가 "링크가 있는 모든 사용자"가 아님. 공유 설정을 바꾼다 |
| `gh auth login` 이 첫 질문에서 멈춤 | 터미널 창을 클릭해 포커스를 준 뒤 `Y` + Enter. 코드는 브라우저에서 본인이 입력한다 |
| 공개 저장소 생성 명령이 거부됨 | 자동 안전 검사 때문. 본인이 터미널에서 직접 실행하거나 허용 후 재시도 |
| 배포 주소가 404 | Pages 빌드 중. 1~2분 기다린다 (`gh api repos/<아이디>/<저장소>/pages/builds/latest --jq .status`) |
| 배포 후에도 옛 화면 | 브라우저 캐시. Cmd+Shift+R |
| 화면이 비어 있고 "data/resp_claims.json 을 읽지 못했습니다" | `python3 build.py` 를 실행하지 않았거나 `file://` 로 열었음. `python3 -m http.server` 로 연다 |
