-- Chapter 09 선택 실습. 오류 상태와 SAVEPOINT 복구
-- 실행 전 01→06 주 실습을 완료합니다.
-- 오류를 의도적으로 발생시키는 문장은 기본 주석 상태입니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

SELECT
    e.id,
    e.student_id,
    e.course_id,
    e.status,
    e.recorded_amount,
    ci.remaining_seats
FROM transaction_lab.enrollments AS e
JOIN transaction_lab.course_inventory AS ci
    ON ci.course_id = e.course_id
WHERE e.id = 9001;

-- 1. 트랜잭션과 SAVEPOINT 시작
-- BEGIN;
-- SAVEPOINT before_duplicate_enrollment;

-- 2. SAVEPOINT 이후 임시 좌석 차감
-- UPDATE transaction_lab.course_inventory
-- SET remaining_seats = remaining_seats - 1
-- WHERE course_id = 301
--   AND remaining_seats > 0
-- RETURNING *;

-- 3. 중복 활성 신청 오류 유발
-- uq_transaction_enrollments_active 오류가 발생해야 정상입니다.
-- INSERT INTO transaction_lab.enrollments (
--     id, student_id, course_id,
--     enrolled_at, status, recorded_amount
-- )
-- VALUES (
--     9003, 101, 301,
--     CURRENT_TIMESTAMP, '수강중', 100000
-- );

-- 4. 오류가 발생한 뒤 SAVEPOINT까지 복구
-- ROLLBACK TO SAVEPOINT before_duplicate_enrollment;

-- SELECT *
-- FROM transaction_lab.course_inventory
-- WHERE course_id = 301;

-- SELECT *
-- FROM transaction_lab.enrollments
-- WHERE id = 9003;

-- 기대 결과:
-- course 301 remaining_seats = 1
-- enrollment 9003 = 0행

-- 5. SAVEPOINT 정리와 전체 트랜잭션 종료
-- RELEASE SAVEPOINT before_duplicate_enrollment;
-- ROLLBACK;

-- SAVEPOINT가 없다면 오류 상태의 전체 트랜잭션을 ROLLBACK으로 종료합니다.
