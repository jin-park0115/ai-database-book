-- Chapter 10. performance_lab 대량 데이터 생성
-- 실행 전 01_performance_lab_schema.sql을 먼저 실행합니다.
-- 검증 기준: PostgreSQL 16
-- 완료 기준: students 10003 / instructors 2 / courses 2003 / enrollments 100005

SELECT current_database();
SELECT current_schema();
SHOW search_path;
SHOW server_version;

BEGIN;

DO $$
DECLARE
    v_index_count bigint;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '데이터 생성 중단: 현재 데이터베이스는 %입니다.',
            current_database();
    END IF;

    IF current_setting('transaction_read_only')::boolean THEN
        RAISE EXCEPTION
            '데이터 생성 중단: 현재 연결이 읽기 전용입니다.';
    END IF;

    IF to_regclass('performance_lab.students') IS NULL
       OR to_regclass('performance_lab.instructors') IS NULL
       OR to_regclass('performance_lab.courses') IS NULL
       OR to_regclass('performance_lab.enrollments') IS NULL THEN
        RAISE EXCEPTION
            '데이터 생성 중단: performance_lab 테이블이 준비되지 않았습니다. 01 파일을 먼저 실행하세요.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'performance_lab'
          AND table_name = 'courses'
          AND column_name = 'price'
          AND data_type = 'numeric'
          AND numeric_precision = 12
          AND numeric_scale = 0
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'performance_lab'
          AND table_name = 'enrollments'
          AND column_name = 'recorded_amount'
          AND data_type = 'numeric'
          AND numeric_precision = 12
          AND numeric_scale = 0
    ) THEN
        RAISE EXCEPTION
            '데이터 생성 중단: price와 recorded_amount는 NUMERIC(12,0)이어야 합니다.';
    END IF;

    IF EXISTS (SELECT 1 FROM performance_lab.students)
       OR EXISTS (SELECT 1 FROM performance_lab.instructors)
       OR EXISTS (SELECT 1 FROM performance_lab.courses)
       OR EXISTS (SELECT 1 FROM performance_lab.enrollments) THEN
        RAISE EXCEPTION
            '데이터 생성 중단: performance_lab이 비어 있지 않습니다. 중복 실행하지 마세요.';
    END IF;

    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE schemaname = 'performance_lab';

    IF v_index_count <> 6
       OR to_regclass('performance_lab.idx_performance_courses_title') IS NOT NULL
       OR to_regclass('performance_lab.idx_performance_enrollments_student_id') IS NOT NULL
       OR to_regclass('performance_lab.idx_performance_enrollments_course_status') IS NOT NULL THEN
        RAISE EXCEPTION
            '데이터 생성 중단: 초기 인덱스 상태는 자동 인덱스 6개, 실험 후보 0개여야 합니다.';
    END IF;
END
$$;

-- 기본 학생 3명
INSERT INTO performance_lab.students (id, name, email, joined_at)
VALUES
    (101, '김민지', 'minji@example.com', DATE '2026-03-01'),
    (102, '이준호', 'junho@example.com', DATE '2026-03-03'),
    (103, '박서연', 'seoyeon@example.com', DATE '2026-03-05');

-- 기본 강사 2명
INSERT INTO performance_lab.instructors (id, name, email, specialty)
VALUES
    (201, '문길래', 'gilbert@example.com', 'Database'),
    (202, '홍길동', 'hong@example.com', 'Python');

-- 기본 강의 3개
INSERT INTO performance_lab.courses (
    id, instructor_id, title, description, level, price, opened_at
)
VALUES
    (301, 201, '데이터베이스 입문', '관계형 데이터베이스와 SQL 기초', 'basic', 100000, DATE '2026-04-01'),
    (302, 201, '정규화 실습', '좋은 테이블 설계와 정규화', 'basic', 120000, DATE '2026-04-05'),
    (303, 202, '파이썬 데이터 분석', 'Pandas 기반 데이터 분석 입문', 'basic', 150000, DATE '2026-04-10');

-- 기본 신청 5건
INSERT INTO performance_lab.enrollments (
    id, student_id, course_id, enrolled_at, status, recorded_amount
)
VALUES
    (1001, 101, 301, DATE '2026-04-02', '완료', 100000),
    (1002, 101, 302, DATE '2026-04-06', '신청', 120000),
    (1003, 102, 301, DATE '2026-04-03', '수강중', 100000),
    (1004, 103, 303, DATE '2026-04-11', '취소', 150000),
    (1005, 102, 302, DATE '2026-04-07', '신청', 120000);

-- 성능 학생 10000명: id 1001~11000
INSERT INTO performance_lab.students (id, name, email, joined_at)
SELECT
    1000 + gs,
    '성능학생' || LPAD((1000 + gs)::text, 5, '0'),
    'performance' || (1000 + gs) || '@example.com',
    DATE '2025-01-01' + (gs % 365)
FROM generate_series(1, 10000) AS gs;

-- 성능 강의 2000개: id 1001~3000
INSERT INTO performance_lab.courses (
    id, instructor_id, title, description, level, price, opened_at
)
SELECT
    1000 + gs,
    CASE WHEN gs % 2 = 0 THEN 201 ELSE 202 END,
    '성능 테스트 강의 ' || LPAD(gs::text, 5, '0'),
    '인덱스 실습을 위한 자동 생성 강의',
    CASE gs % 3
        WHEN 0 THEN 'advanced'
        WHEN 1 THEN 'basic'
        ELSE 'intermediate'
    END,
    50000 + ((gs % 10) * 10000),
    DATE '2025-01-01' + (gs % 365)
FROM generate_series(1, 2000) AS gs;

-- 성능 신청 100000건: id 10001~110000
-- 각 학생은 서로 다른 강의 10개를 가지며 각 성능 강의는 정확히 50건을 가집니다.
WITH generated_enrollments AS (
    SELECT
        10000 + gs AS enrollment_id,
        1001 + ((gs - 1) / 10) AS student_id,
        1001 + (
            (
                ((gs - 1) / 10)
                + (((gs - 1) % 10) * 200)
            ) % 2000
        ) AS course_id,
        DATE '2025-01-01' + (gs % 365) AS enrolled_at,
        CASE (((gs - 1) % 10) % 4)
            WHEN 0 THEN '신청'
            WHEN 1 THEN '수강중'
            WHEN 2 THEN '완료'
            ELSE '취소'
        END AS status
    FROM generate_series(1, 100000) AS gs
)
INSERT INTO performance_lab.enrollments (
    id, student_id, course_id, enrolled_at, status, recorded_amount
)
SELECT
    g.enrollment_id,
    g.student_id,
    g.course_id,
    g.enrolled_at,
    g.status,
    c.price
FROM generated_enrollments AS g
JOIN performance_lab.courses AS c
    ON c.id = g.course_id;

-- 명시적 ID 입력 뒤 다음 자동값을 기준값으로 조정합니다.
ALTER TABLE performance_lab.students
    ALTER COLUMN id RESTART WITH 11001;
ALTER TABLE performance_lab.instructors
    ALTER COLUMN id RESTART WITH 203;
ALTER TABLE performance_lab.courses
    ALTER COLUMN id RESTART WITH 3001;
ALTER TABLE performance_lab.enrollments
    ALTER COLUMN id RESTART WITH 110001;

-- 기준 계획과 사후 계획이 공통으로 사용할 통계를 한 번 수집합니다.
ANALYZE performance_lab.students;
ANALYZE performance_lab.instructors;
ANALYZE performance_lab.courses;
ANALYZE performance_lab.enrollments;

DO $$
DECLARE
    v_requested_count bigint;
    v_learning_count bigint;
    v_completed_count bigint;
    v_cancelled_count bigint;
    v_duplicate_active_pairs bigint;
    v_amount_mismatch bigint;
    v_bad_student_distribution bigint;
    v_bad_course_distribution bigint;
    v_index_count bigint;
BEGIN
    IF (SELECT COUNT(*) FROM performance_lab.students) <> 10003
       OR (SELECT COUNT(*) FROM performance_lab.instructors) <> 2
       OR (SELECT COUNT(*) FROM performance_lab.courses) <> 2003
       OR (SELECT COUNT(*) FROM performance_lab.enrollments) <> 100005 THEN
        RAISE EXCEPTION
            '데이터 생성 검증 실패: 기준 행 수 10003/2/2003/100005와 다릅니다.';
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE status = '신청'),
        COUNT(*) FILTER (WHERE status = '수강중'),
        COUNT(*) FILTER (WHERE status = '완료'),
        COUNT(*) FILTER (WHERE status = '취소')
    INTO v_requested_count, v_learning_count, v_completed_count, v_cancelled_count
    FROM performance_lab.enrollments;

    IF v_requested_count <> 30002
       OR v_learning_count <> 30001
       OR v_completed_count <> 20001
       OR v_cancelled_count <> 20001 THEN
        RAISE EXCEPTION
            '데이터 생성 검증 실패: 상태 분포는 30002/30001/20001/20001이어야 합니다.';
    END IF;

    IF (SELECT COUNT(*) FROM performance_lab.students
        WHERE id = 5000 AND email = 'performance5000@example.com') <> 1
       OR (SELECT COUNT(*) FROM performance_lab.courses
           WHERE id = 1500 AND title = '성능 테스트 강의 00500') <> 1
       OR (SELECT COUNT(*) FROM performance_lab.enrollments
           WHERE student_id = 5000) <> 10
       OR (SELECT COUNT(*) FROM performance_lab.enrollments
           WHERE course_id = 1500) <> 50
       OR (SELECT COUNT(*) FROM performance_lab.enrollments
           WHERE course_id = 1500 AND status = '수강중') <> 15
       OR (SELECT COUNT(*) FROM performance_lab.enrollments
           WHERE status = '수강중') <> 30001 THEN
        RAISE EXCEPTION
            '데이터 생성 검증 실패: 기준 조회 결과 1/1/10/50/15/30001과 다릅니다.';
    END IF;

    SELECT COUNT(*) INTO v_duplicate_active_pairs
    FROM (
        SELECT student_id, course_id
        FROM performance_lab.enrollments
        WHERE status IN ('신청', '수강중')
        GROUP BY student_id, course_id
        HAVING COUNT(*) > 1
    ) AS duplicated_active_pairs;

    SELECT COUNT(*) INTO v_amount_mismatch
    FROM performance_lab.enrollments AS e
    JOIN performance_lab.courses AS c
      ON c.id = e.course_id
    WHERE e.recorded_amount <> c.price;

    SELECT COUNT(*) INTO v_bad_student_distribution
    FROM (
        SELECT s.id
        FROM performance_lab.students AS s
        LEFT JOIN performance_lab.enrollments AS e
          ON e.student_id = s.id
        WHERE s.id BETWEEN 1001 AND 11000
        GROUP BY s.id
        HAVING COUNT(e.id) <> 10
    ) AS bad_students;

    SELECT COUNT(*) INTO v_bad_course_distribution
    FROM (
        SELECT c.id
        FROM performance_lab.courses AS c
        LEFT JOIN performance_lab.enrollments AS e
          ON e.course_id = c.id
        WHERE c.id BETWEEN 1001 AND 3000
        GROUP BY c.id
        HAVING COUNT(e.id) <> 50
    ) AS bad_courses;

    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE schemaname = 'performance_lab';

    IF v_duplicate_active_pairs <> 0
       OR v_amount_mismatch <> 0
       OR v_bad_student_distribution <> 0
       OR v_bad_course_distribution <> 0
       OR v_index_count <> 6
       OR to_regclass('performance_lab.idx_performance_courses_title') IS NOT NULL
       OR to_regclass('performance_lab.idx_performance_enrollments_student_id') IS NOT NULL
       OR to_regclass('performance_lab.idx_performance_enrollments_course_status') IS NOT NULL THEN
        RAISE EXCEPTION
            '데이터 생성 검증 실패: active_dup=%, amount_mismatch=%, bad_students=%, bad_courses=%, indexes=%',
            v_duplicate_active_pairs,
            v_amount_mismatch,
            v_bad_student_distribution,
            v_bad_course_distribution,
            v_index_count;
    END IF;

    RAISE NOTICE 'Chapter 10 performance lab seed validation passed';
END
$$;

COMMIT;

SELECT COUNT(*) AS student_count FROM performance_lab.students;
SELECT COUNT(*) AS instructor_count FROM performance_lab.instructors;
SELECT COUNT(*) AS course_count FROM performance_lab.courses;
SELECT COUNT(*) AS enrollment_count FROM performance_lab.enrollments;

SELECT status, COUNT(*) AS row_count
FROM performance_lab.enrollments
GROUP BY status
ORDER BY CASE status
    WHEN '신청' THEN 1
    WHEN '수강중' THEN 2
    WHEN '완료' THEN 3
    WHEN '취소' THEN 4
    ELSE 99
END;

SELECT course_id, status, COUNT(*) AS row_count
FROM performance_lab.enrollments
WHERE course_id = 1500
GROUP BY course_id, status
ORDER BY CASE status
    WHEN '신청' THEN 1
    WHEN '수강중' THEN 2
    WHEN '완료' THEN 3
    WHEN '취소' THEN 4
    ELSE 99
END;
