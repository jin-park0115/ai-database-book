-- Chapter 09. 최종 트랜잭션 정합성 검증
-- 실행 전 01→02→03→04→05 파일을 순서대로 실행합니다.
-- 이 파일은 데이터를 변경하지 않습니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- 1. Chapter 07·08 프로젝트 데이터 보호 확인
SELECT
    COUNT(*) AS project_enrollment_count,
    SUM(recorded_amount) AS project_recorded_amount,
    COUNT(*) FILTER (WHERE status IN ('신청', '수강중')) AS active_enrollment_count,
    SUM(recorded_amount) FILTER (WHERE status IN ('신청', '수강중')) AS active_recorded_amount,
    COUNT(*) FILTER (WHERE status <> '취소') AS non_cancelled_count,
    SUM(recorded_amount) FILTER (WHERE status <> '취소') AS non_cancelled_recorded_amount
FROM course_project.enrollments;

-- 2. lab 최종 행 수
SELECT COUNT(*) AS lab_enrollment_count
FROM transaction_lab.enrollments;

SELECT COUNT(*) AS payment_count
FROM transaction_lab.payments;

-- 3. 최종 좌석 상태
SELECT
    ci.course_id,
    c.title,
    ci.capacity,
    ci.remaining_seats,
    CASE ci.course_id
        WHEN 301 THEN ci.remaining_seats = 1
        WHEN 302 THEN ci.remaining_seats = 0
        WHEN 303 THEN ci.remaining_seats = 1
        ELSE FALSE
    END AS expected_remaining_ok
FROM transaction_lab.course_inventory AS ci
JOIN course_project.courses AS c
    ON c.id = ci.course_id
ORDER BY ci.course_id;

-- 4. 신청·결제 연결 확인
SELECT
    e.id AS enrollment_id,
    e.student_id,
    s.name AS student_name,
    e.course_id,
    c.title AS course_title,
    e.status,
    e.recorded_amount,
    p.id AS payment_id,
    p.amount,
    e.recorded_amount = p.amount AS amount_matches,
    ci.remaining_seats
FROM transaction_lab.enrollments AS e
JOIN course_project.students AS s
    ON s.id = e.student_id
JOIN course_project.courses AS c
    ON c.id = e.course_id
JOIN transaction_lab.payments AS p
    ON p.enrollment_id = e.id
JOIN transaction_lab.course_inventory AS ci
    ON ci.course_id = e.course_id
ORDER BY e.id;

-- 5. 위반 데이터 조회: 모두 0행
SELECT *
FROM transaction_lab.course_inventory
WHERE remaining_seats < 0
   OR remaining_seats > capacity;

SELECT
    e.id AS enrollment_id,
    e.recorded_amount,
    p.amount AS payment_amount
FROM transaction_lab.enrollments AS e
LEFT JOIN transaction_lab.payments AS p
    ON p.enrollment_id = e.id
WHERE e.status = '수강중'
  AND (
      p.id IS NULL
      OR e.recorded_amount <> p.amount
  );

SELECT p.*
FROM transaction_lab.payments AS p
LEFT JOIN transaction_lab.enrollments AS e
    ON e.id = p.enrollment_id
WHERE e.id IS NULL;

SELECT student_id, course_id, COUNT(*) AS active_count
FROM transaction_lab.enrollments
WHERE status = '수강중'
GROUP BY student_id, course_id
HAVING COUNT(*) > 1;

-- 6. 좌석 사용량과 활성 신청 비교
SELECT
    ci.course_id,
    c.title,
    ci.capacity,
    ci.remaining_seats,
    COUNT(e.id) FILTER (WHERE e.status = '수강중') AS active_enrollment_count,
    ci.capacity - ci.remaining_seats AS used_seats,
    COUNT(e.id) FILTER (WHERE e.status = '수강중')
        = ci.capacity - ci.remaining_seats AS is_consistent
FROM transaction_lab.course_inventory AS ci
JOIN course_project.courses AS c
    ON c.id = ci.course_id
LEFT JOIN transaction_lab.enrollments AS e
    ON e.course_id = ci.course_id
GROUP BY
    ci.course_id,
    c.title,
    ci.capacity,
    ci.remaining_seats
ORDER BY ci.course_id;

-- 7. 좌석 부족 테스트 잔여 행: 모두 0행
SELECT *
FROM transaction_lab.enrollments
WHERE id = 9003;

SELECT *
FROM transaction_lab.payments
WHERE id = 9903;

-- 8. 전체 상태 자동 판정
DO $$
DECLARE
    v_requested_count INTEGER;
    v_learning_count INTEGER;
    v_completed_count INTEGER;
    v_cancelled_count INTEGER;
    v_total_amount NUMERIC;
    v_active_count INTEGER;
    v_active_amount NUMERIC;
    v_non_cancelled_count INTEGER;
    v_non_cancelled_amount NUMERIC;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '최종 검증 실패: 현재 데이터베이스가 ai_database_book이 아닙니다.';
    END IF;

    IF (SELECT COUNT(*) FROM course_project.students) <> 3
       OR (SELECT COUNT(*) FROM course_project.instructors) <> 2
       OR (SELECT COUNT(*) FROM course_project.courses) <> 3
       OR (SELECT COUNT(*) FROM course_project.enrollments) <> 5 THEN
        RAISE EXCEPTION
            '최종 검증 실패: Chapter 07 기준 행 수 3/2/3/5가 유지되지 않았습니다.';
    END IF;

    IF (
        SELECT COUNT(*)
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
          )
    ) <> 15 OR (
        SELECT COUNT(*)
        FROM information_schema.columns
        WHERE table_schema = 'course_project'
          AND table_name IN ('students', 'instructors', 'courses', 'enrollments')
          AND is_nullable = 'NO'
    ) <> 20 THEN
        RAISE EXCEPTION
            '최종 검증 실패: Chapter 07 구조 기준 15개 명명 제약조건 / 20개 NOT NULL 열이 유지되지 않았습니다.';
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE status = '신청'),
        COUNT(*) FILTER (WHERE status = '수강중'),
        COUNT(*) FILTER (WHERE status = '완료'),
        COUNT(*) FILTER (WHERE status = '취소'),
        SUM(recorded_amount),
        COUNT(*) FILTER (WHERE status IN ('신청', '수강중')),
        SUM(recorded_amount) FILTER (WHERE status IN ('신청', '수강중')),
        COUNT(*) FILTER (WHERE status <> '취소'),
        SUM(recorded_amount) FILTER (WHERE status <> '취소')
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
            '최종 검증 실패: Chapter 07·08 상태·금액 기준값이 유지되지 않았습니다.';
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
            '최종 검증 실패: Chapter 07 핵심 신청 1001·1004·1005가 변경되었습니다.';
    END IF;

    IF (SELECT COUNT(*) FROM transaction_lab.course_inventory) <> 3
       OR (SELECT COUNT(*) FROM transaction_lab.enrollments) <> 2
       OR (SELECT COUNT(*) FROM transaction_lab.payments) <> 2 THEN
        RAISE EXCEPTION
            '최종 검증 실패: inventory/enrollment/payment는 3/2/2행이어야 합니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM transaction_lab.enrollments AS e
        JOIN transaction_lab.payments AS p ON p.enrollment_id = e.id
        WHERE e.id = 9001
          AND e.student_id = 101
          AND e.course_id = 301
          AND e.status = '수강중'
          AND e.recorded_amount = 100000
          AND p.id = 9901
          AND p.amount = 100000
    ) OR NOT EXISTS (
        SELECT 1
        FROM transaction_lab.enrollments AS e
        JOIN transaction_lab.payments AS p ON p.enrollment_id = e.id
        WHERE e.id = 9002
          AND e.student_id = 103
          AND e.course_id = 302
          AND e.status = '수강중'
          AND e.recorded_amount = 120000
          AND p.id = 9902
          AND p.amount = 120000
    ) THEN
        RAISE EXCEPTION
            '최종 검증 실패: 확정된 신청·결제 9001/9901 또는 9002/9902가 기대 상태와 다릅니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM transaction_lab.course_inventory
        WHERE course_id = 301 AND capacity = 2 AND remaining_seats = 1
    ) OR NOT EXISTS (
        SELECT 1
        FROM transaction_lab.course_inventory
        WHERE course_id = 302 AND capacity = 1 AND remaining_seats = 0
    ) OR NOT EXISTS (
        SELECT 1
        FROM transaction_lab.course_inventory
        WHERE course_id = 303 AND capacity = 1 AND remaining_seats = 1
    ) THEN
        RAISE EXCEPTION
            '최종 검증 실패: 강의별 좌석 상태가 기대값과 다릅니다.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM transaction_lab.course_inventory
        WHERE remaining_seats < 0
           OR remaining_seats > capacity
    ) THEN
        RAISE EXCEPTION
            '최종 검증 실패: 좌석 범위 위반이 있습니다.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM transaction_lab.enrollments AS e
        LEFT JOIN transaction_lab.payments AS p
            ON p.enrollment_id = e.id
        WHERE e.status = '수강중'
          AND (p.id IS NULL OR e.recorded_amount <> p.amount)
    ) THEN
        RAISE EXCEPTION
            '최종 검증 실패: 수강중 신청의 결제 누락 또는 금액 불일치가 있습니다.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM transaction_lab.payments AS p
        LEFT JOIN transaction_lab.enrollments AS e
            ON e.id = p.enrollment_id
        WHERE e.id IS NULL
    ) THEN
        RAISE EXCEPTION
            '최종 검증 실패: 고아 payment가 있습니다.';
    END IF;

    IF EXISTS (
        SELECT student_id, course_id
        FROM transaction_lab.enrollments
        WHERE status = '수강중'
        GROUP BY student_id, course_id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION
            '최종 검증 실패: 중복 활성 신청이 있습니다.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM transaction_lab.course_inventory AS ci
        LEFT JOIN transaction_lab.enrollments AS e
            ON e.course_id = ci.course_id
        GROUP BY ci.course_id, ci.capacity, ci.remaining_seats
        HAVING COUNT(e.id) FILTER (WHERE e.status = '수강중')
               <> ci.capacity - ci.remaining_seats
    ) THEN
        RAISE EXCEPTION
            '최종 검증 실패: 활성 신청 수와 사용 좌석 수가 다릅니다.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM transaction_lab.enrollments WHERE id = 9003
    ) OR EXISTS (
        SELECT 1 FROM transaction_lab.payments WHERE id = 9903
    ) THEN
        RAISE EXCEPTION
            '최종 검증 실패: 좌석 부족 테스트 행이 남아 있습니다.';
    END IF;
END
$$;

SELECT 'Chapter 09 main transaction validation passed' AS validation_result;
