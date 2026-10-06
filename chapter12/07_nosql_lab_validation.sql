-- Chapter 12. nosql_lab 최종 자동 검증
-- 실행 전 01→06 파일을 순서대로 실행합니다.
-- 데이터를 변경하지 않습니다.

SELECT current_user AS current_user_name;
SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- ============================================================
-- 0. 실행 위치와 객체 존재 차단
-- ============================================================
DO $$
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '검증 중단: 현재 데이터베이스는 %입니다.',
            current_database();
    END IF;

    IF to_regclass('course_project.students') IS NULL
       OR to_regclass('course_project.instructors') IS NULL
       OR to_regclass('course_project.courses') IS NULL
       OR to_regclass('course_project.enrollments') IS NULL
       OR to_regclass('nosql_lab.course_documents') IS NULL
       OR to_regclass('nosql_lab.key_value_cache_examples') IS NULL
       OR to_regclass('nosql_lab.storage_choice_cases') IS NULL THEN
        RAISE EXCEPTION
            '검증 중단: Chapter 07·08 또는 Chapter 12 핵심 객체가 없습니다.';
    END IF;
END
$$;

-- ============================================================
-- 1. 사람이 읽는 기준 결과
-- ============================================================
SELECT
    (SELECT COUNT(*) FROM course_project.students) AS source_students,
    (SELECT COUNT(*) FROM course_project.instructors) AS source_instructors,
    (SELECT COUNT(*) FROM course_project.courses) AS source_courses,
    (SELECT COUNT(*) FROM course_project.enrollments) AS source_enrollments,
    (SELECT COUNT(*) FROM nosql_lab.course_documents) AS course_documents,
    (SELECT COUNT(*) FROM nosql_lab.key_value_cache_examples) AS cache_examples,
    (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases) AS storage_choices;

SELECT
    COUNT(*) AS source_enrollment_count,
    COALESCE(SUM(recorded_amount), 0) AS total_recorded_amount,
    COUNT(*) FILTER (WHERE status IN ('신청', '수강중')) AS active_count,
    COALESCE(SUM(recorded_amount) FILTER (WHERE status IN ('신청', '수강중')), 0)
        AS active_recorded_amount,
    COUNT(*) FILTER (WHERE status <> '취소') AS non_cancelled_count,
    COALESCE(SUM(recorded_amount) FILTER (WHERE status <> '취소'), 0)
        AS non_cancelled_recorded_amount
FROM course_project.enrollments;

SELECT
    COUNT(*) AS total_cache_rows,
    COUNT(*) FILTER (
        WHERE expired_at IS NULL OR expired_at > created_at
    ) AS valid_at_seed_rows,
    COUNT(*) FILTER (
        WHERE expired_at IS NOT NULL AND expired_at <= created_at
    ) AS expired_at_seed_rows,
    COUNT(*) FILTER (
        WHERE expired_at IS NULL OR expired_at > CURRENT_TIMESTAMP
    ) AS currently_valid_rows,
    COUNT(*) FILTER (WHERE expired_at IS NULL) AS no_expiry_rows
FROM nosql_lab.key_value_cache_examples;

SELECT
    source_course_id,
    course_code,
    title,
    level,
    metadata #>> '{instructor_snapshot,source_instructor_id}'
        AS snapshot_instructor_id,
    metadata #>> '{options,online}' AS online,
    document_version
FROM nosql_lab.course_documents
ORDER BY source_course_id;

SELECT
    case_name,
    system_role,
    candidate_storage,
    decision_status
FROM nosql_lab.storage_choice_cases
ORDER BY id;

SELECT
    idx.relname AS index_name,
    am.amname AS access_method,
    i.indisvalid,
    i.indisready,
    pg_get_expr(i.indexprs, i.indrelid) AS expression,
    pg_get_indexdef(idx.oid) AS index_definition
FROM pg_index AS i
JOIN pg_class AS idx ON idx.oid = i.indexrelid
JOIN pg_class AS tbl ON tbl.oid = i.indrelid
JOIN pg_namespace AS n ON n.oid = tbl.relnamespace
JOIN pg_am AS am ON am.oid = idx.relam
WHERE n.nspname = 'nosql_lab'
  AND idx.relname IN (
      'idx_nosql_course_documents_metadata_gin',
      'idx_nosql_course_documents_online'
  )
ORDER BY idx.relname;

-- ============================================================
-- 2. 전체 자동 판정
-- ============================================================
DO $$
DECLARE
    v_requested_count BIGINT;
    v_learning_count BIGINT;
    v_completed_count BIGINT;
    v_cancelled_count BIGINT;
    v_total_amount NUMERIC;
    v_active_count BIGINT;
    v_active_amount NUMERIC;
    v_non_cancelled_count BIGINT;
    v_non_cancelled_amount NUMERIC;
    v_active_duplicate_count BIGINT;
    v_project_named_constraint_count BIGINT;
    v_project_not_null_count BIGINT;
    v_source_mismatch_count BIGINT;
    v_instructor_snapshot_mismatch_count BIGINT;
    v_invalid_document_count BIGINT;
    v_blank_decision_count BIGINT;
    v_popular_cache_mismatch_count BIGINT;
    v_bad_cache_key_count BIGINT;
    v_constraint_count BIGINT;
    v_not_null_count BIGINT;
    v_bad_index_state_count BIGINT;
    v_metadata_index_method TEXT;
    v_metadata_index_definition TEXT;
    v_online_index_method TEXT;
    v_online_index_expression TEXT;
BEGIN
    -- --------------------------------------------------------
    -- Chapter 07·08 canonical source state
    -- --------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'course_project'
          AND table_name = 'enrollments'
          AND column_name = 'recorded_amount'
          AND data_type = 'numeric'
          AND numeric_precision = 12
          AND numeric_scale = 0
    ) THEN
        RAISE EXCEPTION
            '검증 실패: course_project.enrollments.recorded_amount는 NUMERIC(12,0)이어야 합니다.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'course_project'
          AND table_name = 'enrollments'
          AND column_name = 'paid_amount'
    ) THEN
        RAISE EXCEPTION
            '검증 실패: 이전 금액 열이 남아 있습니다.';
    END IF;

    IF (SELECT COUNT(*) FROM course_project.students) <> 3
       OR (SELECT COUNT(*) FROM course_project.instructors) <> 2
       OR (SELECT COUNT(*) FROM course_project.courses) <> 3
       OR (SELECT COUNT(*) FROM course_project.enrollments) <> 5 THEN
        RAISE EXCEPTION
            '검증 실패: Chapter 07·08 기준 행 수는 3/2/3/5여야 합니다.';
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE status = '신청'),
        COUNT(*) FILTER (WHERE status = '수강중'),
        COUNT(*) FILTER (WHERE status = '완료'),
        COUNT(*) FILTER (WHERE status = '취소'),
        COALESCE(SUM(recorded_amount), 0),
        COUNT(*) FILTER (WHERE status IN ('신청', '수강중')),
        COALESCE(SUM(recorded_amount) FILTER (WHERE status IN ('신청', '수강중')), 0),
        COUNT(*) FILTER (WHERE status <> '취소'),
        COALESCE(SUM(recorded_amount) FILTER (WHERE status <> '취소'), 0)
    INTO
        v_requested_count,
        v_learning_count,
        v_completed_count,
        v_cancelled_count,
        v_total_amount,
        v_active_count,
        v_active_amount,
        v_non_cancelled_count,
        v_non_cancelled_amount
    FROM course_project.enrollments;

    IF v_requested_count <> 2
       OR v_learning_count <> 1
       OR v_completed_count <> 1
       OR v_cancelled_count <> 1
       OR v_total_amount <> 590000
       OR v_active_count <> 3
       OR v_active_amount <> 340000
       OR v_non_cancelled_count <> 4
       OR v_non_cancelled_amount <> 440000 THEN
        RAISE EXCEPTION
            '검증 실패: Chapter 07·08 상태·금액 기준이 다릅니다. status=%/%/%/%, amount=%/%/%',
            v_requested_count, v_learning_count, v_completed_count, v_cancelled_count,
            v_total_amount, v_active_amount, v_non_cancelled_amount;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM course_project.enrollments
        WHERE id = 1001 AND status = '완료' AND recorded_amount = 100000
    ) OR NOT EXISTS (
        SELECT 1 FROM course_project.enrollments
        WHERE id = 1004 AND status = '취소' AND recorded_amount = 150000
    ) OR NOT EXISTS (
        SELECT 1 FROM course_project.enrollments
        WHERE id = 1005 AND status = '신청' AND recorded_amount = 120000
    ) THEN
        RAISE EXCEPTION
            '검증 실패: Chapter 07 핵심 신청 1001·1004·1005가 기준과 다릅니다.';
    END IF;

    IF to_regclass('course_project.uq_course_enrollments_active') IS NULL THEN
        RAISE EXCEPTION
            '검증 실패: course_project 활성 신청 부분 고유 인덱스가 없습니다.';
    END IF;

    SELECT COUNT(*)
    INTO v_active_duplicate_count
    FROM (
        SELECT student_id, course_id
        FROM course_project.enrollments
        WHERE status IN ('신청', '수강중')
        GROUP BY student_id, course_id
        HAVING COUNT(*) > 1
    ) AS duplicated_active;

    IF v_active_duplicate_count <> 0 THEN
        RAISE EXCEPTION
            '검증 실패: course_project 활성 신청 중복이 %건 있습니다.',
            v_active_duplicate_count;
    END IF;

    SELECT COUNT(*) INTO v_project_named_constraint_count
    FROM pg_constraint
    WHERE conrelid IN (
        'course_project.students'::regclass,
        'course_project.instructors'::regclass,
        'course_project.courses'::regclass,
        'course_project.enrollments'::regclass
    )
      AND conname IN (
        'uq_course_students_email',
        'chk_course_students_name_not_blank',
        'chk_course_students_email_not_blank',
        'uq_course_instructors_email',
        'chk_course_instructors_name_not_blank',
        'chk_course_instructors_email_not_blank',
        'chk_course_instructors_specialty_not_blank',
        'fk_course_courses_instructor',
        'chk_course_courses_title_not_blank',
        'chk_course_courses_level',
        'chk_course_courses_price',
        'fk_course_enrollments_student',
        'fk_course_enrollments_course',
        'chk_course_enrollments_status',
        'chk_course_enrollments_recorded_amount'
      );

    SELECT COUNT(*) INTO v_project_not_null_count
    FROM information_schema.columns
    WHERE table_schema = 'course_project'
      AND table_name IN ('students', 'instructors', 'courses', 'enrollments')
      AND is_nullable = 'NO';

    IF v_project_named_constraint_count <> 15 OR v_project_not_null_count <> 20 THEN
        RAISE EXCEPTION
            '검증 실패: Chapter 07 구조 기준은 named constraints 15 / NOT NULL 20이어야 합니다. 실제 %/%.',
            v_project_named_constraint_count, v_project_not_null_count;
    END IF;

    -- --------------------------------------------------------
    -- Chapter 12 schema and row state
    -- --------------------------------------------------------
    IF (SELECT COUNT(*) FROM nosql_lab.course_documents) <> 3
       OR (SELECT COUNT(*) FROM nosql_lab.key_value_cache_examples) <> 4
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases) <> 6 THEN
        RAISE EXCEPTION
            '검증 실패: Chapter 12 기준 행 수는 3/4/6이어야 합니다.';
    END IF;

    SELECT COUNT(*)
    INTO v_constraint_count
    FROM pg_constraint
    WHERE connamespace = 'nosql_lab'::regnamespace
      AND contype <> 'n';  -- PostgreSQL 18+는 NOT NULL도 pg_constraint에 기록하므로 제외

    SELECT COUNT(*)
    INTO v_not_null_count
    FROM information_schema.columns
    WHERE table_schema = 'nosql_lab'
      AND is_nullable = 'NO';

    IF v_constraint_count <> 25 OR v_not_null_count <> 26 THEN
        RAISE EXCEPTION
            '검증 실패: nosql_lab 구조 기준은 constraints=25, not_null=26입니다. actual=%/%',
            v_constraint_count, v_not_null_count;
    END IF;

    -- --------------------------------------------------------
    -- course document source mapping
    -- --------------------------------------------------------
    SELECT COUNT(*)
    INTO v_source_mismatch_count
    FROM nosql_lab.course_documents AS d
    FULL JOIN (
        SELECT *
        FROM course_project.courses
        WHERE id IN (301, 302, 303)
    ) AS c
        ON c.id = d.source_course_id
    WHERE d.source_course_id IS NULL
       OR c.id IS NULL
       OR d.course_code IS DISTINCT FROM 'COURSE-' || c.id
       OR d.title IS DISTINCT FROM c.title
       OR d.level IS DISTINCT FROM c.level;

    IF v_source_mismatch_count <> 0 THEN
        RAISE EXCEPTION
            '검증 실패: Chapter 07 원본과 불일치하는 강의 문서가 %건 있습니다.',
            v_source_mismatch_count;
    END IF;

    -- 강사 스냅샷의 원본 ID·이름·전문분야를 NULL 누락까지 포함해 대조합니다.
    SELECT COUNT(*)
    INTO v_instructor_snapshot_mismatch_count
    FROM nosql_lab.course_documents AS d
    JOIN course_project.courses AS c
        ON c.id = d.source_course_id
    JOIN course_project.instructors AS i
        ON i.id = c.instructor_id
    WHERE d.metadata #>> '{instructor_snapshot,source_instructor_id}'
              IS DISTINCT FROM i.id::TEXT
       OR d.metadata #>> '{instructor_snapshot,name}'
              IS DISTINCT FROM i.name
       OR d.metadata #>> '{instructor_snapshot,specialty}'
              IS DISTINCT FROM i.specialty
       OR COALESCE(d.metadata #>> '{instructor_snapshot,copied_at}', '') = '';

    IF v_instructor_snapshot_mismatch_count <> 0 THEN
        RAISE EXCEPTION
            '검증 실패: 원본과 다르거나 불완전한 instructor_snapshot이 %건 있습니다.',
            v_instructor_snapshot_mismatch_count;
    END IF;

    -- JSONB 핵심 구조와 문서 버전
    SELECT COUNT(*)
    INTO v_invalid_document_count
    FROM nosql_lab.course_documents
    WHERE jsonb_typeof(metadata) IS DISTINCT FROM 'object'
       OR jsonb_typeof(metadata -> 'tags') IS DISTINCT FROM 'array'
       OR jsonb_typeof(metadata -> 'options') IS DISTINCT FROM 'object'
       OR jsonb_typeof(metadata #> '{options,online}') IS DISTINCT FROM 'boolean'
       OR jsonb_typeof(metadata #> '{options,certificate}') IS DISTINCT FROM 'boolean'
       OR jsonb_typeof(metadata -> 'instructor_snapshot') IS DISTINCT FROM 'object'
       OR document_version < 1
       OR updated_at < created_at;

    IF v_invalid_document_count <> 0 THEN
        RAISE EXCEPTION
            '검증 실패: JSONB 구조·버전·시각 규칙 위반 문서가 %건 있습니다.',
            v_invalid_document_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM nosql_lab.course_documents
        WHERE source_course_id = 301
          AND course_code = 'COURSE-301'
          AND metadata #>> '{options,certificate}' = 'true'
          AND metadata #>> '{options,online}' = 'true'
          AND document_version = 1
    ) OR NOT EXISTS (
        SELECT 1
        FROM nosql_lab.course_documents
        WHERE source_course_id = 302
          AND course_code = 'COURSE-302'
          AND metadata #>> '{options,certificate}' = 'false'
          AND metadata #>> '{options,online}' = 'true'
          AND document_version = 1
    ) OR NOT EXISTS (
        SELECT 1
        FROM nosql_lab.course_documents
        WHERE source_course_id = 303
          AND course_code = 'COURSE-303'
          AND metadata #>> '{options,certificate}' = 'true'
          AND metadata #>> '{options,online}' = 'false'
          AND document_version = 1
    ) THEN
        RAISE EXCEPTION
            '검증 실패: COURSE-301~303 옵션 또는 document_version 기준이 다릅니다.';
    END IF;

    -- --------------------------------------------------------
    -- Reproducible cache baseline
    -- --------------------------------------------------------
    IF (
        SELECT COUNT(*)
        FROM nosql_lab.key_value_cache_examples
        WHERE expired_at IS NULL OR expired_at > created_at
    ) <> 3
       OR (
        SELECT COUNT(*)
        FROM nosql_lab.key_value_cache_examples
        WHERE expired_at IS NOT NULL AND expired_at <= created_at
    ) <> 1
       OR (
        SELECT COUNT(*)
        FROM nosql_lab.key_value_cache_examples
        WHERE expired_at IS NULL
    ) <> 1 THEN
        RAISE EXCEPTION
            '검증 실패: Seed 기준 캐시는 전체 4, 유효 3, 만료 1, 무만료 1이어야 합니다.';
    END IF;

    SELECT COUNT(*)
    INTO v_bad_cache_key_count
    FROM nosql_lab.key_value_cache_examples
    WHERE cache_key NOT IN (
        'student:101:session',
        'course:popular:v1:top3',
        'feature:recommendation:v1',
        'student:103:session'
    );

    IF v_bad_cache_key_count <> 0
       OR (SELECT COUNT(DISTINCT cache_key) FROM nosql_lab.key_value_cache_examples) <> 4 THEN
        RAISE EXCEPTION
            '검증 실패: 기준 cache_key 집합이 다릅니다.';
    END IF;

    SELECT COUNT(*)
    INTO v_popular_cache_mismatch_count
    FROM nosql_lab.key_value_cache_examples
    WHERE cache_key = 'course:popular:v1:top3'
      AND (
          source_name IS DISTINCT FROM 'course_project'
          OR cache_value -> 'course_ids' IS DISTINCT FROM '[301, 302, 303]'::jsonb
      );

    IF v_popular_cache_mismatch_count <> 0
       OR (SELECT COUNT(*) FROM nosql_lab.key_value_cache_examples
           WHERE cache_key = 'course:popular:v1:top3') <> 1 THEN
        RAISE EXCEPTION
            '검증 실패: 인기 강의 캐시의 원본 또는 course_ids가 기준과 다릅니다.';
    END IF;

    -- --------------------------------------------------------
    -- Storage decision record
    -- --------------------------------------------------------
    SELECT COUNT(*)
    INTO v_blank_decision_count
    FROM nosql_lab.storage_choice_cases
    WHERE char_length(trim(primary_query)) = 0
       OR char_length(trim(candidate_storage)) = 0
       OR char_length(trim(source_of_truth)) = 0
       OR char_length(trim(consistency_requirement)) = 0
       OR char_length(trim(synchronization_strategy)) = 0
       OR char_length(trim(recovery_strategy)) = 0
       OR char_length(trim(poc_success_criteria)) = 0
       OR char_length(trim(reason)) = 0;

    IF v_blank_decision_count <> 0
       OR (SELECT COUNT(DISTINCT system_role) FROM nosql_lab.storage_choice_cases) <> 6
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases WHERE system_role = 'source_of_truth') <> 1
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases WHERE decision_status = 'adopted') <> 1
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases WHERE decision_status = 'poc_planned') <> 2
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases WHERE decision_status = 'candidate') <> 2
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases WHERE decision_status = 'hold') <> 1
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases WHERE decision_status = 'rejected') <> 0 THEN
        RAISE EXCEPTION
            '검증 실패: 저장소 선택 근거·역할·결정 상태가 기대와 다릅니다.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM nosql_lab.storage_choice_cases
        WHERE system_role = 'source_of_truth'
          AND decision_status = 'adopted'
          AND candidate_storage = 'PostgreSQL RDBMS'
          AND reason LIKE '%recorded_amount%'
    ) THEN
        RAISE EXCEPTION
            '검증 실패: PostgreSQL 원본 adopted 사례의 기록 금액 의미가 최신 기준과 다릅니다.';
    END IF;

    -- --------------------------------------------------------
    -- Experimental JSONB indexes
    -- --------------------------------------------------------
    IF to_regclass('nosql_lab.idx_nosql_course_documents_metadata_gin') IS NULL
       OR to_regclass('nosql_lab.idx_nosql_course_documents_online') IS NULL THEN
        RAISE EXCEPTION
            '검증 실패: JSONB 실험 인덱스 2개가 모두 존재해야 합니다.';
    END IF;

    SELECT
        am.amname,
        pg_get_indexdef(idx.oid)
    INTO
        v_metadata_index_method,
        v_metadata_index_definition
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
        v_online_index_method,
        v_online_index_expression
    FROM pg_index AS i
    JOIN pg_class AS idx ON idx.oid = i.indexrelid
    JOIN pg_class AS tbl ON tbl.oid = i.indrelid
    JOIN pg_namespace AS n ON n.oid = tbl.relnamespace
    JOIN pg_am AS am ON am.oid = idx.relam
    WHERE n.nspname = 'nosql_lab'
      AND idx.relname = 'idx_nosql_course_documents_online';

    SELECT COUNT(*)
    INTO v_bad_index_state_count
    FROM pg_index AS i
    JOIN pg_class AS idx ON idx.oid = i.indexrelid
    JOIN pg_namespace AS n ON n.oid = idx.relnamespace
    WHERE n.nspname = 'nosql_lab'
      AND idx.relname IN (
          'idx_nosql_course_documents_metadata_gin',
          'idx_nosql_course_documents_online'
      )
      AND (NOT i.indisvalid OR NOT i.indisready);

    IF v_metadata_index_method IS DISTINCT FROM 'gin'
       OR lower(COALESCE(v_metadata_index_definition, '')) NOT LIKE '%using gin%metadata%'
       OR v_online_index_method IS DISTINCT FROM 'btree'
       OR COALESCE(v_online_index_expression, '') NOT LIKE '%#>>%options%online%'
       OR v_bad_index_state_count <> 0 THEN
        RAISE EXCEPTION
            '검증 실패: JSONB 인덱스 정의 또는 상태가 기준과 다릅니다.';
    END IF;

    RAISE NOTICE 'Chapter 12 nosql_lab validation passed';
END
$$;
