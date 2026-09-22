-- Chapter 09. 두 세션 Lock 대기 실습
-- 목적: SELECT ... FOR UPDATE로 같은 좌석 행을 잠글 때의 대기를 관찰합니다.
-- 주의: 아래 트랜잭션 SQL은 실수로 대기 상태를 만들지 않도록 모두 주석 처리되어 있습니다.
-- 서로 다른 연결 세션의 DBeaver SQL Editor 두 개를 열고 필요한 블록만 선택 실행합니다.
-- 이 실습은 PostgreSQL 기본 격리 수준인 READ COMMITTED를 기준으로 설명합니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;
SHOW transaction_isolation;

-- ============================================================
-- 사전 조건
-- course 303 remaining_seats가 1인지 확인합니다.
-- ============================================================
SELECT *
FROM transaction_lab.course_inventory
WHERE course_id = 303;

-- 역할 구분
-- SELECT ... FOR UPDATE
--   → 대상 행을 잠그고 현재 세션에서 최신 상태를 관찰합니다.
-- UPDATE ... WHERE remaining_seats > 0
--   → 좌석이 실제로 남아 있을 때만 변경합니다.
-- RETURNING 또는 영향 행 수
--   → 좌석 확보 성공 여부를 확인합니다.
-- 단일 조건부 UPDATE ... RETURNING 자체도 수정 대상 행의 잠금을 획득합니다.
-- FOR UPDATE는 잠근 상태를 먼저 읽고 여러 후속 판단을 이어갈 때 특히 유용합니다.

-- ============================================================
-- 세션 A
-- 1. 아래 BEGIN과 SELECT를 세션 A에서 실행합니다.
-- 2. COMMIT하지 않은 상태로 세션 B를 실행합니다.
-- ============================================================
-- BEGIN;
--
-- SELECT *
-- FROM transaction_lab.course_inventory
-- WHERE course_id = 303
-- FOR UPDATE;
--
-- -- 잠금을 확인하는 동안 트랜잭션을 오래 방치하지 않습니다.

-- ============================================================
-- 세션 B
-- 세션 A가 잠금을 유지한 상태에서 아래를 실행하면 대기할 수 있습니다.
-- lock_timeout은 실습 중 무기한 대기를 피하기 위한 선택 설정입니다.
-- ============================================================
-- BEGIN;
--
-- SET LOCAL lock_timeout = '5s';
--
-- SELECT *
-- FROM transaction_lab.course_inventory
-- WHERE course_id = 303
-- FOR UPDATE;
--
-- -- lock timeout 오류가 발생했다면 현재 트랜잭션이 오류 상태일 수 있으므로
-- -- ROLLBACK;으로 종료한 뒤 다시 시작합니다.

-- ============================================================
-- 세션 A 종료
-- 변경 없이 잠금만 관찰했다면 ROLLBACK으로 종료합니다.
-- ============================================================
-- ROLLBACK;

-- ============================================================
-- 세션 B 재개 후 종료
-- READ COMMITTED에서는 A가 종료된 뒤 B가 잠금을 얻고 최신 값을 볼 수 있습니다.
-- REPEATABLE READ 또는 SERIALIZABLE에서는 동시 변경 오류가 발생할 수 있습니다.
-- ============================================================
-- SELECT *
-- FROM transaction_lab.course_inventory
-- WHERE course_id = 303;
--
-- ROLLBACK;

-- ============================================================
-- 선택 확장: 세션 A가 좌석을 차감하는 경우
-- ============================================================
-- -- 세션 A
-- BEGIN;
-- SELECT *
-- FROM transaction_lab.course_inventory
-- WHERE course_id = 303
-- FOR UPDATE;
--
-- UPDATE transaction_lab.course_inventory
-- SET remaining_seats = remaining_seats - 1
-- WHERE course_id = 303
--   AND remaining_seats > 0
-- RETURNING *;
--
-- COMMIT;
--
-- -- 세션 B는 A의 COMMIT 후 최신 remaining_seats를 확인해야 합니다.
-- -- 0이면 후속 신청을 실행하지 않습니다.

-- 실습 후 course 303을 원래 상태로 되돌려야 한다면
-- 전체 transaction_lab을 reset하고 01~06 순서를 다시 실행하는 것이 가장 명확합니다.

-- Deadlock을 의도적으로 유발하는 SQL은 이 파일에 포함하지 않습니다.
-- Deadlock은 서로 다른 행을 반대 순서로 잠그는 순환 대기이며,
-- 단순히 한 잠금의 해제를 기다리는 상황과 다릅니다.
