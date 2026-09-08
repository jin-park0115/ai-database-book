-- Chapter 03. 권장 로컬 PostgreSQL 환경 자동 확인
-- 목적: Chapter 04 이후 기본 실습에 필요한 권장 로컬 환경을 예외 기반으로 확인합니다.
-- 이 파일은 테이블과 업무 데이터를 생성·수정·삭제하지 않습니다.
-- 관리형 PostgreSQL이나 다른 대안 환경에서는 데이터베이스 이름과 권한 구조가 다를 수 있습니다.
-- 이 파일을 통과시키기 위해 관리형 환경의 권한을 무리하게 변경하지 마세요.

SELECT
    current_setting('server_version_num')::integer AS server_version_num,
    current_database() AS database_name,
    current_user AS user_name,
    current_schema() AS current_schema_name,
    current_setting('transaction_read_only') AS transaction_read_only,
    current_setting('TimeZone') AS timezone,
    to_regnamespace('public') IS NOT NULL AS public_schema_exists,
    CASE
        WHEN to_regnamespace('public') IS NULL THEN false
        ELSE has_schema_privilege(current_user, 'public', 'USAGE')
    END AS public_schema_usage_ok,
    CASE
        WHEN to_regnamespace('public') IS NULL THEN false
        ELSE has_schema_privilege(current_user, 'public', 'CREATE')
    END AS public_schema_create_ok;

DO $$
DECLARE
    v_server_version_num integer :=
        current_setting('server_version_num')::integer;
BEGIN
    IF v_server_version_num < 150000 THEN
        RAISE EXCEPTION
            '환경 확인 중단: PostgreSQL 15 이상이 필요합니다. server_version_num=%',
            v_server_version_num;
    END IF;

    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '환경 확인 중단: 현재 데이터베이스는 %입니다. 권장 로컬 경로에서는 ai_database_book 연결을 선택하세요.',
            current_database();
    END IF;

    IF NOT has_database_privilege(
        current_user,
        current_database(),
        'CONNECT'
    ) THEN
        RAISE EXCEPTION
            '환경 확인 중단: 사용자 %에게 현재 데이터베이스 CONNECT 권한이 없습니다.',
            current_user;
    END IF;

    IF to_regnamespace('public') IS NULL THEN
        RAISE EXCEPTION
            '환경 확인 중단: public 스키마가 존재하지 않습니다.';
    END IF;

    IF NOT has_schema_privilege(current_user, 'public', 'USAGE') THEN
        RAISE EXCEPTION
            '환경 확인 중단: 사용자 %에게 public 스키마 USAGE 권한이 없습니다.',
            current_user;
    END IF;

    IF NOT has_schema_privilege(current_user, 'public', 'CREATE') THEN
        RAISE EXCEPTION
            '환경 확인 중단: 사용자 %에게 public 스키마 CREATE 권한이 없습니다. Chapter 04에서 public.students를 만들 수 있는 연결을 선택하세요.',
            current_user;
    END IF;

    IF current_setting('transaction_read_only')::boolean THEN
        RAISE EXCEPTION
            '환경 확인 중단: 현재 연결이 읽기 전용입니다. Chapter 04에서 테이블을 만들 수 있는 연결을 선택하세요.';
    END IF;

    IF 1 + 1 <> 2 THEN
        RAISE EXCEPTION
            '환경 확인 중단: SQL 계산 결과 검증에 실패했습니다.';
    END IF;

    RAISE NOTICE 'Chapter 03 recommended local environment validation passed';
END
$$;