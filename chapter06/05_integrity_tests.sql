-- Chapter 06. 05 정상·경계·오류 데이터 테스트
-- 시작 상태: 04_add_integrity_rules.sql 실행 완료
-- 중요: 주석 처리된 테스트를 한 번에 하나씩 실행합니다.
-- 실패해야 하는 SQL에서 예상한 제약조건 오류가 발생하면 테스트가 성공한 것입니다.
-- 수동 커밋 상태에서 오류 후 트랜잭션이 중단되면 ROLLBACK;을 실행하세요.

SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;

DO $$
DECLARE
    v_constraint_count bigint;
    v_not_null_count bigint;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '테스트 중단: 현재 데이터베이스는 %입니다. ai_database_book에 연결하세요.',
            current_database();
    END IF;

    IF to_regclass('public.library_records_raw') IS NULL
       OR to_regclass('public.members_nf') IS NULL
       OR to_regclass('public.books_nf') IS NULL
       OR to_regclass('public.loans_nf') IS NULL THEN
        RAISE EXCEPTION
            '테스트 중단: Chapter 06 테이블이 모두 존재하지 않습니다.';
    END IF;

    SELECT COUNT(*) INTO v_constraint_count
    FROM pg_constraint
    WHERE (conrelid = 'public.members_nf'::regclass
           AND conname IN ('uq_members_nf_email', 'chk_members_nf_name_not_blank'))
       OR (conrelid = 'public.books_nf'::regclass
           AND conname IN ('uq_books_nf_isbn', 'chk_books_nf_title_not_blank'))
       OR (conrelid = 'public.loans_nf'::regclass
           AND conname IN (
               'fk_loans_nf_member',
               'fk_loans_nf_book',
               'chk_loans_nf_due_date',
               'chk_loans_nf_returned_date'
           ));

    SELECT COUNT(*) INTO v_not_null_count
    FROM pg_attribute
    WHERE (attrelid = 'public.members_nf'::regclass
           AND attname IN ('name', 'email', 'joined_at') AND attnotnull)
       OR (attrelid = 'public.books_nf'::regclass
           AND attname IN ('title', 'author', 'isbn') AND attnotnull)
       OR (attrelid = 'public.loans_nf'::regclass
           AND attname IN ('member_id', 'book_id', 'borrowed_at', 'due_at') AND attnotnull);

    IF v_constraint_count <> 8
       OR v_not_null_count <> 10
       OR to_regclass('public.uq_loans_nf_active_book') IS NULL THEN
        RAISE EXCEPTION
            '테스트 중단: 04_add_integrity_rules.sql 적용 상태가 아닙니다. constraints=%, not_null_columns=%, active_index=%',
            v_constraint_count,
            v_not_null_count,
            to_regclass('public.uq_loans_nf_active_book');
    END IF;
END
$$;

-- 기준 상태: raw 3, members 2, books 2, loans 3, 미반납 2
SELECT COUNT(*) AS raw_count_before FROM public.library_records_raw;
SELECT COUNT(*) AS member_count_before FROM public.members_nf;
SELECT COUNT(*) AS book_count_before FROM public.books_nf;
SELECT COUNT(*) AS loan_count_before FROM public.loans_nf;
SELECT COUNT(*) AS open_loan_count_before FROM public.loans_nf WHERE returned_at IS NULL;

-- ============================================================
-- 경계 테스트 A: 같은 날 대여·반납 허용
-- C-04·C-05 경계값
-- ISBN은 books_nf.isbn VARCHAR(20) 범위 안의 테스트 값을 사용합니다.
-- 아래 네 문장을 순서대로 실행한 뒤 임시 행을 삭제합니다.
-- ============================================================
-- INSERT INTO public.books_nf (id, title, author, published_year, isbn)
-- VALUES (1800, '경계값 테스트 도서', '테스트 저자', 2026, 'ISBN-BND-LOAN-001');
--
-- INSERT INTO public.loans_nf (
--     id, member_id, book_id, borrowed_at, due_at, returned_at
-- )
-- VALUES (1801, 101, 1800, DATE '2026-05-01', DATE '2026-05-01', DATE '2026-05-01');
--
-- DELETE FROM public.loans_nf WHERE id = 1801;
-- DELETE FROM public.books_nf WHERE id = 1800;

-- ============================================================
-- 경계 테스트 B: published_year = NULL 허용
-- ============================================================
-- INSERT INTO public.books_nf (id, title, author, published_year, isbn)
-- VALUES (1802, '연도 미상 도서', '익명', NULL, 'ISBN-BOUNDARY-001');
-- DELETE FROM public.books_nf WHERE id = 1802;

-- ============================================================
-- 경계 테스트 C: 공백이 아닌 한 글자 이름 허용
-- ============================================================
-- INSERT INTO public.members_nf (id, name, email, joined_at)
-- VALUES (1803, '김', 'one-char@example.com', DATE '2026-03-20');
-- DELETE FROM public.members_nf WHERE id = 1803;

-- ============================================================
-- 오류 테스트 1: NOT NULL 위반
-- 기대: null value in column "name" ... violates not-null constraint
-- ============================================================
-- INSERT INTO public.members_nf (id, name, email, joined_at)
-- VALUES (1901, NULL, 'null-name@example.com', DATE '2026-03-20');

-- 오류 테스트 2: C-01 이메일 UNIQUE 위반
-- 기대 제약조건: uq_members_nf_email
-- INSERT INTO public.members_nf (id, name, email, joined_at)
-- VALUES (1902, '중복 이메일 회원', 'junho@example.com', DATE '2026-03-20');

-- 오류 테스트 3A: C-02 ISBN NOT NULL 위반
-- 기대: null value in column "isbn" ... violates not-null constraint
-- INSERT INTO public.books_nf (id, title, author, published_year, isbn)
-- VALUES (1912, 'ISBN 없음 도서', '테스트 저자', 2026, NULL);

-- 오류 테스트 3B: C-02 ISBN UNIQUE 위반
-- 기대 제약조건: uq_books_nf_isbn
-- INSERT INTO public.books_nf (id, title, author, published_year, isbn)
-- VALUES (1903, '중복 ISBN 도서', '테스트 저자', 2026, 'ISBN-001');

-- 오류 테스트 4: C-03 공백 이름 CHECK 위반
-- 기대 제약조건: chk_members_nf_name_not_blank
-- INSERT INTO public.members_nf (id, name, email, joined_at)
-- VALUES (1904, '   ', 'blank-name@example.com', DATE '2026-03-20');

-- 오류 테스트 5: C-03 공백 제목 CHECK 위반
-- 기대 제약조건: chk_books_nf_title_not_blank
-- INSERT INTO public.books_nf (id, title, author, published_year, isbn)
-- VALUES (1905, '   ', '테스트 저자', 2026, 'ISBN-BLANK-001');

-- 오류 테스트 6A: C-06 존재하지 않는 회원 FOREIGN KEY 위반
-- 기대 제약조건: fk_loans_nf_member
-- INSERT INTO public.loans_nf (
--     id, member_id, book_id, borrowed_at, due_at, returned_at
-- )
-- VALUES (1906, 999, 201, DATE '2026-04-10', DATE '2026-04-24', DATE '2026-04-12');

-- 오류 테스트 6B: C-06 존재하지 않는 도서 FOREIGN KEY 위반
-- 기대 제약조건: fk_loans_nf_book
-- INSERT INTO public.loans_nf (
--     id, member_id, book_id, borrowed_at, due_at, returned_at
-- )
-- VALUES (1910, 101, 999, DATE '2026-04-10', DATE '2026-04-24', DATE '2026-04-12');

-- 오류 테스트 7: C-04 잘못된 반납예정일 CHECK 위반
-- 기대 제약조건: chk_loans_nf_due_date
-- INSERT INTO public.loans_nf (
--     id, member_id, book_id, borrowed_at, due_at, returned_at
-- )
-- VALUES (1907, 101, 202, DATE '2026-04-20', DATE '2026-04-10', DATE '2026-04-21');

-- 오류 테스트 8: C-05 실제반납일 CHECK 위반
-- 기대 제약조건: chk_loans_nf_returned_date
-- INSERT INTO public.loans_nf (
--     id, member_id, book_id, borrowed_at, due_at, returned_at
-- )
-- VALUES (1908, 101, 202, DATE '2026-04-20', DATE '2026-05-04', DATE '2026-04-10');

-- 오류 테스트 9: C-08 같은 도서의 두 번째 미반납 대여
-- 도서 201에는 대여 1003이 미반납 상태로 존재합니다.
-- 기대 객체: uq_loans_nf_active_book
-- INSERT INTO public.loans_nf (
--     id, member_id, book_id, borrowed_at, due_at, returned_at
-- )
-- VALUES (1909, 101, 201, DATE '2026-04-10', DATE '2026-04-24', NULL);

-- 오류 테스트 10: C-07 참조 중인 부모 삭제
-- 기대 제약조건: fk_loans_nf_member
-- DELETE FROM public.members_nf WHERE id = 101;

-- 정상 테스트: 참조되지 않는 부모는 삭제 가능
-- INSERT INTO public.members_nf (id, name, email, joined_at)
-- VALUES (1911, '미대여 회원', 'unused@example.com', DATE '2026-03-20');
-- DELETE FROM public.members_nf WHERE id = 1911;

-- 테스트 후 기준 데이터 자동 확인
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
    v_active_duplicate_count bigint;
BEGIN
    SELECT COUNT(*) INTO v_raw_count FROM public.library_records_raw;
    SELECT COUNT(*) INTO v_member_count FROM public.members_nf;
    SELECT COUNT(*) INTO v_book_count FROM public.books_nf;
    SELECT COUNT(*) INTO v_loan_count FROM public.loans_nf;
    SELECT COUNT(*) INTO v_open_count FROM public.loans_nf WHERE returned_at IS NULL;
    SELECT COUNT(*) INTO v_member_101_count FROM public.loans_nf WHERE member_id = 101;
    SELECT COUNT(*) INTO v_book_201_count FROM public.loans_nf WHERE book_id = 201;

    SELECT COUNT(*) INTO v_orphan_member_count
    FROM public.loans_nf AS l
    LEFT JOIN public.members_nf AS m ON l.member_id = m.id
    WHERE m.id IS NULL;

    SELECT COUNT(*) INTO v_orphan_book_count
    FROM public.loans_nf AS l
    LEFT JOIN public.books_nf AS b ON l.book_id = b.id
    WHERE b.id IS NULL;

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
       OR v_active_duplicate_count <> 0 THEN
        RAISE EXCEPTION
            '테스트 후 기준 상태 불일치: raw=%, members=%, books=%, loans=%, open=%, member101=%, book201=%, orphan_member=%, orphan_book=%, active_duplicate=%',
            v_raw_count,
            v_member_count,
            v_book_count,
            v_loan_count,
            v_open_count,
            v_member_101_count,
            v_book_201_count,
            v_orphan_member_count,
            v_orphan_book_count,
            v_active_duplicate_count;
    END IF;

    RAISE NOTICE 'Chapter 06 integrity test baseline preserved';
END
$$;

SELECT * FROM public.members_nf ORDER BY id;
SELECT * FROM public.books_nf ORDER BY id;
SELECT * FROM public.loans_nf ORDER BY id;