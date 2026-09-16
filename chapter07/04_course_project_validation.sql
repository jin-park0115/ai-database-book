-- Chapter 07. 04 온라인 강의 프로젝트 최종 검증
-- 시작 상태: 01 → 02 → 03 실행 완료
-- 완료 상태: 구조·관계·도메인·상태·금액 자동 검증 통과와 상세 조회
-- 이 파일은 데이터를 변경하지 않으므로 반복 실행할 수 있습니다.

SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;

DO $$
DECLARE
    v_named_constraint_count bigint;
    v_not_null_count bigint;
    v_student_count bigint;
    v_instructor_count bigint;
    v_course_count bigint;
    v_enrollment_count bigint;
    v_service_join_count bigint;
    v_student_101_enrollments bigint;
    v_course_301_enrollments bigint;
    v_instructor_201_courses bigint;
    v_orphan_student_count bigint;
    v_orphan_course_count bigint;
    v_orphan_instructor_count bigint;
    v_invalid_student_count bigint;
    v_invalid_instructor_count bigint;
    v_invalid_course_count bigint;
    v_invalid_enrollment_count bigint;
    v_active_duplicate_count bigint;
    v_status_1001 text;
    v_amount_1001 numeric;
    v_status_1004 text;
    v_amount_1004 numeric;
    v_status_1005 text;
    v_amount_1005 numeric;
    v_total_recorded numeric;
    v_non_cancelled_count bigint;
    v_non_cancelled_recorded numeric;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '검증 중단: 현재 데이터베이스는 %입니다. ai_database_book에 연결하세요.',
            current_database();
    END IF;

    IF to_regclass('course_project.students') IS NULL
       OR to_regclass('course_project.instructors') IS NULL
       OR to_regclass('course_project.courses') IS NULL
       OR to_regclass('course_project.enrollments') IS NULL
       OR to_regclass('course_project.uq_course_enrollments_active') IS NULL THEN
        RAISE EXCEPTION
            '검증 중단: Chapter 07 프로젝트 객체가 모두 존재하지 않습니다.';
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
            '검증 중단: enrollments.recorded_amount NUMERIC(12,0) 열이 없습니다.';
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
        v_total_recorded,
        v_non_cancelled_count,
        v_non_cancelled_recorded
    FROM course_project.enrollments;

    SELECT COUNT(*) INTO v_service_join_count
    FROM course_project.enrollments AS e
    JOIN course_project.students AS s ON e.student_id = s.id
    JOIN course_project.courses AS c ON e.course_id = c.id
    JOIN course_project.instructors AS i ON c.instructor_id = i.id;

    SELECT COUNT(*) INTO v_student_101_enrollments
    FROM course_project.enrollments
    WHERE student_id = 101;

    SELECT COUNT(*) INTO v_course_301_enrollments
    FROM course_project.enrollments
    WHERE course_id = 301;

    SELECT COUNT(*) INTO v_instructor_201_courses
    FROM course_project.courses
    WHERE instructor_id = 201;

    SELECT COUNT(*) INTO v_orphan_student_count
    FROM course_project.enrollments AS e
    LEFT JOIN course_project.students AS s ON e.student_id = s.id
    WHERE s.id IS NULL;

    SELECT COUNT(*) INTO v_orphan_course_count
    FROM course_project.enrollments AS e
    LEFT JOIN course_project.courses AS c ON e.course_id = c.id
    WHERE c.id IS NULL;

    SELECT COUNT(*) INTO v_orphan_instructor_count
    FROM course_project.courses AS c
    LEFT JOIN course_project.instructors AS i ON c.instructor_id = i.id
    WHERE i.id IS NULL;

    SELECT COUNT(*) INTO v_invalid_student_count
    FROM course_project.students
    WHERE name IS NULL
       OR email IS NULL
       OR joined_at IS NULL
       OR char_length(trim(name)) = 0
       OR char_length(trim(email)) = 0;

    SELECT COUNT(*) INTO v_invalid_instructor_count
    FROM course_project.instructors
    WHERE name IS NULL
       OR email IS NULL
       OR specialty IS NULL
       OR char_length(trim(name)) = 0
       OR char_length(trim(email)) = 0
       OR char_length(trim(specialty)) = 0;

    SELECT COUNT(*) INTO v_invalid_course_count
    FROM course_project.courses
    WHERE instructor_id IS NULL
       OR title IS NULL
       OR level IS NULL
       OR price IS NULL
       OR opened_at IS NULL
       OR char_length(trim(title)) = 0
       OR level NOT IN ('basic', 'intermediate', 'advanced')
       OR price < 0;

    SELECT COUNT(*) INTO v_invalid_enrollment_count
    FROM course_project.enrollments
    WHERE student_id IS NULL
       OR course_id IS NULL
       OR enrolled_at IS NULL
       OR status IS NULL
       OR recorded_amount IS NULL
       OR status NOT IN ('신청', '수강중', '완료', '취소')
       OR recorded_amount < 0;

    SELECT COUNT(*) INTO v_active_duplicate_count
    FROM (
        SELECT student_id, course_id
        FROM course_project.enrollments
        WHERE status IN ('신청', '수강중')
        GROUP BY student_id, course_id
        HAVING COUNT(*) > 1
    ) AS duplicated_active_enrollments;

    SELECT status, recorded_amount INTO v_status_1001, v_amount_1001
    FROM course_project.enrollments WHERE id = 1001;

    SELECT status, recorded_amount INTO v_status_1004, v_amount_1004
    FROM course_project.enrollments WHERE id = 1004;

    SELECT status, recorded_amount INTO v_status_1005, v_amount_1005
    FROM course_project.enrollments WHERE id = 1005;

    IF v_named_constraint_count <> 15
       OR v_not_null_count <> 20
       OR v_student_count <> 3
       OR v_instructor_count <> 2
       OR v_course_count <> 3
       OR v_enrollment_count <> 5
       OR v_service_join_count <> 5
       OR v_student_101_enrollments <> 2
       OR v_course_301_enrollments <> 2
       OR v_instructor_201_courses <> 2
       OR v_orphan_student_count <> 0
       OR v_orphan_course_count <> 0
       OR v_orphan_instructor_count <> 0
       OR v_invalid_student_count <> 0
       OR v_invalid_instructor_count <> 0
       OR v_invalid_course_count <> 0
       OR v_invalid_enrollment_count <> 0
       OR v_active_duplicate_count <> 0
       OR v_status_1001 IS DISTINCT FROM '완료'
       OR v_amount_1001 IS DISTINCT FROM 100000::numeric
       OR v_status_1004 IS DISTINCT FROM '취소'
       OR v_amount_1004 IS DISTINCT FROM 150000::numeric
       OR v_status_1005 IS DISTINCT FROM '신청'
       OR v_amount_1005 IS DISTINCT FROM 120000::numeric
       OR v_total_recorded <> 590000
       OR v_non_cancelled_count <> 4
       OR v_non_cancelled_recorded <> 440000 THEN
        RAISE EXCEPTION
            '검증 실패: constraints=%, not_null=%, rows=%/%/%/%, join=%, relation=%/%/%, orphan=%/%/%, invalid=%/%/%/%, active_duplicate=%, 1001=%/%, 1004=%/%, 1005=%/%, total=%, non_cancelled=%/%',
            v_named_constraint_count,
            v_not_null_count,
            v_student_count,
            v_instructor_count,
            v_course_count,
            v_enrollment_count,
            v_service_join_count,
            v_student_101_enrollments,
            v_course_301_enrollments,
            v_instructor_201_courses,
            v_orphan_student_count,
            v_orphan_course_count,
            v_orphan_instructor_count,
            v_invalid_student_count,
            v_invalid_instructor_count,
            v_invalid_course_count,
            v_invalid_enrollment_count,
            v_active_duplicate_count,
            v_status_1001,
            v_amount_1001,
            v_status_1004,
            v_amount_1004,
            v_status_1005,
            v_amount_1005,
            v_total_recorded,
            v_non_cancelled_count,
            v_non_cancelled_recorded;
    END IF;

    RAISE NOTICE 'Chapter 07 course project validation passed';
END
$$;

-- 최종 서비스 조회
SELECT
    e.id AS enrollment_id,
    s.name AS student_name,
    c.title AS course_title,
    i.name AS instructor_name,
    e.status,
    e.recorded_amount,
    e.enrolled_at
FROM course_project.enrollments AS e
JOIN course_project.students AS s ON e.student_id = s.id
JOIN course_project.courses AS c ON e.course_id = c.id
JOIN course_project.instructors AS i ON c.instructor_id = i.id
ORDER BY e.id;

-- 관계 확인
SELECT * FROM course_project.enrollments WHERE student_id = 101 ORDER BY id;
SELECT * FROM course_project.enrollments WHERE course_id = 301 ORDER BY id;
SELECT * FROM course_project.courses WHERE instructor_id = 201 ORDER BY id;

-- 변경 상태와 금액 확인
SELECT id, status, recorded_amount
FROM course_project.enrollments
WHERE id IN (1001, 1004, 1005)
ORDER BY id;

-- 검산값
SELECT
    COUNT(*) AS total_enrollments,
    SUM(recorded_amount) AS total_recorded_amount,
    COUNT(*) FILTER (WHERE status <> '취소') AS non_cancelled_enrollments,
    SUM(recorded_amount) FILTER (WHERE status <> '취소') AS non_cancelled_recorded_amount
FROM course_project.enrollments;