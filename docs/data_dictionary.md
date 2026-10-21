# 데이터 사전

원본 설명은 시트 README 탭 참고. 컬럼별 통계는 `data_profile.md`(자동 생성).

## 조인 키

- `claim.jid` → `patient.jid` / `claim.yid` → `institution.yid`
- `claim.mid` → `claim_sick.mid`, `claim_rx.mid`
- `claim_sick.sick_cd`, `claim.main_sick` → `sick_master.sickcd`
- `claim_rx.gnl_cd` → `drug_ingredient.gnl_cd`
- `patient.sido_cd` → `sido_code.sido_cd` (→ 권역 `region_cd`)
- `*_cd` 코드값 해석 → `code_table (code_type, code, code_nm)`

## 주의

- 모든 값은 텍스트(앞자리 0 보존). 숫자 계산 시 변환 필요.
- 빈 칸 = NULL. `institution` 과 `hospital_open` 은 연결 키 없음.
- 청구 기간 2024-01-01 ~ 2025-12-31, 총진료비 = 본인부담 + 보험자부담 (전 건 일치).
