-- Chapter 12. nosql_lab 스키마 생성
-- 목적: 기존 프로젝트를 보호하면서 JSONB·Key-Value 개념과 저장소 선택 기준을 실습합니다.
-- 주의: 기존 스키마나 테이블을 자동으로 삭제하지 않습니다.

SELECT current_user AS current_user_name;
SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- ============================================================
-- 0. 실행 전 보호 조건
-- Chapter 07·08에서 확정한 course_project 기준 상태를 정확히 확인합니다.
-- ============================================================
DO $$
DECLARE
    v_student_count BIGINT;
    v_instructor_count BIGINT;
    v_course_count BIGINT;
    v_enrollment_count BIGINT;
    v_requested_count BIGINT;
    v_learning_count BIGINT;
    v_completed_count BIGINT;
    v_cancelled_count BIGINT;
    v_total_amount NUMERIC;
    v_active_count BIGINT;
    v_active_amount NUMERIC;
    v_non_cancelled_count BIGINT;
    v_non_cancelled_amount NUMERIC;
    v_active_duplicate_count BIGINT;
    v_project_named_constraint_count BIGINT;
    v_project_not_null_count BIGINT;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '실행 중단: 현재 데이터베이스는 %입니다. ai_database_book에 연결하세요.',
            current_database();
    END IF;

    IF current_setting('transaction_read_only')::BOOLEAN THEN
        RAISE EXCEPTION
            '실행 중단: 읽기 전용 연결에서는 nosql_lab을 만들 수 없습니다.';
    END IF;

    IF to_regclass('course_project.students') IS NULL
       OR to_regclass('course_project.instructors') IS NULL
       OR to_regclass('course_project.courses') IS NULL
       OR to_regclass('course_project.enrollments') IS NULL THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07·08 course_project 핵심 테이블이 준비되지 않았습니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'course_project'
          AND table_name = 'enrollments'
          AND column_name = 'recorded_amount'
          AND data_type = 'numeric'
          AND numeric_precision = 12
          AND numeric_scale = 0
    ) THEN
        RAISE EXCEPTION
            '실행 중단: course_project.enrollments.recorded_amount는 NUMERIC(12,0)이어야 합니다.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'course_project'
          AND table_name = 'enrollments'
          AND column_name = 'paid_amount'
    ) THEN
        RAISE EXCEPTION
            '실행 중단: 이전 금액 열이 남아 있습니다. Chapter 07·08의 recorded_amount 기준을 확인하세요.';
    END IF;

    SELECT COUNT(*) INTO v_student_count FROM course_project.students;
    SELECT COUNT(*) INTO v_instructor_count FROM course_project.instructors;
    SELECT COUNT(*) INTO v_course_count FROM course_project.courses;
    SELECT COUNT(*) INTO v_enrollment_count FROM course_project.enrollments;

    SELECT
        COUNT(*) FILTER (WHERE status = '신청'),
        COUNT(*) FILTER (WHERE status = '수강중'),
        COUNT(*) FILTER (WHERE status = '완료'),
        COUNT(*) FILTER (WHERE status = '취소'),
        COALESCE(SUM(recorded_amount), 0),
        COUNT(*) FILTER (WHERE status IN ('신청', '수강중')),
        COALESCE(SUM(recorded_amount) FILTER (WHERE status IN ('신청', '수강중')), 0),
        COUNT(*) FILTER (WHERE status <> '취소'),
        COALESCE(SUM(recorded_amount) FILTER (WHERE status <> '취소'), 0)
    INTO
        v_requested_count,
        v_learning_count,
        v_completed_count,
        v_cancelled_count,
        v_total_amount,
        v_active_count,
        v_active_amount,
        v_non_cancelled_count,
        v_non_cancelled_amount
    FROM course_project.enrollments;

    IF v_student_count <> 3
       OR v_instructor_count <> 2
       OR v_course_count <> 3
       OR v_enrollment_count <> 5
       OR v_requested_count <> 2
       OR v_learning_count <> 1
       OR v_completed_count <> 1
       OR v_cancelled_count <> 1
       OR v_total_amount <> 590000
       OR v_active_count <> 3
       OR v_active_amount <> 340000
       OR v_non_cancelled_count <> 4
       OR v_non_cancelled_amount <> 440000 THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07·08 기준 상태가 아닙니다. rows=%/%/%/%, status=%/%/%/%, amount=%/%/%',
            v_student_count, v_instructor_count, v_course_count, v_enrollment_count,
            v_requested_count, v_learning_count, v_completed_count, v_cancelled_count,
            v_total_amount, v_active_amount, v_non_cancelled_amount;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM course_project.enrollments
        WHERE id = 1001 AND status = '완료' AND recorded_amount = 100000
    ) OR NOT EXISTS (
        SELECT 1
        FROM course_project.enrollments
        WHERE id = 1004 AND status = '취소' AND recorded_amount = 150000
    ) OR NOT EXISTS (
        SELECT 1
        FROM course_project.enrollments
        WHERE id = 1005 AND status = '신청' AND recorded_amount = 120000
    ) THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07 핵심 신청 1001·1004·1005의 상태 또는 기록 금액이 다릅니다.';
    END IF;

    IF to_regclass('course_project.uq_course_enrollments_active') IS NULL THEN
        RAISE EXCEPTION
            '실행 중단: course_project 활성 신청 부분 고유 인덱스가 없습니다.';
    END IF;

    SELECT COUNT(*)
    INTO v_active_duplicate_count
    FROM (
        SELECT student_id, course_id
        FROM course_project.enrollments
        WHERE status IN ('신청', '수강중')
        GROUP BY student_id, course_id
        HAVING COUNT(*) > 1
    ) AS duplicated_active;

    IF v_active_duplicate_count <> 0 THEN
        RAISE EXCEPTION
            '실행 중단: 활성 신청 중복이 %건 있습니다.',
            v_active_duplicate_count;
    END IF;

    IF NOT has_database_privilege(current_user, current_database(), 'CREATE') THEN
        RAISE EXCEPTION
            '실행 중단: 현재 역할 %에는 데이터베이스 %의 CREATE 권한이 없습니다.',
            current_user, current_database();
    END IF;

    SELECT COUNT(*) INTO v_project_named_constraint_count
    FROM pg_constraint
    WHERE conrelid IN (
        'course_project.students'::regclass,
        'course_project.instructors'::regclass,
        'course_project.courses'::regclass,
        'course_project.enrollments'::regclass
    )
      AND conname IN (
        'uq_course_students_email',
        'chk_course_students_name_not_blank',
        'chk_course_students_email_not_blank',
        'uq_course_instructors_email',
        'chk_course_instructors_name_not_blank',
        'chk_course_instructors_email_not_blank',
        'chk_course_instructors_specialty_not_blank',
        'fk_course_courses_instructor',
        'chk_course_courses_title_not_blank',
        'chk_course_courses_level',
        'chk_course_courses_price',
        'fk_course_enrollments_student',
        'fk_course_enrollments_course',
        'chk_course_enrollments_status',
        'chk_course_enrollments_recorded_amount'
      );

    SELECT COUNT(*) INTO v_project_not_null_count
    FROM information_schema.columns
    WHERE table_schema = 'course_project'
      AND table_name IN ('students', 'instructors', 'courses', 'enrollments')
      AND is_nullable = 'NO';

    IF v_project_named_constraint_count <> 15 OR v_project_not_null_count <> 20 THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07 구조 기준과 다릅니다. named_constraints=%, not_null_columns=%',
            v_project_named_constraint_count, v_project_not_null_count;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_namespace
        WHERE nspname = 'nosql_lab'
    ) THEN
        RAISE EXCEPTION
            '실행 중단: nosql_lab 스키마가 이미 존재합니다. 보존 여부를 확인한 뒤 reset_nosql_lab.sql 사용을 검토하세요.';
    END IF;
END
$$;

-- ============================================================
-- 1. 스키마와 테이블 생성
-- 중간 실패 시 일부 객체만 남지 않도록 하나의 트랜잭션으로 처리합니다.
-- ============================================================
BEGIN;

CREATE SCHEMA nosql_lab;

-- 안정된 핵심 속성은 일반 컬럼으로 두고,
-- 가변 태그·옵션·강사 표시용 스냅샷만 JSONB에 둡니다.
-- source_course_id는 Chapter 07 원본과 대조하기 위한 논리적 참조입니다.
-- nosql_lab 단독 이동성을 유지하기 위해 물리적 FK는 만들지 않습니다.
CREATE TABLE nosql_lab.course_documents (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    source_course_id INTEGER NOT NULL,
    course_code TEXT NOT NULL,
    title TEXT NOT NULL,
    level TEXT NOT NULL,
    metadata JSONB NOT NULL,
    document_version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_nosql_course_documents_source_course
        UNIQUE (source_course_id),

    CONSTRAINT uq_nosql_course_documents_code
        UNIQUE (course_code),

    CONSTRAINT chk_nosql_course_documents_code_not_blank
        CHECK (char_length(trim(course_code)) > 0),

    CONSTRAINT chk_nosql_course_documents_title_not_blank
        CHECK (char_length(trim(title)) > 0),

    CONSTRAINT chk_nosql_course_documents_level
        CHECK (level IN ('basic', 'intermediate', 'advanced')),

    CONSTRAINT chk_nosql_course_documents_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object'),

    CONSTRAINT chk_nosql_course_documents_version
        CHECK (document_version >= 1),

    CONSTRAINT chk_nosql_course_documents_updated_at
        CHECK (updated_at >= created_at)
);

-- 이 테이블은 Key-Value 제품의 개념 시뮬레이션입니다.
-- 값은 편의를 위해 JSONB로 저장하지만 객체·배열·문자열·숫자 등 JSONB 값 전체를 허용합니다.
-- expired_at이 NULL이면 만료 정책이 없는 키로 해석합니다.
CREATE TABLE nosql_lab.key_value_cache_examples (
    cache_key TEXT PRIMARY KEY,
    cache_value JSONB NOT NULL,
    source_name TEXT NOT NULL,
    expired_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_nosql_cache_key_not_blank
        CHECK (char_length(trim(cache_key)) > 0),

    CONSTRAINT chk_nosql_cache_source_not_blank
        CHECK (char_length(trim(source_name)) > 0)
);

-- 저장소 후보는 정답표가 아니라 근거·PoC·복구 계획이 포함된 의사결정 기록입니다.
CREATE TABLE nosql_lab.storage_choice_cases (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    case_name TEXT NOT NULL,
    system_role TEXT NOT NULL,
    primary_query TEXT NOT NULL,
    candidate_storage TEXT NOT NULL,
    source_of_truth TEXT NOT NULL,
    consistency_requirement TEXT NOT NULL,
    synchronization_strategy TEXT NOT NULL,
    recovery_strategy TEXT NOT NULL,
    poc_success_criteria TEXT NOT NULL,
    decision_status TEXT NOT NULL,
    reason TEXT NOT NULL,
    reviewed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_nosql_storage_choice_case
        UNIQUE (case_name),

    CONSTRAINT chk_nosql_storage_role
        CHECK (system_role IN (
            'source_of_truth',
            'ephemeral_state',
            'derived_cache',
            'flexible_metadata',
            'event_log',
            'relationship_index'
        )),

    CONSTRAINT chk_nosql_storage_decision_status
        CHECK (decision_status IN (
            'candidate',
            'poc_planned',
            'hold',
            'adopted',
            'rejected'
        )),

    CONSTRAINT chk_nosql_storage_case_name_not_blank
        CHECK (char_length(trim(case_name)) > 0),

    CONSTRAINT chk_nosql_storage_primary_query_not_blank
        CHECK (char_length(trim(primary_query)) > 0),

    CONSTRAINT chk_nosql_storage_candidate_not_blank
        CHECK (char_length(trim(candidate_storage)) > 0),

    CONSTRAINT chk_nosql_storage_source_not_blank
        CHECK (char_length(trim(source_of_truth)) > 0),

    CONSTRAINT chk_nosql_storage_consistency_not_blank
        CHECK (char_length(trim(consistency_requirement)) > 0),

    CONSTRAINT chk_nosql_storage_sync_not_blank
        CHECK (char_length(trim(synchronization_strategy)) > 0),

    CONSTRAINT chk_nosql_storage_recovery_not_blank
        CHECK (char_length(trim(recovery_strategy)) > 0),

    CONSTRAINT chk_nosql_storage_poc_not_blank
        CHECK (char_length(trim(poc_success_criteria)) > 0),

    CONSTRAINT chk_nosql_storage_reason_not_blank
        CHECK (char_length(trim(reason)) > 0)
);

-- ============================================================
-- 2. COMMIT 전 구조 자동 판정
-- ============================================================
DO $$
DECLARE
    v_table_count BIGINT;
    v_constraint_count BIGINT;
    v_not_null_count BIGINT;
BEGIN
    SELECT COUNT(*)
    INTO v_table_count
    FROM information_schema.tables
    WHERE table_schema = 'nosql_lab'
      AND table_type = 'BASE TABLE';

    SELECT COUNT(*)
    INTO v_constraint_count
    FROM pg_constraint
    WHERE connamespace = 'nosql_lab'::regnamespace;

    SELECT COUNT(*)
    INTO v_not_null_count
    FROM information_schema.columns
    WHERE table_schema = 'nosql_lab'
      AND is_nullable = 'NO';

    IF v_table_count <> 3
       OR v_constraint_count <> 25
       OR v_not_null_count <> 26 THEN
        RAISE EXCEPTION
            'Chapter 12 구조 검증 실패: tables=% constraints=% not_null=%',
            v_table_count, v_constraint_count, v_not_null_count;
    END IF;

    IF to_regclass('nosql_lab.course_documents') IS NULL
       OR to_regclass('nosql_lab.key_value_cache_examples') IS NULL
       OR to_regclass('nosql_lab.storage_choice_cases') IS NULL THEN
        RAISE EXCEPTION
            'Chapter 12 구조 검증 실패: 핵심 테이블이 없습니다.';
    END IF;

    RAISE NOTICE 'Chapter 12 nosql lab schema validation passed';
END
$$;

COMMIT;

-- ============================================================
-- 3. 생성 결과 확인
-- ============================================================
SELECT
    table_schema,
    table_name
FROM information_schema.tables
WHERE table_schema = 'nosql_lab'
ORDER BY table_name;

SELECT
    conrelid::regclass::text AS table_name,
    conname AS constraint_name,
    contype AS constraint_type
FROM pg_constraint
WHERE connamespace = 'nosql_lab'::regnamespace
ORDER BY conrelid::regclass::text, conname;
