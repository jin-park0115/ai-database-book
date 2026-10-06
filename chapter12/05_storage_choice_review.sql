-- Chapter 12. 저장 방식 선택 검토
-- 실행 전 01, 02 파일을 실행합니다.
-- 이 파일은 저장소 선택 사례를 조회·검증하며 데이터를 변경하지 않습니다.

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

    IF to_regclass('nosql_lab.storage_choice_cases') IS NULL
       OR (SELECT COUNT(*) FROM nosql_lab.storage_choice_cases) <> 6 THEN
        RAISE EXCEPTION
            '실행 중단: storage_choice_cases 기준 6행이 준비되지 않았습니다.';
    END IF;
END
$$;

-- ============================================================
-- 1. 전체 선택 사례
-- 후보 저장소와 최종 결정 상태를 구분합니다.
-- ============================================================
SELECT
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
    reason,
    reviewed_at
FROM nosql_lab.storage_choice_cases
ORDER BY id;

-- ============================================================
-- 2. 시스템 역할별 건수
-- 업무 순서를 CASE로 명시합니다.
-- ============================================================
SELECT
    system_role,
    COUNT(*) AS case_count
FROM nosql_lab.storage_choice_cases
GROUP BY system_role
ORDER BY CASE system_role
    WHEN 'source_of_truth' THEN 1
    WHEN 'ephemeral_state' THEN 2
    WHEN 'derived_cache' THEN 3
    WHEN 'flexible_metadata' THEN 4
    WHEN 'event_log' THEN 5
    WHEN 'relationship_index' THEN 6
    ELSE 99
END;

-- 기대: 여섯 역할이 각각 1건

-- ============================================================
-- 3. Source of Truth와 파생·상태 저장소 구분
-- ============================================================
SELECT
    case_name,
    system_role,
    candidate_storage,
    source_of_truth,
    synchronization_strategy,
    recovery_strategy,
    decision_status
FROM nosql_lab.storage_choice_cases
WHERE system_role <> 'source_of_truth'
ORDER BY id;

-- ============================================================
-- 4. 별도 동기화·복구 전략이 필요한 사례
-- ============================================================
SELECT
    case_name,
    candidate_storage,
    synchronization_strategy,
    recovery_strategy,
    poc_success_criteria,
    decision_status
FROM nosql_lab.storage_choice_cases
WHERE system_role IN (
    'derived_cache',
    'event_log',
    'relationship_index',
    'flexible_metadata'
)
ORDER BY id;

-- ============================================================
-- 5. 결정 상태별 사례
-- ============================================================
SELECT
    decision_status,
    COUNT(*) AS case_count,
    string_agg(case_name, ', ' ORDER BY id) AS cases
FROM nosql_lab.storage_choice_cases
GROUP BY decision_status
ORDER BY CASE decision_status
    WHEN 'adopted' THEN 1
    WHEN 'poc_planned' THEN 2
    WHEN 'candidate' THEN 3
    WHEN 'hold' THEN 4
    WHEN 'rejected' THEN 5
    ELSE 99
END;

-- ============================================================
-- 6. 선택 근거 필수값 검증
-- 기대 결과: 0행
-- ============================================================
SELECT *
FROM nosql_lab.storage_choice_cases
WHERE char_length(trim(primary_query)) = 0
   OR char_length(trim(candidate_storage)) = 0
   OR char_length(trim(source_of_truth)) = 0
   OR char_length(trim(consistency_requirement)) = 0
   OR char_length(trim(synchronization_strategy)) = 0
   OR char_length(trim(recovery_strategy)) = 0
   OR char_length(trim(poc_success_criteria)) = 0
   OR char_length(trim(reason)) = 0;

-- ============================================================
-- 7. 기준 행 수와 역할·결정 상태 확인
-- ============================================================
SELECT
    COUNT(*) AS total_cases,
    COUNT(DISTINCT system_role) AS distinct_system_roles,
    COUNT(*) FILTER (
        WHERE system_role = 'source_of_truth'
    ) AS source_of_truth_cases,
    COUNT(*) FILTER (
        WHERE system_role <> 'source_of_truth'
    ) AS non_source_cases,
    COUNT(*) FILTER (
        WHERE decision_status = 'adopted'
    ) AS adopted_cases,
    COUNT(*) FILTER (
        WHERE decision_status IN ('candidate', 'poc_planned', 'hold')
    ) AS unresolved_or_testing_cases
FROM nosql_lab.storage_choice_cases;

-- 기대 결과: 6 / 6 / 1 / 5 / 1 / 5

-- ============================================================
-- 8. AI 추천 검토용 요약
-- ============================================================
SELECT
    case_name,
    candidate_storage,
    decision_status,
    primary_query,
    consistency_requirement,
    synchronization_strategy,
    recovery_strategy,
    poc_success_criteria
FROM nosql_lab.storage_choice_cases
ORDER BY id;
