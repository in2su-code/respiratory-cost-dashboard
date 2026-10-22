-- 시트(kr_claims)의 핵심 6개 탭. 코드값은 앞자리 0 보존을 위해 text 로 둔다.
-- claim_sick, claim_rx, drug_ingredient, hospital_open 은 현재 대시보드가 쓰지 않아 제외.

create table public.claim (
  mid text primary key,
  jid text not null,
  yid text not null,
  insup_tp_cd text,
  fom_tp_cd text,
  main_sick text,
  sub_sick text,
  dgsbjt_cd text,
  recu_fr_dd date,
  recu_to_dd date,
  vst_ddcnt int,
  recu_ddcnt int,
  rvd_rpe_tamt_amt int,
  rvd_slf_brdn_amt int,
  rvd_insup_brdn_amt int,
  sopr_yn text,
  dgrslt_tp_cd text
);

create table public.patient (
  jid text primary key,
  sex_tp_cd text,
  birth_yr int,
  sido_cd text,
  qlf_tp_cd text,
  prem_quintile text
);

create table public.institution (
  yid text primary key,
  cl_cd text,
  region_cd text,
  shw_sbjt_cd text
);

create table public.sick_master (
  sickcd text primary key,
  krnm text,
  sicknm text,
  wcd text,
  msick text,
  cdd text,
  sex text,
  max_age text,
  min_age text,
  wocd text
);

create table public.code_table (
  code_type text,
  code text,
  code_nm text,
  primary key (code_type, code)
);

create table public.sido_code (
  sido_cd text primary key,
  sido_nm text,
  region_cd text,
  region_nm text
);

create index claim_main_sick_idx on public.claim (main_sick);
create index claim_yid_idx on public.claim (yid);
create index claim_recu_fr_dd_idx on public.claim (recu_fr_dd);

-- 원본 행은 화면(anon)에서 직접 읽지 못하게 막는다. 정책을 만들지 않으면 RLS 가 모두 거부한다.
-- 화면은 아래 집계 함수(다음 마이그레이션)만 호출한다.
alter table public.claim enable row level security;
alter table public.patient enable row level security;
alter table public.institution enable row level security;
alter table public.sick_master enable row level security;
alter table public.code_table enable row level security;
alter table public.sido_code enable row level security;
