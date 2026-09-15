-- Chapter 06. 03 정규화 전·후 비교와 기본 검증
-- 시작 상태: 02_normalization_seed.sql 실행 완료
-- 완료 상태: 데이터 변경 없이 반복·행 수·관계·시간 순서를 확인
-- 이 파일은 데이터를 변경하지 않으므로 반복 실행할 수 있습니다.

SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;

DO $$
DECLARE
    v_raw_count bigint;
    v_member_count bigint;
    v_book_count bigint;
    v_loan_count bigint;
    v_open_count bigint;
    v_member_101_count bigint;
    v_book_201_count bigint;
    v_orphan_member_count bigint;
    v_orphan_book_count bigint;
    v_invalid_date_count bigint;
    v_book_201_invalid_order bigint;
    v_active_duplicate_count bigint;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '비교 중단: 현재 데이터베이스는 %입니다. ai_database_book에 연결하세요.',
            current_database();
    END IF;

    IF to_regclass('public.library_records_raw') IS NULL
       OR to_regclass('public.members_nf') IS NULL
       OR to_regclass('public.books_nf') IS NULL
       OR to_regclass('public.loans_nf') IS NULL THEN
        RAISE EXCEPTION
            '비교 중단: Chapter 06 테이블이 모두 존재하지 않습니다.';
    END IF;

    SELECT COUNT(*) INTO v_raw_count FROM public.library_records_raw;
    SELECT COUNT(*) INTO v_member_count FROM public.members_nf;
    SELECT COUNT(*) INTO v_book_count FROM public.books_nf;
    SELECT COUNT(*) INTO v_loan_count FROM public.loans_nf;
    SELECT COUNT(*) INTO v_open_count FROM public.loans_nf WHERE returned_at IS NULL;
    SELECT COUNT(*) INTO v_member_101_count FROM public.loans_nf WHERE member_id = 101;
    SELECT COUNT(*) INTO v_book_201_count FROM public.loans_nf WHERE book_id = 201;

    SELECT COUNT(*) INTO v_orphan_member_count
    FROM public.loans_nf AS l
    LEFT JOIN public.members_nf AS m
        ON l.member_id = m.id
    WHERE m.id IS NULL;

    SELECT COUNT(*) INTO v_orphan_book_count
    FROM public.loans_nf AS l
    LEFT JOIN public.books_nf AS b
        ON l.book_id = b.id
    WHERE b.id IS NULL;

    SELECT COUNT(*) INTO v_invalid_date_count
    FROM public.loans_nf
    WHERE due_at < borrowed_at
       OR (returned_at IS NOT NULL AND returned_at < borrowed_at);

    SELECT COUNT(*) INTO v_book_201_invalid_order
    FROM public.loans_nf AS earlier
    JOIN public.loans_nf AS later
        ON earlier.book_id = later.book_id
       AND earlier.borrowed_at < later.borrowed_at
    WHERE earlier.book_id = 201
      AND earlier.returned_at IS NOT NULL
      AND earlier.returned_at >= later.borrowed_at;

    SELECT COUNT(*) INTO v_active_duplicate_count
    FROM (
        SELECT book_id
        FROM public.loans_nf
        WHERE returned_at IS NULL
        GROUP BY book_id
        HAVING COUNT(*) > 1
    ) AS duplicated_active_books;

    IF v_raw_count <> 3
       OR v_member_count <> 2
       OR v_book_count <> 2
       OR v_loan_count <> 3
       OR v_open_count <> 2
       OR v_member_101_count <> 2
       OR v_book_201_count <> 2
       OR v_orphan_member_count <> 0
       OR v_orphan_book_count <> 0
       OR v_invalid_date_count <> 0
       OR v_book_201_invalid_order <> 0
       OR v_active_duplicate_count <> 0 THEN
        RAISE EXCEPTION
            '비교 검증 실패: raw=%, members=%, books=%, loans=%, open=%, member101=%, book201=%, orphan_member=%, orphan_book=%, invalid_date=%, book201_order=%, active_duplicate=%',
            v_raw_count,
            v_member_count,
            v_book_count,
            v_loan_count,
            v_open_count,
            v_member_101_count,
            v_book_201_count,
            v_orphan_member_count,
            v_orphan_book_count,
            v_invalid_date_count,
            v_book_201_invalid_order,
            v_active_duplicate_count;
    END IF;

    RAISE NOTICE 'Chapter 06 normalization comparison passed';
END
$$;

-- 정규화 전 원시 데이터
SELECT *
FROM public.library_records_raw
ORDER BY loan_id;

-- 같은 회원 사실의 반복
SELECT
    member_name,
    member_email,
    COUNT(*) AS repeated_rows
FROM public.library_records_raw
GROUP BY member_name, member_email
ORDER BY repeated_rows DESC, member_name;

-- 같은 도서 사실의 반복
SELECT
    book_title,
    author,
    COUNT(*) AS repeated_rows
FROM public.library_records_raw
GROUP BY book_title, author
ORDER BY repeated_rows DESC, book_title;

-- 정규화 후 각 사실의 주인 테이블
SELECT * FROM public.members_nf ORDER BY id;
SELECT * FROM public.books_nf ORDER BY id;
SELECT * FROM public.loans_nf ORDER BY id;

-- 정규화된 관계가 원래 업무 결과를 만들 수 있는지 확인
-- JOIN 상세 문법은 Chapter 08에서 다룹니다.
SELECT
    l.id AS loan_id,
    m.name AS member_name,
    m.email AS member_email,
    b.title AS book_title,
    b.author,
    l.borrowed_at,
    l.due_at,
    l.returned_at
FROM public.loans_nf AS l
JOIN public.members_nf AS m
    ON l.member_id = m.id
JOIN public.books_nf AS b
    ON l.book_id = b.id
ORDER BY l.id;

-- 회원 101과 도서 201의 반복 이력
SELECT *
FROM public.loans_nf
WHERE member_id = 101
ORDER BY borrowed_at, id;

SELECT *
FROM public.loans_nf
WHERE book_id = 201
ORDER BY borrowed_at, id;

-- 미반납 대여
SELECT *
FROM public.loans_nf
WHERE returned_at IS NULL
ORDER BY due_at, id;