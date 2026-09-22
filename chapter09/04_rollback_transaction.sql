-- Chapter 09. ROLLBACK 예제
-- 학생 102가 강의 302를 신청하는 임시 변경을 만든 뒤 전체 취소합니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

BEGIN;

DO $$
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '실행 중단: 현재 데이터베이스는 %입니다.',
            current_database();
    END IF;

    IF (SELECT remaining_seats
        FROM transaction_lab.course_inventory
        WHERE course_id = 302) IS DISTINCT FROM 1 THEN
        RAISE EXCEPTION
            '실행 중단: 강의 302의 시작 잔여 좌석은 1이어야 합니다.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM transaction_lab.enrollments
        WHERE id = 9002
           OR (student_id = 102 AND course_id = 302 AND status = '수강중')
    ) OR EXISTS (
        SELECT 1
        FROM transaction_lab.payments
        WHERE id = 9902
    ) THEN
        RAISE EXCEPTION
            '실행 중단: 신청 9002 또는 결제 9902가 이미 존재합니다.';
    END IF;
END
$$;

SELECT *
FROM transaction_lab.course_inventory
WHERE course_id = 302
FOR UPDATE;

WITH seat AS (
    UPDATE transaction_lab.course_inventory AS ci
    SET remaining_seats = ci.remaining_seats - 1
    FROM course_project.courses AS c
    WHERE ci.course_id = c.id
      AND ci.course_id = 302
      AND ci.remaining_seats > 0
    RETURNING ci.course_id, c.price
),
new_enrollment AS (
    INSERT INTO transaction_lab.enrollments (
        id,
        student_id,
        course_id,
        enrolled_at,
        status,
        recorded_amount
    )
    SELECT
        9002,
        102,
        course_id,
        CURRENT_TIMESTAMP,
        '수강중',
        price
    FROM seat
    RETURNING id, course_id, recorded_amount
)
INSERT INTO transaction_lab.payments (
    id,
    enrollment_id,
    amount,
    paid_at
)
SELECT
    9902,
    id,
    recorded_amount,
    CURRENT_TIMESTAMP
FROM new_enrollment
RETURNING id, enrollment_id, amount;

SELECT
    e.id AS enrollment_id,
    e.student_id,
    e.course_id,
    e.recorded_amount,
    p.id AS payment_id,
    p.amount,
    ci.remaining_seats
FROM transaction_lab.enrollments AS e
JOIN transaction_lab.payments AS p
    ON p.enrollment_id = e.id
JOIN transaction_lab.course_inventory AS ci
    ON ci.course_id = e.course_id
WHERE e.id = 9002;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM transaction_lab.enrollments AS e
        JOIN transaction_lab.payments AS p
            ON p.enrollment_id = e.id
        JOIN transaction_lab.course_inventory AS ci
            ON ci.course_id = e.course_id
        WHERE e.id = 9002
          AND e.student_id = 102
          AND e.course_id = 302
          AND e.status = '수강중'
          AND p.id = 9902
          AND e.recorded_amount = 120000
          AND p.amount = 120000
          AND ci.remaining_seats = 0
    ) THEN
        RAISE EXCEPTION
            '임시 상태 검증 실패: ROLLBACK 실습 결과가 예상과 다릅니다.';
    END IF;
END
$$;

ROLLBACK;

SELECT *
FROM transaction_lab.course_inventory
WHERE course_id = 302;

SELECT *
FROM transaction_lab.enrollments
WHERE id = 9002;

SELECT *
FROM transaction_lab.payments
WHERE id = 9902;

DO $$
BEGIN
    IF (SELECT remaining_seats
        FROM transaction_lab.course_inventory
        WHERE course_id = 302) IS DISTINCT FROM 1 THEN
        RAISE EXCEPTION
            'ROLLBACK 검증 실패: 강의 302의 잔여 좌석이 1로 복구되지 않았습니다.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM transaction_lab.enrollments WHERE id = 9002
    ) OR EXISTS (
        SELECT 1 FROM transaction_lab.payments WHERE id = 9902
    ) THEN
        RAISE EXCEPTION
            'ROLLBACK 검증 실패: 임시 신청 9002 또는 결제 9902가 남아 있습니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM transaction_lab.enrollments AS e
        JOIN transaction_lab.payments AS p
            ON p.enrollment_id = e.id
        JOIN transaction_lab.course_inventory AS ci
            ON ci.course_id = e.course_id
        WHERE e.id = 9001
          AND e.student_id = 101
          AND e.course_id = 301
          AND e.status = '수강중'
          AND e.recorded_amount = 100000
          AND p.id = 9901
          AND p.amount = 100000
          AND ci.remaining_seats = 1
    ) THEN
        RAISE EXCEPTION
            'ROLLBACK 검증 실패: 이전 COMMIT 결과 9001·9901 또는 강의 301 좌석이 손상되었습니다.';
    END IF;
END
$$;

SELECT 'Chapter 09 rollback validation passed' AS validation_result;
