-- Chapter 12. JSONB 질의 형태별 인덱스 후보
-- 실행 전 01~05 파일을 실행합니다.
-- 표본이 3행뿐이므로 성능 향상 증명이 아니라 인덱스 구조와 대상 질의를 확인합니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- ============================================================
-- 0. 실행 전 상태 확인
-- CREATE INDEX IF NOT EXISTS는 기존 정의가 같은지 보장하지 않으므로 사용하지 않습니다.
-- ============================================================
DO $$
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '실행 중단: 현재 데이터베이스는 %입니다.',
            current_database();
    END IF;

    IF current_setting('transaction_read_only')::BOOLEAN THEN
        RAISE EXCEPTION
            '실행 중단: 읽기 전용 연결에서는 인덱스를 만들 수 없습니다.';
    END IF;

    IF to_regclass('nosql_lab.course_documents') IS NULL
       OR (SELECT COUNT(*) FROM nosql_lab.course_documents) <> 3 THEN
        RAISE EXCEPTION
            '실행 중단: course_documents 기준 3행이 준비되지 않았습니다.';
    END IF;

    IF to_regclass('nosql_lab.idx_nosql_course_documents_metadata_gin') IS NOT NULL
       OR to_regclass('nosql_lab.idx_nosql_course_documents_online') IS NOT NULL THEN
        RAISE EXCEPTION
            '실행 중단: 실험 인덱스가 이미 존재합니다. 정의를 확인하거나 reset 후 다시 실행하세요.';
    END IF;
END
$$;

-- 두 인덱스는 하나의 실험 단위입니다.
-- 두 번째 생성 또는 정의 검증이 실패하면 첫 번째 생성도 함께 취소합니다.
BEGIN;

-- ============================================================
-- 1. JSONB 전체 포함 검색 후보
-- 기본 jsonb_ops GIN은 @>, ?, @?, @@ 등 다양한 연산을 검토할 수 있습니다.
-- jsonb_path_ops는 포함·JSON path 중심으로 더 작을 수 있지만 ? 키 존재 연산은 지원하지 않습니다.
-- ============================================================
CREATE INDEX idx_nosql_course_documents_metadata_gin
ON nosql_lab.course_documents
USING GIN (metadata);

-- ============================================================
-- 2. 자주 조회하는 특정 경로의 표현식 B-tree 후보
-- level은 안정된 일반 컬럼으로 이동했으므로 가변 options.online 경로를 사용합니다.
-- ============================================================
CREATE INDEX idx_nosql_course_documents_online
ON nosql_lab.course_documents ((metadata #>> '{options,online}'));

-- ============================================================
-- 3. COMMIT 전 인덱스 정의 자동 판정
-- ============================================================
DO $$
DECLARE
    v_gin_method TEXT;
    v_gin_definition TEXT;
    v_online_method TEXT;
    v_online_expression TEXT;
    v_bad_state_count BIGINT;
BEGIN
    SELECT
        am.amname,
        pg_get_indexdef(idx.oid)
    INTO
        v_gin_method,
        v_gin_definition
    FROM pg_index AS i
    JOIN pg_class AS idx ON idx.oid = i.indexrelid
    JOIN pg_class AS tbl ON tbl.oid = i.indrelid
    JOIN pg_namespace AS n ON n.oid = tbl.relnamespace
    JOIN pg_am AS am ON am.oid = idx.relam
    WHERE n.nspname = 'nosql_lab'
      AND idx.relname = 'idx_nosql_course_documents_metadata_gin';

    SELECT
        am.amname,
        pg_get_expr(i.indexprs, i.indrelid)
    INTO
        v_online_method,
        v_online_expression
    FROM pg_index AS i
    JOIN pg_class AS idx ON idx.oid = i.indexrelid
    JOIN pg_class AS tbl ON tbl.oid = i.indrelid
    JOIN pg_namespace AS n ON n.oid = tbl.relnamespace
    JOIN pg_am AS am ON am.oid = idx.relam
    WHERE n.nspname = 'nosql_lab'
      AND idx.relname = 'idx_nosql_course_documents_online';

    SELECT COUNT(*)
    INTO v_bad_state_count
    FROM pg_index AS i
    JOIN pg_class AS idx ON idx.oid = i.indexrelid
    JOIN pg_namespace AS n ON n.oid = idx.relnamespace
    WHERE n.nspname = 'nosql_lab'
      AND idx.relname IN (
          'idx_nosql_course_documents_metadata_gin',
          'idx_nosql_course_documents_online'
      )
      AND (NOT i.indisvalid OR NOT i.indisready);

    IF v_gin_method IS DISTINCT FROM 'gin'
       OR lower(COALESCE(v_gin_definition, '')) NOT LIKE '%using gin%metadata%'
       OR v_online_method IS DISTINCT FROM 'btree'
       OR COALESCE(v_online_expression, '') NOT LIKE '%#>>%options%online%'
       OR v_bad_state_count <> 0 THEN
        RAISE EXCEPTION
            'Chapter 12 인덱스 정의 검증 실패: gin_method=% online_method=% bad_state=%',
            v_gin_method, v_online_method, v_bad_state_count;
    END IF;

    RAISE NOTICE 'Chapter 12 JSONB index candidate validation passed';
END
$$;

COMMIT;

-- ============================================================
-- 4. 생성된 정의 확인
-- ============================================================
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'nosql_lab'
  AND indexname IN (
      'idx_nosql_course_documents_metadata_gin',
      'idx_nosql_course_documents_online'
  )
ORDER BY indexname;

-- ============================================================
-- 5. 인덱스 방식과 표현식 확인
-- ============================================================
SELECT
    idx.relname AS index_name,
    am.amname AS access_method,
    i.indisvalid,
    i.indisready,
    pg_get_expr(i.indexprs, i.indrelid) AS expression,
    pg_get_indexdef(idx.oid) AS index_definition
FROM pg_index AS i
JOIN pg_class AS idx
    ON idx.oid = i.indexrelid
JOIN pg_class AS tbl
    ON tbl.oid = i.indrelid
JOIN pg_namespace AS n
    ON n.oid = tbl.relnamespace
JOIN pg_am AS am
    ON am.oid = idx.relam
WHERE n.nspname = 'nosql_lab'
  AND tbl.relname = 'course_documents'
  AND idx.relname IN (
      'idx_nosql_course_documents_metadata_gin',
      'idx_nosql_course_documents_online'
  )
ORDER BY idx.relname;

-- ============================================================
-- 6. 포함 검색 실행 계획
-- ============================================================
EXPLAIN
SELECT source_course_id, course_code, title
FROM nosql_lab.course_documents
WHERE metadata @> '{"tags": ["PostgreSQL"]}'::jsonb;

-- ============================================================
-- 7. 특정 경로 텍스트 조건 실행 계획
-- ============================================================
EXPLAIN
SELECT source_course_id, course_code, title
FROM nosql_lab.course_documents
WHERE metadata #>> '{options,online}' = 'true';

-- 표본이 3행뿐이므로 인덱스가 있어도 Seq Scan이 합리적일 수 있습니다.
-- 인덱스 적용 여부는 데이터 분포·선택도·쓰기 비용과 실제 실행 계획으로 결정합니다.
