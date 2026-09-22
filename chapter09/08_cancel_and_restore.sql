-- Chapter 09 선택 실습. 취소와 좌석 복구를 같은 트랜잭션으로 처리하기
-- 실행 전 01→06 주 실습을 완료합니다.
-- 기본 동작은 마지막에 ROLLBACK하여 Chapter 09 최종 기준 상태를 보존합니다.
-- 환불 상태와 환불 금액은 이번 장의 범위가 아니므로 기존 payment 행은 유지합니다.

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

    IF NOT EXISTS (
        SELECT 1
        FROM transaction_lab.enrollments
        WHERE id = 9001
          AND status = '수강중'
          AND course_id = 301
          AND recorded_amount = 100000
    ) THEN
        RAISE EXCEPTION
            '실행 중단: 신청 9001은 강의 301의 수강중·100000 상태여야 합니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM transaction_lab.payments
        WHERE id = 9901
          AND enrollment_id = 9001
          AND amount = 100000
    ) THEN
        RAISE EXCEPTION
            '실행 중단: 결제 9901의 기준 상태를 확인하세요.';
    END IF;

    IF (SELECT remaining_seats
        FROM transaction_lab.course_inventory
        WHERE course_id = 301) IS DISTINCT FROM 1 THEN
        RAISE EXCEPTION
            '실행 중단: 강의 301의 시작 잔여 좌석은 1이어야 합니다.';
    END IF;
END
$$;

-- 취소와 좌석 복구가 같은 행 집합을 다루도록 좌석 행을 잠급니다.
SELECT *
FROM transaction_lab.course_inventory
WHERE course_id = 301
FOR UPDATE;

-- 상태 변경에 성공한 신청 행만 좌석 복구의 입력으로 사용합니다.
-- 같은 취소가 재시도되면 cancelled가 0행이므로 좌석도 다시 증가하지 않습니다.
WITH cancelled AS (
    UPDATE transaction_lab.enrollments
    SET status = '취소'
    WHERE id = 9001
      AND status = '수강중'
    RETURNING id, student_id, course_id, status
),
restored AS (
    UPDATE transaction_lab.course_inventory AS ci
    SET remaining_seats = ci.remaining_seats + 1
    FROM cancelled AS e
    WHERE ci.course_id = e.course_id
      AND ci.remaining_seats < ci.capacity
    RETURNING ci.course_id, ci.capacity, ci.remaining_seats
)
SELECT
    e.id AS enrollment_id,
    e.status,
    r.course_id,
    r.capacity,
    r.remaining_seats
FROM cancelled AS e
JOIN restored AS r
    ON r.course_id = e.course_id;

-- 동일 취소를 한 번 더 시도해도 상태 변경과 좌석 복구는 모두 0행입니다.
WITH cancelled AS (
    UPDATE transaction_lab.enrollments
    SET status = '취소'
    WHERE id = 9001
      AND status = '수강중'
    RETURNING course_id
),
restored AS (
    UPDATE transaction_lab.course_inventory AS ci
    SET remaining_seats = ci.remaining_seats + 1
    FROM cancelled AS e
    WHERE ci.course_id = e.course_id
      AND ci.remaining_seats < ci.capacity
    RETURNING ci.course_id
)
SELECT
    (SELECT COUNT(*) FROM cancelled) AS repeated_cancel_count,
    (SELECT COUNT(*) FROM restored) AS repeated_restore_count;

-- payment 9901은 신청 당시 결제 기록으로 남아 있습니다.
-- 실제 환불 업무에는 refund 상태·금액·승인 ID와 별도 보상 처리가 필요합니다.
SELECT
    e.id AS enrollment_id,
    e.status,
    p.id AS payment_id,
    p.amount,
    ci.capacity,
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
          AND e.status = '취소'
          AND e.recorded_amount = 100000
          AND p.id = 9901
          AND p.amount = 100000
          AND ci.remaining_seats = 2
    ) THEN
        RAISE EXCEPTION
            '취소 검증 실패: 상태 변경·결제 기록·좌석 복구 결과가 예상과 다릅니다.';
    END IF;
END
$$;

-- 선택 실습은 주 실습의 최종 상태를 보존하기 위해 기본적으로 취소합니다.
ROLLBACK;

-- 원래 상태 확인: 신청 9001 수강중, course 301 remaining 1
SELECT
    e.id,
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
          AND p.amount = 100000
          AND ci.remaining_seats = 1
    ) THEN
        RAISE EXCEPTION
            '취소 ROLLBACK 검증 실패: 신청 9001·결제 9901·강의 301 좌석이 원래 상태로 복구되지 않았습니다.';
    END IF;

    IF (SELECT COUNT(*) FROM transaction_lab.enrollments) <> 2
       OR (SELECT COUNT(*) FROM transaction_lab.payments) <> 2 THEN
        RAISE EXCEPTION
            '취소 ROLLBACK 검증 실패: 주 실습의 2/2 최종 행 수가 유지되지 않았습니다.';
    END IF;
END
$$;

SELECT 'Chapter 09 cancel rollback validation passed' AS validation_result;
