#!/usr/bin/env bash
# data/*.csv → Supabase(Postgres) 적재. 다시 실행해도 안전하다(테이블을 비우고 다시 채움).
# 사용: DB 접속 문자열을 .env 의 SUPABASE_DB_URL 에 두고 `bash supabase/load_data.sh`
#       (먼저 `python3 build.py --refresh` 로 최신 CSV 를 받아 둔다)
set -euo pipefail
cd "$(dirname "$0")/.."

[ -f .env ] && set -a && . ./.env && set +a
: "${SUPABASE_DB_URL:?SUPABASE_DB_URL 이 없습니다. .env.example 을 참고해 .env 에 넣으세요}"

PSQL="${PSQL:-psql}"
command -v "$PSQL" >/dev/null || PSQL=/opt/homebrew/opt/libpq/bin/psql

# 부모 테이블 순서는 상관없지만(FK 없음) 한 트랜잭션으로 묶어 중간 실패 시 되돌린다.
{
  echo "begin;"
  echo "truncate claim, patient, institution, sick_master, code_table, sido_code;"
  for t in institution patient sick_master code_table sido_code claim; do
    echo "\\copy public.$t from 'data/$t.csv' with (format csv, header true)"
  done
  echo "commit;"
} | "$PSQL" "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -q

"$PSQL" "$SUPABASE_DB_URL" -At -c "select 'claim='||count(*) from claim union all select 'institution='||count(*) from institution union all select 'sick_master='||count(*) from sick_master"
