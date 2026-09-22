-- Chapter 09. 두 번째 COMMIT과 좌석 부족 처리
-- 실행 전 01→02→03→04 파일을 실행합니다.
-- 04에서 명시적 ID 9002·9902 행을 ROLLBACK했으므로 같은 숫자를 다시 사용합니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- ============================================================
-- 1. 학생 103, 강의 302 정상 신청
-- ============================================================
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
           OR (student_id = 103 AND course_id = 302 AND status = '수강중')
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
        103,
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
          AND e.student_id = 103
          AND e.course_id = 302
          AND e.status = '수강중'
          AND e.recorded_amount = 120000
          AND p.id = 9902
          AND p.amount = 120000
          AND ci.remaining_seats = 0
    ) THEN
        RAISE EXCEPTION
            'COMMIT 중단: 두 번째 신청·결제·좌석 결과가 기대 상태와 다릅니다.';
    END IF;
END
$$;

COMMIT;

-- ============================================================
-- 2. 좌석이 0인 강의 302에 추가 신청 시도
-- seat CTE가 0행이면 신청과 결제도 0행입니다.
-- ============================================================
BEGIN;

DO $$
BEGIN
    IF (SELECT remaining_seats
        FROM transaction_lab.course_inventory
        WHERE course_id = 302) IS DISTINCT FROM 0 THEN
        RAISE EXCEPTION
            '실행 중단: 좌석 부족 실습 전 강의 302 잔여 좌석은 0이어야 합니다.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM transaction_lab.enrollments WHERE id = 9003
    ) OR EXISTS (
        SELECT 1 FROM transaction_lab.payments WHERE id = 9903
    ) THEN
        RAISE EXCEPTION
            '실행 중단: 9003 또는 9903 행이 이미 존재합니다.';
    END IF;
END
$$;

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
        9003,
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
    9903,
    id,
    recorded_amount,
    CURRENT_TIMESTAMP
FROM new_enrollment
RETURNING id, enrollment_id, amount;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM transaction_lab.enrollments WHERE id = 9003
    ) OR EXISTS (
        SELECT 1 FROM transaction_lab.payments WHERE id = 9903
    ) OR (SELECT remaining_seats
          FROM transaction_lab.course_inventory
          WHERE course_id = 302) IS DISTINCT FROM 0 THEN
        RAISE EXCEPTION
            '좌석 부족 처리 실패: 신청·결제가 생성되지 않고 좌석이 0이어야 합니다.';
    END IF;
END
$$;

ROLLBACK;

-- 명시적 ID 입력은 IDENTITY 다음 값을 자동으로 이동시키지 않으므로
-- 두 시퀀스 조정을 하나의 트랜잭션으로 묶습니다.
BEGIN;

ALTER TABLE transaction_lab.enrollments
    ALTER COLUMN id RESTART WITH 9003;

ALTER TABLE transaction_lab.payments
    ALTER COLUMN id RESTART WITH 9903;

COMMIT;

SELECT *
FROM transaction_lab.course_inventory
WHERE course_id = 302;

SELECT id, student_id, course_id, status, recorded_amount
FROM transaction_lab.enrollments
WHERE id IN (9001, 9002, 9003)
ORDER BY id;

SELECT *
FROM transaction_lab.payments
WHERE id IN (9901, 9902, 9903)
ORDER BY id;

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM transaction_lab.enrollments) <> 2
       OR (SELECT COUNT(*) FROM transaction_lab.payments) <> 2 THEN
        RAISE EXCEPTION
            '좌석 부족 최종 검증 실패: lab enrollment와 payment는 각각 2행이어야 합니다.';
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
            '좌석 부족 최종 검증 실패: 확정된 신청·결제 9001/9901 또는 9002/9902가 다릅니다.';
    END IF;

    IF EXISTS (SELECT 1 FROM transaction_lab.enrollments WHERE id = 9003)
       OR EXISTS (SELECT 1 FROM transaction_lab.payments WHERE id = 9903) THEN
        RAISE EXCEPTION
            '좌석 부족 최종 검증 실패: 9003 또는 9903이 생성되었습니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM transaction_lab.course_inventory
        WHERE course_id = 301 AND capacity = 2 AND remaining_seats = 1
    ) OR NOT EXISTS (
        SELECT 1 FROM transaction_lab.course_inventory
        WHERE course_id = 302 AND capacity = 1 AND remaining_seats = 0
    ) OR NOT EXISTS (
        SELECT 1 FROM transaction_lab.course_inventory
        WHERE course_id = 303 AND capacity = 1 AND remaining_seats = 1
    ) THEN
        RAISE EXCEPTION
            '좌석 부족 최종 검증 실패: 강의별 좌석 상태가 다릅니다.';
    END IF;
END
$$;

SELECT 'Chapter 09 sold-out validation passed' AS validation_result;
