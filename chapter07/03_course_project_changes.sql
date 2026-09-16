-- Chapter 07. 03 온라인 강의 프로젝트 변경 시나리오
-- 시작 상태: 기본 샘플 3 / 2 / 3 / 4행, 기록 금액 합계 470000
-- 완료 상태: 최종 3 / 2 / 3 / 5행, 전체 590000 / 취소 제외 440000
-- 신규 신청과 상태 변경을 하나의 트랜잭션으로 실행합니다.

SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;

BEGIN;

DO $$
DECLARE
    v_student_count bigint;
    v_instructor_count bigint;
    v_course_count bigint;
    v_enrollment_count bigint;
    v_recorded_total numeric;
    v_status_1001 text;
    v_status_1004 text;
    v_count_1005 bigint;
    v_active_102_302 bigint;
    v_course_302_price numeric;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '변경 중단: 현재 데이터베이스는 %입니다. ai_database_book에 연결하세요.',
            current_database();
    END IF;

    IF current_setting('transaction_read_only')::boolean THEN
        RAISE EXCEPTION
            '변경 중단: 현재 연결이 읽기 전용입니다.';
    END IF;

    IF to_regclass('course_project.students') IS NULL
       OR to_regclass('course_project.instructors') IS NULL
       OR to_regclass('course_project.courses') IS NULL
       OR to_regclass('course_project.enrollments') IS NULL
       OR to_regclass('course_project.uq_course_enrollments_active') IS NULL THEN
        RAISE EXCEPTION
            '변경 중단: 프로젝트 객체가 모두 존재하지 않습니다.';
    END IF;

    SELECT COUNT(*) INTO v_student_count FROM course_project.students;
    SELECT COUNT(*) INTO v_instructor_count FROM course_project.instructors;
    SELECT COUNT(*) INTO v_course_count FROM course_project.courses;
    SELECT COUNT(*), COALESCE(SUM(recorded_amount), 0)
    INTO v_enrollment_count, v_recorded_total
    FROM course_project.enrollments;

    SELECT status INTO v_status_1001
    FROM course_project.enrollments
    WHERE id = 1001;

    SELECT status INTO v_status_1004
    FROM course_project.enrollments
    WHERE id = 1004;

    SELECT COUNT(*) INTO v_count_1005
    FROM course_project.enrollments
    WHERE id = 1005;

    SELECT COUNT(*) INTO v_active_102_302
    FROM course_project.enrollments
    WHERE student_id = 102
      AND course_id = 302
      AND status IN ('신청', '수강중');

    SELECT price INTO v_course_302_price
    FROM course_project.courses
    WHERE id = 302;

    IF v_student_count <> 3
       OR v_instructor_count <> 2
       OR v_course_count <> 3
       OR v_enrollment_count <> 4
       OR v_recorded_total <> 470000
       OR v_status_1001 IS DISTINCT FROM '수강중'
       OR v_status_1004 IS DISTINCT FROM '신청'
       OR v_count_1005 <> 0
       OR v_active_102_302 <> 0
       OR v_course_302_price IS DISTINCT FROM 120000::numeric THEN
        RAISE EXCEPTION
            '변경 시작 상태 불일치: rows=%/%/%/%, total=%, status1001=%, status1004=%, id1005=%, active102_302=%, course302_price=%',
            v_student_count,
            v_instructor_count,
            v_course_count,
            v_enrollment_count,
            v_recorded_total,
            v_status_1001,
            v_status_1004,
            v_count_1005,
            v_active_102_302,
            v_course_302_price;
    END IF;
END
$$;

INSERT INTO course_project.enrollments (
    id,
    student_id,
    course_id,
    enrolled_at,
    status,
    recorded_amount
)
SELECT
    1005,
    102,
    c.id,
    DATE '2026-04-07',
    '신청',
    c.price
FROM course_project.courses AS c
WHERE c.id = 302
RETURNING id, student_id, course_id, status, recorded_amount;

UPDATE course_project.enrollments
SET status = '완료'
WHERE id = 1001
  AND status = '수강중'
RETURNING id, status, recorded_amount;

UPDATE course_project.enrollments
SET status = '취소'
WHERE id = 1004
  AND status = '신청'
RETURNING id, status, recorded_amount;

ALTER TABLE course_project.enrollments
    ALTER COLUMN id RESTART WITH 1006;

DO $$
DECLARE
    v_student_count bigint;
    v_instructor_count bigint;
    v_course_count bigint;
    v_enrollment_count bigint;
    v_status_1001 text;
    v_amount_1001 numeric;
    v_status_1004 text;
    v_amount_1004 numeric;
    v_status_1005 text;
    v_amount_1005 numeric;
    v_active_duplicate_count bigint;
    v_recorded_total numeric;
    v_non_cancelled_count bigint;
    v_non_cancelled_recorded numeric;
BEGIN
    SELECT COUNT(*) INTO v_student_count FROM course_project.students;
    SELECT COUNT(*) INTO v_instructor_count FROM course_project.instructors;
    SELECT COUNT(*) INTO v_course_count FROM course_project.courses;

    SELECT
        COUNT(*),
        COALESCE(SUM(recorded_amount), 0),
        COUNT(*) FILTER (WHERE status <> '취소'),
        COALESCE(SUM(recorded_amount) FILTER (WHERE status <> '취소'), 0)
    INTO
        v_enrollment_count,
        v_recorded_total,
        v_non_cancelled_count,
        v_non_cancelled_recorded
    FROM course_project.enrollments;

    SELECT status, recorded_amount
    INTO v_status_1001, v_amount_1001
    FROM course_project.enrollments
    WHERE id = 1001;

    SELECT status, recorded_amount
    INTO v_status_1004, v_amount_1004
    FROM course_project.enrollments
    WHERE id = 1004;

    SELECT status, recorded_amount
    INTO v_status_1005, v_amount_1005
    FROM course_project.enrollments
    WHERE id = 1005;

    SELECT COUNT(*) INTO v_active_duplicate_count
    FROM (
        SELECT student_id, course_id
        FROM course_project.enrollments
        WHERE status IN ('신청', '수강중')
        GROUP BY student_id, course_id
        HAVING COUNT(*) > 1
    ) AS duplicated_active_enrollments;

    IF v_student_count <> 3
       OR v_instructor_count <> 2
       OR v_course_count <> 3
       OR v_enrollment_count <> 5
       OR v_status_1001 IS DISTINCT FROM '완료'
       OR v_amount_1001 IS DISTINCT FROM 100000::numeric
       OR v_status_1004 IS DISTINCT FROM '취소'
       OR v_amount_1004 IS DISTINCT FROM 150000::numeric
       OR v_status_1005 IS DISTINCT FROM '신청'
       OR v_amount_1005 IS DISTINCT FROM 120000::numeric
       OR v_active_duplicate_count <> 0
       OR v_recorded_total <> 590000
       OR v_non_cancelled_count <> 4
       OR v_non_cancelled_recorded <> 440000 THEN
        RAISE EXCEPTION
            '변경 완료 상태 불일치: rows=%/%/%/%, 1001=%/%, 1004=%/%, 1005=%/%, active_duplicate=%, total=%, non_cancelled=%/%',
            v_student_count,
            v_instructor_count,
            v_course_count,
            v_enrollment_count,
            v_status_1001,
            v_amount_1001,
            v_status_1004,
            v_amount_1004,
            v_status_1005,
            v_amount_1005,
            v_active_duplicate_count,
            v_recorded_total,
            v_non_cancelled_count,
            v_non_cancelled_recorded;
    END IF;

    RAISE NOTICE 'Chapter 07 course project changes passed';
END
$$;

COMMIT;

SELECT id, student_id, course_id, status, recorded_amount
FROM course_project.enrollments
WHERE id IN (1001, 1004, 1005)
ORDER BY id;