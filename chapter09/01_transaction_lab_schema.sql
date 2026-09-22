-- Chapter 09. transaction_lab 스키마 생성
-- Chapter 07의 course_project 최종 상태를 확인한 뒤 트랜잭션 실습 공간을 만듭니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- 잘못된 환경에서는 DDL 트랜잭션을 열기 전에 중단합니다.
DO $$
DECLARE
    v_requested_count INTEGER;
    v_learning_count INTEGER;
    v_completed_count INTEGER;
    v_cancelled_count INTEGER;
    v_total_amount NUMERIC;
    v_active_amount NUMERIC;
    v_non_cancelled_amount NUMERIC;
    v_named_constraint_count BIGINT;
    v_not_null_count BIGINT;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '실행 중단: 현재 데이터베이스는 %입니다. ai_database_book에 연결하세요.',
            current_database();
    END IF;

    IF to_regclass('course_project.students') IS NULL
       OR to_regclass('course_project.instructors') IS NULL
       OR to_regclass('course_project.courses') IS NULL
       OR to_regclass('course_project.enrollments') IS NULL THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07 course_project 핵심 테이블이 준비되지 않았습니다.';
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
            '실행 중단: Chapter 07 recorded_amount는 NUMERIC(12,0)이어야 합니다.';
    END IF;

    IF to_regclass('course_project.uq_course_enrollments_active') IS NULL THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07 활성 신청 부분 고유 인덱스를 확인하세요.';
    END IF;

    IF NOT has_database_privilege(current_user, current_database(), 'CREATE') THEN
        RAISE EXCEPTION
            '실행 중단: 현재 역할 %에는 데이터베이스 %의 CREATE 권한이 없습니다.',
            current_user,
            current_database();
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
            '실행 중단: Chapter 07 구조 기준과 다릅니다. named_constraints=%, not_null_columns=%',
            v_named_constraint_count,
            v_not_null_count;
    END IF;

    IF to_regnamespace('transaction_lab') IS NOT NULL THEN
        RAISE EXCEPTION
            '실행 중단: transaction_lab 스키마가 이미 존재합니다. 현재 상태를 확인하거나 reset_transaction_lab.sql을 사용하세요.';
    END IF;

    IF (SELECT COUNT(*) FROM course_project.students) <> 4
       OR (SELECT COUNT(*) FROM course_project.instructors) <> 2
       OR (SELECT COUNT(*) FROM course_project.courses) <> 3
       OR (SELECT COUNT(*) FROM course_project.enrollments) <> 5 THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07 기준 행 수 3/2/3/5를 확인하세요.';
    END IF;

    IF (SELECT COUNT(*) FROM course_project.students WHERE id IN (101, 102, 103)) <> 3
       OR (
            SELECT COUNT(*)
            FROM course_project.courses
            WHERE (id, price) IN (
                (301, 100000::numeric),
                (302, 120000::numeric),
                (303, 150000::numeric)
            )
       ) <> 3 THEN
        RAISE EXCEPTION
            '실행 중단: 학생 101~103 또는 강의 301~303의 기준값을 확인하세요.';
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE status = '신청'),
        COUNT(*) FILTER (WHERE status = '수강중'),
        COUNT(*) FILTER (WHERE status = '완료'),
        COUNT(*) FILTER (WHERE status = '취소'),
        SUM(recorded_amount),
        SUM(recorded_amount) FILTER (WHERE status IN ('신청', '수강중')),
        SUM(recorded_amount) FILTER (WHERE status <> '취소')
    INTO
        v_requested_count,
        v_learning_count,
        v_completed_count,
        v_cancelled_count,
        v_total_amount,
        v_active_amount,
        v_non_cancelled_amount
    FROM course_project.enrollments;

    IF v_requested_count <> 2
       OR v_learning_count <> 1
       OR v_completed_count <> 1
       OR v_cancelled_count <> 1
       OR v_total_amount <> 590000
       OR v_active_amount <> 340000
       OR v_non_cancelled_amount <> 440000 THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07·08 기준 상태 또는 기록 금액이 다릅니다.';
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
            '실행 중단: Chapter 07 핵심 신청 1001·1004·1005의 상태와 금액을 확인하세요.';
    END IF;
END
$$;

BEGIN;

CREATE SCHEMA transaction_lab;

CREATE TABLE transaction_lab.course_inventory (
    course_id INTEGER PRIMARY KEY,
    capacity INTEGER NOT NULL,
    remaining_seats INTEGER NOT NULL,

    CONSTRAINT fk_transaction_inventory_course
        FOREIGN KEY (course_id)
        REFERENCES course_project.courses(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_transaction_inventory_capacity
        CHECK (capacity > 0),

    CONSTRAINT chk_transaction_inventory_remaining
        CHECK (
            remaining_seats >= 0
            AND remaining_seats <= capacity
        )
);

CREATE TABLE transaction_lab.enrollments (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    student_id INTEGER NOT NULL,
    course_id INTEGER NOT NULL,
    enrolled_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL,
    recorded_amount NUMERIC(12, 0) NOT NULL,

    CONSTRAINT fk_transaction_enrollment_student
        FOREIGN KEY (student_id)
        REFERENCES course_project.students(id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transaction_enrollment_course
        FOREIGN KEY (course_id)
        REFERENCES course_project.courses(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_transaction_enrollment_status
        CHECK (status IN ('수강중', '취소')),

    CONSTRAINT chk_transaction_enrollment_amount
        CHECK (recorded_amount >= 0)
);

CREATE UNIQUE INDEX uq_transaction_enrollments_active
ON transaction_lab.enrollments (student_id, course_id)
WHERE status = '수강중';

CREATE TABLE transaction_lab.payments (
    id INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    enrollment_id INTEGER NOT NULL,
    amount NUMERIC(12, 0) NOT NULL,
    paid_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT uq_transaction_payment_enrollment
        UNIQUE (enrollment_id),

    CONSTRAINT fk_transaction_payment_enrollment
        FOREIGN KEY (enrollment_id)
        REFERENCES transaction_lab.enrollments(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_transaction_payment_amount
        CHECK (amount >= 0)
);

DO $$
BEGIN
    IF to_regclass('transaction_lab.course_inventory') IS NULL
       OR to_regclass('transaction_lab.enrollments') IS NULL
       OR to_regclass('transaction_lab.payments') IS NULL
       OR to_regclass('transaction_lab.uq_transaction_enrollments_active') IS NULL THEN
        RAISE EXCEPTION
            '스키마 생성 검증 실패: transaction_lab 객체가 모두 생성되지 않았습니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'transaction_lab'
          AND table_name = 'enrollments'
          AND column_name = 'recorded_amount'
          AND data_type = 'numeric'
          AND numeric_precision = 12
          AND numeric_scale = 0
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'transaction_lab'
          AND table_name = 'payments'
          AND column_name = 'amount'
          AND data_type = 'numeric'
          AND numeric_precision = 12
          AND numeric_scale = 0
    ) THEN
        RAISE EXCEPTION
            '스키마 생성 검증 실패: 금액 열은 NUMERIC(12,0)이어야 합니다.';
    END IF;

    IF EXISTS (SELECT 1 FROM transaction_lab.course_inventory)
       OR EXISTS (SELECT 1 FROM transaction_lab.enrollments)
       OR EXISTS (SELECT 1 FROM transaction_lab.payments) THEN
        RAISE EXCEPTION
            '스키마 생성 검증 실패: 새 transaction_lab 테이블은 비어 있어야 합니다.';
    END IF;
END
$$;

COMMIT;

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'transaction_lab'
ORDER BY table_name;

SELECT 'Chapter 09 transaction lab schema validation passed' AS validation_result;