-- Chapter 06. 04 기존 데이터 검사 후 무결성 규칙 추가
-- 시작 상태: 02_normalization_seed.sql 실행 완료, C-01~C-08 규칙은 아직 없음
-- 완료 상태: NOT NULL·UNIQUE·CHECK·FOREIGN KEY·부분 고유 인덱스 적용
-- 전체 작업을 하나의 트랜잭션으로 실행합니다. 오류가 나면 ROLLBACK 후 원인을 확인하세요.

SELECT current_database();
SELECT current_user;
SELECT current_schema();
SHOW search_path;

BEGIN;

DO $$
DECLARE
    v_null_member_count bigint;
    v_null_book_count bigint;
    v_null_loan_count bigint;
    v_duplicate_email_count bigint;
    v_duplicate_isbn_count bigint;
    v_blank_member_count bigint;
    v_blank_book_count bigint;
    v_invalid_date_count bigint;
    v_orphan_member_count bigint;
    v_orphan_book_count bigint;
    v_active_duplicate_count bigint;
BEGIN
    IF current_database() <> 'ai_database_book' THEN
        RAISE EXCEPTION
            '규칙 추가 중단: 현재 데이터베이스는 %입니다. ai_database_book에 연결하세요.',
            current_database();
    END IF;

    IF current_setting('transaction_read_only')::boolean THEN
        RAISE EXCEPTION '규칙 추가 중단: 현재 연결이 읽기 전용입니다.';
    END IF;

    IF to_regclass('public.members_nf') IS NULL
       OR to_regclass('public.books_nf') IS NULL
       OR to_regclass('public.loans_nf') IS NULL THEN
        RAISE EXCEPTION
            '규칙 추가 중단: 정규화 후 테이블이 모두 존재하지 않습니다.';
    END IF;

    -- 같은 제약조건 이름이 다른 테이블·스키마에 있어도 오탐하지 않도록 대상 테이블까지 확인합니다.
    IF EXISTS (
        SELECT 1
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
               ))
    ) OR to_regclass('public.uq_loans_nf_active_book') IS NOT NULL THEN
        RAISE EXCEPTION
            '규칙 추가 중단: Chapter 06 무결성 규칙이 이미 존재합니다.';
    END IF;

    SELECT COUNT(*) INTO v_null_member_count
    FROM public.members_nf
    WHERE name IS NULL OR email IS NULL OR joined_at IS NULL;

    SELECT COUNT(*) INTO v_null_book_count
    FROM public.books_nf
    WHERE title IS NULL OR author IS NULL OR isbn IS NULL;

    SELECT COUNT(*) INTO v_null_loan_count
    FROM public.loans_nf
    WHERE member_id IS NULL
       OR book_id IS NULL
       OR borrowed_at IS NULL
       OR due_at IS NULL;

    SELECT COUNT(*) INTO v_duplicate_email_count
    FROM (
        SELECT email
        FROM public.members_nf
        GROUP BY email
        HAVING COUNT(*) > 1
    ) AS duplicated_emails;

    SELECT COUNT(*) INTO v_duplicate_isbn_count
    FROM (
        SELECT isbn
        FROM public.books_nf
        GROUP BY isbn
        HAVING COUNT(*) > 1
    ) AS duplicated_isbns;

    SELECT COUNT(*) INTO v_blank_member_count
    FROM public.members_nf
    WHERE char_length(trim(name)) = 0;

    SELECT COUNT(*) INTO v_blank_book_count
    FROM public.books_nf
    WHERE char_length(trim(title)) = 0;

    SELECT COUNT(*) INTO v_invalid_date_count
    FROM public.loans_nf
    WHERE due_at < borrowed_at
       OR (returned_at IS NOT NULL AND returned_at < borrowed_at);

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

    SELECT COUNT(*) INTO v_active_duplicate_count
    FROM (
        SELECT book_id
        FROM public.loans_nf
        WHERE returned_at IS NULL
        GROUP BY book_id
        HAVING COUNT(*) > 1
    ) AS duplicated_active_books;

    IF v_null_member_count <> 0
       OR v_null_book_count <> 0
       OR v_null_loan_count <> 0
       OR v_duplicate_email_count <> 0
       OR v_duplicate_isbn_count <> 0
       OR v_blank_member_count <> 0
       OR v_blank_book_count <> 0
       OR v_invalid_date_count <> 0
       OR v_orphan_member_count <> 0
       OR v_orphan_book_count <> 0
       OR v_active_duplicate_count <> 0 THEN
        RAISE EXCEPTION
            '규칙 추가 중단: null_member=%, null_book=%, null_loan=%, duplicate_email=%, duplicate_isbn=%, blank_member=%, blank_book=%, invalid_date=%, orphan_member=%, orphan_book=%, active_duplicate=%',
            v_null_member_count,
            v_null_book_count,
            v_null_loan_count,
            v_duplicate_email_count,
            v_duplicate_isbn_count,
            v_blank_member_count,
            v_blank_book_count,
            v_invalid_date_count,
            v_orphan_member_count,
            v_orphan_book_count,
            v_active_duplicate_count;
    END IF;
END
$$;

-- C-01·C-03: 회원 필수값·이메일 고유성·공백 이름 금지
ALTER TABLE public.members_nf
    ALTER COLUMN name SET NOT NULL,
    ALTER COLUMN email SET NOT NULL,
    ALTER COLUMN joined_at SET NOT NULL,
    ADD CONSTRAINT uq_members_nf_email UNIQUE (email),
    ADD CONSTRAINT chk_members_nf_name_not_blank
        CHECK (char_length(trim(name)) > 0);

-- Chapter 05 기존 필수값 + C-02·C-03: 도서 제목·저자 필수, ISBN 필수·고유, 공백 제목 금지
ALTER TABLE public.books_nf
    ALTER COLUMN title SET NOT NULL,
    ALTER COLUMN author SET NOT NULL,
    ALTER COLUMN isbn SET NOT NULL,
    ADD CONSTRAINT uq_books_nf_isbn UNIQUE (isbn),
    ADD CONSTRAINT chk_books_nf_title_not_blank
        CHECK (char_length(trim(title)) > 0);

-- C-04~C-07: 대여 필수값·날짜·참조·삭제 규칙
ALTER TABLE public.loans_nf
    ALTER COLUMN member_id SET NOT NULL,
    ALTER COLUMN book_id SET NOT NULL,
    ALTER COLUMN borrowed_at SET NOT NULL,
    ALTER COLUMN due_at SET NOT NULL,
    ADD CONSTRAINT fk_loans_nf_member
        FOREIGN KEY (member_id)
        REFERENCES public.members_nf(id)
        ON DELETE RESTRICT,
    ADD CONSTRAINT fk_loans_nf_book
        FOREIGN KEY (book_id)
        REFERENCES public.books_nf(id)
        ON DELETE RESTRICT,
    ADD CONSTRAINT chk_loans_nf_due_date
        CHECK (due_at >= borrowed_at),
    ADD CONSTRAINT chk_loans_nf_returned_date
        CHECK (returned_at IS NULL OR returned_at >= borrowed_at);

-- C-08: 현재 미반납 대여는 도서당 최대 한 건
CREATE UNIQUE INDEX uq_loans_nf_active_book
ON public.loans_nf (book_id)
WHERE returned_at IS NULL;

-- 적용 결과를 커밋 전에 검증합니다.
DO $$
DECLARE
    v_constraint_count bigint;
    v_not_null_count bigint;
BEGIN
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
            '규칙 적용 검증 실패: constraints=%, not_null_columns=%, active_index=%',
            v_constraint_count,
            v_not_null_count,
            to_regclass('public.uq_loans_nf_active_book');
    END IF;
END
$$;

COMMIT;

-- 적용 결과 확인
SELECT
    conrelid::regclass AS table_name,
    conname AS constraint_name,
    contype AS constraint_type
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
       ))
ORDER BY conrelid::regclass::text, conname;

SELECT to_regclass('public.uq_loans_nf_active_book') AS active_loan_unique_index;
