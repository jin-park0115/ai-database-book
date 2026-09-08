-- Chapter 03. PostgreSQL 실습 환경 정보 조회
-- 목적: 서버, 데이터베이스, 스키마, 검색 경로, 사용자, public 사용·생성 권한, 읽기 전용 상태와 시간대를 확인합니다.
-- 이 파일은 데이터를 변경하지 않는 조회문만 포함하므로 여러 번 안전하게 실행할 수 있습니다.
-- 권장 로컬 환경의 주요 조건을 자동으로 확인하려면 setup_validate_local.sql을 실행합니다.

-- 1. PostgreSQL 서버 버전 확인
SELECT version();

-- 2. 현재 연결된 데이터베이스 확인
-- 권장 로컬 경로의 기대 결과: ai_database_book
-- 관리형 또는 다른 대안 환경에서는 데이터베이스 이름이 다를 수 있습니다.
SELECT current_database();

-- 3. 현재 접속 사용자 확인
SELECT current_user;

-- 4. 현재 스키마 확인
-- current_schema()는 search_path에서 실제로 사용할 수 있는 첫 번째 스키마를 반환합니다.
-- 환경에 따라 public이 아닐 수 있습니다.
SELECT current_schema();

-- 5. 스키마 검색 순서 확인
SHOW search_path;

-- 6. 현재 세션의 읽기 전용 상태 확인
-- Chapter 04에서 변경 SQL을 실행할 권장 로컬 경로의 기대 결과: off
SHOW transaction_read_only;

-- 7. 현재 세션 시간대 확인
SHOW TimeZone;

-- 8. PostgreSQL이 날짜·시간 값을 정상적으로 반환하는지 확인
SELECT CURRENT_TIMESTAMP AS checked_at;

-- 9. SQL 편집기 실행과 결과 표시 확인
-- 기대 결과: 2
SELECT 1 + 1 AS result;

-- 10. 핵심 환경 정보를 한 행으로 요약
SELECT
    current_database() AS database_name,
    current_user AS user_name,
    current_schema() AS current_schema_name,
    current_setting('transaction_read_only') AS transaction_read_only,
    current_setting('TimeZone') AS timezone,
    current_database() = 'ai_database_book' AS recommended_database_name_ok,
    to_regnamespace('public') IS NOT NULL AS public_schema_exists,
    CASE
        WHEN to_regnamespace('public') IS NULL THEN false
        ELSE has_schema_privilege(current_user, 'public', 'USAGE')
    END AS public_schema_usage_ok,
    CASE
        WHEN to_regnamespace('public') IS NULL THEN false
        ELSE has_schema_privilege(current_user, 'public', 'CREATE')
    END AS public_schema_create_ok,
    1 + 1 = 2 AS sql_execution_ok;