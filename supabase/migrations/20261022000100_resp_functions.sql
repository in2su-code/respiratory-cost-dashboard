-- 대시보드가 호출하는 집계 함수. 모두 jsonb 를 돌려주고, 원본 행은 노출하지 않는다.
-- 백분위수는 percentile_cont(선형 보간)로 index.html 의 pct() 와 같은 방식이다.
-- 필터 규칙은 index.html 과 동일: 섹션마다 무시하는 필터가 다르다.
--   p_from/p_to : 'YYYY-MM', p_sick : 상병코드 또는 null, p_cls : 종별코드 또는 null, p_inp : 입원 포함 여부

-- 내부용: 호흡기(J) 명세서 + 종별. 화면(anon)이 직접 부를 수 없다.
create function public.resp_base(p_from text, p_to text, p_inp boolean)
returns table (month text, sick text, cls text, amt int)
language sql stable security definer set search_path = public as $$
  select to_char(c.recu_fr_dd, 'YYYY-MM'), c.main_sick, i.cl_cd, c.rvd_rpe_tamt_amt
  from claim c join institution i using (yid)
  where c.main_sick like 'J%'
    and to_char(c.recu_fr_dd, 'YYYY-MM') between p_from and p_to
    and (p_inp or c.fom_tp_cd = '031')
$$;
revoke execute on function public.resp_base(text, text, boolean) from public, anon, authenticated;

-- 필터 드롭다운용 (월 목록, 상병, 종별)
create function public.resp_meta()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'months', (select jsonb_agg(m order by m) from (select distinct to_char(recu_fr_dd, 'YYYY-MM') m from claim where main_sick like 'J%') x),
    'sicks',  (select jsonb_agg(jsonb_build_object('cd', s.sickcd, 'nm', s.krnm) order by s.sickcd)
               from sick_master s where s.sickcd in (select distinct main_sick from claim where main_sick like 'J%')),
    'classes',(select jsonb_agg(jsonb_build_object('cd', t.code, 'nm', t.code_nm) order by t.code)
               from code_table t where t.code_type = '종별코드'
                 and t.code in (select distinct cl_cd from institution i join claim c using (yid) where c.main_sick like 'J%'))
  )
$$;

-- KPI 카드: 필터(기간·상병·종별) 적용. 종별 격차는 종별 필터를 무시하고 n>=30 인 종별만 비교.
create function public.resp_kpi(p_from text, p_to text, p_sick text, p_cls text, p_inp boolean)
returns jsonb language sql stable security definer set search_path = public as $$
  with b as (select * from resp_base(p_from, p_to, p_inp) where p_sick is null or sick = p_sick),
       f as (select * from b where p_cls is null or cls = p_cls),
       cm as (select percentile_cont(0.5) within group (order by amt) med
              from b group by cls having count(*) >= 30)
  select jsonb_build_object(
    'n', (select count(*) from f),
    'sum', (select coalesce(sum(amt), 0) from f),
    'p50', (select percentile_cont(0.5) within group (order by amt) from f),
    'p90', (select percentile_cont(0.9) within group (order by amt) from f),
    'class_ratio', (select case when count(*) >= 2 then max(med) / min(med) end from cm)
  )
$$;

-- 월별 추이 (필터 모두 적용)
create function public.resp_monthly(p_from text, p_to text, p_sick text, p_cls text, p_inp boolean)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'month', month, 'n', n, 'p50', p50, 'p90', p90) order by month), '[]'::jsonb)
  from (
    select month, count(*) n,
           percentile_cont(0.5) within group (order by amt) p50,
           percentile_cont(0.9) within group (order by amt) p90
    from resp_base(p_from, p_to, p_inp)
    where (p_sick is null or sick = p_sick) and (p_cls is null or cls = p_cls)
    group by month
  ) t
$$;

-- 종별 분포 (종별 필터 무시)
create function public.resp_by_class(p_from text, p_to text, p_sick text, p_inp boolean)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'cd', cls, 'nm', t.code_nm, 'n', n, 'p25', p25, 'p50', p50, 'p75', p75, 'p90', p90) order by cls), '[]'::jsonb)
  from (
    select cls, count(*) n,
           percentile_cont(0.25) within group (order by amt) p25,
           percentile_cont(0.5)  within group (order by amt) p50,
           percentile_cont(0.75) within group (order by amt) p75,
           percentile_cont(0.9)  within group (order by amt) p90
    from resp_base(p_from, p_to, p_inp)
    where p_sick is null or sick = p_sick
    group by cls
  ) a join code_table t on t.code_type = '종별코드' and t.code = a.cls
$$;

-- 상병 × 종별 (상위 10개 상병, 상병·종별 필터 무시)
create function public.resp_sick_class(p_from text, p_to text, p_inp boolean)
returns jsonb language sql stable security definer set search_path = public as $$
  with b as (select * from resp_base(p_from, p_to, p_inp)),
       top as (select sick, count(*) n, percentile_cont(0.5) within group (order by amt) p50
               from b group by sick order by count(*) desc limit 10)
  select coalesce(jsonb_agg(jsonb_build_object(
      'sick', top.sick, 'nm', s.krnm, 'n', top.n, 'p50', top.p50,
      'by_class', (select jsonb_agg(jsonb_build_object('cd', cls, 'n', cn, 'p50', cp) order by cls)
                   from (select cls, count(*) cn, percentile_cont(0.5) within group (order by amt) cp
                         from b where b.sick = top.sick group by cls) q)
    ) order by top.n desc), '[]'::jsonb)
  from top join sick_master s on s.sickcd = top.sick
$$;

-- 상병 비중 (상병 필터 무시, 종별 필터 적용, 상위 12개)
create function public.resp_sick_mix(p_from text, p_to text, p_cls text, p_inp boolean)
returns jsonb language sql stable security definer set search_path = public as $$
  with b as (select * from resp_base(p_from, p_to, p_inp) where p_cls is null or cls = p_cls)
  select jsonb_build_object(
    'total', (select count(*) from b),
    'items', coalesce((select jsonb_agg(jsonb_build_object('sick', sick, 'nm', s.krnm, 'n', n) order by n desc)
                       from (select sick, count(*) n from b group by sick order by count(*) desc limit 12) t
                       join sick_master s on s.sickcd = t.sick), '[]'::jsonb))
$$;

-- 화면(anon)이 부를 수 있는 함수만 허용
grant execute on function public.resp_meta() to anon, authenticated;
grant execute on function public.resp_kpi(text, text, text, text, boolean) to anon, authenticated;
grant execute on function public.resp_monthly(text, text, text, text, boolean) to anon, authenticated;
grant execute on function public.resp_by_class(text, text, text, boolean) to anon, authenticated;
grant execute on function public.resp_sick_class(text, text, boolean) to anon, authenticated;
grant execute on function public.resp_sick_mix(text, text, text, boolean) to anon, authenticated;
