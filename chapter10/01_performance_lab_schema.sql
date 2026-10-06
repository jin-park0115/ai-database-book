-- Chapter 10. performance_lab 스키마 생성
-- 목적: Chapter 07·08 기준 데이터를 보호하면서 인덱스 성능 실험용 테이블을 만듭니다.
-- 검증 기준: PostgreSQL 16. PostgreSQL 18+에서는 일부 다중 컬럼 인덱스 계획이 달라질 수 있습니다.
-- 주의: 기존 스키마나 테이블을 자동으로 삭제하지 않습니다.

SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;
SHOW server_version;

-- 잘못된 환경에서는 DDL 트랜잭션을 열기 전에 중단합니다.
DO $$
DECLARE
    v_requested_count bigint;
    v_learning_count bigint;
    v_completed_count bigint;
    v_cancelled_count bigint;
    v_total_amount numeric(20,0);
    v_active_count bigint;
    v_active_amount numeric(20,0);
    v_non_cancelled_count bigint;
    v_non_cancelled_amount numeric(20,0);
    v_named_constraint_count bigint;
    v_not_null_count bigint;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '스키마 생성 중단: 현재 데이터베이스는 %입니다. ai_database_book에 연결하세요.',
            current_database();
    END IF;

    IF current_setting('transaction_read_only')::boolean THEN
        RAISE EXCEPTION
            '스키마 생성 중단: 현재 연결이 읽기 전용입니다.';
    END IF;

    IF to_regclass('course_project.students') IS NULL
       OR to_regclass('course_project.instructors') IS NULL
       OR to_regclass('course_project.courses') IS NULL
       OR to_regclass('course_project.enrollments') IS NULL THEN
        RAISE EXCEPTION
            '스키마 생성 중단: Chapter 07 course_project 핵심 테이블이 준비되지 않았습니다.';
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
            '스키마 생성 중단: course_project.enrollments.recorded_amount는 NUMERIC(12,0)이어야 합니다.';
    END IF;

    IF (SELECT COUNT(*) FROM course_project.students) <> 3
       OR (SELECT COUNT(*) FROM course_project.instructors) <> 2
       OR (SELECT COUNT(*) FROM course_project.courses) <> 3
       OR (SELECT COUNT(*) FROM course_project.enrollments) <> 5 THEN
        RAISE EXCEPTION
            '스키마 생성 중단: Chapter 07·08 기준 행 수 3/2/3/5를 확인하세요.';
    END IF;

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

    IF v_requested_count <> 2
       OR v_learning_count <> 1
       OR v_completed_count <> 1
       OR v_cancelled_count <> 1
       OR v_total_amount <> 590000
       OR v_active_count <> 3
       OR v_active_amount <> 340000
       OR v_non_cancelled_count <> 4
       OR v_non_cancelled_amount <> 440000 THEN
        RAISE EXCEPTION
            '스키마 생성 중단: Chapter 07·08 상태·금액 기준이 다릅니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM course_project.enrollments
        WHERE id = 1001 AND status = '완료' AND recorded_amount = 100000
    ) OR NOT EXISTS (
        SELECT 1 FROM course_project.enrollments
        WHERE id = 1004 AND status = '취소' AND recorded_amount = 150000
    ) OR NOT EXISTS (
        SELECT 1 FROM course_project.enrollments
        WHERE id = 1005 AND status = '신청' AND recorded_amount = 120000
    ) THEN
        RAISE EXCEPTION
            '스키마 생성 중단: 기준 신청 1001·1004·1005 상태 또는 기록 금액을 확인하세요.';
    END IF;

    IF to_regclass('course_project.uq_course_enrollments_active') IS NULL THEN
        RAISE EXCEPTION
            '스키마 생성 중단: Chapter 07 활성 신청 부분 고유 인덱스가 없습니다.';
    END IF;

    IF NOT has_database_privilege(current_user, current_database(), 'CREATE') THEN
        RAISE EXCEPTION
            '스키마 생성 중단: 현재 역할 %에는 데이터베이스 %의 CREATE 권한이 없습니다.',
            current_user, current_database();
    END IF;

    SELECT COUNT(*) INTO v_named_constraint_count
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

    SELECT COUNT(*) INTO v_not_null_count
    FROM information_schema.columns
    WHERE table_schema = 'course_project'
      AND table_name IN ('students', 'instructors', 'courses', 'enrollments')
      AND is_nullable = 'NO';

    IF v_named_constraint_count <> 15 OR v_not_null_count <> 20 THEN
        RAISE EXCEPTION
            '스키마 생성 중단: Chapter 07 구조 기준과 다릅니다. named_constraints=%, not_null_columns=%',
            v_named_constraint_count, v_not_null_count;
    END IF;

    IF to_regnamespace('performance_lab') IS NOT NULL THEN
        RAISE EXCEPTION
            '스키마 생성 중단: performance_lab 스키마가 이미 존재합니다. 현재 실험을 검토하거나 reset_performance_lab.sql을 사용하세요.';
    END IF;
END
$$;

BEGIN;

CREATE SCHEMA performance_lab;

CREATE TABLE performance_lab.students (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    joined_at DATE NOT NULL,

    CONSTRAINT uq_performance_students_email
        UNIQUE (email),

    CONSTRAINT chk_performance_students_name
        CHECK (char_length(trim(name)) > 0),

    CONSTRAINT chk_performance_students_email
        CHECK (char_length(trim(email)) > 0)
);

CREATE TABLE performance_lab.instructors (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    specialty VARCHAR(100) NOT NULL,

    CONSTRAINT uq_performance_instructors_email
        UNIQUE (email),

    CONSTRAINT chk_performance_instructors_name
        CHECK (char_length(trim(name)) > 0),

    CONSTRAINT chk_performance_instructors_email
        CHECK (char_length(trim(email)) > 0),

    CONSTRAINT chk_performance_instructors_specialty
        CHECK (char_length(trim(specialty)) > 0)
);

CREATE TABLE performance_lab.courses (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    instructor_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    level VARCHAR(20) NOT NULL,
    price NUMERIC(12, 0) NOT NULL,
    opened_at DATE NOT NULL,

    CONSTRAINT fk_performance_courses_instructor
        FOREIGN KEY (instructor_id)
        REFERENCES performance_lab.instructors(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_performance_courses_title
        CHECK (char_length(trim(title)) > 0),

    CONSTRAINT chk_performance_courses_level
        CHECK (level IN ('basic', 'intermediate', 'advanced')),

    CONSTRAINT chk_performance_courses_price
        CHECK (price >= 0)
);

CREATE TABLE performance_lab.enrollments (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    enrolled_at DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    recorded_amount NUMERIC(12, 0) NOT NULL,

    CONSTRAINT fk_performance_enrollments_student
        FOREIGN KEY (student_id)
        REFERENCES performance_lab.students(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_performance_enrollments_course
        FOREIGN KEY (course_id)
        REFERENCES performance_lab.courses(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_performance_enrollments_status
        CHECK (status IN ('신청', '수강중', '완료', '취소')),

    CONSTRAINT chk_performance_enrollments_recorded_amount
        CHECK (recorded_amount >= 0)
);

-- Chapter 07의 활성 신청 부분 고유 인덱스는 performance_lab에 미리 만들지 않습니다.
-- 이 장에서는 enrollments의 후보 인덱스 생성 전 기준 계획이 필요하므로,
-- 02의 합성 데이터 생성식과 07의 검증으로 활성 중복 0건을 확인합니다.

DO $$
DECLARE
    v_named_constraint_count bigint;
    v_not_null_count bigint;
    v_index_count bigint;
BEGIN
    IF to_regclass('performance_lab.students') IS NULL
       OR to_regclass('performance_lab.instructors') IS NULL
       OR to_regclass('performance_lab.courses') IS NULL
       OR to_regclass('performance_lab.enrollments') IS NULL THEN
        RAISE EXCEPTION
            '스키마 생성 검증 실패: performance_lab 핵심 테이블이 모두 생성되지 않았습니다.';
    END IF;

    SELECT COUNT(*) INTO v_named_constraint_count
    FROM pg_constraint
    WHERE conrelid IN (
        'performance_lab.students'::regclass,
        'performance_lab.instructors'::regclass,
        'performance_lab.courses'::regclass,
        'performance_lab.enrollments'::regclass
    )
      AND conname IN (
        'uq_performance_students_email',
        'chk_performance_students_name',
        'chk_performance_students_email',
        'uq_performance_instructors_email',
        'chk_performance_instructors_name',
        'chk_performance_instructors_email',
        'chk_performance_instructors_specialty',
        'fk_performance_courses_instructor',
        'chk_performance_courses_title',
        'chk_performance_courses_level',
        'chk_performance_courses_price',
        'fk_performance_enrollments_student',
        'fk_performance_enrollments_course',
        'chk_performance_enrollments_status',
        'chk_performance_enrollments_recorded_amount'
      );

    SELECT COUNT(*) INTO v_not_null_count
    FROM information_schema.columns
    WHERE table_schema = 'performance_lab'
      AND table_name IN ('students', 'instructors', 'courses', 'enrollments')
      AND is_nullable = 'NO';

    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE schemaname = 'performance_lab';

    IF v_named_constraint_count <> 15
       OR v_not_null_count <> 20
       OR v_index_count <> 6
       OR EXISTS (SELECT 1 FROM performance_lab.students)
       OR EXISTS (SELECT 1 FROM performance_lab.instructors)
       OR EXISTS (SELECT 1 FROM performance_lab.courses)
       OR EXISTS (SELECT 1 FROM performance_lab.enrollments) THEN
        RAISE EXCEPTION
            '스키마 생성 검증 실패: constraints=%, not_null=%, indexes=%',
            v_named_constraint_count, v_not_null_count, v_index_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'performance_lab'
          AND table_name = 'courses'
          AND column_name = 'price'
          AND data_type = 'numeric'
          AND numeric_precision = 12
          AND numeric_scale = 0
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'performance_lab'
          AND table_name = 'enrollments'
          AND column_name = 'recorded_amount'
          AND data_type = 'numeric'
          AND numeric_precision = 12
          AND numeric_scale = 0
    ) THEN
        RAISE EXCEPTION
            '스키마 생성 검증 실패: price와 recorded_amount는 NUMERIC(12,0)이어야 합니다.';
    END IF;

    RAISE NOTICE 'Chapter 10 performance lab schema validation passed';
END
$$;

COMMIT;

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'performance_lab'
ORDER BY table_name;
