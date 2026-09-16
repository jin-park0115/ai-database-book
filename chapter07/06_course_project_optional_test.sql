-- Chapter 07. 06 선택 경계·무결성 테스트
-- 실행 전 01 → 02 → 03 → 04 파일을 순서대로 실행합니다.
-- 아래 SQL은 모두 주석 상태입니다. 하나의 테스트 구간만 실행합니다.

SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;

DO $$
DECLARE
    v_named_constraint_count bigint;
    v_not_null_count bigint;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION '선택 테스트 중단: ai_database_book에 연결하세요.';
    END IF;

    IF to_regclass('course_project.students') IS NULL
       OR to_regclass('course_project.instructors') IS NULL
       OR to_regclass('course_project.courses') IS NULL
       OR to_regclass('course_project.enrollments') IS NULL
       OR to_regclass('course_project.uq_course_enrollments_active') IS NULL THEN
        RAISE EXCEPTION '선택 테스트 중단: Chapter 07 프로젝트 객체가 모두 존재하지 않습니다.';
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
            '선택 테스트 중단: 구조 기준이 다릅니다. named_constraints=%, not_null_columns=%',
            v_named_constraint_count, v_not_null_count;
    END IF;

    IF (SELECT COUNT(*) FROM course_project.students) <> 3
       OR (SELECT COUNT(*) FROM course_project.instructors) <> 2
       OR (SELECT COUNT(*) FROM course_project.courses) <> 3
       OR (SELECT COUNT(*) FROM course_project.enrollments) <> 5 THEN
        RAISE EXCEPTION '선택 테스트 중단: Chapter 07 최종 기준 상태가 아닙니다.';
    END IF;
END
$$;

-- 선택 성공 A. description=NULL과 공백이 아닌 한 글자 학생 이름 허용
-- INSERT INTO course_project.students (id,name,email,joined_at)
-- VALUES (1803,'김','one-char@example.com','2026-03-20');
-- INSERT INTO course_project.courses (id,instructor_id,title,description,level,price,opened_at)
-- VALUES (1804,202,'설명 없는 강의',NULL,'basic',10000,'2026-05-01');
-- DELETE FROM course_project.courses WHERE id=1804;
-- DELETE FROM course_project.students WHERE id=1803;

-- 선택 성공 B. 완료 이력 뒤 동일 학생·강의 재신청 허용
-- 신청 1001은 완료 상태입니다.
-- INSERT INTO course_project.enrollments (id,student_id,course_id,enrolled_at,status,recorded_amount)
-- VALUES (1805,101,301,'2026-05-03','신청',100000);
-- DELETE FROM course_project.enrollments WHERE id=1805;

-- 선택 성공 C. 참조되지 않는 학생 삭제 허용
-- INSERT INTO course_project.students (id,name,email,joined_at)
-- VALUES (1806,'미신청 학생','unused-student@example.com','2026-03-20');
-- DELETE FROM course_project.students WHERE id=1806;

-- 선택 오류 1. 학생 이름 공백 → chk_course_students_name_not_blank
-- INSERT INTO course_project.students (id,name,email,joined_at)
-- VALUES (1901,'   ','blank-student@example.com','2026-03-20');

-- 선택 오류 2. 학생 이메일 공백 → chk_course_students_email_not_blank
-- INSERT INTO course_project.students (id,name,email,joined_at)
-- VALUES (1902,'공백 이메일 학생','   ','2026-03-20');

-- 선택 오류 3. 강사 이름 공백 → chk_course_instructors_name_not_blank
-- INSERT INTO course_project.instructors (id,name,email,specialty)
-- VALUES (1903,'   ','blank-instructor@example.com','Database');

-- 선택 오류 4. 강사 이메일 공백 → chk_course_instructors_email_not_blank
-- INSERT INTO course_project.instructors (id,name,email,specialty)
-- VALUES (1904,'공백 이메일 강사','   ','Database');

-- 선택 오류 5. 강사 전문 분야 공백 → chk_course_instructors_specialty_not_blank
-- INSERT INTO course_project.instructors (id,name,email,specialty)
-- VALUES (1905,'전문분야 없음','blank-specialty@example.com','   ');

-- 선택 오류 6. 강의 제목 공백 → chk_course_courses_title_not_blank
-- INSERT INTO course_project.courses (id,instructor_id,title,description,level,price,opened_at)
-- VALUES (1906,201,'   ',NULL,'basic',10000,'2026-05-01');

-- 오류 후 수동 트랜잭션이 실패 상태라면 다음 테스트 전에 실행합니다.
-- ROLLBACK;

DO $$
DECLARE
    v_total numeric;
    v_non_cancelled numeric;
BEGIN
    SELECT COALESCE(SUM(recorded_amount),0),
           COALESCE(SUM(recorded_amount) FILTER (WHERE status <> '취소'),0)
    INTO v_total, v_non_cancelled
    FROM course_project.enrollments;

    IF (SELECT COUNT(*) FROM course_project.students) <> 3
       OR (SELECT COUNT(*) FROM course_project.instructors) <> 2
       OR (SELECT COUNT(*) FROM course_project.courses) <> 3
       OR (SELECT COUNT(*) FROM course_project.enrollments) <> 5
       OR v_total <> 590000
       OR v_non_cancelled <> 440000 THEN
        RAISE EXCEPTION '선택 테스트 후 기준 상태 불일치: total=%, non_cancelled=%', v_total, v_non_cancelled;
    END IF;

    RAISE NOTICE 'Chapter 07 optional integrity test baseline preserved';
END
$$;