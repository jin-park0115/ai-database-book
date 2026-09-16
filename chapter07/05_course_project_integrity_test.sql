-- Chapter 07. 05 핵심 경계·무결성 테스트
-- 실행 전 01 → 02 → 03 → 04 파일을 순서대로 실행합니다.
-- 아래 변경 SQL은 모두 주석 상태입니다. 한 번에 하나의 테스트만 실행합니다.
-- 실패해야 하는 테스트는 오류가 발생해야 정상입니다.

SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;

DO $$
DECLARE
    v_named_constraint_count bigint;
    v_not_null_count bigint;
    v_rows text;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION '테스트 중단: ai_database_book에 연결하세요.';
    END IF;

    IF to_regclass('course_project.students') IS NULL
       OR to_regclass('course_project.instructors') IS NULL
       OR to_regclass('course_project.courses') IS NULL
       OR to_regclass('course_project.enrollments') IS NULL
       OR to_regclass('course_project.uq_course_enrollments_active') IS NULL THEN
        RAISE EXCEPTION '테스트 중단: Chapter 07 프로젝트 객체가 모두 존재하지 않습니다.';
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
            '테스트 중단: 구조 기준이 다릅니다. named_constraints=%, not_null_columns=%',
            v_named_constraint_count, v_not_null_count;
    END IF;

    SELECT
        (SELECT COUNT(*) FROM course_project.students) || '/' ||
        (SELECT COUNT(*) FROM course_project.instructors) || '/' ||
        (SELECT COUNT(*) FROM course_project.courses) || '/' ||
        (SELECT COUNT(*) FROM course_project.enrollments)
    INTO v_rows;

    IF v_rows <> '3/2/3/5' THEN
        RAISE EXCEPTION '테스트 중단: 최종 기준 상태가 아닙니다. rows=%', v_rows;
    END IF;
END
$$;

-- 경계 테스트 A. 무료 강의 price=0, description=NULL, 무료 신청 recorded_amount=0 허용
-- 기대: 성공 후 임시 행 삭제
-- INSERT INTO course_project.courses (id,instructor_id,title,description,level,price,opened_at)
-- VALUES (1801,202,'무료 체험 강의',NULL,'basic',0,'2026-05-01');
-- INSERT INTO course_project.enrollments (id,student_id,course_id,enrolled_at,status,recorded_amount)
-- VALUES (1802,103,1801,'2026-05-02','신청',0);
-- DELETE FROM course_project.enrollments WHERE id=1802;
-- DELETE FROM course_project.courses WHERE id=1801;

-- 오류 0. 학생 이름 NULL → NOT NULL
-- INSERT INTO course_project.students (id,name,email,joined_at)
-- VALUES (1900,NULL,'null-name@example.com',DATE '2026-03-20');

-- 오류 1. 학생 이메일 중복 → uq_course_students_email
-- INSERT INTO course_project.students (id,name,email,joined_at)
-- VALUES (1901,'중복 학생','minji@example.com','2026-03-20');

-- 오류 2. 강사 이메일 중복 → uq_course_instructors_email
-- INSERT INTO course_project.instructors (id,name,email,specialty)
-- VALUES (1902,'중복 강사','gilbert@example.com','Database');

-- 오류 3. 존재하지 않는 강사 참조 → fk_course_courses_instructor
-- INSERT INTO course_project.courses (id,instructor_id,title,description,level,price,opened_at)
-- VALUES (1903,999,'없는 강사 강의',NULL,'basic',10000,'2026-05-01');

-- 오류 4. 허용되지 않은 난이도 → chk_course_courses_level
-- INSERT INTO course_project.courses (id,instructor_id,title,description,level,price,opened_at)
-- VALUES (1904,201,'잘못된 난이도',NULL,'expert',10000,'2026-05-01');

-- 오류 5. 음수 강의 가격 → chk_course_courses_price
-- INSERT INTO course_project.courses (id,instructor_id,title,description,level,price,opened_at)
-- VALUES (1905,201,'잘못된 가격',NULL,'basic',-1,'2026-05-01');

-- 오류 6. 허용되지 않은 신청 상태 → chk_course_enrollments_status
-- INSERT INTO course_project.enrollments (id,student_id,course_id,enrolled_at,status,recorded_amount)
-- VALUES (1906,101,303,'2026-05-02','대기',150000);

-- 오류 7. 음수 신청 기록 금액 → chk_course_enrollments_recorded_amount
-- INSERT INTO course_project.enrollments (id,student_id,course_id,enrolled_at,status,recorded_amount)
-- VALUES (1907,101,303,'2026-05-02','신청',-1);

-- 오류 8. 존재하지 않는 학생 참조 → fk_course_enrollments_student
-- INSERT INTO course_project.enrollments (id,student_id,course_id,enrolled_at,status,recorded_amount)
-- VALUES (1908,999,303,'2026-05-02','신청',150000);

-- 오류 9. 존재하지 않는 강의 참조 → fk_course_enrollments_course
-- INSERT INTO course_project.enrollments (id,student_id,course_id,enrolled_at,status,recorded_amount)
-- VALUES (1909,101,999,'2026-05-02','신청',150000);

-- 오류 10. 같은 학생·강의의 두 번째 활성 신청 → uq_course_enrollments_active
-- 학생 101·강의 302에는 활성 신청 1002가 존재합니다.
-- INSERT INTO course_project.enrollments (id,student_id,course_id,enrolled_at,status,recorded_amount)
-- VALUES (1910,101,302,'2026-05-03','수강중',120000);

-- 오류 11. 참조 중인 학생 삭제 → fk_course_enrollments_student / RESTRICT
-- DELETE FROM course_project.students WHERE id=101;

-- 오류 12. 참조 중인 강사 삭제 → fk_course_courses_instructor / RESTRICT
-- DELETE FROM course_project.instructors WHERE id=201;

-- 오류 후 수동 트랜잭션이 실패 상태라면 다음 테스트 전에 실행합니다.
-- ROLLBACK;

DO $$
DECLARE
    v_student_count bigint;
    v_instructor_count bigint;
    v_course_count bigint;
    v_enrollment_count bigint;
    v_total numeric;
    v_non_cancelled numeric;
    v_active_duplicate_count bigint;
    v_status_1001 text;
    v_status_1004 text;
    v_status_1005 text;
BEGIN
    SELECT COUNT(*) INTO v_student_count FROM course_project.students;
    SELECT COUNT(*) INTO v_instructor_count FROM course_project.instructors;
    SELECT COUNT(*) INTO v_course_count FROM course_project.courses;
    SELECT COUNT(*), COALESCE(SUM(recorded_amount),0),
           COALESCE(SUM(recorded_amount) FILTER (WHERE status <> '취소'),0)
    INTO v_enrollment_count, v_total, v_non_cancelled
    FROM course_project.enrollments;

    SELECT status INTO v_status_1001 FROM course_project.enrollments WHERE id=1001;
    SELECT status INTO v_status_1004 FROM course_project.enrollments WHERE id=1004;
    SELECT status INTO v_status_1005 FROM course_project.enrollments WHERE id=1005;

    SELECT COUNT(*) INTO v_active_duplicate_count
    FROM (
        SELECT student_id, course_id
        FROM course_project.enrollments
        WHERE status IN ('신청','수강중')
        GROUP BY student_id, course_id
        HAVING COUNT(*) > 1
    ) d;

    IF v_student_count <> 3 OR v_instructor_count <> 2 OR v_course_count <> 3
       OR v_enrollment_count <> 5 OR v_total <> 590000 OR v_non_cancelled <> 440000
       OR v_active_duplicate_count <> 0
       OR v_status_1001 IS DISTINCT FROM '완료'
       OR v_status_1004 IS DISTINCT FROM '취소'
       OR v_status_1005 IS DISTINCT FROM '신청' THEN
        RAISE EXCEPTION '핵심 테스트 후 기준 상태 불일치: rows=%/%/%/%, total=%, non_cancelled=%, active_duplicate=%, status=%/%/%',
            v_student_count,v_instructor_count,v_course_count,v_enrollment_count,
            v_total,v_non_cancelled,v_active_duplicate_count,
            v_status_1001,v_status_1004,v_status_1005;
    END IF;

    RAISE NOTICE 'Chapter 07 core integrity test baseline preserved';
END
$$;