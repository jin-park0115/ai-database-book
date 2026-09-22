-- Chapter 09. 성공 COMMIT 예제
-- 학생 101이 강의 301을 신청합니다.
-- 실행 전 01, 02 파일을 실행합니다.

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
        WHERE course_id = 301) IS DISTINCT FROM 2 THEN
        RAISE EXCEPTION
            '실행 중단: 강의 301의 시작 잔여 좌석은 2여야 합니다.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM transaction_lab.enrollments
        WHERE id = 9001
           OR (student_id = 101 AND course_id = 301 AND status = '수강중')
    ) THEN
        RAISE EXCEPTION
            '실행 중단: 신청 9001 또는 동일 활성 신청이 이미 존재합니다.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM transaction_lab.payments
        WHERE id = 9901
    ) THEN
        RAISE EXCEPTION
            '실행 중단: 결제 9901이 이미 존재합니다.';
    END IF;
END
$$;

SELECT
    ci.course_id,
    c.title,
    c.price,
    ci.remaining_seats
FROM transaction_lab.course_inventory AS ci
JOIN course_project.courses AS c
    ON c.id = ci.course_id
WHERE ci.course_id = 301
FOR UPDATE OF ci;

WITH seat AS (
    UPDATE transaction_lab.course_inventory AS ci
    SET remaining_seats = ci.remaining_seats - 1
    FROM course_project.courses AS c
    WHERE ci.course_id = c.id
      AND ci.course_id = 301
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
        9001,
        101,
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
    9901,
    id,
    recorded_amount,
    CURRENT_TIMESTAMP
FROM new_enrollment
RETURNING id, enrollment_id, amount;

SELECT
    e.id AS enrollment_id,
    e.student_id,
    e.course_id,
    e.status,
    e.recorded_amount,
    p.id AS payment_id,
    p.amount,
    ci.remaining_seats
FROM transaction_lab.enrollments AS e
JOIN transaction_lab.payments AS p
    ON p.enrollment_id = e.id
JOIN transaction_lab.course_inventory AS ci
    ON ci.course_id = e.course_id
WHERE e.id = 9001;

DO $$
BEGIN
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
          AND p.amount = e.recorded_amount
          AND ci.remaining_seats = 1
    ) THEN
        RAISE EXCEPTION
            'COMMIT 중단: 신청·결제·좌석 결과가 기대 상태와 다릅니다.';
    END IF;
END
$$;

COMMIT;

SELECT
    e.id AS enrollment_id,
    e.student_id,
    e.course_id,
    p.id AS payment_id,
    p.amount,
    ci.remaining_seats
FROM transaction_lab.enrollments AS e
JOIN transaction_lab.payments AS p
    ON p.enrollment_id = e.id
JOIN transaction_lab.course_inventory AS ci
    ON ci.course_id = e.course_id
WHERE e.id = 9001;

SELECT 'Chapter 09 first commit validation passed' AS validation_result;
