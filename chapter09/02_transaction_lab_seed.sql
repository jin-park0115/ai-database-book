-- Chapter 09. transaction_lab 초기 좌석 데이터
-- 실행 전 01_transaction_lab_schema.sql을 먼저 실행합니다.
-- 이 파일은 Chapter 07의 course_project 데이터를 변경하지 않습니다.
-- 좌석 입력과 검증을 하나의 트랜잭션으로 처리합니다.

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

    IF to_regclass('transaction_lab.course_inventory') IS NULL
       OR to_regclass('transaction_lab.enrollments') IS NULL
       OR to_regclass('transaction_lab.payments') IS NULL
       OR to_regclass('transaction_lab.uq_transaction_enrollments_active') IS NULL THEN
        RAISE EXCEPTION
            '실행 중단: 01_transaction_lab_schema.sql을 먼저 실행하세요.';
    END IF;

    IF EXISTS (SELECT 1 FROM transaction_lab.course_inventory)
       OR EXISTS (SELECT 1 FROM transaction_lab.enrollments)
       OR EXISTS (SELECT 1 FROM transaction_lab.payments) THEN
        RAISE EXCEPTION
            '실행 중단: transaction_lab이 비어 있지 않습니다. 현재 상태를 확인하거나 초기화하세요.';
    END IF;

    IF (SELECT COUNT(*) FROM course_project.students) <> 3
       OR (SELECT COUNT(*) FROM course_project.courses) <> 3
       OR (SELECT COUNT(*) FROM course_project.enrollments) <> 5 THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07 기준 행 수를 확인하세요.';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM course_project.students
        WHERE id IN (101, 102, 103)
    ) <> 3 THEN
        RAISE EXCEPTION
            '실행 중단: 실습 학생 101~103을 확인하세요.';
    END IF;

    IF (
        SELECT COUNT(*)
        FROM course_project.courses
        WHERE (id, price) IN (
            (301, 100000::numeric),
            (302, 120000::numeric),
            (303, 150000::numeric)
        )
    ) <> 3 THEN
        RAISE EXCEPTION
            '실행 중단: 강의 301~303의 존재 여부와 가격을 확인하세요.';
    END IF;
END
$$;

INSERT INTO transaction_lab.course_inventory (
    course_id,
    capacity,
    remaining_seats
)
VALUES
    (301, 2, 2),
    (302, 1, 1),
    (303, 1, 1);

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM transaction_lab.course_inventory) <> 3
       OR (SELECT COUNT(*) FROM transaction_lab.enrollments) <> 0
       OR (SELECT COUNT(*) FROM transaction_lab.payments) <> 0 THEN
        RAISE EXCEPTION
            '초기 상태 검증 실패: inventory 3, enrollments 0, payments 0이어야 합니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM transaction_lab.course_inventory
        WHERE course_id = 301 AND capacity = 2 AND remaining_seats = 2
    ) OR NOT EXISTS (
        SELECT 1 FROM transaction_lab.course_inventory
        WHERE course_id = 302 AND capacity = 1 AND remaining_seats = 1
    ) OR NOT EXISTS (
        SELECT 1 FROM transaction_lab.course_inventory
        WHERE course_id = 303 AND capacity = 1 AND remaining_seats = 1
    ) THEN
        RAISE EXCEPTION
            '초기 상태 검증 실패: 강의 301~303의 capacity와 remaining_seats를 확인하세요.';
    END IF;
END
$$;

COMMIT;

-- 초기 상태 확인
SELECT
    ci.course_id,
    c.title,
    c.price,
    ci.capacity,
    ci.remaining_seats
FROM transaction_lab.course_inventory AS ci
JOIN course_project.courses AS c
    ON c.id = ci.course_id
ORDER BY ci.course_id;

SELECT COUNT(*) AS inventory_count
FROM transaction_lab.course_inventory;

SELECT COUNT(*) AS lab_enrollment_count
FROM transaction_lab.enrollments;

SELECT COUNT(*) AS payment_count
FROM transaction_lab.payments;

SELECT 'Chapter 09 transaction lab seed validation passed' AS validation_result;
