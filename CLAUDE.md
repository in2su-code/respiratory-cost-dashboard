# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

호흡기(J코드) 명세서의 기관 종별 진료비 편차를 보는 웹 대시보드. 데이터는 오즈코딩 헬스케어 SQL 3기 실습용 구글 시트(`kr_claims`, 탭 10개)이고 실제 청구 데이터가 아니다. 화면은 정적 파일(GitHub Pages)이고, 데이터는 Supabase(Postgres)의 집계 함수를 브라우저가 직접 호출해 가져온다.

- 배포: https://in2su-code.github.io/respiratory-cost-dashboard/ (`main` 브랜치 루트)
- Supabase 프로젝트 ref: `tsiljnfuexmdswxfivvg`
- 요구사항과 결정 이력 `docs/requirements.md`, 처음부터 재현하는 절차 `docs/reproduce.md` (Supabase 전환 이전 기준)

## Commands

```bash
python3 build.py --refresh                  # 시트의 CSV 를 data/ 로 내려받기 (data/*.csv 는 git 제외)
python3 supabase/load_data.py               # data/*.csv → Supabase 적재 (테이블을 비우고 다시 채움)
supabase db push --linked --yes             # supabase/migrations/ 를 원격 DB 에 적용
python3 -m http.server                      # http://localhost:8000/  (file:// 로 열면 fetch 가 막힘)
```

빌드·린트·테스트 도구는 없다. 검증은 화면(또는 RPC 응답)의 숫자를 CSV 에서 파이썬 `statistics.quantiles(method='inclusive')` 로 다시 계산한 값과 대조한다. 기준 값(외래만, 전 기간): 13,232건, 총진료비 299,500,400원, 건당 중앙값 18,300원, P90 38,600원, 종별 격차 2.98배.

`load_data.py` 와 `db push` 는 `supabase login` + `supabase link --project-ref tsiljnfuexmdswxfivvg` 가 되어 있으면 DB 비밀번호 없이 동작한다(서버 키는 CLI 로 읽어 메모리에서만 쓴다). 로컬 Docker 가 없어서 `supabase start` 는 못 쓴다. 마이그레이션을 미리 시험하려면 임시 Postgres 를 띄우고 `anon`, `authenticated` 롤을 만든 뒤 적용한다.

## Architecture

데이터 흐름: 구글 시트 → `build.py --refresh` → `data/*.csv` → `supabase/load_data.py` → Supabase 테이블 → 집계 함수(RPC) → `index.html`.

- **원본 행은 브라우저에 노출하지 않는다.** 테이블 6개는 RLS 를 켜고 정책을 만들지 않아 anon 이 읽지 못한다(조회하면 빈 배열). 화면은 `security definer` 집계 함수 6개(`resp_meta`, `resp_kpi`, `resp_monthly`, `resp_by_class`, `resp_sick_class`, `resp_sick_mix`)만 `anon` 권한으로 호출한다. 내부 함수 `resp_base` 는 anon 실행 권한을 회수했다. 새 함수를 만들면 `grant execute ... to anon` 을 직접 넣어야 하고, 내부용이면 `revoke` 해야 한다.
- **필터 규칙은 SQL 과 화면이 맞아야 한다.** 섹션마다 무시하는 필터가 다르다: 종별 분포는 종별 필터 무시, 상병 비중은 상병 필터 무시, 상병×종별 표는 상병·종별 필터 모두 무시, KPI 의 종별 격차는 종별 필터 무시. 이 규칙은 `supabase/migrations/20261022000100_resp_functions.sql` 의 함수별 `where` 와 `index.html` 의 `render()` 가 같은 이름의 파라미터(`p_from`, `p_to`, `p_sick`, `p_cls`, `p_inp`)로 연결된다. 백분위수는 `percentile_cont`(선형 보간), 표본 30건 미만 칸은 화면에서 "표본 부족" 처리한다(`MIN_N`).
- **`index.html` 단일 파일**: CSS 토큰(`:root`), HTML 섹션, JS 가 한 파일에 있다. 필터를 바꾸면 `render()` 가 RPC 5개를 병렬 호출하고, `seq` 로 늦게 도착한 옛 응답을 버린다. 차트는 라이브러리 없이 손으로 그린 SVG 이고 외부 의존은 Pretendard 글꼴 CSS 뿐이다. 코드에 들어 있는 Supabase URL 과 publishable(anon) 키는 공개되어도 되는 값이다.
- **디자인 시스템**: Montage(wanteddev/montage-web `packages/theme/src/theme/`)의 시맨틱 토큰을 `:root` 블록에 옮겨 쓴다. React 컴포넌트 라이브러리는 쓰지 않는다. 다크 모드는 `prefers-color-scheme` 과 `data-theme` 양쪽으로 처리한다.
- **`build.py`**: 지금은 사실상 CSV 다운로더다. `metric_*` 함수는 Supabase 전환 이전의 JSON 방식(`data/resp_claims.json`)의 잔재로, `index.html` 은 더 이상 이 JSON 을 읽지 않는다.
- **`skill/dashboard-scaffold/`**: `~/.claude/skills/dashboard-scaffold/` 의 사본(다른 PC에서 재현하기 위함). 한쪽을 고치면 다른 쪽도 맞춘다. 이 스킬은 Supabase 전환 전의 정적 JSON 구조를 만든다.

## Data gotchas

- 시트 값은 전부 텍스트다. 앞자리 0 코드(`031`, `01`)는 text 컬럼으로 두고 금액·건수만 int 로 변환한다(`load_data.py` 의 `TABLES`). 빈 칸은 NULL.
- 조인: `claim.yid → institution.yid`(종별은 `institution.cl_cd`, 이름은 `code_table` 의 `종별코드`), `claim.main_sick → sick_master.sickcd`. `hospital_open`(기관명 있음)은 `institution` 과 연결 키가 없어 쓰지 않는다. 기관 단위(개별 병원) 비교는 불가능하다.
- Supabase 에는 핵심 6개 테이블만 적재한다(`claim_sick`, `claim_rx`, `drug_ingredient`, `hospital_open` 은 제외).
- 입원(`fom_tp_cd=021`)은 호흡기 53건뿐이라 기본 제외하고 화면 토글로만 포함한다.

## Deployment

- `main` 에 push 하면 Pages 가 1~2분 뒤 갱신된다. 화면이 Supabase 를 직접 호출하므로 데이터만 갱신할 때는 push 가 필요 없고 `build.py --refresh` 후 `load_data.py` 만 실행한다.
- 저장소는 공개이고 GitHub CLI 는 `in2su-code` 계정으로 로그인되어 있다. 공개 저장소 생성처럼 외부에 공개되는 동작은 자동 안전 검사에서 막힐 수 있다.
- Supabase 무료 플랜은 접속이 없으면 프로젝트가 일시 정지되어 화면이 비게 된다.
- 집계 결과는 anon 으로 누구나 조회할 수 있다. 실제 식약처·심평원 데이터에는 이 구성(공개 읽기)을 쓰지 않는다.
