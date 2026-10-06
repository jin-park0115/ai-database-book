-- Chapter 12. PostgreSQL JSONB 문서형 데이터 실습
-- 실행 전 01, 02 파일을 실행합니다.
-- 기준 데이터 수정 예제는 document_version 조건을 사용하고 ROLLBACK으로 원상 복구합니다.

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

    IF to_regclass('nosql_lab.course_documents') IS NULL
       OR (SELECT COUNT(*) FROM nosql_lab.course_documents) <> 3 THEN
        RAISE EXCEPTION
            '실행 중단: nosql_lab.course_documents 기준 3행이 준비되지 않았습니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM nosql_lab.course_documents
        WHERE source_course_id = 301
          AND course_code = 'COURSE-301'
          AND title = '데이터베이스 입문'
          AND level = 'basic'
          AND metadata #>> '{options,certificate}' = 'true'
          AND document_version = 1
    ) THEN
        RAISE EXCEPTION
            '실행 중단: COURSE-301 문서의 낙관적 잠금 기준값이 다릅니다.';
    END IF;
END
$$;

-- ============================================================
-- 1. 안정된 일반 컬럼과 JSONB 필드 함께 조회
-- level은 일반 컬럼이며, online은 가변 options 문서에서 읽습니다.
-- ============================================================
SELECT
    source_course_id,
    course_code,
    title,
    level,
    metadata #>> '{options,online}' AS online,
    document_version
FROM nosql_lab.course_documents
ORDER BY source_course_id;

-- 기대 결과:
-- 301 / COURSE-301 / 데이터베이스 입문 / basic / true / 1
-- 302 / COURSE-302 / 정규화 실습 / basic / true / 1
-- 303 / COURSE-303 / 파이썬 데이터 분석 / basic / false / 1

-- ============================================================
-- 2. 최상위 키 존재 여부
-- ============================================================
SELECT
    source_course_id,
    course_code,
    title
FROM nosql_lab.course_documents
WHERE metadata ? 'instructor_snapshot'
ORDER BY source_course_id;

-- ============================================================
-- 3. JSONB 포함 조건
-- ============================================================
SELECT
    source_course_id,
    course_code,
    title
FROM nosql_lab.course_documents
WHERE metadata @> '{"tags": ["PostgreSQL"]}'::jsonb;

-- 기대 결과: COURSE-301 한 행

-- ============================================================
-- 4. 특정 JSON 경로 조건
-- ============================================================
SELECT
    source_course_id,
    course_code,
    title
FROM nosql_lab.course_documents
WHERE metadata #>> '{options,online}' = 'true'
ORDER BY source_course_id;

-- 기대 결과: COURSE-301, COURSE-302

-- ============================================================
-- 5. 문서 구조와 원본 스냅샷 검증
-- ============================================================
SELECT
    d.source_course_id,
    d.course_code,
    jsonb_typeof(d.metadata) = 'object' AS metadata_is_object,
    jsonb_typeof(d.metadata -> 'tags') = 'array' AS tags_is_array,
    jsonb_typeof(d.metadata -> 'options') = 'object' AS options_is_object,
    jsonb_typeof(d.metadata #> '{options,online}') = 'boolean'
        AS online_is_boolean,
    jsonb_typeof(d.metadata -> 'instructor_snapshot') = 'object'
        AS instructor_snapshot_is_object,
    (d.metadata #>> '{instructor_snapshot,source_instructor_id}')::INTEGER
        = c.instructor_id AS instructor_id_matches,
    d.document_version >= 1 AS version_is_valid
FROM nosql_lab.course_documents AS d
JOIN course_project.courses AS c
    ON c.id = d.source_course_id
ORDER BY d.source_course_id;

-- 모든 boolean 결과가 true여야 합니다.

-- ============================================================
-- 6. 원본과 문서 핵심 컬럼 대조
-- 기대 결과: 0행
-- ============================================================
SELECT
    d.source_course_id,
    d.course_code,
    d.title AS document_title,
    c.title AS source_title,
    d.level AS document_level,
    c.level AS source_level
FROM nosql_lab.course_documents AS d
LEFT JOIN course_project.courses AS c
    ON c.id = d.source_course_id
WHERE c.id IS NULL
   OR d.title <> c.title
   OR d.level <> c.level;

-- ============================================================
-- 7. document_version을 이용한 낙관적 잠금과 ROLLBACK
-- 읽은 버전이 1일 때만 수정합니다.
-- options 경로가 객체가 아니거나 다른 사용자가 먼저 수정했다면 0행이 되고 예외를 발생시킵니다.
-- ============================================================
SELECT
    course_code,
    metadata #>> '{options,certificate}' AS certificate,
    document_version
FROM nosql_lab.course_documents
WHERE course_code = 'COURSE-301';

BEGIN;

DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE nosql_lab.course_documents
    SET
        metadata = jsonb_set(
            metadata,
            '{options,certificate}',
            'false'::jsonb
        ),
        document_version = document_version + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE course_code = 'COURSE-301'
      AND document_version = 1
      AND jsonb_typeof(metadata -> 'options') = 'object';

    GET DIAGNOSTICS updated_count = ROW_COUNT;

    IF updated_count <> 1 THEN
        RAISE EXCEPTION
            '문서 수정 중단: 예상 버전 또는 options 경로가 다릅니다. 갱신 행 수=%',
            updated_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM nosql_lab.course_documents
        WHERE course_code = 'COURSE-301'
          AND metadata #>> '{options,certificate}' = 'false'
          AND document_version = 2
          AND updated_at >= created_at
    ) THEN
        RAISE EXCEPTION
            '문서 수정 검증 실패: certificate=false, document_version=2 상태가 아닙니다.';
    END IF;

    RAISE NOTICE 'Chapter 12 optimistic document update passed inside transaction';
END
$$;

SELECT
    course_code,
    metadata #>> '{options,certificate}' AS certificate,
    document_version,
    updated_at
FROM nosql_lab.course_documents
WHERE course_code = 'COURSE-301';

-- 기대: certificate=false, document_version=2
-- 기준 데이터를 유지하기 위해 전체 변경을 취소합니다.
ROLLBACK;

SELECT
    course_code,
    metadata #>> '{options,certificate}' AS certificate,
    document_version
FROM nosql_lab.course_documents
WHERE course_code = 'COURSE-301';

-- 기대: certificate=true, document_version=1

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM nosql_lab.course_documents
        WHERE course_code = 'COURSE-301'
          AND metadata #>> '{options,certificate}' = 'true'
          AND document_version = 1
    ) THEN
        RAISE EXCEPTION
            'Chapter 12 문서 실습 실패: ROLLBACK 후 기준 상태가 복구되지 않았습니다.';
    END IF;

    IF (SELECT COUNT(*) FROM nosql_lab.course_documents) <> 3 THEN
        RAISE EXCEPTION
            'Chapter 12 문서 실습 실패: 기준 행 수가 변경되었습니다.';
    END IF;

    RAISE NOTICE 'Chapter 12 document JSONB practice passed';
END
$$;

-- ============================================================
-- 8. 검증 책임 경계
-- ============================================================
-- DB 제약조건:
-- - 안정된 course_code·title·level
-- - metadata 객체 여부
-- - document_version >= 1
-- - updated_at >= created_at
--
-- 애플리케이션·검증 SQL:
-- - tags 배열
-- - options.online boolean
-- - instructor_snapshot 구조와 원본 대조
-- - 문서 버전 충돌 재시도
-- - 문서 스키마 마이그레이션
