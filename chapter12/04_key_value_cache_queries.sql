-- Chapter 12. Key-Value 캐시 개념 시뮬레이션
-- 실행 전 01, 02 파일을 실행합니다.
-- 이 테이블은 실제 Key-Value DB의 TTL·복제·메모리 정책을 구현하지 않습니다.
-- 실제 제품에서 expiration(TTL 만료)과 eviction(메모리 정책에 따른 제거)은 서로 다른 동작일 수 있습니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

DO $$
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '실행 중단: 현재 데이터베이스는 %입니다.',
            current_database();
    END IF;

    IF to_regclass('nosql_lab.key_value_cache_examples') IS NULL
       OR (SELECT COUNT(*) FROM nosql_lab.key_value_cache_examples) <> 4 THEN
        RAISE EXCEPTION
            '실행 중단: key_value_cache_examples 기준 4행이 준비되지 않았습니다.';
    END IF;
END
$$;

-- ============================================================
-- 1. 전체 키와 Seed 기준·현재 기준 상태
-- expired_at IS NULL은 만료 정책이 없는 키입니다.
-- ============================================================
SELECT
    cache_key,
    source_name,
    created_at,
    expired_at,
    CASE
        WHEN expired_at IS NULL THEN 'no_expiry'
        WHEN expired_at > created_at THEN 'valid_at_seed'
        ELSE 'expired_at_seed'
    END AS seed_status,
    CASE
        WHEN expired_at IS NULL THEN 'no_expiry'
        WHEN expired_at > CURRENT_TIMESTAMP THEN 'currently_valid'
        ELSE 'currently_expired'
    END AS current_status
FROM nosql_lab.key_value_cache_examples
ORDER BY cache_key;

-- ============================================================
-- 2. 재현 가능한 Seed 기준 집계
-- 기대 결과: 4 / 3 / 1
-- ============================================================
SELECT
    COUNT(*) AS total_cache_rows,
    COUNT(*) FILTER (
        WHERE expired_at IS NULL OR expired_at > created_at
    ) AS valid_at_seed_rows,
    COUNT(*) FILTER (
        WHERE expired_at IS NOT NULL AND expired_at <= created_at
    ) AS expired_at_seed_rows
FROM nosql_lab.key_value_cache_examples;

-- ============================================================
-- 3. 실제 현재 시각 기준 집계
-- 실행 시점이 늦어지면 결과가 달라질 수 있으므로 고정 정답으로 사용하지 않습니다.
-- ============================================================
SELECT
    COUNT(*) AS total_cache_rows,
    COUNT(*) FILTER (
        WHERE expired_at IS NULL OR expired_at > CURRENT_TIMESTAMP
    ) AS currently_valid_rows,
    COUNT(*) FILTER (
        WHERE expired_at IS NOT NULL AND expired_at <= CURRENT_TIMESTAMP
    ) AS currently_expired_rows,
    COUNT(*) FILTER (
        WHERE expired_at IS NULL
    ) AS no_expiry_rows
FROM nosql_lab.key_value_cache_examples;

-- ============================================================
-- 4. 정확한 키 조회: Seed 기준으로 유효했던 세션
-- ============================================================
SELECT
    cache_key,
    cache_value,
    created_at,
    expired_at
FROM nosql_lab.key_value_cache_examples
WHERE cache_key = 'student:101:session'
  AND (expired_at IS NULL OR expired_at > created_at);

-- 기대 결과: 1행

-- 실제 현재 시각에 유효한지는 별도 조건으로 확인합니다.
SELECT
    cache_key,
    cache_value,
    expired_at
FROM nosql_lab.key_value_cache_examples
WHERE cache_key = 'student:101:session'
  AND (expired_at IS NULL OR expired_at > CURRENT_TIMESTAMP);

-- ============================================================
-- 5. Seed 시점에 이미 만료된 실제 학생 세션
-- 기대 결과: 0행
-- ============================================================
SELECT
    cache_key,
    cache_value,
    expired_at
FROM nosql_lab.key_value_cache_examples
WHERE cache_key = 'student:103:session'
  AND (expired_at IS NULL OR expired_at > created_at);

-- ============================================================
-- 6. 만료 정책이 없는 기능 플래그
-- ============================================================
SELECT
    cache_key,
    cache_value,
    expired_at
FROM nosql_lab.key_value_cache_examples
WHERE cache_key = 'feature:recommendation:v1';

-- 기대: expired_at IS NULL

-- ============================================================
-- 7. 캐시 미스 시뮬레이션
-- ============================================================
WITH requested_key(cache_key) AS (
    VALUES ('course:popular:v2:top3')
)
SELECT
    r.cache_key AS requested_key,
    c.cache_value,
    CASE
        WHEN c.cache_key IS NULL THEN 'cache_miss'
        WHEN c.expired_at IS NOT NULL
             AND c.expired_at <= CURRENT_TIMESTAMP THEN 'expired'
        ELSE 'cache_hit'
    END AS cache_status
FROM requested_key AS r
LEFT JOIN nosql_lab.key_value_cache_examples AS c
    ON c.cache_key = r.cache_key;

-- cache_miss 이후 실제 서비스에서는 다음 흐름을 검토합니다.
-- 1. Source of Truth에서 데이터를 읽습니다.
-- 2. 중복 재생성을 줄이기 위한 잠금·요청 병합 정책을 확인합니다.
-- 3. TTL과 버전이 포함된 키로 캐시를 저장합니다.
-- 4. 사용자에게 결과를 반환합니다.

-- ============================================================
-- 8. 인기 강의 파생 캐시와 Chapter 07 원본 ID
-- ============================================================
SELECT
    cache_key,
    source_name,
    cache_value -> 'course_ids' AS course_ids,
    expired_at
FROM nosql_lab.key_value_cache_examples
WHERE cache_key LIKE 'course:popular:%';

-- 기대 course_ids: [301, 302, 303]

-- ============================================================
-- 9. 만료 행 정리 문장은 자동 실행하지 않습니다.
-- ============================================================
-- expired_at은 자동 TTL 삭제 기능이 아닙니다.
-- DELETE FROM nosql_lab.key_value_cache_examples
-- WHERE expired_at IS NOT NULL
--   AND expired_at <= CURRENT_TIMESTAMP;
