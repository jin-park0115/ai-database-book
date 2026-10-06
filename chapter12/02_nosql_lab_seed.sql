-- Chapter 12. nosql_lab 기준 데이터 입력
-- 실행 전 01_nosql_lab_schema.sql을 먼저 실행합니다.
-- 자동 생성 ID는 업무 의미나 후속 참조에 사용하지 않습니다.
-- 파일 전체는 하나의 트랜잭션으로 처리합니다.

SELECT current_database();
SELECT current_schema();
SHOW search_path;

-- ============================================================
-- 0. 실행 전 상태 확인
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
            '실행 중단: 읽기 전용 연결에서는 Seed 데이터를 입력할 수 없습니다.';
    END IF;

    IF to_regclass('nosql_lab.course_documents') IS NULL
       OR to_regclass('nosql_lab.key_value_cache_examples') IS NULL
       OR to_regclass('nosql_lab.storage_choice_cases') IS NULL THEN
        RAISE EXCEPTION
            '실행 중단: nosql_lab 핵심 테이블이 없습니다. 01 파일을 먼저 실행하세요.';
    END IF;

    IF (SELECT COUNT(*) FROM nosql_lab.course_documents) <> 0
       OR (SELECT COUNT(*) FROM nosql_lab.key_value_cache_examples) <> 0
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases) <> 0 THEN
        RAISE EXCEPTION
            '실행 중단: nosql_lab 테이블은 모두 비어 있어야 합니다. 기존 데이터를 확인하세요.';
    END IF;

    IF (SELECT COUNT(*) FROM course_project.courses WHERE id IN (301, 302, 303)) <> 3
       OR (SELECT COUNT(*) FROM course_project.instructors WHERE id IN (201, 202)) <> 2 THEN
        RAISE EXCEPTION
            '실행 중단: Chapter 07 기준 강의 301~303 또는 강사 201~202가 없습니다.';
    END IF;

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
            '실행 중단: Chapter 07·08의 recorded_amount NUMERIC(12,0) 기준이 아닙니다.';
    END IF;
END
$$;

BEGIN;

-- ============================================================
-- 1. Chapter 07 원본에서 문서형 강의 메타데이터 3건 생성
-- source_course_id와 title·level은 원본과 대조할 안정된 핵심 컬럼입니다.
-- instructor_snapshot은 상세 화면 표시용 파생 복사본입니다.
-- ============================================================
INSERT INTO nosql_lab.course_documents (
    source_course_id,
    course_code,
    title,
    level,
    metadata
)
SELECT
    c.id AS source_course_id,
    'COURSE-' || c.id AS course_code,
    c.title,
    c.level,
    jsonb_build_object(
        'tags', CASE c.id
            WHEN 301 THEN to_jsonb(ARRAY['SQL', 'PostgreSQL', 'Database'])
            WHEN 302 THEN to_jsonb(ARRAY['Normalization', 'Schema', 'Integrity'])
            WHEN 303 THEN to_jsonb(ARRAY['Python', 'Pandas', 'Data Analysis'])
        END,
        'instructor_snapshot', jsonb_build_object(
            'source_instructor_id', i.id,
            'name', i.name,
            'specialty', i.specialty,
            'copied_at', CURRENT_TIMESTAMP
        ),
        'options', CASE c.id
            WHEN 301 THEN jsonb_build_object(
                'online', true,
                'certificate', true
            )
            WHEN 302 THEN jsonb_build_object(
                'online', true,
                'certificate', false
            )
            WHEN 303 THEN jsonb_build_object(
                'online', false,
                'certificate', true
            )
        END
    ) AS metadata
FROM course_project.courses AS c
JOIN course_project.instructors AS i
    ON i.id = c.instructor_id
WHERE c.id IN (301, 302, 303)
ORDER BY c.id;

-- ============================================================
-- 2. Key-Value 개념 시뮬레이션 4건
-- CURRENT_TIMESTAMP는 같은 트랜잭션 안에서 고정되므로
-- expired_at과 created_at 비교로 Seed 시점의 4/3/1 상태를 재현할 수 있습니다.
-- expired_at IS NULL은 만료 정책이 없는 키를 뜻합니다.
-- ============================================================
INSERT INTO nosql_lab.key_value_cache_examples (
    cache_key,
    cache_value,
    source_name,
    expired_at,
    created_at
)
VALUES
(
    'student:101:session',
    jsonb_build_object(
        'student_id', 101,
        'login_device', 'browser',
        'status', 'active'
    ),
    'authentication_service',
    CURRENT_TIMESTAMP + INTERVAL '30 minutes',
    CURRENT_TIMESTAMP
),
(
    'course:popular:v1:top3',
    jsonb_build_object(
        'course_ids', to_jsonb(ARRAY[301, 302, 303]),
        'generated_by', 'daily_batch'
    ),
    'course_project',
    CURRENT_TIMESTAMP + INTERVAL '1 hour',
    CURRENT_TIMESTAMP
),
(
    'feature:recommendation:v1',
    jsonb_build_object(
        'enabled', true,
        'target', 'student_course_topic'
    ),
    'feature_configuration',
    NULL,
    CURRENT_TIMESTAMP
),
(
    'student:103:session',
    jsonb_build_object(
        'student_id', 103,
        'login_device', 'mobile',
        'status', 'expired'
    ),
    'authentication_service',
    CURRENT_TIMESTAMP - INTERVAL '10 minutes',
    CURRENT_TIMESTAMP
);

-- ============================================================
-- 3. 저장 방식 선택 사례 6건
-- candidate_storage와 decision_status를 구분합니다.
-- ============================================================
INSERT INTO nosql_lab.storage_choice_cases (
    case_name,
    system_role,
    primary_query,
    candidate_storage,
    source_of_truth,
    consistency_requirement,
    synchronization_strategy,
    recovery_strategy,
    poc_success_criteria,
    decision_status,
    reason
)
VALUES
(
    '수강신청과 신청 당시 금액 기록',
    'source_of_truth',
    '학생·강의·신청 당시 기록 금액을 제약조건·트랜잭션·JOIN으로 처리',
    'PostgreSQL RDBMS',
    'course_project.enrollments와 관련 원본 테이블',
    '강한 무결성과 다중 변경 원자성 필요',
    '원본 데이터베이스 내부 트랜잭션으로 처리',
    'Chapter 11에서 검증한 백업·복원 원칙으로 원본 복구',
    'PK·FK·CHECK·활성 신청 규칙과 트랜잭션 검증 통과',
    'adopted',
    'course_project.enrollments.recorded_amount NUMERIC(12,0)는 신청 시점에 신청 행에 기록한 금액이며 결제 승인액·환불 반영 순액·회계 매출이 아닙니다. 별도 결제·환불 원장은 현재 범위 밖입니다.'
),
(
    '학생 로그인 세션',
    'ephemeral_state',
    '정확한 세션 키로 읽고 TTL 또는 명시적 폐기 후 무효화',
    'Key-Value DB 후보',
    '인증 시스템의 사용자·로그인 원본',
    '세션 생성 직후 읽기와 만료·폐기 정책이 중요',
    '세션 생성·폐기 이벤트와 TTL 정책',
    '원본 인증 상태를 확인하고 세션을 다시 발급',
    '키 조회·만료·폐기·장애 시 재로그인 흐름 검증',
    'poc_planned',
    '정확한 키 조회와 만료가 중심이며 영구 원본은 아닙니다.'
),
(
    '인기 강의 캐시',
    'derived_cache',
    '고정 키로 상위 강의 ID 목록 읽기',
    'Key-Value DB 후보',
    'course_project 강의·수강신청 데이터',
    '일시적으로 오래된 값 허용 가능',
    '배치·변경 이벤트 갱신과 캐시 미스 재생성',
    '원본 집계로 키를 재생성하고 오래된 버전을 폐기',
    '캐시 히트·미스·동시 재생성·원본 부하와 복구 시간 측정',
    'poc_planned',
    '원본에서 다시 만들 수 있는 파생 데이터입니다.'
),
(
    '강의 유연 메타데이터',
    'flexible_metadata',
    '원본 강의 ID 또는 문서 필드로 상세 조회',
    'PostgreSQL JSONB 또는 Document DB 후보',
    'course_project 강의·강사 원본',
    '핵심 제목·난이도는 원본과 일치해야 하며 부가 정보는 지연 가능',
    '원본 변경 이벤트·문서 버전·주기적 대조',
    'source_course_id로 원본을 대조하고 문서를 재구축',
    '대표 필드 조회·버전 충돌·마이그레이션·재구축 시험',
    'candidate',
    '가변 속성은 문서형 저장을 검토하되 안정된 필드는 일반 컬럼에 둡니다.'
),
(
    '학습 행동 이벤트',
    'event_log',
    '학생·날짜 파티션에서 이벤트를 시간순 범위 조회',
    'Column-Family DB 후보',
    '검증된 이벤트 수집 로그',
    '중복·늦은 도착·재처리 허용 범위를 정의해야 함',
    'event_id 멱등성·실패 대기열·분석 파이프라인',
    '원본 이벤트 보관본에서 파티션을 재생성',
    '실제 분포에서 파티션 크기·쓰기 핫스팟·재처리·복구 측정',
    'hold',
    '대표 조회와 데이터 규모가 확정되기 전까지 전용 제품 도입을 보류합니다.'
),
(
    '학생-강의-주제 추천 관계',
    'relationship_index',
    '여러 단계 관계를 따라 추천 후보 탐색',
    'Graph DB 후보',
    'RDBMS·학습 이벤트·추천 모델 입력 데이터',
    '원본보다 지연된 파생 관계를 허용할 수 있음',
    '변경 이벤트·주기적 재구축·대조 작업',
    '원본에서 전체 관계 인덱스를 다시 생성',
    'JOIN 대안과 비교해 관계 깊이·지연·재구축 시간을 측정',
    'candidate',
    '다단계 관계 탐색이 반복되는지 PoC로 확인한 뒤 결정합니다.'
);

-- ============================================================
-- 4. COMMIT 전 기준 상태 자동 판정
-- ============================================================
DO $$
DECLARE
    v_source_mismatch_count BIGINT;
    v_snapshot_mismatch_count BIGINT;
    v_invalid_document_count BIGINT;
    v_blank_decision_count BIGINT;
    v_bad_cache_key_count BIGINT;
BEGIN
    IF (SELECT COUNT(*) FROM nosql_lab.course_documents) <> 3
       OR (SELECT COUNT(*) FROM nosql_lab.key_value_cache_examples) <> 4
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases) <> 6 THEN
        RAISE EXCEPTION
            '샘플 입력 중단: 기준 행 수는 course_documents 3, cache 4, choices 6이어야 합니다.';
    END IF;

    SELECT COUNT(*)
    INTO v_source_mismatch_count
    FROM nosql_lab.course_documents AS d
    JOIN course_project.courses AS c
        ON c.id = d.source_course_id
    WHERE d.course_code IS DISTINCT FROM 'COURSE-' || c.id
       OR c.title IS DISTINCT FROM d.title
       OR c.level IS DISTINCT FROM d.level;

    IF v_source_mismatch_count <> 0 THEN
        RAISE EXCEPTION
            '샘플 입력 중단: Chapter 07 원본과 다른 문서가 %건 있습니다.',
            v_source_mismatch_count;
    END IF;

    SELECT COUNT(*)
    INTO v_snapshot_mismatch_count
    FROM nosql_lab.course_documents AS d
    JOIN course_project.courses AS c
        ON c.id = d.source_course_id
    JOIN course_project.instructors AS i
        ON i.id = c.instructor_id
    WHERE d.metadata #>> '{instructor_snapshot,source_instructor_id}' IS DISTINCT FROM i.id::TEXT
       OR d.metadata #>> '{instructor_snapshot,name}' IS DISTINCT FROM i.name
       OR d.metadata #>> '{instructor_snapshot,specialty}' IS DISTINCT FROM i.specialty
       OR COALESCE(d.metadata #>> '{instructor_snapshot,copied_at}', '') = '';

    IF v_snapshot_mismatch_count <> 0 THEN
        RAISE EXCEPTION
            '샘플 입력 중단: instructor_snapshot 원본 대조 실패가 %건 있습니다.',
            v_snapshot_mismatch_count;
    END IF;

    SELECT COUNT(*)
    INTO v_invalid_document_count
    FROM nosql_lab.course_documents
    WHERE jsonb_typeof(metadata) IS DISTINCT FROM 'object'
       OR jsonb_typeof(metadata -> 'tags') IS DISTINCT FROM 'array'
       OR jsonb_typeof(metadata -> 'options') IS DISTINCT FROM 'object'
       OR jsonb_typeof(metadata #> '{options,online}') IS DISTINCT FROM 'boolean'
       OR jsonb_typeof(metadata #> '{options,certificate}') IS DISTINCT FROM 'boolean'
       OR jsonb_typeof(metadata -> 'instructor_snapshot') IS DISTINCT FROM 'object'
       OR document_version <> 1;

    IF v_invalid_document_count <> 0 THEN
        RAISE EXCEPTION
            '샘플 입력 중단: JSONB 구조 또는 문서 버전이 잘못된 문서가 %건 있습니다.',
            v_invalid_document_count;
    END IF;

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
            '샘플 입력 중단: Seed 기준 캐시는 전체 4, 유효 3, 만료 1, 무만료 1이어야 합니다.';
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
       OR NOT EXISTS (
            SELECT 1
            FROM nosql_lab.key_value_cache_examples
            WHERE cache_key = 'course:popular:v1:top3'
              AND source_name = 'course_project'
              AND cache_value -> 'course_ids' = '[301, 302, 303]'::jsonb
       ) THEN
        RAISE EXCEPTION
            '샘플 입력 중단: cache_key 집합 또는 인기 강의 원본 ID가 다릅니다.';
    END IF;

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
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases WHERE decision_status = 'adopted') <> 1
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases WHERE decision_status = 'poc_planned') <> 2
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases WHERE decision_status = 'candidate') <> 2
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases WHERE decision_status = 'hold') <> 1
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases WHERE decision_status = 'rejected') <> 0 THEN
        RAISE EXCEPTION
            '샘플 입력 중단: 저장소 선택 근거·역할 또는 결정 상태 구성이 잘못되었습니다.';
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
            '샘플 입력 중단: PostgreSQL 원본 사례의 recorded_amount 의미가 누락되었습니다.';
    END IF;

    RAISE NOTICE 'Chapter 12 nosql lab seed validation passed';
END
$$;

COMMIT;

-- ============================================================
-- 5. 기준 결과
-- ============================================================
SELECT COUNT(*) AS course_document_count
FROM nosql_lab.course_documents;

SELECT COUNT(*) AS cache_example_count
FROM nosql_lab.key_value_cache_examples;

SELECT COUNT(*) AS storage_choice_count
FROM nosql_lab.storage_choice_cases;

SELECT
    COUNT(*) AS total_cache_rows,
    COUNT(*) FILTER (
        WHERE expired_at IS NULL OR expired_at > created_at
    ) AS valid_at_seed_rows,
    COUNT(*) FILTER (
        WHERE expired_at IS NOT NULL AND expired_at <= created_at
    ) AS expired_at_seed_rows,
    COUNT(*) FILTER (WHERE expired_at IS NULL) AS no_expiry_rows
FROM nosql_lab.key_value_cache_examples;

-- 기대 결과: 3 / 4 / 6, Seed 기준 캐시 4 / 3 / 1, 무만료 1
-- 자동 생성 ID는 업무 키로 사용하지 않으므로 번호 공백을 정합성 오류로 보지 않습니다.
